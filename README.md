# Cost-aware multi-fidelity warm starts

MATLAB experiment code, archived HIGGS results, and Python diagnostics for
iteration allocation in two-level accelerated gradient descent (AGD).

The study compares an allocation derived from a sufficient-cost bound with
observed optimization work. Suitable warm starts reduce work on this instance,
while the theoretical allocation often spends too long at low fidelity.
The distance diagnostics examine this conservatism.

## Start here

- [Summary data](results/higgs_rq12_summary.csv): medians and ranges across subset seeds.
- [Individual decisions](results/higgs_rq12_decisions.csv): all 27 parameter combinations.
- [Raw evaluated budgets](results/higgs_rq12_raw.csv): 510 budget/target records.
- [MATLAB results](results/higgs_rq12_results.mat): references, trajectories, and settings.
- [Experiment sample](data/higgs_high_sample.mat): the standardized high-fidelity data.
- [Data dictionary](DATA_DICTIONARY.md) and [data provenance](data/README.md).

![Empirical cost curves for the three sample ratios](results/higgs_rq1_cost_curves.png)

## Experiment

| Setting | Value |
| --- | --- |
| Objective | L2-regularized binary logistic regression |
| High-fidelity sample | 110,000 stratified HIGGS observations; 28 features |
| Regularization | 0.01 |
| Low-fidelity ratios | 0.05, 0.15, 0.25 |
| Objective-gap targets | 1e-3, 1e-4, 1e-5 |
| High-sample seed | 1 |
| Nested subset seeds | 11, 12, 13 |
| Optimizer | Deterministic varying-momentum AGD; momentum reset at transfer |
| Work measure | `r * K1 + K2_gap` |
| Experiment code version | `HIGGS_RQ12_20260909` |

These settings define nine low-fidelity objectives and 27 seed/ratio/target
combinations. Features use the high-fidelity sample's mean and sample standard
deviation. Changing the sample ratio changes cost, mismatch, and curvature together.

## Inspect the archived results in MATLAB

Open the downloaded repository as MATLAB's current folder and run:

```matlab
view_higgs_results
```

This loads the MAT results and displays the CSV summary. It does not require
the full HIGGS CSV or a new optimization run. The `results` folder contains the
archived outputs; new computations use `output`.

## Reproduce the analysis and figures

The included sample and archived trajectories are sufficient for this step;
the full source dataset is not needed. From the repository root, use Python
3.11 or newer and run:

```bash
python -m pip install -r analysis/requirements.txt
python analysis/analyze_results.py
```

The analysis checks CSV/MAT consistency, cost identities, first-hitting counts,
reference solutions, nested subsets, and distance bounds. It independently
replays the direct high-fidelity trajectory and six representative warm starts,
then regenerates the diagnostic figures and the two paper PDFs.
Outputs are saved to `output/analysis` and `output/figures`.

These checks are specific to the archived experiment. Their expected counts
should be revised if the experiment design changes. The surrogate comparisons
use reference solutions and saved trajectories; they are post-hoc diagnostics.

## Rerun the full MATLAB experiment

1. Download HIGGS from the [UCI dataset page](https://archive.ics.uci.edu/dataset/280/higgs).
2. Extract the headerless CSV to `data/HIGGS.csv`.
3. Open the repository folder in MATLAB and run:

```matlab
run_higgs_rq12
```

The runner displays the code version, runs the synthetic self-test, and starts
the paper experiment. It scans the full CSV once to construct the stratified
high-fidelity sample, then caches it and saves checkpoints under
`output/higgs_rq12_output`. Repeating the command resumes that run.

For a different CSV location:

```matlab
opts = struct('output_dir', fullfile(pwd, 'output', 'new_run'));
results = generate_higgs_sensitivity_data('E:/datasets/HIGGS.csv', opts);
```

Use a new output directory after changing the settings or source file.
The source CSV path, size, and timestamp are part of the cache signature.
The archived MAT files are for inspection and analysis; copying them into a
new run's output directory will not bypass the original cache checks.
The unchanged experiment generator accepts a CSV, not the distributed sample MAT.

MATLAB is required to run the generator. Its helper functions are included in
the same file; earlier separate solver files are not used. The original MATLAB
release was not recorded, and the release package has not been rerun in MATLAB
in the packaging environment. The Python audit is an independent check of the
supplied experiment, not a claim of MATLAB/Octave compatibility.

## Interpretation

- The continuous theoretical budget minimizes a sufficient-cost model.
  The executable decision compares its neighboring positive integers and direct AGD.
- The empirical benchmark is the best **tested** budget, not the optimum over
  every possible integer budget.
- Speedup is normalized gradient work. Preprocessing, reference solves, the
  offline budget search, and diagnostic evaluations are excluded.
- All tested configurations admit a beneficial warm start, so agreement alone
  does not establish the ability to reject unhelpful warm starts.
- Results describe one data instance with three subset seeds. Accuracy targets
  and subsets share trajectories/data, so they are not independent replications.

## File organization

| Path | Contents |
| --- | --- |
| `generate_higgs_sensitivity_data.m` | Original experiment generator and all solver helpers |
| `run_higgs_rq12.m` | Portable runner for a new full experiment |
| `view_higgs_results.m` | MATLAB viewer for the archived outputs |
| `data/` | Standardized experimental sample and provenance |
| `results/` | Archived CSV/MAT outputs and figures |
| `analysis/` | Independent numerical audit and figure scripts |
| `docs/` | Static GitHub Pages project homepage |
| `SHA256SUMS.txt` | Checksums of packaged files, excluding this checksum list |

## Data source and permissions

HIGGS: Whiteson, D. (2014). *HIGGS* [Dataset]. UCI Machine Learning Repository.
DOI: [10.24432/C5V312](https://doi.org/10.24432/C5V312).
UCI distributes HIGGS under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
The included sample is a stratified and standardized derivative; see
[data/README.md](data/README.md) for the transformation and attribution.
No project-wide software license has been assigned in this initial package.

## Publishing the repository and project page

See [PUBLISHING.md](PUBLISHING.md). The homepage is prepared for
`ViggleH/multifidelity-warmstart`; update its repository links if the owner or
repository name changes. The page becomes public after GitHub Pages deployment
succeeds. A local copy of `docs/index.html` can be opened before publication.
