%% Inspect the archived experiment without rerunning optimization.
project_dir = fileparts(mfilename('fullpath'));
results_dir = fullfile(project_dir, 'results');
saved = load(fullfile(results_dir, 'higgs_rq12_results.mat'), 'results');
results = saved.results;
decisions = readtable(fullfile(results_dir, 'higgs_rq12_decisions.csv'));
summary = readtable(fullfile(results_dir, 'higgs_rq12_summary.csv'));
disp(summary);
fprintf('\nArchived experiment version: %s\n', results.code_version);
fprintf('Complete decisions: %d of %d\n', ...
    sum(decisions.comparison_complete), height(decisions));
fprintf('Cost and speedup refer to normalized gradient work.\n');
