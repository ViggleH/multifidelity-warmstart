function results = generate_higgs_sensitivity_data(data_file, options)
%GENERATE_HIGGS_SENSITIVITY_DATA HIGGS experiments for RQ1 and RQ2.
% UPDATED: 2026-09-09 | VERSION: HIGGS_RQ12_20260909
% Verify the loaded version without HIGGS data:
%   generate_higgs_sensitivity_data('version');
%
% Save this file as generate_higgs_sensitivity_data.m. All helpers are local;
% the old agd_solver/logistic_l2_objective functions are NOT used.
%
% Run with the paper settings:
%   results = generate_higgs_sensitivity_data('data/HIGGS.csv');
% Or press Run: the default CSV is data/HIGGS.csv beside this file.
%
% Optional overrides (a smaller n_full is a pilot, not the paper experiment):
%   opts = struct('output_dir', 'higgs_rq12_output', 'make_figures', true);
%   results = generate_higgs_sensitivity_data('data/HIGGS.csv', opts);
%
% Small numerical and end-to-end checks, without downloading HIGGS:
%   generate_higgs_sensitivity_data('selftest');
%
% Defaults: n_full=110000, r=[.05 .15 .25], epsilon=[1e-3 1e-4 1e-5],
% high sample seed=1, nested subset seeds=[11 12 13], lambda=.01.
% A CSV is streamed once to sample the HIGH objective from the whole supplied
% file, rather than silently taking its first n_full rows. The sample is
% cached, so subsequent runs do not rescan the CSV.
%
% Outputs (new schema; do not feed into the old analysis script):
%   higgs_rq12_results.mat  results.runs{seed_index,ratio_index}
%   higgs_rq12_raw.csv      one row per seed/ratio/K1/epsilon
%   higgs_rq12_decisions.csv one row per seed/ratio/epsilon
%   higgs_rq12_summary.csv  medians/ranges and completion counts
%   higgs_rq1_cost_curves.png, higgs_rq2_sensitivity.png
%
% Checkpoints are saved after each high-fidelity candidate. Rerunning the
% same command resumes unfinished pairs. Use a NEW output_dir after changing
% experiment settings. Unreached targets are NaN, never successful limits.
% Costs count optimization gradients only: reference solves, preprocessing,
% budget search, and diagnostic objective evaluations are excluded.
% Distances/gaps use accurate reference minimizers; this is an oracle-input
% allocation experiment. The empirical optimum means BEST TESTED budget.
% Integer theory selection compares the two neighbors of the continuous
% optimum and direct solving, not every integer in the ceiled cost model.
% RQ2 varies sample ratio and accuracy at fixed lambda; subset size also
% changes L1 and Delta, so these are coupled effects, not isolated causality.

code_version = 'HIGGS_RQ12_20260909';
if nargin >= 1 && strcmpi(char(data_file), 'version')
    results = struct('version', code_version, 'file', mfilename('fullpath'));
    fprintf('Version: %s\nFile: %s.m\n', results.version, results.file);
    return
end
if nargin >= 1 && strcmpi(char(data_file), 'selftest')
    results = selftest_higgs();
    return
end
root = fileparts(mfilename('fullpath'));
if nargin < 1 || isempty(data_file)
    data_file = fullfile(root, 'data', 'HIGGS.csv');
end
if nargin < 2
    options = struct();
end
cfg = default_config(root, options);
say(cfg, 'Version: %s\nFile: %s.m\n', code_version, mfilename('fullpath'));
data_file = char(data_file);
if exist(data_file, 'file') ~= 2
    error('HIGGS:DataFile', 'CSV not found: %s. Pass its actual path.', data_file);
end
[~, ~, ext] = fileparts(data_file);
if strcmpi(ext, '.gz')
    error('HIGGS:CompressedInput', ...
        'Unzip HIGGS.csv.gz first, then pass the path to HIGGS.csv.');
end
[ok, attr] = fileattrib(data_file);
if ok
    data_file = attr.Name;
end
if exist(cfg.output_dir, 'dir') ~= 7
    mkdir(cfg.output_dir);
end
info = dir(data_file);
sample_key = struct('path', data_file, 'bytes', info.bytes, ...
    'datenum', info.datenum, 'n_full', cfg.n_full, 'd', cfg.d, ...
    'seed', cfg.high_seed, 'chunk_rows', cfg.read_chunk_rows);
signature = struct('schema', 'HIGGS_RQ12_v1', 'sample', sample_key, ...
    'settings', rmfield(cfg, {'output_dir', 'make_figures', 'verbose'}));
checkpoint = fullfile(cfg.output_dir, 'higgs_rq12_results.mat');
if exist(checkpoint, 'file') == 2
    old = load(checkpoint, 'results');
    if ~isfield(old.results, 'signature') || ...
            ~isequaln(old.results.signature, signature)
        error('HIGGS:DifferentRun', ...
            'Existing checkpoint has different settings/data. Use a new output_dir.');
    end
    results = old.results;
    results.config = cfg;
    say(cfg, 'Resuming %s\n', checkpoint);
else
    results = struct('signature', signature, 'config', cfg, ...
        'created', datestr(now, 30), 'complete', false, ...
        'r_list', cfg.r_list, 'epsilon_list', cfg.epsilon_list, ...
        'subset_seeds', cfg.subset_seeds, 'c2', 1, ...
        'runs', {cell(numel(cfg.subset_seeds), numel(cfg.r_list))});
end

results.code_version = code_version;
sample = load_high_sample(data_file, cfg, sample_key);
X = sample.X;
b = sample.b;
x0 = zeros(cfg.d, 1);
results.sampling = rmfield(sample, {'X', 'b'});
results.sampling.labels = b;
if ~isfield(results, 'high')
    high.L = logistic_L(X, cfg.lambda);
    say(cfg, 'High reference: n=%d, L=%.6g, mu=%.6g\n', ...
        size(X, 1), high.L, cfg.lambda);
    high.reference = reference_newton(X, b, cfg.lambda, x0, cfg);
    high.dist = norm(x0 - high.reference.x);
    high.direct = agd_high(X, b, cfg.lambda, high.L, x0, ...
        high.reference.f, cfg.epsilon_list, cfg);
    results.high = high;
    results.K_HF = high.direct.first_hit;
    results.Cost_HF = high.direct.first_hit;
    save_checkpoint(checkpoint, results);
