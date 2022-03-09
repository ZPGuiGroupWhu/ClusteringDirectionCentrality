function [epp, subset_ids]=run_epp(csv_file_or_data, varargin)
%   RUN_EPP runs exhaustive projection pursuit to discover/learn
%   significant subsets of a given data set.
%
%   EPP is an unsupervised data subset discovery method intended for any
%   N-dimensional dataset containing continuous numeric measurements. See
%   ALGORITHM section below for more details.
%
%   [epp, subset_ids]=RUN_EPP(csv_file_or_data,...'NAME1',VALUE1, 'NAMEN',VALUEN) 
%   
%   OUTPUT ARGUMENTS
%   Invoking run_umap returns these values:
%   1)  epp, an instance of the class defined in SuhEpp
%   2)  subset_ids, numeric identifiers for each 
%        row in the dataset
%   
%   REQUIRED INPUT ARGUMENT
%    csv_file_or_data is either 
%   A) a char array identifying a CSV text file containing the dataset 
%   for EPP to divide into subsets.
%   B) the actual dataset to be reduced; a numeric matrix.
%
%   If A), then the CSV file must have column names in the first line.
%   These annotate the dimensions which EPP reduces.  If B), then names are
%   provided by the name-value pair argument 'column_names' when creating
%   or running a template.
%
%  EPP requires that the dataset values be normalized from 0 to 1. Values
%  slightly below 0 are okay.
%
%   OPTIONAL NAME VALUE PAIR ARGUMENTS
%   NAME                VALUE
%
%  'balanced'           true/false to specify the split goal. If false then
%                       EPP favors splits with the least weight/density
%                       along their edges. If true then EPP favors splits
%                       that are both edge density as well as being similar
%                       sized.
%		                The default is true.
%
%  'KLD_normal_1D'      A number from 0 to 1 which represents the cutoff of
%                       the Kullback-Leibler Divergence (KLD) test used to
%                       determine each measurement's informativeness and
%                       whether it is worth using in a split. 0 indicates
%                       the data is the normal distriubtion and thus not
%                       informative. 1 indicates very informative.
%                       The default is .16.
%
%  'KLD_normal_2D'      Cutoff for the KLD test to determine if a pair of
%                       dimensions is worth splitting.
%                       The default is .16.
%
%  'KLD_exponential_1D' Cutoff for the KLD test used when the data is to be
%                       compared against an exponential tail (e.g. CyTOF).
%                       The default is .16
%    
%  'max_clusters'       The most clusters before narrowing the clustering
%                       bandwidth whether splitting by DBM or modal
%                       clustering.
%                       The default is 12.
%    
%  'threads'            The # of threads to use. 0 means no threads
%                       and -1 means as many threads as available hardware
%                       cores on the computer doing the split.
%                       The default is -1.
%
%  'splitter'           A string specifying the clustering method EPP
%                       uses to determine separations.  'modal' specifies
%                       modal clustering.  'dbm' specifies density-based
%                       merging.
%                       The default is 'modal'.
%
%  'W'                  A number used when splitter=modal. Standard
%                       deviation of kernel: this is the highest achievable
%                       resolution. In practice a higher value might be
%                       used for application reasons or just performance.
%                       The default is .01.
%
%  'sigma'              A number used when splitter=modal. This controls
%                       the density threshold for starting a new cluster.
%                       The default is 3.0.
%
%  'cytometer'          A string used when splitter=modal.
%                       'conventional' provides settings appropriate for
%                       most fluorescent cytometers that use band pass
%                       filters and long pass filters.
%                       'spectral' provides settings appropriate for most
%                       fluorescent cytometers which use the the full light
%                       spectrum.
%                       'cytof' provides settings appropriate to most
%                       mass cytometers.
%                       
%  'cluster_detail'     A string used when splitter=dbm. From narrow to
%                       wide kernel bandwidth the values are 'most high',
%                       'very high', 'high', 'medium', 'low' and 'very
%                       low'.
%                       The default is 'high'.
%
%   'umap_option'       An integer directing a UMAP reduction to be run
%                       after EPP completes.  1 does a basic UMAP
%                       reduction; 2 does 1 with fast approximation; 3 does
%                       UMAP supervised reduction; 4 does 3 with fast
%                       approximation.  If prior classification labels
%                       exist then: 5 does UMAP unsupervised reduction and
%                       then compares the prior labels to clusters; 6 does
%                       5 with fast approximation; 7 does label-supervised
%                       reduction; 8 does 7 with fast approximation.
%
%   'match_predictions' true/false to invoke the PredictionAjudictor
%                       window.  This contains a table of mass+distance
%                       similariies between the predicted and predicting
%                       subsets.  Selecting a row activates our
%                       DimensionExplorer which shows each dimension's 
%                       measurement distribution, informativeness
%                       (via Kullback-Leibler divergence) and other
%                       statistics for the row's subset. You can adjudicate
%                       classification disagreement by comparing the prior 
%                       classification's false negatives to the EPP 
%                       classification's false positives ... and then 
%                       comparing both to the agreed upon true positives
%                       as well as prior classification'`s full predicted 
%                       subset.
%                       Default is false.
%
%
%  'explore_hierarchy' true/false to show a window
%                       with the gating tree which EPP produces 
%   run_umap arguments  If umap_option is given then any valid run_umap
%                       argument can be give to run_epp.
%                              
%   EXAMPLES 
%   Note these examples assume your current MATLAB folder is where
%   run_epp.m is stored.
%
%   1.  Download the example CSV files and run sample10k.csv.
%
%       run_epp;
%
%   2.  Use EPP to discover data subsets in the OMIP-044 dataset, collected
%       with a conventional flow cytometer.  We reduce the published sample
%       by 75% for speed.  The full sample is omip044Labeled.csv.
%
%       run_epp('omip044Labeled400k.csv', 'label_column', 'end', 'cytometer', 'conventional', 'min_branch_size', 150);
%
%   3.  Use EPP to discover data subsets in lymphocyte data taken from a
%       BALB/c mouse strain, collected with a conventional flow cytometer.
%
%       run_epp('eliverLabeled.csv', 'label_column', 'end', 'cytometer', 'conventional', 'min_branch_size', 150);
%
%   4.  Use EPP to discover data subsets in human blood data, collected
%       with a mass cytometer.  We reduce the published example by 50% for
%       speed. The full sample is genentechLabeled.csv.
%
%       run_epp('genentechLabeled100k.csv', 'label_column', 'end', 'cytometer', 'cytof', 'min_branch_size', 150);
%
%   5.  Use EPP to discover data subsets in human peripheral blood
%       mononuclear cells, collected with a mass cytometer.
%
%       run_epp('maeckerLabeled.csv', 'label_column', 'end', 'cytometer', 'cytof', 'min_branch_size', 150);
%
%   6.  Use EPP to discover data subsets in the OMIP-069 dataset, collected
%       with a spectral flow cytometer.  We reduce the published sample by
%       66% for speed. The full sample is omip69Labeled.csv.
%
%       run_epp('omip69Labeled200k.csv', 'label_column', 'end', 'cytometer', 'spectral', 'min_branch_size', 150);
%
%   7.  Use EPP to discover data subsets in the OMIP-047 dataset, collected
%       with a conventional flow cytometer.
%
%       run_epp('omipBLabeled.csv', 'label_column', 'end', 'cytometer', 'conventional', 'min_branch_size', 150, 'W', .015);
%
%   8.  Use EPP to discover data subsets in the "Panorama" dataset,
%       collected with a mass cytometer.
%
%       run_epp('panoramaLabeled.csv', 'label_column', 'end', 'cytometer', 'cytof', 'min_branch_size', 150, 'W', .024);
%
%
%  ALGORITHM
%  Wayne Moore is EPP's primary inventor.  Secondary inventors include
%  David Parks, (drparks@stanford.edu), Connor Meehan, and Stephen Meehan.
%
% Slides describing the invention can be viewed at
% https://onedrive.live.com/?authkey=%21ALyGEpe8AqP2sMQ&cid=FFEEA79AC523CD46&id=FFEEA79AC523CD46%21209192&parId=FFEEA79AC523CD46%21204865&o=OneUp
% or downloaded at 
% http://cgworkspace.cytogenie.org/run_umap/publications/herzenberg60.pptx.
%
% In summary EPP is an unsupervised data subset discovery method that for
% an N-dimensional dataset determines the best 2 way split in any possible
% pair of dimensions and then repeats on each split until no further splits
% occur in any possible dimension pair.  The result is a hierarchy of 2-way
% splits where the leaves represent well separated subsets of the total
% data set. Every row in the dataset occurs exactly once in only one of
% EPP's leaves: hence "no data point is left behind".
% One of the motivations for this invention is to find an ultra
% conservative approach to avoiding the curse of dimensionality that is
% constantly a risk for N-dimensional subset discovery methods which rely
% on "all at once" separation detecting techniques. Thus EPP is distinctly
% more cautious than subset discovery methods (or data island visualization
% methods) like t-SNE, UMAP and flowSOM.
%
%
%
% AUTHORSHIP
%   Primary Developer: Stephen Meehan <swmeehan@stanford.edu> 
%   Math Lead & Secondary Developer:  Connor Meehan <connor.gw.meehan@gmail.com>
%   Bioinformatics Lead & Secondary Developer:  Wayne Moore <wmoore@stanford.edu>
%   Provided by the Herzenberg Lab at Stanford University 
%   License: BSD 3 clause
%
subset_ids=[];

