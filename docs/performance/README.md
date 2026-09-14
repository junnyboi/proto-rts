# Runtime benchmark

`tools/benchmark_runtime.gd` measures the original four-player opening for 60
simulated seconds at 30 ticks per second. The human player issues no commands;
the three default AIs, wildlife, map, balance and animation settings are unchanged.
It emits one `ACCEPTANCE_JSON` line containing three 600-tick timing windows,
profiled simulation phases, state hashes and a digest of every drained event.

Run it using Godot 4.7.2 after normal project imports are ready:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --audio-driver Dummy --path /Users/jun/Documents/Projects/Games/proto-rts --script /Users/jun/Documents/Projects/Games/proto-rts/tools/benchmark_runtime.gd
```

For a before/after comparison, keep the unmodified project in a separate temporary
directory, initialize its imports, then run the **same absolute benchmark script**
with `--path` pointing at that baseline directory. The script resolves
`RtsSimulation` from the chosen project. Do not run imports, exports, the full test
suite or other benchmarks concurrently with timing measurements. Alternate fresh
processes in baseline/candidate/candidate/baseline/baseline/candidate order and keep
all six JSON records. Compare medians on the same machine and engine build.

Each 20-second state hash includes every authoritative entity and player record,
elapsed time/outcome, all three wander RNG states, and all teams' visible/explored
cells. The event digest includes tick numbers and empty event batches as well as
events. Equality proves these recorded states and the complete event stream agree
for this bounded fixture; it is not a claim about every possible match.

The focused correctness gate compares the optimized implementations against the
frozen original separation, visibility and path-query algorithms in
`tests/support/runtime_reference.gd`:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --audio-driver Dummy --path /Users/jun/Documents/Projects/Games/proto-rts --script tests/runtime_equivalence_test.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --audio-driver Dummy --path /Users/jun/Documents/Projects/Games/proto-rts --script tests/runtime_performance_test.gd
```

On shared CI runners, set `RTS_REPORT_ONLY_TIMINGS=1` for the performance smoke
test. This only disables its wall-clock ratio failure. The deterministic
equivalence checks and the opening broad-phase candidate reduction remain hard
gates. The smoke test uses shorter alternating runs; the 60-second benchmark is
the acceptance measurement.

The recorded September 14 comparison is in
`runtime-before-after-2026-09-14.json`. Median mean tick time fell from 12.12 ms to
5.01 ms (58.6%). Median p95 values for the three windows changed from
11.82/13.52/15.40 ms to 5.07/5.77/6.97 ms. All six runs produced the same state,
RNG, vision and event hashes. The opening broad phase considers 74 candidate pairs
per pass rather than 4,278. These are native simulation timings, not browser frame
rate or GPU measurements. Content reductions were not part of the comparison.

Authoritative dead-unit dictionaries retain their existing lookup contract.
This change does not claim to eliminate historical dead-record memory growth;
only existing renewable-wildlife retirement remains in place.
