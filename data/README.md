# Numerical data archive

**Article:** Cost-Aware Iteration Allocation for Sequential Multi-Fidelity First-Order Optimization  
**Authors:** Zhongda Huang; Amir Ardestani-Jaafari; Warren Hare  
**Target journal:** Journal of Global Optimization  
**Corresponding author:** Warren Hare, Department of Mathematics, University of British Columbia,
3187 University Way, Kelowna, BC V1V 1V7, Canada; warren.hare@ubc.ca

[Download ESM_1.zip](ESM_1.zip?raw=true) (21,469,581 bytes).

SHA-256:
```text
8b5819a835d47dbce43bbdc5c6286c85a5293e7a365f4662c0440860e9a6f3bd
```

The archive is the complete numerical package prepared on 9 September 2026.
Its internal documentation calls it Online Resource 1. The package is now
publicly distributed here; that internal label does not assert that a journal
has published or accepted the manuscript.

| File in the archive | Contents |
| --- | --- |
| `higgs_high_sample.mat` | Standardized sample, labels, source indices, and preprocessing statistics |
| `higgs_rq12_results.mat` | Settings, reference solutions, saved optimization trajectories, and decisions |
| `higgs_rq12_raw.csv` | 510 evaluated budget/target records |
| `higgs_rq12_decisions.csv` | 27 seed/ratio/target decisions |
| `higgs_rq12_summary.csv` | 9 ratio/target summaries over three subset seeds |
| `make_figures.py` | Portable source for both manuscript figures |
| `README.pdf` | Data dictionary, attribution, and reproduction instructions |
| `metadata.json` | Article metadata and original-data checksums |
| `SHA256SUMS.txt` | Checksums for every other archive member |

All five CSV/MAT files are preserved byte for byte. The separately browsable
CSVs in `../results` match the archive. The two `.mat` files are supplied inside
the archive. See the [repository README](../README.md) for Python plotting and
MATLAB inspection commands.

## Source data and transformation

Whiteson, Daniel (2014). **HIGGS**. UCI Machine Learning Repository.
[Dataset DOI](https://doi.org/10.24432/C5V312).
[Dataset page](https://archive.ics.uci.edu/dataset/280/higgs).

The source is distributed under [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/).
The included derivative is a stratified sample of 110,000 observations from
the 11,000,000-row source, with 28 standardized features and binary labels.
The MAT file preserves source row indices and the feature mean and standard
deviation. This notice attributes the source dataset; no new project-wide
software license is assigned here.

The measurements describe one high-fidelity instance, three subset seeds,
three sample ratios, and three accuracy targets. They are not 27 independent
data sets. Cost is normalized gradient work, not wall-clock time.
