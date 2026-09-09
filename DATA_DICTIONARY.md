# Result data dictionary

The original numeric CSVs and MAT files are preserved. `NaN` denotes an
unresolved or undefined value; it must not be replaced by a successful iteration limit.

## CSV tables

| File | Row unit | Archived rows |
| --- | --- | ---: |
| `higgs_rq12_raw.csv` | Subset seed / ratio / tested K1 / accuracy target | 510 |
| `higgs_rq12_decisions.csv` | Subset seed / ratio / accuracy target | 27 |
| `higgs_rq12_summary.csv` | Ratio / accuracy target, summarized over seeds | 9 |

## Shared settings and measurements

| Column | Meaning |
| --- | --- |
| `seed` | Low-fidelity nested-subset seed |
| `r_requested`, `r_actual` | Requested and realized low/high sample ratios |
| `n_low`, `epsilon` | Low-fidelity sample size and high-fidelity objective-gap target |
| `L1`, `L2`, `mu` | Global smoothness constants; common strong-convexity constant |
| `R1`, `R2` | Reference distances from zero to the low/high minimizer |
| `Delta` | Distance between the reference minimizers |
| `K1` | Tested low-fidelity iterations; zero is direct high-fidelity AGD |
| `K2_gap` | First high-fidelity iterate reaching the target; may be zero |
| `cost` | `r_actual * K1 + K2_gap` |
| `direct_cost` | Direct high-fidelity first-hitting count |
| `cost_over_direct` | Tested cost divided by direct cost |
| `target_reached` | 1 when this candidate reaches this target |
| `hf_iterations_run` | Length of the shared high-fidelity trajectory, not the first hit for each target |
| `warm_gap`, `warm_distance` | High-fidelity objective gap and minimizer distance at transfer |
| `transfer_distance_bound` | Rate-plus-minimizer-gap bound at transfer |
| `comparison_complete` | 1 when all required candidate comparisons are resolved |

## Allocation and performance columns

| Column | Meaning |
| --- | --- |
| `K1_continuous` | Continuous positive warm-start minimizer of the sufficient-cost model |
| `K1_warm` | Preferred positive integer neighbor before comparing with direct AGD |
| `K1_selected` | Executable theoretical decision; zero if direct AGD is selected |
| `K1_empirical` | Best tested budget, with ties favoring the smaller budget |
| `direct_bound`, `warm_bound`, `selected_bound` | Corresponding sufficient costs |
| `selected_cost`, `empirical_cost` | Observed work for the selected and best tested budgets |
| `regret` | `selected_cost / empirical_cost - 1`, stored as a fraction |
| `speedup` | `direct_cost / selected_cost` |
| `theory_warm` | 1 if the model selects a positive budget |
| `empirical_warm` | 1 if any tested positive budget strictly improves on direct AGD |
| `agreement` | Equality of these two warm/direct labels |
| `harmful_selected_warm` | Positive selected budget is more expensive than direct AGD |
| `candidate_count`, `reached_candidates` | Numbers of tested and resolved candidates |
| `low_reference_grad_norm`, `high_reference_grad_norm` | Reference-solve residuals |

Summary suffixes `_median`, `_min`, and `_max` refer to the three subset seeds.
`regret_pct_*` stores percentages. `n_complete`, `n_unresolved`,
`n_regret_valid`, and `n_speedup_valid` record the corresponding valid denominators.
`*_count` fields count the relevant Boolean labels across seeds.

## MATLAB archive

`higgs_rq12_results.mat` contains `results` with `config`, `signature`,
`sampling`, `high`, `runs`, and the exported `raw`, `decisions`, and `summary` tables.
`runs{seed_index, ratio_index}` retains low-fidelity indices, references,
low-fidelity iterates, high-fidelity trajectories, and budget decisions.
Array indices are one-based in MATLAB; stored subset/source indices retain
that convention when read in Python. The archive includes historical source
and output paths as provenance; the public runners use repository-relative paths.