disp(SuhEpp.DISCLOSURE)
if nargin<1
    csv_file_or_data='sample10k.csv';
end
if ~isdeployed
    initPaths;
end
if ~confirmMex
    epp=[];
    return;
end
    
SuhModalSplitter.Quarantine;
eppArgs=Args(SuhEpp.DefineArgs);
ignoreIfChar={'verbose'};
varArgIn=Args.Str2NumOrLogical(eppArgs.fields, ...
    varargin, ignoreIfChar);
splitterArgs=Args(SuhModalSplitter.DefineArgs);
varArgIn=Args.Str2NumOrLogical(...
    splitterArgs.p.Results, varArgIn, ignoreIfChar);
splitterArgs=Args(SuhDbmSplitter.DefineArgs);
varArgIn=Args.Str2NumOrLogical(...
    splitterArgs.p.Results, varArgIn, ignoreIfChar);
if isdeployed
    if length(varargin)>1
        if ~Args.Contains('explore_hierarchy', varArgIn{:})
            varArgIn{end+1}='explore_hierarchy';
            varArgIn{end+1}=false;
        end
        epp=SuhEpp.New(csv_file_or_data, varArgIn{:});
    else
        epp=SuhEpp.New(csv_file_or_data, 'explore_hierarchy', false);
    end
