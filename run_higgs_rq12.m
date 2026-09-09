%% Reproduce the HIGGS RQ1/RQ2 experiment from the full source CSV.
% Place the uncompressed official dataset at data/HIGGS.csv.
% New computations are written to output/higgs_rq12_output.
clear; clc; close all;
project_dir = fileparts(mfilename('fullpath'));
addpath(project_dir);
clear generate_higgs_sensitivity_data
data_file = fullfile(project_dir, 'data', 'HIGGS.csv');
options = struct( ...
    'output_dir', fullfile(project_dir, 'output', 'higgs_rq12_output'), ...
    'make_figures', true, ...
    'verbose', true);
generate_higgs_sensitivity_data('version');
generate_higgs_sensitivity_data('selftest');
results = generate_higgs_sensitivity_data(data_file, options);
fprintf('\nResults saved to:\n%s\n', options.output_dir);
