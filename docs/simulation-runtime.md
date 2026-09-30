# Explicit match simulation steps

Live `game._process(delta)` updates presentation and calls `game.step(delta)`. The
same public step drives headless long matches and balance probes. Delta remains
caller-controlled: this refactor does not impose fixed-rate catch-up or promise
network determinism.

`match/match_simulation.gd` owns registered live actors and `match_clock.gd` owns
monotonically increasing simulation tick/time within a match. Match logic/AI and
navigation dispatch run first; world actors (weather/objectives), entity actors
in insertion order, then visibility run once. Actors spawned by AI are included
in that step; actors born during entity callbacks start on the next step. Queued
and disabled actors are skipped, and reentrant or invalid steps are rejected.

Registration takes ownership after Node.ready, when Godot has enabled scripted
callbacks. Automatic actor processing is disabled to prevent double ticks. UI,
previews and remembered fog visuals retain their own presentation callbacks.
Use `simulation.set_actor_enabled(actor, false)` to suspend a managed actor, or
set its `process_mode` to DISABLED. Direct `_process` calls remain available for
isolated behavior tests and minimal navigation fixtures.

A paused/ended/not-started match does not advance its clock or dispatch searches;
completed background work can still be reaped. Restart resets time and retires
old actors through the existing registry. In-flight projectiles have a separate
transient disposal path at end/reset so fixed-target splash attacks cannot leak
into a new match. Simulation does not flush SceneTree's
deferred deletion queue synchronously; accelerated harnesses await a real frame
between steps to drain that queue, not to advance navigation/group epochs.

Navigation, spatial indexing and movement groups use an explicit simulation
epoch during simulation and its following presentation. Reset restores the
engine-frame fallback until the first step; standalone fixtures keep that fallback.
The namespaces cannot alias. Repeated steps in one rendering frame therefore update geometry and
spatial caches without forcing a whole-world invalidation or manually resetting
movement-group last_frame.

`tests/simulation_runtime.gd` covers independent time, exact once processing,
suspension, disabled actors, birth/death boundaries, reentrancy, pause/end,
invalid deltas and restart. `tests/ai_long_match.gd` and `balance_multiseed.gd`
use the production driver. The fixed-step battle benchmark now reports the
complete match simulation as `simulation`, with presentation CPU as `other_cpu`;
these labels should not be compared directly to older unit-only timings.
