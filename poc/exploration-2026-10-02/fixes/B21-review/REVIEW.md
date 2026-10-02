# B21 work traffic yield review

Prepared patch: `b21-final.patch`; source snapshot: `source-final/`.

Patch SHA256: `d530d49e8532bef88dbfd090ede323b7e6b4fac4a08db3341a700804cbee9579`.

## Confirmed causes and bounded change

* Stalled travelling build/repair/gather units were excluded from ally yielding. The three direct old-source policy controls fail consistently.
* Route retries and accepted recovery jobs reset route_stalled_time even while a worker remains physically stationary. The fix adds an independent travel_stalled_time measured from physical position, cleared by >2px displacement, a new goal/stop range, arrival, or route/order reset. It does not change route retry timing or normal move/attack_move admission.
* Six original sidestep directions omit longitudinal retreat. A legal three actor fixture at the actual villager 0.05-second displacement (4.52px) isolates this: with the new timer present in both versions, only removal of the two appended angles produces the red control. Existing direction preference is retained.
* Workers require a valid live target, finite route goal, nonnegative stop distance, true travel stall >=0.9, and both actual-target and cached-goal distances outside stop_distance+0.5. Workers already working, hold units, enemies, and higher-priority actors remain protected. Orders/targets/queues and collision/speed checks are preserved. Residual group stall is not used for workers.

## Targeted evidence

`final-targeted-results.json` records exact commands, hashes, and all final targeted runs. Two frozen exact B05 runs each pass 113 checks; a legal-only B05 candidate passes all six original seven actor oracles. Tests retain 96 legal sites, original snapped narrow layout, seven original positions, 2600 x 0.05-second deadline, complete construction/queues, no teleport, and no overlap. The added three actor witness passes 7/7 with eight angles and fails 2/7 with six angles while all other source and timer state remain identical. Its second red diagnostic requires the caller's next step to be clear; it does not imply any actor actually overlapped.

Old-source seven actor recovery is scheduling dependent: one frozen legal-only run ends at 95/96 and unfinished queues (two deadline failures), while another exact B05 old run passes. Earlier old runs remained 89/96. These outcomes are retained; the report does not claim a deterministic old-source failure on every run. The direct policy and angle witnesses isolate the confirmed causes without relying on retrying for a green result.

The final test fixes the repair fixture to the actual production stop range (no +4), uses a physically clear +0.4 arrival epsilon for productive work, and isolates moved target position with a Node2D to avoid a moving footprint making the guard test pass trivially. Independent infrastructure review separately passed 172 policy controls and 12 actual physical stall controls for the same business implementation.

## Limits and publication

Root is running the available headless regression and 63 PoC cases. The native test environment is blocked before normal window startup; 18 native tests remain unverified. Full testing is not complete. No commit or push has been made for B21, and no main business source or git metadata was changed by this subagent.
