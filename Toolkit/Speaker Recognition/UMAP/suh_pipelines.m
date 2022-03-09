%  AUTHORSHIP
%   Primary Developer: Stephen Meehan <swmeehan@stanford.edu> 
%   Math Lead & Secondary Developer:  Connor Meehan <connor.gw.meehan@gmail.com>
%   Bioinformatics Lead:  Wayne Moore <wmoore@stanford.edu>
%   Provided by the Herzenberg Lab at Stanford University 
%   License: BSD 3 clause
%

function [ umapOrEppOrMatch, reduction, clusterIdentifiers, extras]=...
    suh_pipelines(csvFileOrData, varargin)
%Brokers ALL input and output argument of either run_umap or run_epp
%or SuhMatch.Run depending on the named argument 'pipeline' which 
%defaults to 'umap'.
%For usage of umap see umap/run_umap.m
%For usage of epp  see epp/run_epp.m
globals=[];

umapOrEppOrMatch=[];
reduction=[];
clusterIdentifiers=[];
extras=[];
if nargin<1
    csvFileOrData=[];
end
if ~isdeployed
    try
        edu.stanford.facs.swing.CpuInfo.isMac;
    catch
        initPaths
        try
            edu.stanford.facs.swing.CpuInfo.isMac;
        catch
            msg('Problem loading SUH jars');
            return;
        end
    end
else
    if ismac %&& isdeployed
        appleApp = com.apple.eawt.Application.getApplication();
        globals=BasicMap.Global;
        f=fullfile(globals.contentFolder, ...
            'pipeline.png');
        img=java.awt.Toolkit.getDefaultToolkit.createImage(f);
        appleApp.setDockIconImage(img);
    end
end
if nargin==2 && strcmpi('job_folder', csvFileOrData)
    ArgumentClinic.RunJobs(varargin{1});
    return;
elseif isempty(csvFileOrData)
    openClinic;
    return;
end
args = inputParser;
addParameter(args, 'pipeline', 'epp', @ischar);
addParameter(args, 'job_folder', '', @Args.IsJobFolderOk);
[~, arg1NameIfNotFile, csvExt]=fileparts(lower(csvFileOrData));
if ~isempty(csvExt)
    arg1NameIfNotFile='';
end
if startsWith(arg1NameIfNotFile, 'pipe')
    varargin=['pipeline', varargin];
elseif startsWith(arg1NameIfNotFile, 'job_folder')
    varargin=['job_folder', varargin];
end
args=Args.NewKeepUnmatched(args, varargin{:});
varArgIn=Args.RemoveArg(varargin, 'pipeline');
varArgIn=Args.RemoveArg(varArgIn, 'job_folder');
MatBasics.WarningsOff;
if ~strcmpi(args.pipeline, 'epp') ...
        && ~strcmpi(args.pipeline, 'umap') ...
        && ~strcmpi(args.pipeline, 'clinic') ...
        && ~strcmpi(args.pipeline, 'match') 
    msgError('<html>Pipeline argument must be <br>''epp'',  ''umap'', ''match'' or "clinic"<hr></html>');
    return;
end
if strcmpi(args.pipeline, 'umap')
    if isdeployed
        if length(varArgIn)>1
            umapArgs=Args(UmapUtil.DefineArgs);
            args=Args.Str2NumOrLogical(umapArgs.p.Results, varArgIn);
            [reduction, umapOrEppOrMatch, clusterIdentifiers, extras]=...
                run_umap(csvFileOrData, args{:});
        else
            [reduction, umapOrEppOrMatch, clusterIdentifiers, extras]=...
                run_umap(csvFileOrData);
        end
    else
        [reduction, umapOrEppOrMatch, clusterIdentifiers, extras]=...
            run_umap(csvFileOrData, varArgIn{:});
    end
    if isempty(reduction)
        umapOrEppOrMatch=[];
    end
elseif strcmpi(args.pipeline, 'epp')
    umapOrEppOrMatch=run_epp(csvFileOrData, varArgIn{:});
    if isempty(umapOrEppOrMatch)
        fprintf('\n\nThe EPP hierarchy was NOT built!!\n\n');
        return;
    end
elseif strcmpi(args.pipeline, 'clinic')
    openClinic;
else
    if ~startsWith(arg1NameIfNotFile, 'pipe')
        [match, matchTable, ~,  trainingQfTree, ...
            ~, testQfTree]=SuhMatch.Run('training_set', ...
            csvFileOrData, varArgIn{:});
    else
        [match, matchTable, ~,  trainingQfTree, ...
            ~, testQfTree]=SuhMatch.Run(varArgIn{:});
    end
    extras=UMAP_extra_results;
    extras.qfd={matchTable};
    extras.qft={trainingQfTree, testQfTree};
    umapOrEppOrMatch=match;
end
if isstruct(args) 
    ArgumentClinic.RunJobs(args.job_folder);
end

    function initPaths
        pPth=fileparts(mfilename('fullpath'));
        utilPath=fullfile(pPth, 'util');
        addpath(utilPath);
        MatBasics.WarningsOff
        if ~initJava
            error('Cannot find suh.jar');
        end
        eppPath=fullfile(pPth, 'epp');
        addpath(eppPath);
        addpath(utilPath);
        umapPath=fullfile(pPth, 'umap');
        mlpPath=fullfile(pPth, 'mlp');
        FileBasics.AddNonConflictingPaths({eppPath, utilPath, ...
            umapPath, mlpPath});
        globals=BasicMap.Global;
        if isempty(globals.propertyFile)
            homeFolder=globals.appFolder;
            try
                props=fullfile(homeFolder, 'globalsV3.mat');
                globals.load(props);
            catch
            end
        end

    end
    
    function openClinic
        curPath=fileparts(mfilename('fullpath'));
        if ~isdeployed
            mexNN=fullfile(curPath, 'umap', UmapUtil.LocateMex);
            mexEPP=fullfile(curPath, 'epp', SuhEpp.LocateMex);
            if ~exist(mexEPP, 'file')
                mexEPP=fullfile(curPath, 'util', SuhEpp.LocateMex);
            end
            if ~exist(mexEPP, 'file') || ~exist(mexNN, 'file')
                UmapUtil.OfferFullDistribution(true)
                globals.save;
                mexEPP=fullfile(curPath, 'epp', SuhEpp.LocateMex);
                if ~exist(mexNN, 'file')
                    msg('Must have UMAP''s MEX files to continue');
                    return;
                end
                if ~exist(mexEPP, 'file')
                    if ~askYesOrNo('Proceed without EPP pipeline?')
                        return;
                    end
                end
            end
        end
        ArgumentClinic;
    end
    
end
