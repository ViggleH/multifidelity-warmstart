# Current publication data

The manuscript uses completed iterations, with `Cost_obs = c1*K1 + c2*K2`,
`c1 = r`, and `c2 = 1`. Certificate checks have no separate charge.
The current publication CSVs are authoritative for the paper's results.

## Files

| File | Contents |
| --- | --- |
| `publication_methods.csv` | 108 records, four methods in each of 27 configurations |
| `publication_candidates.csv` | All 870 tested budget/target records |
| `publication_summary.csv` | 36 summaries by ratio, target, and method over three seeds |
| `publication_aggregate.csv` | Four summaries across all 27 configurations |
| `performance_markers.csv` | Values for every method marker in Figure 2 |
| `distance_diagnostics.csv` | Reference distances and certificate bounds for Figure 1 |
| `allocation_summary_table.tex` | The manuscript's compact three-row table |

These files are in `results/` in the repository and `figures/current/` in the
reproduction archive. The `higgs_rq12_*.csv` files in `results/` are historical
MATLAB outputs from 9 September and do not reproduce the current table.

## Fields

| Field | Meaning |
| --- | --- |
| `seed` | Low-fidelity subset seed, 11, 12, or 13 |
| `r` | Low/high sample ratio and normalized low-fidelity iteration cost |
| `epsilon` | Target high-fidelity objective gap, certified by the gradient |
| `method` | `direct`, `initial_certificate`, `cost_comparison`, or `best_tested_fixed` |
| `status` | `complete` for all published method records |
| `low_steps`, `high_steps` | Completed iterations K1 and K2 |
| `c1`, `c2` | Iteration cost weights r and 1 |
| `observed_cost` | c1*K1 + c2*K2 |
| `direct_cost` | Cost of direct high-fidelity AGD at the same target |
| `best_tested_budget`, `best_tested_cost` | Best fixed budget and cost in the tested set |
| `cost_ratio` | direct_cost / observed_cost; above one improves on direct |
| `regret_percent` | 100*(observed_cost / best_tested_cost - 1) |
| `beneficial` | Whether observed cost is strictly smaller than direct cost |
| `candidate_sources` | Provenance of a tested budget in the finite search set |
| `plotted_cost_over_direct` | observed_cost / direct_cost, the Figure 2 vertical coordinate |
| `fixed_budget_cost_at_same_k` | Cost on the matching fixed-budget curve |
| `K_median`, `K_min`, `K_max` | Low-fidelity iteration summaries across subset seeds |
| `ratio_median`, `ratio_min`, `ratio_max` | Direct-to-method cost-ratio summaries |
| `regret_median` | Median percentage regret |
| `runs` | Number of configurations summarized |

In aggregate/summary files, `beneficial` is a count rather than a Boolean.
Figure 1 fields ending in `_reference` use numerical reference minimizers.
Its two `_transfer_bound` columns contain unnormalized bounds; the lower
panels divide each by `transfer_distance_reference`. The upper panels divide
the measured distances by `minimizer_mismatch_reference`.

## Preserved experiment records

The archive includes immutable simulation outputs and checkpoints under
`higgs_cost_comparison_output/`. Those raw files retain an earlier
gradient-call cost convention and a budget-below-one control. The current
paper excludes that control and recomputes costs from the saved iteration
counts using `figures/make_figures.py`. It reselects the best tested fixed
budget under the current cost convention, with ties favoring smaller budgets.
Do not substitute raw `total_work`, speedup, or regret fields for the current
publication values. The three files under `higgs_online_certificate_output/`
preserve earlier candidate-set inputs required by the experiment runner.

There are 27 dependent comparisons on one shared HIGGS sample. They combine
three ratios, three targets, and three subset seeds. The tested-budget
benchmark is retrospective and excludes search costs. These configurations
were used during rule development; they are not a held-out evaluation.
