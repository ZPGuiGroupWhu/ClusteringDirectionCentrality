%   AUTHORSHIP
%   Math Lead & Primary Developer:  Connor Meehan <connor.gw.meehan@gmail.com>
%   Secondary Developer: Stephen Meehan <swmeehan@stanford.edu> 
%   Bioinformatics Lead:  Wayne Moore <wmoore@stanford.edu>
%   Provided by the Herzenberg Lab at Stanford University 
%   License: BSD 3 clause
%

function [reduction, umap, clusterIds, extras, epp]...
    =run_examples(whichOnes, verbose, varargin)
N_RUN_UMAP_EXAMPLES = 66;
N_EXTRA_EXAMPLES = 5;
N_EXAMPLES = N_RUN_UMAP_EXAMPLES + N_EXTRA_EXAMPLES;

if nargin<1
    verbose='none';
    whichOnes=1:N_EXAMPLES;
else
    if nargin<2
        if ischar(whichOnes) ...
                && (strcmp(whichOnes, 'none') ...
                    || strcmp(whichOnes, 'text') ...
                    || strcmp(whichOnes, 'graphic'))
                verbose=whichOnes;
                whichOnes=2:N_EXAMPLES;
        else
            verbose='graphic';
        end
    end
    if isempty(verbose)
        verbose='graphic';
    end
    if ischar(whichOnes)
        whichOnes=str2num(whichOnes); %#ok<ST2NM> 
    end
    if ~isnumeric(whichOnes) || any(isnan(whichOnes)) || any(whichOnes<0) || any(whichOnes>N_EXAMPLES)
        error(['run_examples argument must be nothing or numbers from 1 to '...
            num2str(N_EXAMPLES) '!']);
    end
end
if ~isempty(varargin)
    try
        validatestring(verbose, {'none', 'graphic', 'text'})
    catch
        varargin=[ {verbose} varargin ];
        verbose='graphic';
    end
end
beQuiet=strcmp(verbose, 'none');
try
    argsObj=Args(UmapUtil.DefineArgs);
catch
        UmapUtil.Initialize();  %CM: varargin does not need to be passed here
        argsObj=Args(UmapUtil.DefineArgs);
end
%nice support feature for isdeployed or typing commands in console without brackets and ''
varargin=argsObj.parseStr2NumOrLogical(varargin);
if ~argsObj.argued.contains('fast_approximation')
    varargin=['fast_approximation', true, varargin];
end
reduction=[]; umap=[]; clusterIds=[]; extras=[]; epp=[];
if ~strcmpi(verbose, 'none')
    if any(whichOnes < 19)
        UmapExamples.DisplayPub(3);
    end
    if any(whichOnes == 19)
        UmapExamples.DisplayPub(1);
    end
end
if all(whichOnes==0)
    whichOnes = 1:N_EXAMPLES;
