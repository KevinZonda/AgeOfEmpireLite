# Navigation ownership and deferred route admission

`RtsNavigation` remains the query facade and owns scene references. The refactor separates three lifetimes without changing the public synchronous query contract:

- `navigation_cache.gd` owns geometry grids, fine-grid eviction containers, component labels/sizes, corner graphs and their revisions. Rebuild clears every derived container together. Container identity is stable, so the facade can expose existing dictionaries through direct aliases rather than property calls in hot loops. Scalar compatibility properties remain available.
- `navigation_spatial_index.gd` owns live unit/resource/building buckets, maximum body radius and indexed collection counts. Rebuilding happens at most once per engine frame unless collection counts or explicit invalidation change. Unit and wildlife displacement update current-frame buckets immediately. The facade's read-only admission guard avoids adding a helper call to every collision query.
- `navigation_route_jobs.gd` admits ordinary `path_between` and interaction `path_to_range` requests on the main thread. Recovery workers continue to use `navigation_jobs.gd` and isolated value snapshots. Ordinary queries still access live objects and shared geometry; they do not execute on worker threads.

A geometry revision invalidates route collision checks. A separate structural revision wakes failed-route backoff. Living wildlife position changes update live collision buckets without rebuilding expensive geometry or waking every unreachable worker; a live-to-dead wildlife transition is included in the signature. Static resource relocation changes geometry but preserves failed-route backoff, while building ownership/footprint/completion changes and explicit terrain edits wake it. Terrain edits must call `invalidate_obstacles()`; terrain mutation is not polled by hashing every map cell.

## Route request contract

Budgeted admission is opt-in: `RTS_ROUTE_BUDGET=1`. The default synchronous movement behavior remains available. The live game must enable `navigation.route_budget_enabled` from that flag, call `tick_jobs(started and not paused and not game_over)` each engine frame, and call `shutdown_jobs()` on reset and teardown.

The FIFO holds at most 512 pending requests, coalesces per unit, and processes at most 64 searches with a 4 ms **soft** dispatch budget per frame. Native A* and fine-grid construction are not preemptible; one cold search may exceed the budget. Metrics expose total search time, maximum single-query and tick times, admission/update/discard counts, and queue depth. This is gradual admission, not a guarantee of 4 ms frames.

A pending unit waits without increasing failure counts or retry backoff. Moving endpoints update an existing pending request in place, retaining its ticket and queue position; otherwise a moving formation could repeatedly move the last unit to the queue's tail. Completed results remain immutable and must pass order generation, owner, radius, land/water type, geometry revision, endpoint/range and origin-displacement checks. Targets drifting up to half a map cell preserve the existing route-reuse tolerance; larger changes discard the result. Accepted paths start at the unit's current position. When a direct shortcut to the next waypoint crosses a corner, the original safe grid connector must be retained, even when it is less than one pixel away. Movement skips a nearby connector only when the following segment is clear. Every connector is reached through normal speed-limited movement, with no assignment from a captured origin.

New commands, unit death, reaching interaction range, garrisoning and scene reset release requests. Cancellation with no request returns immediately rather than scanning the army's pending queue. Pausing prevents fresh ordinary/range searches and recovery snapshot dispatch; already completed workers can still be reaped safely. `tick_jobs(..., simulation_frame)` optionally accepts a deterministic simulator's frame epoch; production uses `Engine.get_process_frames()` by default.

Group planning, nearest-destination sampling, collision queries, and the ordinary/range search kernels themselves remain synchronous. Enabling admission changes when units acquire paths, so comparisons must report progress and pending work alongside CPU timing. The mode is opt-in because a congested army can trade fewer expensive searches in one frame for delayed path acquisition; a lower average frame time alone is insufficient evidence to enable it by default.

## Verification

`tests/navigation_boundaries.gd` covers cache invalidation, same-frame wildlife buckets, structural versus resource-motion revisions, FIFO budget admission, normal/range equality against synchronous paths, pending target drift, stale-result rejection, pause/reset/death, bounded queue capacity, origin rebasing, reached-range cleanup and eventual move/attack arrival. Every movement step checks speed and terrain safety.

