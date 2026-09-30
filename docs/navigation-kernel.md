# Navigation search kernel boundary

`navigation_search_kernel.gd` owns computation shared by ordinary and interaction-range routes:

- Four-neighbor component labels and component sizes, compatible with native A*'s no-corner-cutting diagonal mode.
- Native grid search followed by conservative collision-edge repair. Temporary blocked cells are restored on both success and failure; a repaired grid never populates the shared component cache.
- Lazy corner visibility A*, including bounded endpoint attachments and positive/negative visibility results.
- Interaction-range approach geometry from positions, reach, radius and rectangle footprints, ordered by distance to the source.

The kernel has no scene, unit, map, session, engine-frame or revision dependency. Grid ownership and geometry lifetimes remain explicit at its call boundary. The navigation facade supplies geometry values and synchronous collision/native-search callbacks, retaining subclass collision overrides and profiling. These facade callbacks still read the scene and **must run on the main thread**. A worker may call the kernel only with a private grid/graph and callbacks over owned value data. The new worker regression demonstrates that contract without a world or unit fixture; ordinary/range route admission itself remains synchronous and opt-in. This change does not promise a hard frame budget or enable ordinary-route threading.

## Sealed-origin regression

`navigation_range_corner_poc` previously checked all origin-to-corner attachments once but repeated the zero-length strict origin-validation sweep for every target. Forty targets produced **55 origin sweeps** (16 on the first target), failing its unchanged cache assertion. A bounded strict-endpoint validity cache now retains both accepted and rejected endpoints before creating a corner graph. The same test produces **16 total / 16 first-target origin sweeps** and passes all 45 checks.

The cache key includes owner, body radius and land/water type. Geometry rebuild clears endpoint validity together with graph edges and attachments. Wildlife movement invalidates only endpoint checks and cached visibility segments intersecting the swept old/new animal footprint, expanded by the graph body radius. Both positive and negative results must be invalidated so animals entering and leaving a route are observed. Conservative graph and endpoint coverage bounds skip distant herds before scanning cached work. Corner candidates depend only on static terrain/buildings/resources, so a moving animal cannot permanently omit a usable corner; actual route edges retain strict live-animal collision checks. Coarse/fine grids and both geometry/retry revisions remain unchanged on wildlife motion.

Normal resource-overlap escape, corner connectors, bounded route admission, FIFO target updates, cancellation, stale-order rejection, pause and reset retain their contracts.

## Verification

`tests/navigation_search_kernel.gd` has 330 checks. It compares component reachability against native A*, lazy corner lengths against an independent exhaustive Dijkstra implementation, validates safe edge repair and restoration, exercises negative-attachment reuse beyond LRU capacity, checks interaction candidates and runs an owned-grid worker with no scene inputs.

`tests/navigation_kernel_geometry.gd` has 128 checks covering endpoint rejection before graph creation, bounded endpoint storage, owner/radius isolation, static-resource invalidation, mobile-wildlife positive/negative endpoint and edge invalidation, stable corners initially occupied by animals, and preservation of cached graph/edges/attachments during distant-herd motion without grid/retry churn.

Targeted facade regressions pass: `navigation_range_corner_poc`, `navigation_boundaries`, `navigation_corner_poc`, `navigation_search_work`, `navigation_async_poc`, `navigation_range_siege_poc`, `navigation_range_stall_poc` `navigation_segment_broadphase_poc` and `navigation_wildlife_churn_poc`. The unchanged wildlife retry-cost assertion passes with warm/moving-animal samples of **354.4 / 356.3 ms** for ten retries; global graph invalidation had violated that threshold and has been replaced by selective swept-footprint invalidation.

The sweep-count reduction is an exact work comparison for this sealed-origin case. It is not evidence of a general game-frame improvement. Native A*, fine-grid building, scene collision checks and ordinary/range scheduling can still produce long frames.

A serial original/final/final/original diagnostic of independent 400-unit movement (180 steps) measured original averages **4.90 / 5.01 ms** and final averages **4.94 / 5.00 ms**. All samples had the same **520-pixel median and maximum remaining distance**. Concurrent functional test processes elsewhere can affect these timings, so this is only a regression diagnostic; the integrated branch requires its own serial measurements. The sealed-origin loop measured original **2.72 / 2.83 ms** and final **2.03 / 2.01 ms**, with the unchanged origin-sweep assertion failing twice before and passing twice after.
