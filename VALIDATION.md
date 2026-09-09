# Release validation

The repository's `python analysis/analyze_results.py` entry point was executed
successfully against the archived data on 2026-09-09, using Python 3.12.14 and
the dependency versions in `analysis/requirements.txt`.

- 950 numerical/data checks passed, including CSV/MAT consistency, sample
  standardization, nested subsets, reference residuals, first-hitting counts,
  cost identities, allocation formulas, and distance inequalities.
- 7 high-fidelity trajectories were independently replayed.
  Maximum absolute objective-value difference: 1.266e-14.
- The diagnostic PNGs and two paper PDFs were regenerated successfully.
- The experiment generator is byte-for-byte identical to the supplied
  `HIGGS_RQ12_20260909` source. The public MATLAB runner uses relative paths.
- Local homepage asset links and packaged file checksums were verified.

MATLAB is unavailable in the packaging environment. The new portable MATLAB
runner was inspected but was not executed here. The archived experiment was
provided from the completed MATLAB run; the original MATLAB release was not
recorded. The static homepage was checked structurally but has not been visually
rendered in a browser here or verified on a deployed GitHub Pages URL.

These checks establish consistency of this archive. They do not establish
performance on other datasets or execution environments.