The existing navigation suite also covers worker snapshot equivalence, dense collision geometry, deer movement, failed-route backoff, construction, group chokepoints and land/water routes. `navigation_range_corner_poc` has a pre-existing origin-sweep-count failure also reproduced on the original source; the existing runner excludes that test from its navigation suite.

For serial fixed-workload comparisons:

```sh
RTS_ROUTE_BUDGET=0 godot --headless --path . --script tests/performance_navigation.gd
RTS_ROUTE_BUDGET=1 godot --headless --path . --script tests/performance_navigation.gd
RTS_ROUTE_BUDGET=0 RTS_BENCH_STEPS=180 godot --headless --path . --script tests/performance_400.gd
RTS_ROUTE_BUDGET=1 RTS_BENCH_STEPS=180 godot --headless --path . --script tests/performance_400.gd
```

Both benchmark modes time the same 180 simulated frames. `performance_navigation` additionally reports median/max remaining distance and, after the timed sample, verifies all budgeted units eventually arrive. `performance_400` uses map seed 4242 and reports units that moved more than 10 pixels plus pending work. Results measure headless CPU time, not window FPS; scheduling changes trajectories and admission delay, so they are not exact replay comparisons.

## Recorded isolated-branch diagnosis

Serial original/final/final/original runs of the 400-unit independent-movement benchmark measured average frame times of **5.67 / 5.86 / 5.88 / 5.69 ms**. Typed helper references, shared container aliases and direct hot-loop field reads removed the earlier large dynamic-property overhead; the final ownership boundary still costs about **0.19 ms (3.3%)** in this isolated comparison. Every unit had the same 520-pixel remaining distance at the 180-frame sample. These runs isolate the navigation changes and exclude the other parallel refactors.

The final 400-unit seed-4242 crowded-army benchmark compares the same updated simulation driver with ordinary route admission disabled/enabled. Off/on averages were **70.7 / 60.4 ms**, P95 **99.4 / 106.6 ms**, and maximum **1001.2 / 930.2 ms**. Units moving more than 10 pixels were **323 / 311**; budgeted admission retained five pending requests after the sample. One native query took **82.7 ms**, exceeding the 4 ms soft budget. Thus the optional mode improved this run's average while delaying some movement and worsening P95; it remains opt-in. No window-FPS or general tail-latency improvement is claimed.

Raw output, original source revision, final file hashes and exact settings are archived in [navigation-boundaries.json](battle-overhead/navigation-boundaries.json). Single crowded-army samples are diagnostics, not stable performance guarantees. The final integrated branch should be checked separately after the other refactors are combined.

## Combined refactor verification

After all four refactors and the necessary fine-grid connector correction were integrated, serial off/on/on/off runs of the same 400-unit, seed-4242 workload measured synchronous averages of **74.2 / 72.9 ms** and budgeted averages of **62.5 / 60.0 ms**. Synchronous P95 was **106.6 / 108.0 ms**, while budgeted P95 was **101.7 / 102.2 ms**. Synchronous movement progressed **330 / 330** units, versus **307 / 314** with budgeting, leaving **2 / 3** requests pending. Maximum individual budgeted searches still took **132.7 / 84.8 ms**. These compare two modes of the combined implementation, not the original system.

Independent 400-unit movement averaged **5.87 / 5.86 ms** synchronously and **6.23 / 6.21 ms** with budgeting. All budgeted units eventually arrived in the untimed follow-up. The timed sample retained more remaining distance under budgeting (**530.7** median / **538.7** maximum pixels, versus **520** synchronously). The crowded benchmark's P95 direction differs from the isolated branch sample, further limiting any general performance claim. Budgeting remains opt-in. Raw repeated output and combined source hashes are archived in [refactor-integrated.json](battle-overhead/refactor-integrated.json).