end
high = results.high;
say(cfg, 'Direct first-hit counts (epsilon order): %s\n', mat2str(results.K_HF));

for si = 1:numel(cfg.subset_seeds)
    nested = nested_indices(b, round(cfg.r_list * cfg.n_full), cfg.subset_seeds(si));
    for ri = 1:numel(cfg.r_list)
        if ~isempty(results.runs{si, ri}) && results.runs{si, ri}.complete
            continue
        end
        pair_clock = tic;
        idx = nested{ri};
        XL = X(idx, :);
        bL = b(idx);
        if isempty(results.runs{si, ri})
            p = struct();
            p.seed = cfg.subset_seeds(si);
            p.r_requested = cfg.r_list(ri);
            p.indices = idx;
            p.n_low = numel(idx);
            p.c1 = numel(idx) / cfg.n_full;
            p.L_low = logistic_L(XL, cfg.lambda);
            say(cfg, '\nSeed %d, ratio %.3f, n_low=%d: low reference...\n', ...
                p.seed, p.c1, p.n_low);
            p.reference = reference_newton(XL, bL, cfg.lambda, x0, cfg);
            p.dist_low = norm(x0 - p.reference.x);
            p.Delta = norm(p.reference.x - high.reference.x);
            p.theory = theory_decision(p.L_low, high.L, cfg.lambda, ...
                p.dist_low, high.dist, p.Delta, p.c1, cfg.epsilon_list);
            finite_direct = high.direct.first_hit(isfinite(high.direct.first_hit));
            coarse = 0;
            if ~isempty(finite_direct)
                bound = max(finite_direct) / p.c1;
                if bound > 1
                    powers = 2 .^ (0:ceil(log2(bound)));
                    coarse = [coarse, powers(powers < bound)]; %#ok<AGROW>
                end
            end
            p.coarse_K1 = unique([coarse, p.theory.neighbors(:)']);
            p.K1_list = p.coarse_K1;
            p.refinement_done = false;
            p.complete = false;
            p.low_state = empty_low_state(x0);
            p.hf = cell(numel(p.K1_list), 1);
            p.warm_distance = nan(numel(p.K1_list), 1);
            p.warm_gap = nan(numel(p.K1_list), 1);
            % K1=0 reuses the one shared direct trajectory.
            j0 = find(p.K1_list == 0);
            p.hf{j0} = high.direct;
            p.warm_distance(j0) = high.dist;
            p.warm_gap(j0) = high.direct.gap(1);
        else
            p = results.runs{si, ri};
            say(cfg, '\nResuming seed %d, ratio %.3f.\n', p.seed, p.c1);
        end

        while true
            p.low_state = extend_low(p.low_state, max(p.K1_list), ...
                XL, bL, cfg.lambda, p.L_low);
            for j = 1:numel(p.K1_list)
                if ~isempty(p.hf{j})
                    continue
                end
                K1 = p.K1_list(j);
                warm = p.low_state.X(:, K1 + 1);
                p.hf{j} = agd_high(X, b, cfg.lambda, high.L, warm, ...
                    high.reference.f, cfg.epsilon_list, cfg);
                p.warm_distance(j) = norm(warm - high.reference.x);
                p.warm_gap(j) = p.hf{j}.gap(1);
                say(cfg, '  K1=%d, K2=%s (NaN=unreached)\n', ...
                    K1, mat2str(p.hf{j}.first_hit));
                results.runs{si, ri} = p;
                save_checkpoint(checkpoint, results);
            end
            if p.refinement_done
                break
            end
            % Exactly one refinement pass, using the original coarse set.
            extra = [];
            for e = 1:numel(cfg.epsilon_list)
                if ~isfinite(high.direct.first_hit(e))
                    continue
                end
                hits = cellfun(@(h) h.first_hit(e), p.hf);
                costs = p.c1 * p.K1_list(:) + hits;
                finite = find(isfinite(costs));
                if ~isempty(finite)
                    [~, loc] = min(costs(finite)); % K1_list is sorted.
                    best = p.K1_list(finite(loc));
                    extra = [extra, max(0, best - 1), best + 1]; %#ok<AGROW>
                end
            end
            oldK = p.K1_list;
            p.K1_list = unique([oldK, extra]);
            [~, where] = ismember(oldK, p.K1_list);
            newHF = cell(numel(p.K1_list), 1);
            newHF(where) = p.hf;
            newD = nan(numel(p.K1_list), 1);
            newG = newD;
            newD(where) = p.warm_distance;
            newG(where) = p.warm_gap;
            p.hf = newHF;
            p.warm_distance = newD;
            p.warm_gap = newG;
            p.refinement_done = true;
            results.runs{si, ri} = p;
            save_checkpoint(checkpoint, results);
        end

        p.K2_all = cell2mat(cellfun(@(h) h.first_hit, p.hf, 'UniformOutput', false));
        p.Cost_WS_all = bsxfun(@plus, p.c1 * p.K1_list(:), p.K2_all);
        p.R_cost = nan(size(p.Cost_WS_all));
        validDirect = isfinite(results.Cost_HF) & results.Cost_HF > 0;
        p.R_cost(:, validDirect) = bsxfun(@rdivide, ...
            p.Cost_WS_all(:, validDirect), results.Cost_HF(validDirect));
        p.decision = evaluate_decisions(p.K1_list, p.Cost_WS_all, ...
            p.theory.K1_selected, results.Cost_HF);
        p.complete = true; % Execution complete; some targets can be unresolved.
        results.runs{si, ri} = p;
        save_checkpoint(checkpoint, results);
        say(cfg, 'Pair finished in %.1f s; comparison-complete targets: %s\n', ...
            toc(pair_clock), mat2str(p.decision.comparison_complete));
    end
end

results.complete = true;
results.finished = datestr(now, 30);
results.metric_notes = struct( ...
    'cost', 'Optimization gradient work with c1=n_low/n_full, c2=1; not wall-clock speedup.', ...
    'inputs', 'Theory uses high-accuracy reference minimizers; reference costs are excluded.', ...
    'benchmark', 'Best tested K1, including zero and theoretical neighbors; not global optimum.', ...
    'unresolved', 'NaN counts are censored; regret/labels require all candidates to reach epsilon.', ...
    'regret', 'selected_cost/empirical_cost - 1; undefined when empirical_cost is zero.', ...
    'speedup', 'direct_cost/selected_cost; undefined when either cost is zero.', ...
    'summary', 'Medians and min/max over three default seeds; valid counts are exported.', ...
    'agreement', 'Theory warm/direct label versus whether any tested warm budget beats direct.', ...
    'integer_rule', 'Best positive floor/ceil neighbor, then strict improvement over direct bound.');
[results.raw, results.decisions, results.summary] = result_tables(results);
save_checkpoint(checkpoint, results);
write_numeric_csv(fullfile(cfg.output_dir, 'higgs_rq12_raw.csv'), results.raw);
write_numeric_csv(fullfile(cfg.output_dir, 'higgs_rq12_decisions.csv'), results.decisions);
write_numeric_csv(fullfile(cfg.output_dir, 'higgs_rq12_summary.csv'), results.summary);
if cfg.make_figures
    try
        make_plots(results);
    catch err
        warning('HIGGS:PlotFailed', 'Data are saved. Plotting failed: %s', err.message);
    end
end
say(cfg, '\nSaved results and CSV summaries to %s\n', cfg.output_dir);
say(cfg, 'Speedup is normalized optimization work, not end-to-end runtime.\n');
end

function cfg = default_config(root, options)
cfg = struct('n_full', 110000, 'd', 28, 'lambda', 1e-2, ...
    'r_list', [.05 .15 .25], 'epsilon_list', [1e-3 1e-4 1e-5], ...
    'high_seed', 1, 'subset_seeds', [11 12 13], ...
    'max_iter', 1000, 'extended_max_iter', 2000, ...
    'reference_tol', 1e-8, 'reference_max_iter', 100, ...
    'read_chunk_rows', 50000, 'gap_roundoff', 1e-12, ...
    'output_dir', fullfile(root, 'higgs_rq12_output'), ...
    'make_figures', true, 'verbose', true);
names = fieldnames(options);
for j = 1:numel(names)
    if ~isfield(cfg, names{j})
        error('HIGGS:Option', 'Unknown option: %s', names{j});
    end
    cfg.(names{j}) = options.(names{j});
end
cfg.r_list = cfg.r_list(:)';
cfg.epsilon_list = cfg.epsilon_list(:)';
cfg.subset_seeds = cfg.subset_seeds(:)';
cfg.output_dir = char(cfg.output_dir);
positive = [cfg.n_full cfg.d cfg.lambda cfg.max_iter cfg.extended_max_iter ...
    cfg.reference_tol cfg.reference_max_iter cfg.read_chunk_rows cfg.gap_roundoff];
assert(all(isfinite(positive) & positive > 0), 'Options must be positive and finite.');
ints = [cfg.n_full cfg.d cfg.max_iter cfg.extended_max_iter ...
    cfg.reference_max_iter cfg.read_chunk_rows cfg.high_seed cfg.subset_seeds];
assert(all(isfinite(ints) & ints >= 0 & ints == floor(ints)), ...
    'Sizes, iteration limits, and seeds must be finite nonnegative integers.');
assert(cfg.n_full >= 2 && cfg.extended_max_iter >= cfg.max_iter, 'Invalid limits.');
assert(~isempty(cfg.r_list) && all(isfinite(cfg.r_list)) && ...
    all(cfg.r_list > 0 & cfg.r_list < 1) && all(diff(cfg.r_list) > 0), ...
    'r_list must be strictly increasing and between zero and one.');
counts = round(cfg.n_full * cfg.r_list);
assert(all(counts >= 1 & counts < cfg.n_full) && all(diff(counts) > 0), ...
    'Low sample sizes must be distinct and strictly below n_full.');
assert(~isempty(cfg.epsilon_list) && all(isfinite(cfg.epsilon_list)) && ...
    all(cfg.epsilon_list > 0) && numel(unique(cfg.epsilon_list)) == numel(cfg.epsilon_list), ...
    'Accuracy targets must be distinct, positive, and finite.');
assert(~isempty(cfg.subset_seeds) && ...
    numel(unique(cfg.subset_seeds)) == numel(cfg.subset_seeds), 'Seeds must be distinct.');
end

function sample = load_high_sample(path, cfg, key)
cache = fullfile(cfg.output_dir, 'higgs_high_sample.mat');
if exist(cache, 'file') == 2
    cached = load(cache, 'sample');
    if isequaln(cached.sample.key, key)
        sample = cached.sample;
        say(cfg, 'Reusing the cached standardized high-fidelity sample.\n');
        return
    end
    error('HIGGS:DifferentSample', 'Sample cache differs. Use a new output_dir.');
end
say(cfg, 'Streaming CSV to stratify the high sample; this first scan is cached.\n');
fid = fopen(path, 'r');
if fid < 0
    error('HIGGS:Open', 'Cannot open %s.', path);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
line = fgetl(fid);
if ~ischar(line) || numel(strfind(line, ',')) ~= cfg.d
    error('HIGGS:Columns', 'Expected a headerless CSV with one label and %d features.', cfg.d);
end
frewind(fid);
rng(cfg.high_seed, 'twister');
reservoir = {zeros(0, cfg.d + 1), zeros(0, cfg.d + 1)};
keys = {zeros(0, 1), zeros(0, 1)};
ids = {zeros(0, 1), zeros(0, 1)};
class_count = [0 0];
rows = 0;
format = repmat('%f', 1, cfg.d + 1);
while ~feof(fid)
    chunk = textscan(fid, format, cfg.read_chunk_rows, 'Delimiter', ',', ...
        'CollectOutput', true, 'ReturnOnError', false);
    D = chunk{1};
    if isempty(D)
        if ~feof(fid)
            error('HIGGS:Parse', 'CSV parser made no progress after row %d.', rows);
        end
        break
    end
    if any(~isfinite(D(:))) || any(D(:, 1) ~= 0 & D(:, 1) ~= 1)
        error('HIGGS:Data', 'Nonfinite features or nonbinary labels after row %d.', rows);
    end
    source_ids = rows + (1:size(D, 1))';
    rows = rows + size(D, 1);
    for c = 1:2
        mask = D(:, 1) == c - 1;
        class_count(c) = class_count(c) + sum(mask);
        new_keys = rand(sum(mask), 1);
        new_rows = D(mask, :);
        new_ids = source_ids(mask);
        if numel(keys{c}) == cfg.n_full
            keep = new_keys < keys{c}(end);
            new_keys = new_keys(keep);
            new_rows = new_rows(keep, :);
            new_ids = new_ids(keep);
        end
        allkeys = [keys{c}; new_keys];
        allrows = [reservoir{c}; new_rows];
        allids = [ids{c}; new_ids];
        [allkeys, order] = sort(allkeys);
        keep = 1:min(cfg.n_full, numel(order));
        keys{c} = allkeys(keep);
        reservoir{c} = allrows(order(keep), :);
        ids{c} = allids(order(keep));
    end
    if mod(rows, 1000000) < size(D, 1)
        say(cfg, '  Scanned %d rows...\n', rows);
    end
end
if rows < cfg.n_full || any(class_count == 0)
    error('HIGGS:SampleSize', 'Need >=%d rows and both label classes.', cfg.n_full);
end
n_positive = round(cfg.n_full * class_count(2) / rows);
n_negative = cfg.n_full - n_positive;
selected = [reservoir{1}(1:n_negative, :); reservoir{2}(1:n_positive, :)];
selected_ids = [ids{1}(1:n_negative); ids{2}(1:n_positive)];
[selected_ids, order] = sort(selected_ids);
selected = selected(order, :);
mu = mean(selected(:, 2:end), 1);
sd = std(selected(:, 2:end), 0, 1);
sd(sd == 0) = 1;
sample = struct('key', key, 'source_rows', rows, 'source_class_counts', class_count, ...
    'high_source_indices', selected_ids, 'feature_mean', mu, 'feature_std', sd, ...
    'high_class_counts', [n_negative n_positive], ...
    'X', bsxfun(@rdivide, bsxfun(@minus, selected(:, 2:end), mu), sd), ...
    'b', 2 * selected(:, 1) - 1);
save(cache, 'sample', '-v7');
say(cfg, 'Cached %d high-fidelity rows from %d source rows.\n', cfg.n_full, rows);
end

function subsets = nested_indices(b, counts, seed)
rng(seed, 'twister');
neg = find(b == -1);
pos = find(b == 1);
neg = neg(randperm(numel(neg)));
pos = pos(randperm(numel(pos)));
subsets = cell(1, numel(counts));
for j = 1:numel(counts)
    np = round(counts(j) * numel(pos) / numel(b));
    nn = counts(j) - np;
    subsets{j} = [neg(1:nn); pos(1:np)];
end
end

function L = logistic_L(X, lambda)
G = (X' * X) / size(X, 1);
L = lambda + max(eig((G + G') / 2)) / 4;
end

function s = sigmoid_negative(margin)
% Stable 1/(1+exp(margin)), including very large signed margins.
z = exp(-abs(margin));
s = zeros(size(margin));
positive = margin >= 0;
s(positive) = z(positive) ./ (1 + z(positive));
s(~positive) = 1 ./ (1 + z(~positive));
end

function f = value_from_scores(scores, b, x, lambda)
z = -b .* scores;
f = mean(max(z, 0) + log1p(exp(-abs(z)))) + (lambda / 2) * (x' * x);
end

function [f, g, H] = logistic_fgH(X, b, lambda, x)
scores = X * x;
f = value_from_scores(scores, b, x, lambda);
if nargout >= 2
    p = sigmoid_negative(b .* scores);
    g = -(X' * (b .* p)) / size(X, 1) + lambda * x;
end
if nargout >= 3
    H = (X' * bsxfun(@times, X, p .* (1 - p))) / size(X, 1) ...
        + lambda * eye(size(X, 2));
end
end

function ref = reference_newton(X, b, lambda, x, cfg)
converged = false;
for k = 0:cfg.reference_max_iter
    [f, g, H] = logistic_fgH(X, b, lambda, x);
    if norm(g) <= cfg.reference_tol
        converged = true;
        break
    end
    if k == cfg.reference_max_iter
        break
    end
    direction = -(H \ g);
    slope = g' * direction;
    if ~all(isfinite(direction)) || slope >= 0
        error('HIGGS:NewtonDirection', 'Reference Newton direction is invalid.');
    end
    alpha = 1;
    accepted = false;
    for bt = 1:40
        trial = x + alpha * direction;
        ftrial = logistic_fgH(X, b, lambda, trial);
        if isfinite(ftrial) && ftrial <= f + 1e-4 * alpha * slope + 10 * eps(max(1, abs(f)))
            x = trial;
            accepted = true;
            break
        end
        alpha = alpha / 2;
    end
    if ~accepted
        error('HIGGS:NewtonLineSearch', 'Reference Newton line search failed.');
    end
end
if ~converged
    error('HIGGS:ReferenceNotConverged', ...
        'Reference gradient %.3g exceeds tolerance %.3g.', norm(g), cfg.reference_tol);
end
ref = struct('x', x, 'f', f, 'grad_norm', norm(g), 'iterations', k);
end

function state = empty_low_state(x0)
state = struct('X', x0, 'y', x0, 't', 1, 'k', 0);
end

function state = extend_low(state, K, X, b, lambda, L)
if state.k >= K
    return
end
state.X(:, K + 1) = 0;
for k = state.k:(K - 1)
    x = state.X(:, k + 1);
    p = sigmoid_negative(b .* (X * state.y));
    g = -(X' * (b .* p)) / size(X, 1) + lambda * state.y;
    xnext = state.y - g / L;
    tnext = (1 + sqrt(1 + 4 * state.t^2)) / 2;
    state.y = xnext + ((state.t - 1) / tnext) * (xnext - x);
    state.X(:, k + 2) = xnext;
    state.t = tnext;
end
state.k = K;
end

function h = agd_high(X, b, lambda, L, x, fref, targets, cfg)
% fval(1)/gap(1) correspond to iteration ZERO.
scores = X * x;
y = x;
scores_y = scores;
t = 1;
h.fval = nan(cfg.extended_max_iter + 1, 1);
h.gap = h.fval;
h.first_hit = nan(1, numel(targets));
h.fval(1) = value_from_scores(scores, b, x, lambda);
h.gap(1) = checked_gap(h.fval(1), fref, cfg);
h.first_hit(h.gap(1) <= targets) = 0;
h.extended = false;
k = 0;
while any(isnan(h.first_hit)) && k < cfg.extended_max_iter
    if k == cfg.max_iter
        h.extended = true;
        say(cfg, '    Extending HF trajectory to %d iterations (no restart).\n', ...
            cfg.extended_max_iter);
    end
    p = sigmoid_negative(b .* scores_y);
    g = -(X' * (b .* p)) / size(X, 1) + lambda * y;
    xnext = y - g / L;
    scores_next = X * xnext;
    k = k + 1;
    h.fval(k + 1) = value_from_scores(scores_next, b, xnext, lambda);
    h.gap(k + 1) = checked_gap(h.fval(k + 1), fref, cfg);
    newly_hit = isnan(h.first_hit) & h.gap(k + 1) <= targets;
    h.first_hit(newly_hit) = k;
    tnext = (1 + sqrt(1 + 4 * t^2)) / 2;
    beta = (t - 1) / tnext;
    y = xnext + beta * (xnext - x);
    % By linearity this is X*y, reusing forward products to avoid an extra
    % matrix-vector pass for diagnostic objective evaluation.
    scores_y = scores_next + beta * (scores_next - scores);
    x = xnext;
    scores = scores_next;
    t = tnext;
end
h.fval = h.fval(1:k + 1);
h.gap = h.gap(1:k + 1);
h.iterations = k;
h.x_final = x;
h.reached = isfinite(h.first_hit);
end

function gap = checked_gap(f, fref, cfg)
gap = f - fref;
if ~isfinite(gap) || gap < -cfg.gap_roundoff
    error('HIGGS:InvalidGap', ...
        'Nonfinite gap or objective below reference (gap=%g). Check the reference.', gap);
end
gap = max(gap, 0); % Only tiny negative roundoff is clipped.
end

function th = theory_decision(L1, L2, mu1, R1, R2, Delta, r, targets)
scale = sqrt(2 * L2 ./ targets);
th.K1_continuous = sqrt((1 / r) * sqrt(8 * L1 * L2 ./ (mu1 * targets)) * R1);
th.neighbors = [max(1, floor(th.K1_continuous)); max(1, ceil(th.K1_continuous))];
th.K1_selected = zeros(size(targets));
th.K1_warm = zeros(size(targets));
th.direct_bound = ceil(scale * R2);
th.warm_bound = zeros(size(targets));
th.selected_bound = zeros(size(targets));
for e = 1:numel(targets)
    candidates = unique(th.neighbors(:, e)); % Ascending, for deterministic ties.
    bound = r * candidates + ceil(scale(e) * ...
        (sqrt(4 * L1 / mu1) * R1 ./ candidates + Delta));
    [th.warm_bound(e), j] = min(bound);
    th.K1_warm(e) = candidates(j);
    th.selected_bound(e) = th.direct_bound(e);
    if th.warm_bound(e) < th.direct_bound(e)
        th.K1_selected(e) = candidates(j);
        th.selected_bound(e) = th.warm_bound(e);
    end
end
end

function out = evaluate_decisions(K, costs, selected, direct)
E = numel(direct);
blank = nan(1, E);
out = struct('comparison_complete', false(1, E), 'K1_empirical', blank, ...
    'empirical_cost', blank, 'selected_cost', blank, 'regret', blank, ...
    'speedup', blank, 'theory_warm', double(selected > 0), ...
    'empirical_warm', blank, 'agreement', blank, 'harmful_selected_warm', blank);
for e = 1:E
    j = find(K == selected(e), 1);
    assert(~isempty(j), 'Selected theoretical budget must be in the tested set.');
    out.selected_cost(e) = costs(j, e);
    if ~isfinite(direct(e)) || any(~isfinite(costs(:, e)))
        continue % Never claim a benchmark from censored candidate runs.
    end
    out.comparison_complete(e) = true;
    [out.empirical_cost(e), best] = min(costs(:, e));
    out.K1_empirical(e) = K(best);
    if out.empirical_cost(e) > 0
        out.regret(e) = out.selected_cost(e) / out.empirical_cost(e) - 1;
    end
    if direct(e) > 0 && out.selected_cost(e) > 0
        out.speedup(e) = direct(e) / out.selected_cost(e);
    end
    if any(K > 0)
        out.empirical_warm(e) = min(costs(K > 0, e)) < direct(e);
    else
        out.empirical_warm(e) = 0;
    end
    out.agreement(e) = out.theory_warm(e) == out.empirical_warm(e);
    out.harmful_selected_warm(e) = selected(e) > 0 && out.selected_cost(e) > direct(e);
end
end

function save_checkpoint(path, results)
tmp = [path '.tmp.mat'];
save(tmp, 'results', '-v7');
[ok, msg] = movefile(tmp, path, 'f');
if ~ok
    error('HIGGS:Checkpoint', 'Could not finalize checkpoint: %s', msg);
end
end

function say(cfg, varargin)
if cfg.verbose
    fprintf(varargin{:});
end
end

function [raw, decisions, summary] = result_tables(results)
% Plain numeric tables keep the saved MAT file independent of table classes.
cfg = results.config;
raw.columns = {'seed', 'r_requested', 'r_actual', 'n_low', 'epsilon', ...
    'K1', 'K2_gap', 'cost', 'direct_cost', 'cost_over_direct', ...
    'target_reached', 'hf_iterations_run', 'warm_gap', 'warm_distance', ...
    'transfer_distance_bound', 'L1', 'L2', 'mu', 'R1', 'R2', 'Delta', ...
    'K1_continuous', 'K1_selected', 'comparison_complete'};
decisions.columns = {'seed', 'r_requested', 'r_actual', 'n_low', 'epsilon', ...
    'L1', 'L2', 'mu', 'R1', 'R2', 'Delta', 'K1_continuous', 'K1_warm', ...
    'K1_selected', 'K1_empirical', 'direct_bound', 'warm_bound', ...
    'selected_bound', 'direct_cost', 'selected_cost', 'empirical_cost', ...
    'regret', 'speedup', 'theory_warm', 'empirical_warm', 'agreement', ...
    'harmful_selected_warm', 'comparison_complete', 'candidate_count', ...
    'reached_candidates', 'low_reference_grad_norm', 'high_reference_grad_norm'};
raw.data = zeros(0, numel(raw.columns));
decisions.data = zeros(0, numel(decisions.columns));
for ri = 1:numel(cfg.r_list)
    for si = 1:numel(cfg.subset_seeds)
        p = results.runs{si, ri};
        for e = 1:numel(cfg.epsilon_list)
            th = p.theory;
            dc = p.decision;
            decisions.data(end + 1, :) = [p.seed, p.r_requested, p.c1, p.n_low, ...
                cfg.epsilon_list(e), p.L_low, results.high.L, cfg.lambda, ...
                p.dist_low, results.high.dist, p.Delta, th.K1_continuous(e), ...
                th.K1_warm(e), th.K1_selected(e), dc.K1_empirical(e), ...
                th.direct_bound(e), th.warm_bound(e), th.selected_bound(e), ...
                results.Cost_HF(e), dc.selected_cost(e), dc.empirical_cost(e), ...
                dc.regret(e), dc.speedup(e), dc.theory_warm(e), ...
                dc.empirical_warm(e), dc.agreement(e), dc.harmful_selected_warm(e), ...
                dc.comparison_complete(e), numel(p.K1_list), ...
                sum(isfinite(p.K2_all(:, e))), p.reference.grad_norm, ...
                results.high.reference.grad_norm]; %#ok<AGROW>
            for j = 1:numel(p.K1_list)
                K1 = p.K1_list(j);
                if K1 == 0
                    transfer = results.high.dist;
                else
                    transfer = sqrt(4 * p.L_low / cfg.lambda) * p.dist_low / K1 + p.Delta;
                end
                raw.data(end + 1, :) = [p.seed, p.r_requested, p.c1, p.n_low, ...
                    cfg.epsilon_list(e), K1, p.K2_all(j, e), p.Cost_WS_all(j, e), ...
                    results.Cost_HF(e), p.R_cost(j, e), isfinite(p.K2_all(j, e)), ...
                    p.hf{j}.iterations, p.warm_gap(j), p.warm_distance(j), ...
                    transfer, p.L_low, results.high.L, cfg.lambda, p.dist_low, ...
                    results.high.dist, p.Delta, th.K1_continuous(e), ...
                    th.K1_selected(e), dc.comparison_complete(e)]; %#ok<AGROW>
            end
        end
    end
end
summary.columns = {'r_requested', 'epsilon', 'n_seeds', 'n_complete', ...
    'n_unresolved', 'n_regret_valid', 'n_speedup_valid', ...
    'K1_cont_median', 'K1_cont_min', 'K1_cont_max', ...
    'K1_selected_median', 'K1_selected_min', 'K1_selected_max', ...
    'K1_empirical_median', 'K1_empirical_min', 'K1_empirical_max', ...
    'regret_pct_median', 'regret_pct_min', 'regret_pct_max', ...
    'speedup_median', 'speedup_min', 'speedup_max', ...
    'theory_warm_count', 'empirical_warm_count', 'agreement_count', ...
    'harmful_selected_warm_count', 'Delta_median', 'Delta_min', 'Delta_max'};
summary.data = zeros(numel(cfg.r_list) * numel(cfg.epsilon_list), numel(summary.columns));
row = 0;
for ri = 1:numel(cfg.r_list)
    for e = 1:numel(cfg.epsilon_list)
        row = row + 1;
        choose = decisions.data(:, 2) == cfg.r_list(ri) & ...
            decisions.data(:, 5) == cfg.epsilon_list(e);
        D = decisions.data(choose, :);
        complete = D(:, 28) == 1;
        summary.data(row, :) = [cfg.r_list(ri), cfg.epsilon_list(e), size(D, 1), ...
            sum(complete), sum(~complete), sum(isfinite(D(:, 22))), ...
            sum(isfinite(D(:, 23))), finite_range(D(:, 12)), finite_range(D(:, 14)), ...
            finite_range(D(:, 15)), finite_range(100 * D(:, 22)), finite_range(D(:, 23)), ...
            sum(D(:, 24) == 1), sum(D(complete, 25) == 1), ...
            sum(D(complete, 26) == 1), sum(D(complete, 27) == 1), finite_range(D(:, 11))];
    end
end
end

function r = finite_range(values)
values = values(isfinite(values));
if isempty(values)
    r = [NaN NaN NaN];
else
    r = [median(values), min(values), max(values)];
end
end

function write_numeric_csv(path, tab)
fid = fopen(path, 'w');
if fid < 0
    error('HIGGS:CSVOutput', 'Cannot write %s.', path);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s\n', strjoin(tab.columns, ','));
format = [repmat('%.17g,', 1, numel(tab.columns) - 1), '%.17g\n'];
fprintf(fid, format, tab.data');
end

function make_plots(results)
cfg = results.config;
% RQ1: fixed, preselected seed and the target closest to 1e-4.
[~, e] = min(abs(log10(cfg.epsilon_list) + 4));
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1200 380]);
cleanup = onCleanup(@() close(fig)); %#ok<NASGU>
for ri = 1:numel(cfg.r_list)
    p = results.runs{1, ri};
    subplot(1, numel(cfg.r_list), ri);
    hold on;
    h = plot(p.K1_list, p.Cost_WS_all(:, e), 'o-', 'LineWidth', 1.2);
    labels = {'Empirical cost'};
    xmax = max(1, max(p.K1_list));
    if isfinite(results.Cost_HF(e))
        h(end + 1) = plot([0 xmax], results.Cost_HF(e) * [1 1], 'k--');
        labels{end + 1} = 'Direct cost';
    end
    ks = p.theory.K1_selected(e);
    j = find(p.K1_list == ks, 1);
    if isfinite(p.Cost_WS_all(j, e))
        h(end + 1) = plot(ks, p.Cost_WS_all(j, e), 'rs', ...
            'MarkerSize', 9, 'LineWidth', 1.5);
        labels{end + 1} = 'Theory selected';
    end
    if p.decision.comparison_complete(e)
        h(end + 1) = plot(p.decision.K1_empirical(e), p.decision.empirical_cost(e), ...
            'kp', 'MarkerSize', 11, 'LineWidth', 1.5);
        labels{end + 1} = 'Best tested';
    end
    limits = ylim;
    h(end + 1) = plot(p.theory.K1_continuous(e) * [1 1], limits, ':', ...
        'Color', [.4 .4 .4], 'LineWidth', 1.2);
    labels{end + 1} = 'Continuous warm budget';
    ylim(limits);
    xlabel('Low-fidelity iterations K_1');
    ylabel('Cost in high-fidelity gradient units');
    title(sprintf('r=%.2f, seed=%d, epsilon=%.0e', p.c1, p.seed, cfg.epsilon_list(e)));
    legend(h, labels, 'Location', 'best', 'FontSize', 8);
    grid on;
end
print(fig, fullfile(cfg.output_dir, 'higgs_rq1_cost_curves.png'), '-dpng', '-r180');
clear cleanup % Close the first figure before allocating the second.

E = numel(cfg.epsilon_list);
R = numel(cfg.r_list);
med_regret = nan(E, R);
med_speedup = nan(E, R);
agreement = nan(E, R);
complete = zeros(E, R);
for ri = 1:R
    for e = 1:E
        row = (ri - 1) * E + e;
        med_regret(e, ri) = results.summary.data(row, 17);
        med_speedup(e, ri) = results.summary.data(row, 20);
        complete(e, ri) = results.summary.data(row, 4);
        if complete(e, ri) > 0
            agreement(e, ri) = results.summary.data(row, 25);
        end
    end
end
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1150 360]);
cleanup = onCleanup(@() close(fig)); %#ok<NASGU>
values = {med_regret, med_speedup, agreement};
names = {'Median allocation regret (%)', 'Median work speedup', 'Break-even agreement (complete runs)'};
for panel = 1:3
    subplot(1, 3, panel);
    vals = values{panel};
    obj = imagesc(vals);
    set(obj, 'AlphaData', isfinite(vals));
    set(gca, 'Color', [.9 .9 .9], 'XTick', 1:R, 'YTick', 1:E, ...
        'XTickLabel', arrayfun(@(x) sprintf('%.2f', x), cfg.r_list, 'UniformOutput', false), ...
        'YTickLabel', arrayfun(@(x) sprintf('%.0e', x), cfg.epsilon_list, 'UniformOutput', false));
    for ri = 1:R
        for e = 1:E
            if ~isfinite(vals(e, ri))
                label = 'NA';
            elseif panel == 3
                label = sprintf('%d/%d', vals(e, ri), complete(e, ri));
            else
                label = sprintf('%.2f', vals(e, ri));
            end
            text(ri, e, label, 'HorizontalAlignment', 'center', ...
                'FontWeight', 'bold', 'BackgroundColor', 'w', 'Margin', 1);
        end
    end
    xlabel('Low-fidelity sample ratio r');
    ylabel('Target epsilon');
    title(names{panel}, 'FontSize', 10);
    colorbar;
end
print(fig, fullfile(cfg.output_dir, 'higgs_rq2_sensitivity.png'), '-dpng', '-r180');
end

function report = selftest_higgs()
% Small synthetic fixtures verify the implementation, not the paper claims.
root = fileparts(mfilename('fullpath'));
cfg = default_config(root, struct('verbose', false, 'make_figures', false));
rng(91, 'twister');
X = randn(80, 4);
b = 2 * double(rand(80, 1) > .45) - 1;
lambda = .2;
x = [.2; -.1; .3; -.2];
L = logistic_L(X, lambda);
[~, g, H] = logistic_fgH(X, b, lambda, x);
step = 1e-5;
gfd = zeros(4, 1);
Hfd = zeros(4);
for j = 1:4
    v = zeros(4, 1);
    v(j) = step;
    [fp, gp] = logistic_fgH(X, b, lambda, x + v);
    [fm, gm] = logistic_fgH(X, b, lambda, x - v);
    gfd(j) = (fp - fm) / (2 * step);
    Hfd(:, j) = (gp - gm) / (2 * step);
end
assert(norm(g - gfd) < 1e-8 && norm(H - Hfd, 'fro') < 1e-8, ...
    'Logistic derivatives disagree with finite differences.');
assert(min(eig(H)) >= lambda - 1e-12 && max(eig(H)) <= L + 1e-12, ...
    'Hessian violates the claimed mu/L bounds.');
assert(all(isfinite(sigmoid_negative([-1000; 0; 1000]))), 'Unstable sigmoid.');
assert(isfinite(value_from_scores([-1000; 1000], [1; 1], 0, lambda)), ...
    'Unstable softplus.');
ref = reference_newton(X, b, lambda, zeros(4, 1), cfg);
assert(ref.grad_norm <= cfg.reference_tol, 'Reference tolerance failed.');

initial = empty_low_state(zeros(4, 1));
staged = extend_low(initial, 7, X, b, lambda, L);
staged = extend_low(staged, 19, X, b, lambda, L);
uninterrupted = extend_low(initial, 19, X, b, lambda, L);
assert(norm(staged.X - uninterrupted.X, 'fro') < 1e-13, 'Low trajectory was restarted.');
short = cfg;
short.max_iter = 7;
short.extended_max_iter = 19;
% Negative private-test target forces all iterations, without affecting the
% public requirement that experimental epsilon values be strictly positive.
fixed = agd_high(X, b, lambda, L, zeros(4, 1), ref.f, -1, short);
assert(fixed.extended && fixed.iterations == 19 && isnan(fixed.first_hit), ...
    'Unreached target or extension limit was counted incorrectly.');
assert(norm(fixed.x_final - uninterrupted.X(:, end)) < 1e-12, ...
    'High-fidelity continuation changed the AGD trajectory.');
for k = 0:19
    f = logistic_fgH(X, b, lambda, uninterrupted.X(:, k + 1));
    assert(abs(fixed.fval(k + 1) - f) < 1e-12, 'Cached scores changed objective values.');
end
zero = agd_high(X, b, lambda, L, ref.x, ref.f, [1e-3 1e-6], short);
assert(all(zero.first_hit == 0) && zero.iterations == 0, 'Iteration-zero success was lost.');
target = fixed.gap(1) / 2;
hit = agd_high(X, b, lambda, L, zeros(4, 1), ref.f, target, short);
expected = find(fixed.gap <= target, 1) - 1;
assert(~isempty(expected) && hit.first_hit == expected, 'First-hit indexing is off by one.');

th = theory_decision(2, 3, .2, 1, 2, .1, .1, [1e-3 1e-4]);
for e = 1:2
    eps_values = [1e-3 1e-4];
    kk = th.neighbors(:, e);
    costs = .1 * kk + ceil(sqrt(6 / eps_values(e)) * (sqrt(40) ./ kk + .1));
    assert(th.warm_bound(e) == min(costs), 'Integer neighbor costs are wrong.');
    assert((th.K1_selected(e) > 0) == (th.warm_bound(e) < th.direct_bound(e)), ...
        'Theoretical break-even selection is wrong.');
end
tie = theory_decision(1, 1, 1, 0, 0, 0, .1, 1e-3);
assert(tie.K1_selected == 0, 'Zero-distance direct solve should cost zero.');
dc = evaluate_decisions([0 1 2], [10; 11; 9], 1, 10);
assert(dc.agreement == 1 && dc.harmful_selected_warm == 1 && dc.speedup < 1, ...
    'Break-even agreement must not hide a harmful selected warm budget.');
assert(abs(dc.regret - (11 / 9 - 1)) < 1e-14 && dc.K1_empirical == 2, ...
    'Empirical regret or best tested budget is wrong.');
dc = evaluate_decisions([0 1 2], [10; NaN; 9], 2, 10);
assert(~dc.comparison_complete && isnan(dc.regret) && isnan(dc.agreement), ...
    'An unresolved candidate was silently discarded from the benchmark.');
dc = evaluate_decisions([0 1], [0; 1], 0, 0);
assert(isnan(dc.regret) && isnan(dc.speedup), 'Zero denominators must remain undefined.');

nested = nested_indices(b, [8 20 40], 11);
again = nested_indices(b, [8 20 40], 11);
assert(isequal(nested, again), 'Subset sampling is not reproducible.');
assert(all(ismember(nested{1}, nested{2})) && all(ismember(nested{2}, nested{3})), ...
    'Low-fidelity subsets are not nested.');
assert(isequal(cellfun(@numel, nested), [8 20 40]), 'Incorrect subset sizes.');

% Exercise CSV streaming, stratification, complete pipeline, outputs, resume.
tmpdir = tempname;
mkdir(tmpdir);
cleanup = onCleanup(@() rmdir(tmpdir, 's')); %#ok<NASGU>
csv_path = fullfile(tmpdir, 'fixture.csv');
rng(123, 'twister');
fixture = [mod((1:240)', 2), randn(240, 4)];
fid = fopen(csv_path, 'w');
assert(fid >= 0, 'Cannot create the self-test fixture.');
fprintf(fid, '%.17g,%.17g,%.17g,%.17g,%.17g\n', fixture');
fclose(fid);
opts = struct('n_full', 120, 'd', 4, 'lambda', .2, 'r_list', [.25 .5 .75], ...
    'epsilon_list', [1e-2 1e-4 1e-6], 'subset_seeds', [11 12], ...
    'max_iter', 20, 'extended_max_iter', 80, 'read_chunk_rows', 37, ...
    'make_figures', false, 'verbose', false, 'output_dir', fullfile(tmpdir, 'output'));
test = generate_higgs_sensitivity_data(csv_path, opts);
assert(test.complete && size(test.decisions.data, 1) == 18 && ...
    size(test.summary.data, 1) == 9, 'End-to-end results are incomplete.');
assert(sum(test.sampling.source_class_counts) == 240 && ...
    isequal(test.sampling.high_class_counts, [60 60]), 'CSV sampling lost rows/classes.');
cached = load(fullfile(opts.output_dir, 'higgs_high_sample.mat'), 'sample');
assert(max(abs(mean(cached.sample.X, 1))) < 1e-12 && ...
    max(abs(std(cached.sample.X, 0, 1) - 1)) < 1e-12, 'Standardization failed.');
assert(exist(fullfile(opts.output_dir, 'higgs_rq12_raw.csv'), 'file') == 2 && ...
    exist(fullfile(opts.output_dir, 'higgs_rq12_summary.csv'), 'file') == 2, ...
    'CSV exports were not written.');
resumed = generate_higgs_sensitivity_data(csv_path, opts);
assert(isequaln(test.raw.data, resumed.raw.data) && ...
    isequaln(test.decisions.data, resumed.decisions.data), 'Resume changed the results.');
report = struct('passed', true, 'message', 'All numerical and end-to-end self-tests passed.');
fprintf('%s\n', report.message);
end