end
args=[{'verbose'}, {verbose}, varargin(:)'];
if ismember(1, whichOnes)
    disp('run_umap Example 1 starting...');
    [reduction, umap, clusterIds, extras]=run_umap;
    disp('run_umap Example 1 completed with no MATLAB exceptions!');
end
if ismember(2, whichOnes)
    disp('run_umap Example 2 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('sample30k.csv', 'save_template_file', 'utBalbc2D.mat', args{:});
    disp('run_umap Example 2 completed with no MATLAB exceptions!');
end
if ismember(3, whichOnes)
    disp('run_umap Example 3 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('sample130k.csv', 'template_file', 'utBalbc2D.mat', args{:});
    disp('run_umap Example 3 completed with no MATLAB exceptions!');
end
if ismember(4, whichOnes)
    disp('run_umap Example 4 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('sampleBalbcLabeled55k.csv', 'label_column', 11, 'label_file', 'balbcLabels.properties', 'save_template_file', 'ustBalbc2D.mat', args{:});
    disp('run_umap Example 4 completed with no MATLAB exceptions!');
end
if ismember(4.1, whichOnes)
    disp('run_umap Example 4.1 starting...');
    run_umap('sampleBalbcLabeled55k.csv', 'label_column', 11, 'label_file', 'balbcLabels.properties', 'save_template_file', true, args{:});
    [reduction, umap, clusterIds, extras]=run_umap('sampleRag148k.csv', 'template_file', 'sampleBalbcLabeled55k.umap.mat', 'match_supervisors', 1, 'cluster_detail', 'medium', args{:});    
    disp('run_umap Example 4.1 completed with no MATLAB exceptions!');
end

if ismember(5, whichOnes)
    disp('run_umap Example 5 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('sampleRag148k.csv', 'template_file', 'ustBalbc2D.mat', 'match_supervisors', 0, 'cluster_detail', 'medium', args{:});    
    UmapUtil.DescribeResults(reduction, umap, clusterIds, extras, 5)
end
if whichOnes==5.1
    disp('run_umap Example 5.1 starting with small example...');
    [reduction, umap, clusterIds, extras]=run_umap('sample10k.csv', 'template_file', 'ustBalbc2D.mat', args{:});
    disp('run_umap Example 5.1 completed with no MATLAB exceptions!');
end
if ismember(5.2, whichOnes)
    disp('run_umap Example 5.2 starting with template mismatch example...');
    [X, parameter_names]=File.ReadCsv(UmapUtil.GetFile('sample55k.csv'));
    X=X(:,1:8);
    run_umap(X, 'parameter_names', parameter_names(1:8), ...
        'save_template_file', 'utExample_5_2.mat');    
    run_umap('sample10k.csv', 'template_file', 'utExample_5_2.mat', args{:});
    disp('run_umap Example 5.2 completed with no MATLAB exceptions!');
end
if whichOnes==5.11
    disp('run_umap Example 5.11 starting with small example and ''verbose''==''none''...');
    run_umap('sample10k.csv', 'template_file', 'ustBalbc2D.mat', 'verbose', 'none');
    disp('run_umap Example 5.11 completed with no MATLAB exceptions!');
end
if ismember(6, whichOnes)
    disp('run_umap Example 6 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('sample30k.csv', 'cluster_output', verbose, 'cluster_detail', 'medium',  args{:});
    disp('run_umap Example 6 completed with no MATLAB exceptions!');
end
if ismember(7, whichOnes)
    disp('run_umap Example 7 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('sample30k.csv', 'n_components', 3, 'save_template_file', 'utBalbc3D.mat', args{:});
    disp('run_umap Example 7 completed with no MATLAB exceptions!');
end
if ismember(8, whichOnes)
    disp('run_umap Example 8 starting...');
    run_umap('sample130k.csv', 'template_file', 'utBalbc3D.mat', args{:});
    disp('run_umap Example 8 completed with no MATLAB exceptions!');
end
if ismember(9, whichOnes)
    disp('run_umap Example 9 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('sampleRagLabeled60k.csv', 'label_column', 11, 'label_file', 'ragLabels.properties', 'save_template_file', 'ustRag2D.mat', args{:});
    disp('run_umap Example 9 completed with no MATLAB exceptions!');
    
end
if ismember(10, whichOnes)
    disp('run_umap Example 10 starting...');
    run_umap('sample30k.csv', 'template_file', 'ustRag2D.mat', args{:});
    disp('run_umap Example 10 completed with no MATLAB exceptions!');
    
end
if ismember(11, whichOnes)
    disp('run_umap Example 11 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('sample30k.csv', 'template_file', 'ustRag2D.mat', 'method', 'Java', 'joined_transform', true, args{:});
    disp('run_umap Example 11 completed with no MATLAB exceptions!');
end
if ismember(12, whichOnes)
    disp('run_umap Example 12 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('sampleRag148k.csv', 'template_file', 'ustBalbc2D.mat', 'qf_tree', true, 'qf_dissimilarity', true, 'see_training', true, args{:});
    disp('run_umap Example 12 completed with no MATLAB exceptions!');
end
if ismember(13, whichOnes)
    disp('run_umap Example 13 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('sample30k.csv', 'python', false, 'hide_reduction_time', false,  args{:});
    [reduction, umap, clusterIds, extras]=run_umap('sample30k.csv', 'python', true, 'hide_reduction_time', false,  args{:});
    disp('run_umap Example 13 completed with no MATLAB exceptions!');
    
end
if ismember(14, whichOnes)
    disp('run_umap Example 14 starting (just MEX first)...');
    [reduction, umap, clusterIds, extras]=run_umap('sampleBalbcLabeled55k.csv', 'label_column', 11, 'label_file', 'balbcLabels.properties', 'save_template_file', 'ustBalbc2D.mat', 'hide_reduction_time', false, args{:});
    disp('run_umap Example 14 (just MEX) completed with no MATLAB exceptions!');
end
if ismember(15, whichOnes)
    disp('run_umap Example 15 starting (just MEX first)...');
    [reduction, umap, clusterIds, extras]=run_umap('sampleRag55k.csv', 'template_file', 'ustBalbc2D.mat', 'hide_reduction_time', false, args{:});
    disp('run_umap Example 15 (just MEX) completed with no MATLAB exceptions!');
end
if ismember(14, whichOnes)
    disp('run_umap Example 14 starting (with Python)...');
    [reduction, umap, clusterIds, extras]=run_umap('sampleBalbcLabeled55k.csv', 'label_column', 11, 'label_file', 'balbcLabels.properties', 'python', true, 'save_template_file', 'pyUstBalbc2D.mat', 'hide_reduction_time', false, args{:});
    disp('run_umap Example 14 (with Python) completed with no MATLAB exceptions!');
end
if ismember(15, whichOnes)
    disp('run_umap Example 15 starting (with Python)...');
    [reduction, umap, clusterIds, extras]=run_umap('sampleRag55k.csv', 'template_file', 'pyUstBalbc2D.mat', 'hide_reduction_time', false, args{:});
    disp('run_umap Example 15 (with Python) completed with no MATLAB exceptions!');
end
if ismember(16, whichOnes)
    disp('run_umap Example 16 starting...');
    run_umap('sampleBalbcLabeled55k.csv', 'label_column', 11, 'label_file', 'balbcLabels.properties', 'qf_tree', true, 'n_components', 3, 'save_template_file', 'ustBalbc3D.mat', args{:});
    [reduction, umap, clusterIds, extras]=run_umap('sample10k.csv', 'template_file', 'ustBalbc3D.mat', 'qf_tree', true, 'qf_dissimilarity', true, 'see_training', true, 'cluster_output', verbose, args{:});
    disp('run_umap Example 16 completed with no MATLAB exceptions!');
end
if ismember(17, whichOnes)
    disp('run_umap Example 17 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('sampleBalbcLabeled12k.csv', 'template_file', 'ustBalbc2D.mat', 'label_column', 'end', 'label_file', 'balbcLabels.properties', 'match_scenarios', 4, 'see_training', true, 'color_file', 'colorsByName.properties', 'match_predictions', true, args{:});
    UmapUtil.DescribeResults(reduction, umap, clusterIds, extras, 17)
end
if ismember(17.1, whichOnes)
    disp('run_umap Example 4 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('balbc4FmoLabeled.csv', 'label_column', 'end', 'save_template_file', 'ustBalbc10D_2D.mat', args{:});
    disp('run_umap Example 17.1 completed with no MATLAB exceptions!');
end
if ismember(17.2, whichOnes)
    disp('run_umap Example 17.2 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('balbcFmoLabeled.csv', 'label_column', 'end', 'template_file', 'ustBalbc10D_2D.mat', 'match_scenarios', 4, 'see_training', true, 'color_file', 'colorsByName.properties', 'match_predictions', true, args{:});
    UmapUtil.DescribeResults(reduction, umap, clusterIds, extras, 17.2)
end

if ismember(17.3, whichOnes)
    disp('run_umap Example 17.3 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('rag10DLabeled148k.csv', 'template_file', 'ustBalbc10D_2D.mat', 'label_column', 'end', 'match_scenarios', 4, 'see_training', true, 'color_file', 'colorsByName.properties', 'match_predictions', true, args{:});
    UmapUtil.DescribeResults(reduction, umap, clusterIds, extras, 17.3)
end

if ismember(17.4, whichOnes)
    disp('run_umap Example 17.4 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('balbcFmoLabeled.csv', 'template_file', 'ustBalbc10D_2D.mat', 'label_column', 'end', 'match_supervisors', 0, 'match_scenarios', 4, 'see_training', true, 'color_file', 'colorsByName.properties', args{:});
    disp('run_umap Example 17.4 completed with no MATLAB exceptions!');
end

if ismember(17.5, whichOnes)
    disp('run_umap Example 17.5 starting...');
    run_umap('sampleBalbcLabeled12k.csv', 'template_file', 'ustBalbc2D.mat', 'label_column', 'end', 'label_file', 'balbcLabels.properties', 'see_training', true, args{:});
    disp('run_umap Example 17.5 completed with no MATLAB exceptions!');
end

if ismember(17.6, whichOnes)
    disp('run_umap Example 17.6 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('rag10DLabeled148k.csv', 'template_file', 'ustBalbc10D_2D.mat', 'label_column', 'end', 'match_scenarios', 2, 'see_training', true, 'color_file', 'colorsByName.properties', args{:});
    disp('run_umap Example 17.6 completed with no MATLAB exceptions!');
end

if ismember(18, whichOnes)
    disp('run_umap Example 18 starting...');    
    [reduction, umap, clusterIds, extras]=run_umap('sampleBalbcLabeled12k.csv', 'template_file', 'ustBalbc2D.mat', 'label_column', 'end', 'label_file', 'balbcLabels.properties', 'match_scenarios', 4, 'match_histogram_fig', false, 'see_training', true, args{:}, 'false_positive_negative_plot', true);
    disp('run_umap Example 18 completed with no MATLAB exceptions!');
end
if ismember(19, whichOnes)
    disp('run_umap Example 19 starting...');    
    run_umap('s1_samusikImported_29D.csv', 'label_column', 'end', 'label_file', 's1_29D.properties', 'qf_tree', true, 'n_components', 3, 'save_template_file', 'ust_s1_samusikImported_29D_15nn_3D.mat', args{:});
    [reduction, umap, clusterIds, extras]=run_umap('s2_samusikImported_29D.csv', 'template_file', 'ust_s1_samusikImported_29D_15nn_3D.mat', 'label_column', 'end', 'label_file', 's2_samusikImported_29D.properties', 'match_scenarios', [1 2 4],  'match_histogram_fig', false, 'see_training', true, 'false_positive_negative_plot', true, 'match_supervisors', [3 1 4], args{:});
    disp('run_umap Example 19 completed with no MATLAB exceptions!');
end
if whichOnes==19.1
    disp('run_umap Example 19.1 starting...');    
    [reduction, umap, clusterIds, extras]=run_umap('s2_samusikImported_29D.csv', 'template_file', 'ust_s1_samusikImported_29D_15nn_3D.mat', 'label_column', 'end', 'label_file', 's2_samusikImported_29D.properties', 'match_scenarios', [1 2 4],  'match_histogram_fig', false, 'see_training', true, 'false_positive_negative_plot', true, 'match_supervisors', [3 1 4], args{:});
    disp('run_umap Example 19.1 completed with no MATLAB exceptions!');
end
if ismember(20, whichOnes)
    disp('run_umap Example 20 starting...first with NO nn_descent acceleration');
    tic;
    run_umap('cytofExample.csv', 'nn_descent_min_rows', 0, args{:});
    toc;
    disp('Slow half of Example 20 completed with no MATLAB exceptions!');
    tic;
    disp('run_umap Example 20 now WITH nn_descent acceleration');
    [reduction, umap, clusterIds, extras]=run_umap('cytofExample.csv', args{:});
    disp('run_umap Example 20 completed with no MATLAB exceptions!');
    toc;
end
if ismember(21, whichOnes)
    disp('run_umap Example 21 starting...');
    run_umap('s1_samusikImported_29D.csv', 'label_column', 'end', 'label_file', 's1_29D.properties', 'n_components', 3, 'save_template_file', 'ust_s1_samusikImported_minkowski_1.80_29D_15nn_3D.mat', 'metric', 'minkowski', 'P', 1.8, args{:});
    [reduction, umap, clusterIds, extras]=run_umap('s2_samusikImported_29D.csv', 'template_file', 'ust_s1_samusikImported_minkowski_1.80_29D_15nn_3D.mat', 'label_column', 'end', 'label_file', 's2_samusikImported_29D.properties', 'match_scenarios', 4,  'see_training', true, 'match_table_fig', false, 'match_histogram_fig', false, 'false_positive_negative_plot', true, 'match_supervisors', 3, args{:});
    disp('run_umap Example 21 completed with no MATLAB exceptions!');
end
if ismember(22, whichOnes)
    disp('run_umap Example 22 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('sample1point.csv', 'marker_size', 25, 'marker', 'd', args{:});
    disp('run_umap Example 22 completed with no MATLAB exceptions!');
end
if ismember(23, whichOnes)
    disp('run_umap Example 23 starting...');
    compareBasicReductions('eliverLabeled');
end
if ismember(23.2, whichOnes)
    compareBasicReductions('omip044Labeled400k');  
end
if ismember(23.3, whichOnes)
    compareBasicReductions('genentechLabeled100k');
end

if ismember(23.4, whichOnes)
    compareBasicReductions('maeckerLabeled');  
end

if ismember(23.5, whichOnes)
    compareBasicReductions('omip69Labeled200k');  
end

if ismember(23.6, whichOnes)
    compareBasicReductions('panoramaLabeled');  
end


if ismember(24, whichOnes)
    disp('run_umap Example 24 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('s1_omip69_35D.csv', 'label_column', 'end', 'label_file',  's1_omip69_35D.properties', 'match_scenarios', 4, 'cluster_detail', 'medium', args{:});
    disp('run_umap Example 24 completed with no MATLAB exceptions!');
            
end
if ismember(25, whichOnes)
    disp('run_umap Example 25 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('s1_omip69_35D.csv', 'label_column', 'end', 'label_file', 's1_omip69_35D.properties', 'compress', [125000 500], 'save_template_file', 'ust_s1_omip69_35D.mat', args{:});
    disp('run_umap Example 25 completed with no MATLAB exceptions!');
end
if ismember(26, whichOnes)
    disp('run_umap Example 26 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('sampleBalbcLabeled55k.csv', 'label_column', 11, 'label_file', 'balbcLabels.properties', 'synthesize', [24000 30], args{:});
    disp('run_umap Example 26 completed with no MATLAB exceptions!');
end
if ismember(27, whichOnes)
    disp('run_umap Example 27 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('omip044Labeled.csv', 'fast_approximation', true, 'label_column', 'end', 'label_file', 'omip044Labeled.properties', 'match_scenarios', 4, 'cluster_detail', 'medium', args{:});
    disp('run_umap Example 27 completed with no MATLAB exceptions!');
    [similarity, overlap, missingTrainingSubsets, newTestSubsets]=extras.getMatchSummary;
    fprintf(['%d missing training subsets found, %4.1f overlap, %4.1f similar, '...
        '%d new test subsets\n'],  missingTrainingSubsets, overlap, ...
        similarity, newTestSubsets);
end

if ismember(28, whichOnes)
    disp('run_umap Example 28 starting...');
    explore=strcmpi(verbose, 'graphic');
    
    epp=run_epp('eliverLabeled.csv', 'label_column', 'end',  'cytometer',  'conventional', 'min_branch_size', 150, 'umap_option', 6, 'cluster_detail', 'medium', 'match_predictions', true, 'rebuild_automatically', true, 'explore_hierarchy', explore);
    [testSetWins, nPredicted, means]=epp.getPredictionSummary;
    if length(means)==3
        fprintf('EPP prediction of prior classification:   similarity true+/false+/false-:  %3.1f%%/%3.1f%%/%3.1f%%; test set wins %d/%d!\n',  means(1), means(2), means(3), testSetWins, nPredicted);
    end
    [testSetWins, nPredicted, means]=epp.getUmapPredictionSummary;
    if length(means)==3
        fprintf('UMAP prediction of prior classification:  similarity true+/false+/false-:  %3.1f%%/%3.1f%%/%3.1f%%; Test set wins %d/%d!\n',  means(1), means(2), means(3), testSetWins, nPredicted);
    end
    disp('run_umap Example 28 completed with no MATLAB exceptions!');
end

if ismember(29, whichOnes)
    disp('run_umap Example 29 starting...');
    run_umap('s1_samusikImported_29D.csv', 'label_column', 'end', 'label_file', ...
        's1_29D.properties', 'save_template_file', 'ust_s1_samusikImported_29D_15nn_2D.mat', args{:});
	[~,~,~,ustExtras]=run_umap('s2_samusikImported_29D.csv', 'template_file', 'ust_s1_samusikImported_29D_15nn_2D.mat', 'label_column', 'end', 'match_scenarios', 1:4,  'see_training', true, args{:});
    [~,~,~,ubExtras]=run_umap('s2_samusikImported_29D.csv', 'label_column', 'end', 'label_file', 's2_samusikImported_29D.properties', 'match_scenarios', [3 4], args{:});
    ustExtras.showAllMatchScenarios('Match results for UMAP supervised template reduction');
    ubExtras.showAllMatchScenarios('Match results for UMAP basic reduction');
    disp('run_umap Example 29 completed with no MATLAB exceptions!');
end

if ismember(30, whichOnes)
    disp('run_umap Example 30 starting...');
    run_umap('sample30k.csv', 'min_dist', 0.5, 'spread', 5, args{:});
	run_umap('sample30k.csv', 'min_dist', 0.05, 'spread', 0.5, args{:});
    disp('run_umap Example 30 completed with no MATLAB exceptions!');
end

if ismember(31, whichOnes)
    disp('run_umap Example 31 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('balbc4FmoLabeled.csv', 'label_column', 'end', 'save_template_file', 'ustBalbcMlpPy.mat' , 'mlp_train', 'tensorflow', args{:});
    disp('run_umap Example 31 completed...');
end

if ismember(32, whichOnes)
    disp('run_umap Example 32 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('balbcFmoLabeled.csv', 'label_column', 'end', 'template_file', 'ustBalbcMlpPy.mat', 'cluster_detail', 'medium', 'match_supervisors', 0, 'mlp_confidence', 0, 'see_training', true, args{:});
    UmapUtil.DescribeResults(reduction, umap, clusterIds, extras, 32)
end

if ismember(33, whichOnes)
    disp('run_umap Example 33 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('balbc4FmoLabeled.csv', 'label_column', 'end', 'save_template_file', 'ustBalbcFmoMlp.mat' , 'mlp_train', 'fitcnet', args{:});
    disp('run_umap Example 33 completed...');
end

if ismember(34, whichOnes)
    disp('run_umap Example 34 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('balbcFmoLabeled.csv', 'label_column', 'end', 'match_scenarios', 4, 'template_file', 'ustBalbcFmoMlp.mat', 'cluster_detail', 'medium', 'match_supervisors', 0, 'mlp_confidence', 0, 'see_training', true, 'confusion_chart', true, 'match_predictions', true, 'match_predictions', true, 'match_webpage_file', '~/Documents/run_umap/MlpResults/example34.html',  'false_positive_negative_plot', true, args{:});
    [statement, ~, tables]=UmapUtil.DescribeResults(reduction, umap, clusterIds, extras, 34);
    disp(statement);
    for i = 1:length(tables)
        disp(tables{i});
    end
    disp('run_umap Example 34 completed...');
end

if ismember(35, whichOnes)
    disp('run_umap Example 35 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('balbc4RagLabeled.csv', 'label_column', 'end', 'save_template_file',  'ustBalbc4RagMlp.mat', 'mlp_train', 'fitcnet', args{:});
    disp('run_umap Example 35 completed...');
end

if ismember(36, whichOnes)
    disp('run_umap Example 36 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('ragLabeled.csv', 'label_column', 'end', 'template_file', 'ustBalbc4RagMlp.mat', 'cluster_detail', 'medium', 'all_prediction_figs', true, 'match_supervisors', 0, 'mlp_confidence', 0, 'see_training', true, args{:});    
    UmapUtil.DescribeResults(reduction, umap, clusterIds, extras, 36)
end


if ismember(37, whichOnes)
    disp('run_umap Example 37 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('balbc4C57Labeled.csv', 'label_column', 'end', 'save_template_file',  'ustBalbc4C57Mlp.mat', 'mlp_train', 'fitcnet', args{:});
    disp('run_umap Example 37 completed...');
end

if ismember(38, whichOnes)
    disp('run_umap Example 38 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('c57Labeled.csv', 'label_column', 'end', 'template_file', 'ustBalbc4C57Mlp.mat', 'cluster_detail', 'medium', 'match_supervisors', 0, 'mlp_confidence', 0, 'see_training', true, args{:});
    UmapUtil.DescribeResults(reduction, umap, clusterIds, extras, 38)
end

if ismember(39, whichOnes)
    disp('run_umap Example 39 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('balbc4RagLabeled.csv', 'label_column', 'end', 'save_template_file',  'ustBalbc4RagMlpPy.mat', 'mlp_train', struct('Epochs', 101), args{:});
    disp('run_umap Example 39 completed...');
end

    
if ismember(40, whichOnes)
    disp('run_umap Example 40 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('ragLabeled.csv', 'label_column', 'end', 'template_file', 'ustBalbc4RagMlpPy.mat', 'cluster_detail', 'medium', 'match_supervisors', 0, 'mlp_confidence', 0, 'see_training', true, args{:});
    UmapUtil.DescribeResults(reduction, umap, clusterIds, extras, 40)
end


    
if ismember(41, whichOnes)
    disp('run_umap Example 41 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('balbc4C57Labeled.csv', 'label_column', 'end', 'save_template_file',  'ustBalbc4C57MlpPy.mat', 'mlp_train', struct('Epochs', 101), args{:});
    disp('run_umap Example 41 completed...');
end
    
if ismember(42, whichOnes)
    disp('run_umap Example 42 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('c57Labeled.csv', 'label_column', 'end', 'template_file', 'ustBalbc4C57MlpPy.mat', 'cluster_detail', 'medium', 'match_supervisors', 0, 'mlp_confidence', 0, 'see_training', true, args{:});
    UmapUtil.DescribeResults(reduction, umap, clusterIds, extras, 42)
end

if ismember(43, whichOnes)
    disp('run_umap Example 43 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('omip044Labeled400k.csv', 'label_column', 'end', 'save_template_file', 'ustOmip044Mlp.mat', 'mlp_train',  'fitcnet', args{:});
    disp('run_umap Example 43 completed...');
end
    
if ismember(44, whichOnes)
    disp('run_umap Example 44 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('omip044Labeled.csv', 'label_column', 'end', 'template_file', 'ustOmip044Mlp.mat', 'cluster_detail', 'medium', 'match_supervisors', 0, 'mlp_confidence', 0, 'see_training', true, args{:});
    UmapUtil.DescribeResults(reduction, umap, clusterIds, extras, 44)
end


if ismember(45, whichOnes)
    disp('run_umap Example 45 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('genentechD1Labeled.csv', 'label_column', 'end', 'save_template_file', 'ustGenentechD1Mlp.mat', 'mlp_train',  'fitcnet', args{:});
    disp('run_umap Example 45 completed...');
end
    
if ismember(46, whichOnes)
    disp('run_umap Example 46 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('genentechD2Labeled.csv', 'label_column', 'end', 'template_file', 'ustGenentechD1Mlp.mat', 'cluster_detail', 'medium', 'match_supervisors', 0, 'mlp_confidence', 0, 'see_training', true, args{:});
    UmapUtil.DescribeResults(reduction, umap, clusterIds, extras, 46)
end


if ismember(47, whichOnes)
    disp('run_umap Example 47 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('samusikManualS1.csv', 'label_column', 'end', 'save_template_file', 'ustSamusikS1Mlp.mat', 'mlp_train',  'fitcnet', args{:});
    disp('run_umap Example 47 completed...');
end
    
if ismember(48, whichOnes)
    disp('run_umap Example 48 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('samusikManualS2.csv', 'label_column', 'end', 'template_file', 'ustSamusikS1Mlp.mat', 'cluster_detail', 'medium', 'match_supervisors', 0, 'mlp_confidence', 0, 'see_training', true, args{:});
    UmapUtil.DescribeResults(reduction, umap, clusterIds, extras, 48)
end
if ismember(49, whichOnes)
    disp('run_umap Example 49 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('s1_omip069.csv', 'label_column', 'end', 'save_template_file', 'ustOmip69S1Mlp.mat', 'mlp_train',  'fitcnet', args{:});
    disp('run_umap Example 49 completed...');
end
    
if ismember(50, whichOnes)
    disp('run_umap Example 50 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('s2_omip069.csv', 'label_column', 'end', 'template_file', 'ustOmip69S1Mlp.mat', 'cluster_detail', 'most high', 'match_supervisors', 0, 'mlp_confidence', 0, 'see_training', true, args{:});
    UmapUtil.DescribeResults(reduction, umap, clusterIds, extras, 50)
end
if ismember(51, whichOnes)
    disp('run_umap Example 51 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('maeckerS1.csv', 'label_column', 'end', 'save_template_file', 'ustMaeckerS1Mlp.mat', 'mlp_train',  'fitcnet', args{:});
    disp('run_umap Example 51 completed...');
end
    
if ismember(52, whichOnes)
    disp('run_umap Example 52 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('maeckerS2.csv', 'label_column', 'end', 'template_file', 'ustMaeckerS1Mlp.mat', 'cluster_detail', 'medium', 'match_supervisors', 0, 'mlp_confidence', 0, 'see_training', true, args{:});
    UmapUtil.DescribeResults(reduction, umap, clusterIds, extras, 52)
end
if ismember(53, whichOnes)
    disp('run_umap Example 53 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('s1_omip047.csv', 'label_column', 'end', 'save_template_file', 'ustOmip047S1Mlp.mat', 'mlp_train',  'fitcnet', args{:});
    disp('run_umap Example 53 completed...');
end
    
if ismember(54, whichOnes)
    disp('run_umap Example 54 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('s2_omip047.csv', 'label_column', 'end', 'template_file', 'ustOmip047S1Mlp.mat', 'cluster_detail', 'medium', 'match_supervisors', 0, 'mlp_confidence', 0, 'see_training', true, args{:});
    UmapUtil.DescribeResults(reduction, umap, clusterIds, extras, 54)
end

if ismember(55, whichOnes)
    disp('run_umap Example 55 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('omip044Labeled400k.csv', 'label_column', 'end', 'save_template_file', 'ustOmip044MlpPy.mat', 'mlp_train',  'tensorflow', args{:});
    disp('run_umap Example 55 completed...');
end
    
if ismember(56, whichOnes)
    disp('run_umap Example 56 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('omip044Labeled.csv', 'label_column', 'end', 'template_file', 'ustOmip044MlpPy.mat', 'cluster_detail', 'medium', 'match_supervisors', 0, 'mlp_confidence', 0, 'see_training', true, args{:});
    UmapUtil.DescribeResults(reduction, umap, clusterIds, extras, 56)
end


if ismember(57, whichOnes)
    disp('run_umap Example 57 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('genentechD1Labeled.csv', 'label_column', 'end', 'save_template_file', 'ustGenentechD1MlpPy.mat', 'mlp_train',  'tensorflow', args{:});
    disp('run_umap Example 57 completed...');
end
    
if ismember(58, whichOnes)
    disp('run_umap Example 58 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('genentechD2Labeled.csv', 'label_column', 'end', 'template_file', 'ustGenentechD1MlpPy.mat', 'cluster_detail', 'medium', 'match_supervisors', 0, 'mlp_confidence', 0, 'see_training', true, args{:});
    UmapUtil.DescribeResults(reduction, umap, clusterIds, extras, 58)
end


if ismember(59, whichOnes)
    disp('run_umap Example 59 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('samusikManualS1.csv', 'label_column', 'end', 'save_template_file', 'ustSamusikS1MlpPy.mat', 'mlp_train',  'tensorflow', args{:});
    disp('run_umap Example 59 completed...');
end
    
if ismember(60, whichOnes)
    disp('run_umap Example 60 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('samusikManualS2.csv', 'label_column', 'end', 'template_file', 'ustSamusikS1MlpPy.mat', 'cluster_detail', 'medium', 'match_supervisors', 0, 'mlp_confidence', 0, 'see_training', true, args{:});
    UmapUtil.DescribeResults(reduction, umap, clusterIds, extras, 60)
end
if ismember(61, whichOnes)
    disp('run_umap Example 61 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('s1_omip069.csv', 'label_column', 'end', 'save_template_file', 'ustOmip69S1MlpPy.mat', 'mlp_train',  'tensorflow', args{:});
    disp('run_umap Example 61 completed...');
end
    
if ismember(62, whichOnes)
    disp('run_umap Example 62 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('s2_omip069.csv', 'label_column', 'end', 'template_file', 'ustOmip69S1MlpPy.mat', 'cluster_detail', 'most high', 'match_supervisors', 0, 'mlp_confidence', 0, 'see_training', true, args{:});
    UmapUtil.DescribeResults(reduction, umap, clusterIds, extras, 62)
end
if ismember(63, whichOnes)
    disp('run_umap Example 63 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('maeckerS1.csv', 'label_column', 'end', 'save_template_file', 'ustMaeckerS1MlpPy.mat', 'mlp_train',  'tensorflow', args{:});
    disp('run_umap Example 63 completed...');
end
    
if ismember(64, whichOnes)
    disp('run_umap Example 64 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('maeckerS2.csv', 'label_column', 'end', 'template_file', 'ustMaeckerS1MlpPy.mat', 'cluster_detail', 'medium', 'match_supervisors', 0, 'mlp_confidence', 0, 'see_training', true, args{:});
    UmapUtil.DescribeResults(reduction, umap, clusterIds, extras, 64)
end
if ismember(65, whichOnes)
    disp('run_umap Example 65 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('s1_omip047.csv', 'label_column', 'end', 'save_template_file', 'ustOmip047S1MlpPy.mat', 'mlp_train',  'tensorflow', args{:});
    disp('run_umap Example 65 completed...');
end
    
if ismember(66, whichOnes)
    disp('run_umap Example 66 starting...');
    [reduction, umap, clusterIds, extras]=run_umap('s2_omip047.csv', 'label_column', 'end', 'template_file', 'ustOmip047S1MlpPy.mat', 'cluster_detail', 'medium', 'match_supervisors', 0, 'mlp_confidence', 0, 'see_training', true, args{:});
    UmapUtil.DescribeResults(reduction, umap, clusterIds, extras, 66)
end

j = N_RUN_UMAP_EXAMPLES + 1;

if ismember(j, whichOnes)
    disp(['run_umap Example ' num2str(j) ' starting...']);
    run_umap('omip044Labeled.csv', 'fast_approximation', true, 'label_column', 'end', 'label_file', 'omip044Labeled.properties', 'match_scenarios', 4, 'cluster_detail', 'very high', args{:});
    disp(['run_umap Example ' num2str(j) ' completed with no MATLAB exceptions!']);
end
j = j+1;

if ismember(j, whichOnes)  
    disp(['run_umap Example ' num2str(j) ' starting...']);
    run_umap('sample2k.csv', 'marker_size', 5, 'marker', '+', ...
        'metric', @KnnFind.ExampleDistFunc, args{:});
    disp(['run_umap Example ' num2str(j) ' completed with no MATLAB exceptions!']);
end
j = j+1;
if ismember(j, whichOnes)
    disp(['run_umap Example ' num2str(j) ' starting...']);
    data=File.ReadCsv(UmapUtil.GetFile);
    X=data(1:2:end, :);
    scale=std(X(:,1:7), 'omitnan');
    try
        [~, ~]=run_umap(X, 'metric', 'seuclidean', 'Scale', scale, args{:});
        disp('ERROR ... should have failed');
    catch ex
        if ~beQuiet
            disp(ex);
        end
        disp('failed as expected');
    end
    scale=std(X, 'omitnan');
    [~, umap]=run_umap(X, 'metric', 'seuclidean', 'Scale', scale, 'K', 17, args{:});
    X=data(2:2:end, :);
    umap.verbose=~beQuiet;
    umap.transform(X);
    disp(['run_umap Example ' num2str(j) ' completed with no MATLAB exceptions!']);
end
j = j+1;
if ismember(j, whichOnes)
    disp(['run_umap Example ' num2str(j) ' starting...']);
    data=File.ReadCsv(UmapUtil.GetFile);
    X=data(1:2:end, :);
    covar=cov(X(:,1:7), 'omitrows');
    try
        [~, ~]=run_umap(X, 'metric', 'mahalanobis', 'Cov', covar, args{:});
        disp('ERROR ... should have failed');
    catch ex
        if ~beQuiet
            disp(ex);
        end
        disp('failed as expected');
    end
    covar=cov(X, 'omitrows');
    [~, umap]=run_umap(X, 'metric', 'mahalanobis', 'Cov', covar, 'K', 19, args{:});
    X=data(2:2:end, :);
    umap.verbose=~beQuiet;
    umap.transform(X);
    disp(['run_umap Example ' num2str(j) ' completed with no MATLAB exceptions!']);
end
j = j+1;
if ismember(j, whichOnes)
    disp(['run_umap Example ' num2str(j) ' starting...']);
    data=File.ReadCsv(UmapUtil.GetFile);
    X=data(1:2:end, :);
    try
        covar=cov(X, 'omitrows');
        [~, ~]=run_umap(X, 'metric', 'MINkowski', 'Cov', covar, args{:});
        disp('ERROR ... should have failed');
    catch ex
        if ~beQuiet
            disp(ex);
        end
        disp('failed as expected');
    end
    P=1.45;
    [~, umap]=run_umap(X, 'metric', 'minkowSKI', 'P', P, 'K', 21, args{:});
    X=data(2:2:end, :);
    umap.verbose=~beQuiet;
    umap.transform(X);
    disp(['run_umap Example ' num2str(j) ' completed with no MATLAB exceptions!']);
end

    function compareBasicReductions(csvFile)
        preamble=['xample 23 with "' csvFile '" '];
        disp(['Starting run_umap e' preamble]);
        [reduction, umap, clusterIds, extras]=run_umap([csvFile '.csv'], 'label_column', 'end', 'match_scenarios', 3, 'cluster_detail', 'medium', 'match_predictions', true, args{:});
        UmapUtil.DescribeResults(reduction, umap, clusterIds, extras, ...
            ['E' preamble 'completed with no MATLAB exceptions!'])
    end

end