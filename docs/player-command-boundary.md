# Player command boundary

`PlayerActions` constructs the complete selection command catalog and owns action callbacks, generation IDs, selection identity, hotkeys, command paging and hidden-page eligibility. Its descriptors contain label, icon kind, description, cost, key, action ID, visibility and grid slot; they contain no Controls. Rebuild emits a synchronous `rebuilt` signal after the catalog is complete.

`RtsGameHudUi` renders that catalog, retains button arrays for presentation/inspection, and forwards action IDs. It no longer chooses training/research/build commands or registers callbacks. Age choice and selection view refresh are presentation requests emitted by the catalog. The assembly injects `PlayerInput._gameplay_input_allowed` as the single interaction query used by both keyboard routing and action execution, so the catalog does not inspect concrete overlays. Null-HUD feedback/refresh bridges permit commands to run before UI creation.

Gameplay availability is rechecked when executing; a changed selection invalidates old commands even before rebuild, and rebuilding expires every prior ID. Page visibility is calculated before a renderer sees descriptors. Hidden commands and their shortcuts cannot execute. All original command ordering, mixed-producer union, market, landmark/naval abilities, formation/stance, and fixed stop/page controls are preserved.

Catalog callbacks can capture the catalog itself. The scene's exit hook and predelete notification clear the registry to release those callbacks. Predelete also covers games that never entered the scene tree. The headless catalog fixture leaves live callbacks in place, frees the game without explicit cleanup, and checks a weak reference to confirm the catalog is released.

## HUD resolution regression

Commit `951f708607f64cbfef5e3f8eee8e64af86ddae0a` intentionally changed the normal bottom HUD floor from 230 to 241 pixels. `hud_resolution.gd` still expected 230 pixels and incorrectly equated a 216px minimap plus 14px padding with the 241px HUD. The test now separately asserts the existing 241px HUD upper bound, 230px minimap frame, bottom alignment, inside-HUD placement, and visible queue/feedback. The 300px upper bound for large text remains unchanged.

Once the outdated first assertion was corrected, the large-text check exposed a real layout issue: the production floor reserved an additional empty status label line even though normal production shows its progress in the bar and queue icons. At 200% text, that unnecessary line inflated the floor to 325px. Empty status labels are now hidden, and the stable town-center floor excludes that unused row. Nonempty construction/farm/resource status labels still render and the container's actual minimum size still prevents clipping. `hud_queue_layout` and `hud_command_pages` verify that selection, enqueue/cancel, and page changes do not move the outer panels.

## Verification

The new `tests/player_command_catalog.gd` constructs the real game script without adding the main scene or creating any HUD. It checks construction, execution-time resource validation, stale selection and generation IDs, hidden pages, direct keyboard execution, an injected interaction block, paging and fixed stop, age-choice requests, mixed producers, production execution, and enemy inspection.

Targeted regressions include `player_input_actions_regression`, `build_selection`, `smoke`, `hud_resolution`, `hud_queue_layout`, `hud_command_pages`, `enemy_inspection`, `chinese`, `strategic_expansion`, `aoe4_requested_systems`, `landmark_roles`, `production_queue_regression`, and `match_changes`. The parent integration runs the full suite after applying this change with the other refactors.