else
    epp=SuhEpp.New(csv_file_or_data, varArgIn{:});
end
if isempty(epp)
    fprintf('\n\nThe EPP hierarchy was NOT built!!\n\n');
    return;
end
if ~isempty(epp.args.properties_file)
    file=epp.args.properties_file;
    if exist(epp.properties_file, 'file')
        if ~exist(epp.properties_file, 'dir')
            if ~isequal(file, epp.properties_file)
                copyfile(epp.properties_file, file);
            end
        else
            file=[];
        end
    end
else
    file=epp.properties_file;
end
persistent times_run;
if isempty(times_run)
    times_run=0;
end
if exist(file, 'file') 
    if times_run==0
        fprintf(['\n\nThe full EPP hierarchy is stored in\n  %s\n\n'...
            '\tThe property name ''0'' fetches  the first polygon split.\n'...
            '\t''0.B'' gets the 2nd polygon unless arguing use_not_gate true. \n'....
            '\tThe next levels of splits use property names ''01'' and ''02'' \n'...
            '\t(if they exist) then ''011'', ''012'', ''021'' and \n'...
            '\t''022''. Add suffix ''.leaf'' to property name to retrieve a \n'...
            '\trectangle gate if the split is the last (leaf). The  \n'...
            '\tproperty value for such a gate property is a string of zero based \n'...
            '\tnumbers containing the input data''s 2 columns, followed by polygon \n'...
            '\tX/Y coordinates in column-wise order.\n\n'...
            '\tSo for example, the value ''2/4\\: 0 1 1 0 0 0 1 0'' would mean\n'...
            '\tthe gate''s X/Y columns are 2 and 4 and the polygon is a triangle\n'...
            '\tthat splits the projection in half with the 4 X/Y coordinates:  \n'...
            '\t\t0 0\n'...
            '\t\t1 0\n'...
            '\t\t1 1\n'...
            '\t\t0 0\n'...
            '\n\n'], file);
    end
else
    fprintf('\n\nThe EPP hierarchy was NOT built!!\n\n');
end
times_run=times_run+1;
if nargout>1
    if ~any(epp.dataSet.finalSubsetIds~=0)
        epp.rakeLeaves;
    end
    subset_ids=epp.dataSet.finalSubsetIds;
end

    function initPaths
        pth=fileparts(mfilename('fullpath'));
        pPth=fileparts(pth);
        utilPath=fullfile(pPth, 'util');
        addpath(utilPath);
        MatBasics.WarningsOff
        if ~initJava
            error('Cannot find suh.jar');
        end
        umapPath=fullfile(pPth, 'umap');
        if exist(umapPath, 'dir')
            FileBasics.AddNonConflictingPaths({pth, utilPath, umapPath});
        else
            FileBasics.AddNonConflictingPaths({pth, utilPath});
        end
    end

    function ok=confirmMex
        ok=true;
        if ~isdeployed  % check if open source distribution
            pth=fileparts(mfilename('fullpath'));
            pPth=fileparts(pth);
            autoGateFile=fullfile(pPth, 'CytoGate.m');
            if ~exist(autoGateFile, 'file')
                file2=['mexSptxModal.' mexext];
                eppFolder=fileparts(mfilename('fullpath'));
                fullFile=fullfile(eppFolder, file2);
                if ~exist(fullFile, 'file')
                    if exist(fullfile(fileparts(eppFolder), 'umap'), 'file')
                        UmapUtil.OfferFullDistribution(true);
                        ok=exist(fullFile, 'file');
                    else
                        ok=SuhEpp.OfferFullDistribution;
                    end
                end
            end
        end
    end
end