%  AUTHORSHIP
%   Primary Developer: Stephen Meehan <swmeehan@stanford.edu> 
%   Math/Statistics:   Connor Meehan <connor.gw.meehan@gmail.com>
%                      Guenther Walther <gwalther@stanford.edu>
%   Primary inventors: Wayne Moore <wmoore@stanford.edu>
%                      David Parks <drparks@stanford.edu>
%   Provided by the Herzenberg Lab at Stanford University 
%   License: BSD 3 clause
%
classdef SuhEpp < SuhAbstractClass
    properties(Constant)
        TESTING=false;
        FONT_SIZE=24;
        VERSION='2021.4';
        TITLE=['EPP (v' SuhEpp.VERSION ')' ];
        CREDITS='Herzenberg Lab, Stanford University';
        INVENTORS='Wayne Moore, David Parks, Connor Meehan & Stephen Meehan';
        PROGRAMMERS='Stephen Meehan & Wayne Moore';
        
        DISCLOSURE=sprintf(...
            '%s, %s,\n\tInventors: %s\n\tProgrammers: %s\n', ...
            SuhEpp.TITLE, SuhEpp.CREDITS, ...
            SuhEpp.INVENTORS, SuhEpp.PROGRAMMERS);
        PROP_JOB_FOLDER='SuhEpp.job_folder';
        CYTOMETER_VALUES= {'cytof', 'spectral', 'conventional'};
            
    end
    
    properties(SetAccess=private)
        splitter;
        dataSet;
        map;
        leafCount=0;
        branchCount=0;
        levels=0;
        fullSize;
        root;
        pu;
        argued;
        unmatched;
        folder;
        properties_file;
        done=false;
        justBuilt=false;
        leafSizes;
        app;
        figHierarchyExplorer;
        busyHierarchyExplorer;
        busyLbl;
        tb;
        umapVersion;
        umapVarArgIn;
        umapArgsDone=false;
        selectedKey;
        cbMirror;
        leafRaker;
        leafFigs;
        suhTree;
        umapArgOut={};
        fncSyncKld;
    end
    
    properties
        verbose=false;
        args;
    end
    
    methods
        function this=SuhEpp(dataSet, args, argued, unmatched, ...
                hierarchyExplorer)
            this=this@SuhAbstractClass();
            this.app=BasicMap.Global;
            try
                this.umapVersion=UMAP.VERSION>0;
            catch 
                this.umapVersion='';
            end
            this.args=args;
            this.argued=argued;
            this.unmatched=unmatched;
            SuhAbstractClass.AssertIsA(args.splitter, 'SuhSplitter');
            this.splitter=args.splitter;
            this.dataSet=dataSet;
            this.folder=args.folder;
            this.root=SuhSubset(dataSet);
            this.map=java.util.Properties;
            dataSet.setProperties(this.map, this.args.column_external_indexes);
            this.map.put('splitter', java.lang.String(this.splitter.type));
            this.fullSize=[String.encodeInteger(this.dataSet.R) ...
                    'x' num2str(this.dataSet.C)];
                build=true;
            properties_file=[];
            if this.args.min_branch_size==0
                min_branch='';
            else
                min_branch=[num2str(this.args.min_branch_size) '_'];
            end
            suffix=['.' min_branch this.splitter.type ...
                this.splitter.getFileNameSuffix '.epp'];
            if ~isempty(this.dataSet.file) && isempty(this.folder)
                [p,f]=fileparts(this.dataSet.file);
                folderName=[f suffix];
                this.folder=fullfile(p,folderName);
            else
                if ~endsWith(this.folder, suffix)
                    this.folder=[this.folder suffix];
                end
            end
            if nargin>4 && ~isempty(hierarchyExplorer)
                this.initFig(hierarchyExplorer);
            end
            if ~isempty(this.folder)
                File.mkDir(this.folder);
                if ~exist(this.folder, 'dir')
                    error('%s is not a folder!', this.folder);
                end
                if ~isempty(this.args.output_folder)
                    this.args.output_folder=File.ExpandHomeSymbol(this.args.output_folder);
                else
                    this.args.output_folder=this.folder;
                end
                if ~isempty(this.args.properties_file)
                    this.args.properties_file=File.ExpandHomeSymbol(this.args.properties_file);
                    properties_file=this.args.properties_file;
                else
                    properties_file=fullfile(this.folder, 'epp.properties');
                end
                if args.try_properties_download ...
                        && ~exist(properties_file, 'file')
                    [~,f,e]=fileparts(this.folder);
                    folderName=[f e];
                    down=WebDownload.GetExampleIfMissing([folderName '.properties']);
                    if exist(down, 'file')
                        movefile(down, properties_file);
                    end
                end
                this.properties_file=properties_file;
                if exist(properties_file, 'file')
                    if ~args.rebuild_automatically
                        if args.reuse_automatically 
                            use=true;
                            cancelled=false;
                        else
                            [use, cancelled]=askYesOrNo(Html.WrapHr(...
                                ['Use the previous EPP hierarchy'...
                                '<br>built for this same data?']), ...
                                'Running EPP', 'North+', true, '', ...
                                'SuhEpp.PreviousBuild');
                        end
                        if cancelled
                            if ~isempty(hierarchyExplorer)
                                close(hierarchyExplorer.fig);
                            end
                            return;
                        elseif use
                            build=false;
                            this.load(properties_file);
                            rows_=this.map.get('rows');
                            assert(isempty(rows_) || str2double(rows_)==this.dataSet.R, ...
                                'rows not equal, original=%d. current=%d',...
                                this.dataSet.R, str2double(rows_))
                            cols_=this.map.get('cols');
                            assert(isempty(cols_) || str2double(cols_)==this.dataSet.C, ...
                                'columns not equal, original=%d. current=%d',...
                                this.dataSet.C, str2double(cols_))%#ok<*ST2NM>
                            mns1=this.map.get('means');
                            if ~isempty(mns1)
                                mns1=str2num(mns1);
                                mns2=mean(dataSet.data);
                                if ~isequal(mns2, mns1)
                                    difs=abs(mns2-mns1);
                                    if ~all(difs<.0001)
                                        if askYesOrNo('Data means differ.. rebuild?')
                                            build=true;
                                        else
                                            this.done=false;
                                            warning('Cannot continue with data issues');
                                            return;
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            pu=[];
            if build
                this.justBuilt=true;
                if ~isempty(args.pu)
                    pu=this.buildAll(args.pu);
                elseif args.verbose_flags
                    pu=this.buildAll;
                else
                    pu=this.buildAll([]);
                end
                this.map.put('means', java.lang.String(num2str(mean(this.dataSet.data))));
                this.map.put('cols', java.lang.String(num2str(this.dataSet.C)));
                this.map.put('rows', java.lang.String(num2str(this.dataSet.R)));
                if ~isempty(properties_file)
                    if ~isempty(pu) && pu.cancelled
                    else
                        this.save(properties_file);
                    end
                end
                if isempty(pu) ||  ~pu.cancelled
                    removeFile(SuhDataSet.FILE_MATCH);
                    removeFile(SuhDataSet.FILE_MATCH_LABEL);
                    removeFile(SuhDataSet.FILE_MATCH_NAMES_CLRS);
                elseif ~isempty(hierarchyExplorer)
                    close(hierarchyExplorer.fig);
                end
            end
            if this.args.verbose_flags
                disp(this.summary);
            end
            this.done=isempty(pu) || ~pu.cancelled;
            this.properties_file=properties_file; 
            if this.done
                if ~isempty(this.args.gating_ml_file)
                    GatingMl.Run(this);
                end
                if this.args.explore_hierarchy
                    this.exploreHierarchy;
                    if this.isCharacterizedByLabels
                        img=Html.ImgXy('demoIcon.gif', ...
                            this.app.contentFolder, 7, false);
                        html=['<html><table border="0"><tr><td align="center">' ...
                            img '</td></tr><tr><td align="center">' ...
                            Gui.YellowH3('Comparing EPP to prior classification')...
                            '</td></tr></table><html>'];
                        this.busyLbl.setText(html);
                    end
                end
                this.dataSet.characterize(this, pu,...
                    this.args.explore_hierarchy);               
                if this.args.umap_option>0
                    for i=1:length(this.args.umap_option)
                        o=struct();
                        opt=this.args.umap_option(i);
                        [o.reduction, o.umap, o.clusterIdentifiers, ...
                            o.extras]= this.umap(opt);
                        this.umapArgOut{opt}=o;
                    end
                end
            end
            if isempty(args.pu) && ~isempty(pu)
                MatBasics.RunLater(@(h,e)closePu, 2.5);
            end
            if this.args.explore_hierarchy
                MatBasics.RunLater(@(h,e)hideBusy, .37);
            end
            this.copyToOutputIfArgued(properties_file)
            
            function hideBusy
                try
                    Gui.HideBusy(this.figHierarchyExplorer, ...
                        this.busyHierarchyExplorer, true);
                    this.busyHierarchyExplorer=[];
                    this.busyLbl=[];
                    figure(this.figHierarchyExplorer);
                catch
                end
            end

            function closePu
                pu.close;
            end
            
            function removeFile(fl)
                fl=fullfile(this.folder, fl);
                if exist(fl, 'file')
                    delete(fl);
                end
            end    
        end
        
        function clearUmapOutputs(this)
            this.umapArgOut={};
        end
        
        function [avgSimilarity, avgOverlap, trainingSubsetsFound, ...
                newTestSubsets]=getUmapMatchSummary(this)
            [avgSimilarity, avgOverlap, trainingSubsetsFound, ...
                newTestSubsets]=this.getMatchSummary(5);
            if isnan(avgSimilarity)
                [avgSimilarity, avgOverlap, trainingSubsetsFound, ...
                            newTestSubsets]=this.getMatchSummary(6);
            end
        end
        
        function [avgSimilarity, avgOverlap, trainingSubsetsFound, ...
                newTestSubsets]=getMatchSummary(this, umapOption)
            avgSimilarity=nan; avgOverlap=nan; ...
                trainingSubsetsFound=nan;  newTestSubsets=nan;
            if nargin>1
                if length(this.umapArgOut)>=umapOption
                    umap=this.umapArgOut{umapOption};
                    if ~isempty(umap)
                        [avgSimilarity, avgOverlap, trainingSubsetsFound, ...
                            newTestSubsets]=umap.extras.getMatchSummary;
                    end
                end
            elseif ~isempty(this.dataSet) ...
                    && ~isempty(this.dataSet.matchTable)
                [avgSimilarity, avgOverlap, trainingSubsetsFound, ...
                    newTestSubsets]=this.dataSet.matchTable.getSummary;
            end
        end
        
        function [testSetWins, nPredicted, means, mdns, stdDevs]...
                =getUmapPredictionSummary(this)
            [testSetWins, nPredicted, means, mdns, stdDevs]...
                =this.getPredictionSummary(5);
            if isempty(testSetWins)
                [testSetWins, nPredicted, means, mdns, stdDevs]...
                =this.getPredictionSummary(6);
            end
        end
        
        function [testSetWins, nPredicted, means, mdns, stdDevs]...
                =getPredictionSummary(this, umapOption)
            testSetWins=[];
            nPredicted=0;
            means=[];
            mdns=[];
            stdDevs=[];
            if nargin>1
                if length(this.umapArgOut)>=umapOption
                    umap=this.umapArgOut{umapOption};
                    if ~isempty(umap)
                        [testSetWins, nPredicted, means, mdns, stdDevs]...
                            =umap.extras.getPredictionSummary;
                    end
                end
            elseif ~isempty(this.dataSet) ...
                    && ~isempty(this.dataSet.predictions)
                [testSetWins, nPredicted, means, mdns, stdDevs]...
                    =this.dataSet.predictions.getPredictionSummary;
            end            
        end
        
        function str=countLeafHtml(this, key)
            cnt=this.countLeaves(key);
            if cnt<2
                str='';
            else
                str=[ ' <font color="green">(<i>' ...
                    String.encodeInteger(cnt) ...
                    '  leaves</i>)</font>'];
            end
        end
        
        function count=countLeaves(this, key)
            N=this.leafCount;
            count=0;
            for leaf=1:N
                leafKey=char(this.map.getProperty(['leaf.split.' num2str(leaf)]));
                if startsWith(leafKey, key)
                    count=count+1;
                end
            end
        end
        
        function copyToOutputIfArgued(this, file)
            if this.args.save_output
                if this.argued.contains('output_folder')
                    if exist(file, 'file')
                        copyfile(file, this.args.output_folder);
                    end
                end
            end
            
        end
        
        function [key, events]=getLeaf(this, leafId)
            [leafKeySplit, leafKeySize]=SuhEpp.LeafKeys(leafId);
            key=this.map.get(leafKeySplit);            
            events=str2double(this.map.get(leafKeySize));
        end
        
        function fig=showSequencePlots(this, leafId, word, where, fncVisit)
            fig=[];
            if nargin<4
                where='center';
                if nargin<3
                    word='';
                    if nargin<2
                        leafId=this.getLeafCount;
                    end
                end
            end
            assert(leafId>0, 'leafId %d must be > 0', leafId);
            leaves=this.getLeafCount;
            assert(leafId<=leaves, 'leafId %d must be <= %d', ...
                leafId, leaves);            
            [lookFor, leafSize]=this.getLeaf(leafId);
            if isempty(this.leafFigs)
                this.leafFigs=BasicMap;
            else
                fig=this.getSequenceFig(lookFor);
                if ~isempty(fig)
                    figure(fig);
                    return;
                end
            end

            if nargin<5
                fncVisit=@visualize;
                numSplits=length(lookFor);
                [R,C]=Gui.SubPlots(numSplits);
                
                fig=figure('name', [ SuhEpp.TITLE ',' word ...
                    ', leaf #' num2str(leafId) ', '...
                    String.encodeInteger(leafSize) ' events, ' ...
                    String.encodeInteger(numSplits) ' splits'], ...
                    'visible', 'off', 'NumberTitle', 'off', ...
                    'menubar', 'none', 'visible', 'off');
                
                ax=subplot(R,C,1, 'Parent', fig);
                H=SuhEpp.Announce(ax, ['Splitting ' this.fullSize]);
                if iscell(where) % locate list
                    SuhWindow.Follow(fig, where{1}, where{2}, where{3});
                elseif ~isempty(where)
                    movegui(fig, where);
                end
                set(fig, 'visible', 'on');
                if R>3 || C>3
                    P=get(fig, 'Position');
                    width=P(3);
                    height=P(4);
                    extraC=min([C-3, 5]);
                    extraR=min([R-3, 4]);
                    P(3)=width+extraC*width/5;
                    P(4)=height+extraR*height/4;
                    set(fig, 'Position', P);
                end
                set(fig, 'visible', 'on');
            end
            this.seq(lookFor, 1, this.root, fncVisit);
            this.setSequenceFig(lookFor, fig);
            
            function isBranch=visualize(this, key, subset, X, Y, ...
                    splitA, ~, nextKey)
                isBranch=~strcmp(key,lookFor);
                num=length(key)-1;
                delete(H);
                name=this.getName(key);
                if SuhEpp.TESTING
                    if isBranch
                        item=['Split ' num2str(num+1) ];
                    else
                        item=['Leaf ' num2str(leafId) ];
                    end
                    disp(item);
                end
                if X<1 && Y<1
                    X=1;
                    Y=2;
                end
                if R>0
                    ax=subplot(R,C,num+1, 'Parent', fig);
                else
                    ax=get(fig, 'currentAxes');
                end
                ttl=SuhEpp.NodeTitle( struct('name', name, 'key', key, ...
                    'subset', subset) );
                if ~isempty(nextKey)
                    %imshow(this.createPng(nextKey, true), 'parent', ax);
                    
                    this.splitter.plotSelected(ax, subset,...
                        X, Y, splitA, isequal(nextKey(end), '2'), ttl, ...
                        this.getPredictions)
                else
                    this.splitter.plot(ax, subset, X, Y, splitA, ttl, ...
                        this.getPredictions);
                end
                if num+1<numSplits
                    ax=subplot(R,C,num+2, 'Parent', fig);
                    H=SuhEpp.Announce(ax, ['Getting next split ' num2str(subset.size) ...
                        'x' num2str(this.dataSet.C)]);
                end
            end
        end
        
        
        function [axOrKld, ax]=show(this, node, axOrKld)
            parentNode=[];
            if ischar(node) % must be epp key
                key=node;
                node=this.find(node);
                if isempty(node)
                    ax=[];
                    if nargin<3
                        axOrKld=[];
                    end
                    warning('EPP node for key=%s is not found', key);
                    return;
                end
                if ~isequal(key,'0')
                    parentNode=this.find(key(1:end-1));
                end
            end
            createdKld=false;
            if nargin<3
                createdKld=true;
                axOrKld=Kld.Table(node.subset.data, ...
                   node.subset.dataSet.columnNames, ...
                   [],... % no normalizing scale
                   gcf, node.name,'south++','Dimension','EPP', false, ...
                   [], {this.figHierarchyExplorer, 'east++', true}, false);
            end
            if isa(axOrKld, 'Kld')
                pred=this.getPredictions;
                if isempty(parentNode)
                    axOrKld.initPlots(1, 2);
                    ax=axOrKld.getAxes;
                    [~,highlights, highlightName]=...
                        this.splitter.plot(ax, node.subset, node.X, node.Y, ...
                        node.splitA, node.name, pred);
                else
                    axOrKld.initPlots(1, 3);
                    ax=axOrKld.getAxes;
                    this.splitter.plotSelected(ax, parentNode.subset,...
                        parentNode.X, parentNode.Y, parentNode.splitA, ...
                        isequal(key(end), '2'), ...
                        SuhEpp.NodeTitle(parentNode), pred);
                    ax=axOrKld.getAxes(2);
                    [~,highlights, highlightName]=...
                        this.splitter.plot(ax, node.subset, node.X,  ...
                        node.Y, node.splitA, SuhEpp.NodeTitle(node), pred);
                end
                if ~isempty(pred)
                    axOrKld.setHighlights(highlights, highlightName);
                end
                if ~createdKld
                    axOrKld.refresh(node.subset.data, node.name);
                end
                figure(axOrKld.getFigure)
                figure(this.figHierarchyExplorer)
            else
                if strcmpi('figure', get(axOrKld, 'type'))
                    ax=Gui.Axes(axOrKld);
                else
                    ax=axOrKld;
                end
                this.splitter.plot(ax, node.subset, node.X, node.Y, ...
                    node.splitA, node.name);
            end
        end
        
        function setPredictionListener(this, predictions)
            if isa(predictions, 'QfTable')
                predictions.predictions.setSelectionListener(...
                    @(P)hearPredictions(this, P));
            elseif isstruct(predictions)
                warning('Can''t set predictions');
            else
                predictions.setSelectionListener(...
                    @(P)hearPredictions(this, P));
            end
        end
        
        function hearPredictions(this, predictions)
            if ~isempty(predictions.selectedIds) % caller clears my last plots
                feval(this.fncSyncKld);
            end
        end
        
        function node=find(this, eppKey)
            fncVisit=@check;
            node=struct();
            this.seq(eppKey, 1, this.root, fncVisit);
            
            function ok=check(this, key, subset, X, Y, splitA, splitB, ~)
                if strcmp(key,eppKey)
                    ok=false;
                    node.name=this.getName(key);
                    node.key=key;
                    node.subset=subset;
                    node.X=X;
                    node.Y=Y;
                    node.splitA=splitA;
                    node.splitB=splitB;
                else
                    ok=true;
                end 
            end
        end
        
        function seq(this, lookFor, level, subset, fncVisit)
            key=lookFor(1:level);
            [X, Y, splitA, splitB]=this.fetch_split(key);
            if ~isempty(fncVisit)
                if length(lookFor)>level
                    nextKey=lookFor(1:level+1);
                else
                    nextKey=[];
                end
                ok=feval(fncVisit, this, key, subset, X, Y, ...
                    splitA, splitB, nextKey);
            else
                ok=true;
            end   
            if ~ok || (isempty(splitA) && level>1)
                
            elseif ok
                [selectedA, selectedB]=this.splitter.getSelected(...
                    subset, X, Y, splitA, splitB);
                if lookFor(level+1)=='2'
                    selectedA=selectedB;
                end
                this.seq(lookFor, level+1, SuhSubset(subset, selectedA), fncVisit);
            end
        end

        
        function [X, Y, splitA_string, splitB_string]=fetch_split(this, key)
            [X, Y, splitA_string]=...
                SuhEpp.Decode(this.map.get(java.lang.String(key)));
            value=this.map.get(java.lang.String([key '.B']));
            if ~isempty(value)
                [~, ~, splitB_string]=SuhEpp.Decode(value);
            else
                splitB_string='';
            end
        end
        
        function store_split(this, key, X, Y, splitA_string, splitB_string)
            this.map.put(java.lang.String(key), ...
                java.lang.String(SuhEpp.Encode(X,Y,splitA_string)));
            if nargin>=6 && ~isempty(splitB_string)
                this.map.put(java.lang.String([key '.B']), ...
                    java.lang.String(SuhEpp.Encode(X,Y,splitB_string)));
            end
            this.branchCount=this.branchCount+1;
            if this.verbose
                disp(['branch count=' String.encodeInteger(this.branchCount)]);
            end
        end
        
        function [deepest, shallowest, biggest, smallest]=...
                visitAll(this, fncVisit, verbose)
            if nargin<3
                verbose=false;
                if nargin<2
                    fncVisit=[];
                end
            end
            
            if isempty(fncVisit)
                fncVisit=@collectExtremes;
                leaves=0;
                deepest=TopItems(10);
                shallowest=TopItems(10, false);
                biggest=TopItems(10);
                smallest=TopItems(10, false);
            else
                deepest=[];
                shallowest=[];
                biggest=[];
                smallest=[];
            end
            this.verbose=verbose;
            this.visit('0', this.root, fncVisit);
            function isBranch=collectExtremes(this, key, subset, X, Y, ...
                    split, ~)
                isBranch=~isempty(split);
                if this.verbose
                    fprintf('%s %d events %d/%d ', key, subset.size, X, Y)
                end
                if isBranch
                    if this.verbose
                        fprintf(' (branch) \n');
                    end
                else
                    leaves=leaves+1;
                    [k1, k2]=SuhEpp.LeafKeys(leaves);
                    leafSize=str2double(this.map.get(k2));
                    levels_=length(key)-1;
                    deepest.add(levels_, leaves);
                    shallowest.add(levels_, leaves);
                    biggest.add(leafSize, leaves);
                    smallest.add(leafSize, leaves);
                    if this.verbose
                        leafKey=this.map.get(k1);
                        fprintf('%s (leaf) \n', leafKey);
                    end
                end
            end
        end
        
        function visit(this, key, subset, fncVisit)
            [X, Y, splitA, splitB]=this.fetch_split(key);
            if X==0 || Y==0 || isnan(X) || isnan(Y)
                ok=false;
            elseif ~isempty(fncVisit)
                try
                    ok=feval(fncVisit, this, key, subset, X, Y, splitA, splitB);
                catch
                    ok=false;
                end
            end
            if subset.size<this.args.min_branch_size
                ok=false;
            end
            if ~ok || isempty(splitA)
                
            elseif ok
                [selectedA, selectedB]=...
                    this.splitter.getSelected(subset, X, Y, splitA, splitB);
                this.visit([key '1'], SuhSubset(subset, selectedA), fncVisit);
                this.visit([key '2'], SuhSubset(subset, selectedB), fncVisit);
            end
        end

        function leafIds=getLeafIds(this)
            if sum(this.dataSet.finalSubsetIds)==0
                this.rakeLeaves;
            end
            leafIds=this.dataSet.finalSubsetIds;
        end
        
        
        function names=getLeafNames(this)
            names=cell(1, this.leafCount);
            for i=1:this.leafCount
                leafKeySplit=SuhEpp.LeafKeys(i);
                key=this.map.get(java.lang.String(leafKeySplit));
                names{i}=this.map.get([key '.name']);
            end
        end
        
        function rakeLeaves(this)
            this.leafSizes=[];
            this.leafCount=0;
            this.rake('0', this.root);
        end
        
        function rake(this, key, subset)
            [X, Y, splitA, splitB]=this.fetch_split(key);
            nEvents=subset.size;
            if nEvents<this.args.min_branch_size
                tooSmall=true;
            else
                tooSmall=false;
            end
            
            if isempty(splitA) || tooSmall
                this.leafCount=this.leafCount+1;
                this.leafSizes(this.leafCount)=nEvents;
                this.dataSet.finalizeSubset(subset, this.leafCount)
            else
                [selectedA, selectedB]=this.splitter.getSelected(...
                    subset, X, Y, splitA, splitB);
                this.rake([key '1'], SuhSubset(subset, selectedA));
                this.rake([key '2'], SuhSubset(subset, selectedB));
            end
        end

        function [keys, ids]=getLeaves(this, key, keys, ids)
            if nargin<3
                keys=java.util.ArrayList;
                ids=java.util.ArrayList;
            end
            isLeaf=this.isLeaf(key);
            if isLeaf
                keys.add(key);
                ids.add(str2double(this.map.get(['leaf.' key])));
            else
                this.getLeaves([key '1'], keys, ids);
                this.getLeaves([key '2'], keys, ids);
            end
        end
        
        function imgFile=createPng(this, key, doParent)
            if doParent
                imgFile=this.getPngFile(key);
            else
                imgFile=this.getPngFileNext(key);
            end
            if ~exist(imgFile, 'file')
                this.plot(key, doParent, imgFile);
            elseif this.wantsPredictionSelections
                [fldr, fn, ext]=fileparts(imgFile);
                imgFile=fullfile(fileparts(fldr), 'img2', [fn ext]);
                this.plot(key, doParent, imgFile);
            end
        end
        
        function fig=plot(this, key, doParent, pngFile, figOrAx)
            if nargin<5
                figOrAx=Gui.Figure;
                if nargin<4
                    pngFile='';
                    if nargout<3
                        doParent=true;
                    end
                end
            end
            node=this.find(key);
            if strcmpi('axes', get(figOrAx,'type'))
                ax=figOrAx;
                fig=get(ax, 'Parent');
            else
                fig=figOrAx;
                ax=Gui.Axes(figOrAx);
            end
            if doParent && ~isequal(key,'0')
                parentNode=this.find(key(1:end-1));
                this.splitter.plotSelected(ax, parentNode.subset,...
                    parentNode.X, parentNode.Y, parentNode.splitA, ...
                    isequal(key(end), '2'), ...
                    SuhEpp.NodeTitle(parentNode), ...
                    this.getPredictions);
            else
                this.splitter.plot(ax, node.subset, node.X, node.Y, ...
                    node.splitA, SuhEpp.NodeTitle(node), ...
                    this.getPredictions);
            end
            if ~isempty(pngFile)
                File.mkDir(fileparts(pngFile));
                set(get(ax, 'XLabel'), 'FontSize', SuhEpp.FONT_SIZE)
                set(get(ax, 'YLabel'), 'FontSize', SuhEpp.FONT_SIZE)
                set(get(ax, 'Title'), 'FontSize', SuhEpp.FONT_SIZE+1)
                Gui.SavePng(fig, pngFile);
            end
        end
        
        function [ok, isLeaf, sz, name]=exists(this, key)
            [name, isLeaf]=this.getName(key);
            ok=~isempty(name);
            sz=this.getSize(key);
        end
        
        function pngFile=getPngFile(this, key)
            fl=fullfile(this.args.output_folder, 'html', 'images');
            pngFile=fullfile(fl, [key '.png']);
        end

        function pngFileNext=getPngFileNext(this, key)
            fl=fullfile(this.args.output_folder, 'html', 'images');
            pngFileNext=fullfile(fl, [key '_next.png']);
        end

        function htmlFile=getHtmlFile(this, key, doParent)
            if nargin<3 || doParent
                suffix='_sequence';
            else
                suffix='_subtree';
            end
            htmlFile=fullfile(this.args.output_folder, 'html', ...
                [key suffix '.html']);
        end

        function img=getHtmlImg(this, key,  doParent, sz, forBrowser)
            if nargin<5
                forBrowser=true;
                if nargin<4
                    sz=.25;
                    if nargin<3
                        doParent=true;
                    end
                end
            end
            img=this.createPng(key, doParent);
            [fldr, f, e]=fileparts(img);
            if forBrowser
                img=Html.ImgXy([f e], fldr, sz, true, true, this.app);
            else
                img=Html.ImgXy([f e], fldr, sz, false);
            end
        end
        
        function ok=isLeaf(this, key)
            v=this.map.getProperty([key '.leaf']);
            ok=~isempty(v);
        end
        
        function ok=nodeExists(this, key)
            if isequal(key, '0')
                ok=true;
            else
                ok=~isempty(this.map.get([key '.name']));
            end
        end
        function [name, isLeaf]=getName(this,key)
            if isequal(key, '0')
                name='EPP top';
                isLeaf=false;
            else
                name=this.map.get([key '.name']);
                if isempty(name)
                    isLeaf=false;
                else
                    isLeaf=this.isLeaf(key);
                    if isLeaf
                        name=this.map.get([key '.name']);
                    elseif endsWith(key, '2')
                        name=this.map.get([key(1:end-1) '.B.name']);
                    else
                        name=this.map.get([key(1:end-1) '.name']);
                    end
                end
            end
        end
        
        function sz=getSize(this,key)
            if isequal(key, '0')
                sz=this.dataSet.R;
            else
                name=this.map.get([key '.name']);
                if isempty(name)
                    sz=nan;
                else
                    if this.isLeaf(key)
                        sz=this.map.get([key '.size']);
                    elseif endsWith(key, '2')
                        sz=this.map.get([key(1:end-1) '.B.size']);
                    else
                        sz=this.map.get([key(1:end-1) '.size']);
                    end
                    if isempty(sz)
                        sz=nan;
                    else
                        sz=str2double(sz);
                    end
                end
            end
        end
        
        function exploreHierarchy(this, startKey, fncNodeSelected)
            if nargin<3
                fncNodeSelected=@(h,e)nodeSelectedCallback(e);
                if nargin<2
                    startKey='0';
                end
            end
            app_=this.app;
            pp=app_.contentFolder;
            this.bullsEye=fullfile(pp, 'bullseye.png');
            this.microScope=fullfile(pp, 'microScope.png');
            this.hiD=fullfile(pp, 'tSNE.png');
            this.scissors=fullfile(pp, 'scissors.png');
            if isequal(startKey, '0')
                startNode=uitreenode('v0', '0', ['<html>'...
                    'Full EPP hierarchy, ' app_.supStart ...
                    String.encodeInteger(this.root.size) ' x ' ...
                    String.encodeInteger(this.root.dataSet.C) ...
                    this.countLeafHtml('0')  app_.supEnd '</html>'],...
                    this.hiD, false);                
            else
                found=this.find(startKey);
                isLeaf=this.isLeaf(startKey);
                if isempty(found)
                    warning('Key %s is not in tree', startKey);
                    return;
                end
                startNode=uitreenode('v0', startKey, ['<html>' ...
                    this.getName(startKey) app_.supStart ...
                    String.encodeInteger(found.subset.size) ' x ' ...
                    String.encodeInteger(found.subset.dataSet.C) ...
                    this.countLeafHtml(startKey) app_.supEnd '</html>'], ...
                    this.hiD, isLeaf);
            end
            if isempty(this.figHierarchyExplorer)
                hierarchyExplorer=...
                    SuhEpp.InitHierarchyExplorer(this.args, this.dataSet.file);
                this.busyHierarchyExplorer=hierarchyExplorer.busy;
                this.figHierarchyExplorer=hierarchyExplorer.fig;
                this.tb=hierarchyExplorer.tb;
            end
            fig=this.figHierarchyExplorer;
            ToolBarMethods.addButton(this.tb, 'table.gif', ...
                'See leaf sequences of selected subset', ...
                @(h,e)openLeafRaker(this, this.selectedKey));
            
            ToolBarMethods.addButton(this.tb, 'comicStrip.png', ...
                'See parent sequence leading up to selected subset', ...
                @(h,e)browseParents(this, {this.selectedKey}));
            ToolBarMethods.addButton(this.tb, 'tree.png', ...
                'See sub-tree of selected subset', ...
                @(h,e)browseChildren(this, this.selectedKey));
            
            img=Html.ImgXy('pseudoBarHi.png', pp, .819);
            this.cbMirror=Gui.CheckBox(...
                        Html.WrapSmallBold(['Sync ' img]), ...
                        this.app.is('SuhEpp.Mirror', true), ...
                        [], '', ...
                        @(h,e)mirror(), ...
                        ['<html>Select to synchronize this tree with '...
                        'the ' img ' DimensionExplorer</html>']);
            ToolBarMethods.addComponent(this.tb, this.cbMirror);        
            if ~isempty(this.dataSet.file)
                fileHtml=Html.FileTree(this.dataSet.file);
                this.tb.jToolbar.addSeparator
                [~, f,e]=fileparts(this.dataSet.file);
                [~,jl]=Gui.ImageLabel(...
                    Html.WrapSmallBold([f e]),...
                    'foldericon.png',...
                    ['<html>' fileHtml '</html>'], @(h,e)showFile());
                ToolBarMethods.addComponent(this.tb,jl);
            end
            hPanLeft = uipanel('Parent',fig, ...
                'Units','normalized','Position',...
                [0.02 0.08 0.98 0.92]);
            drawnow;
            this.suhTree=SuhTree.New(startNode, fncNodeSelected,...
                @getPath, @(key)nodeExists(this, key), ...
                @(key)newUiNodes(this, key), @(key)getChildren(this, key));
            set(this.suhTree.container,'Parent',hPanLeft, ...
                'Units','normalized', 'Position',[0 0 1 1]);
            this.suhTree.stylize;
            this.suhTree.jtree.setToolTipText(['<html><table cellspacing=''5''>'...
                '<tr><td>Click on any node to see:<ul>'...
                '<li>' Html.ImgXy('pseudoBarHi.png', pp, .9) ...
                '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Measurement <i>distributions</i> '...
                 '<li>' Html.ImgXy('scissors.png', pp, .9) ...
                 '&nbsp;&nbsp;EPP''s 2-way <i>splits</i>'... 
                 '</ul><hr></td><tr></table></html>']);
             uit=this.suhTree.tree;
            set(uit, 'NodeExpandedCallback', ...
                @(h,e)SuhEpp.NodeExpanded(e, uit, this));
            kld=[];
            if ~isempty(this.umapVersion)
                UmapUstBtn(fig);
            end
            this.addSeeExtremesButton(fig);
            uit.expand(startNode);
            drawnow;
            nChilds=startNode.getChildCount;
            for i=1:nChilds
                uit.expand(startNode.getChildAt(i-1));
            end
            this.fncSyncKld=@syncKld;
            
            function ok=syncKld
                if ~isempty(this.selectedKey)
                    ok=true;
                    if this.cbMirror.isSelected
                        pu_=PopUp(Html.Wrap(['Synchronizing with EPP '...
                            '<br> DimensionExplorer&nbsp;&nbsp;' ...
                            Html.ImgXy('pseudoBarHi.png', [], 1.2)]), ...
                            'north east', 'One moment...', true, true);
                        if isempty(kld)
                            kld=this.show(this.selectedKey);                            
                        elseif kld.isValid
                            kld=this.show(this.selectedKey, kld);
                        end
                        drawnow
                        if pu_.cancelled
                            this.cbMirror.setSelected(false);
                            
                            edu.stanford.facs.swing.Basics.Shake(...
                                this.cbMirror, 8);
                            this.app.showToolTip(this.cbMirror, Html.WrapHr(...
                                ['Synchronizing was <b>cancelled</b>...<br>'...
                                '(Click shaking button <b>above</b> to resume it)']), ...
                                -22, 23, 0, [], true, .31);
                        end
                        pu_.close;
                    else
                        this.app.showToolTip(this.cbMirror, ...
                            Html.WrapSmall(...
                            ['Click <b>here</b> to keep the<br>'...
                            'DimensionExplorer in sync']), ...
                            12, 23, 0, [], true, .31);
                    end
                else
                    ok=false;
                end
            end
            
            function mirror
                if this.cbMirror.isSelected
                    this.app.set('SuhEpp.Mirror', 'true');
                    if ~isempty(kld) && ~kld.isValid
                        kld=[];
                    end
                    if ~syncKld
                        SuhEpp.MsgSelect;
                    end
                else
                    this.app.set('SuhEpp.Mirror', 'false');
                end
            end
            
            function showFile
                msg(['<html>The input data for this EPP hierarchy<br>'...
                    'is found in: ' fileHtml '<hr></html>'], 10, 'north east+', ...
                    'Data file location');
            end
            
            function [H, J]=UmapUstBtn(fig) 
                words=['Visualize data with our UMAP/UST pipeline'...
                    '<br>(<i>Con me in HiD?</i>)<hr>'];
                if this.app.highDef
                    tip=['<html><center>' this.app.smallStart words ...
                        Html.ImgXy('connor.png', [], .7)...
                        this.app.smallEnd '<hr>Connor Meehan</center></html>'];
                    heightFactor=.75;
                else
                    tip=['<html><center>' words...
                        Html.ImgXy('connor.png', [], .25)...
                        '<hr>Connor Meehan</center></html>'];
                    heightFactor=1;
                end
                [H,J]=Gui.ImageLabel(['<html>' ...
                    Html.WrapBoldSmall('UMAP/UST   ')...
                    '</html>'],  'microScope.png', ...
                    tip, @(h,e)umapOptions(h), fig, 4, 6, true);
                J.setBackground(java.awt.Color(1, 1, .7))
                border=javax.swing.BorderFactory.createLineBorder(...
                    java.awt.Color.blue);
                J.setBorder(border);
                if BasicMap.Global.highDef
                    p=get(H, 'position');
                    set(H, 'position', [p(1) p(2) p(3)*.5 p(4) * heightFactor]);
                end
            end

            function umapOptions(h)
                jm=PopUp.Menu;
                app_=BasicMap.Global;
                Gui.NewMenuItem(jm, ...
                    'UMAP reduces same data', @(h,e)umap(this, 1));
                Gui.NewMenuItem(jm, ...
                    'UMAP reduces with fast approximation', ...
                    @(h,e)umap(this, 2));
                jm.addSeparator;
                Gui.NewMenuItem(jm, ...
                    'EPP supervises UMAP (UST)', @(h,e)umap(this, 3));
                Gui.NewMenuItem(jm, ...
                    'EPP supervises UMAP with fast approximation', @(h,e)umap(this, 4));
                if this.isCharacterizedByLabels 
                    jm.addSeparator;
                    Gui.NewMenuItem(jm, ...
                        'UMAP reduces & compares prior labels to clusters',...
                        @(h,e)umap(this, 5));
                    Gui.NewMenuItem(jm, ...
                        'UMAP reduces & compares with fast approximation',...
                        @(h,e)umap(this, 6));
                    jm.addSeparator;
                    Gui.NewMenuItem(jm, ...
                        'Prior labels supervise UMAP (UST)', ...
                        @(h,e)umap(this, 7));
                    Gui.NewMenuItem(jm, ...
                        'Prior labels supervise with fast approximation', ...
                        @(h,e)umap(this, 8));
                end
                jm.addSeparator;
                Gui.NewMenuItem(jm, ...
                    'Alter key settings', ...
                    @(h,e)alterUmapSettings(this));
                jm.show(h, 15, 15);
            end
            
            
            function nodeSelectedCallback(evd)
                uiNode=evd.getCurrentNode;
                this.selectedKey=char(uiNode.getValue);
                syncKld;
            end
            
            function path=getPath(key)
                N=length(key);
                path=cell(1,N-1);
                for jj=2:N
                    path{jj-1}=key(1:jj);
                end
            end
        end
        
        function alterUmapSettings(this)
            this.initUmapArgs;
            varArgIn=['fake.csv', this.umapVarArgIn];
            argsObj=UmapUtil.GetArgsWithMetaInfo(varArgIn{:});
            if ~this.isCharacterizedByLabels
                argsObj.refineArgs(1, 2); % group#2
            else
                argsObj.refineArgs(1, 2, 3, 'cluster_detail');
            end
            varArgIn=argsObj.getVarArgIn;
            this.umapVarArgIn=varArgIn(2:end);
        end
        
        function initUmapArgs(this)
            if ~this.umapArgsDone
                argsObj=Args(UmapUtil.DefineArgs);
                this.umapVarArgIn=argsObj.extractFromThat(this.unmatched);
                this.umapArgsDone=true;
                this.umapVarArgIn=argsObj.parseStr2NumOrLogical(...
                    this.umapVarArgIn);
            end
        end
            
    end
    
    methods(Static)
        function ttl=NodeTitle(node)
            ttl={node.name, ...
                ['\color{blue} "' ...
                node.key '" ^{' String.encodeInteger(node.subset.size) ...
                    ' events}']};
        end
        function obj=InitHierarchyExplorer(args, file)
            if ~isempty(args.folder)
                propertyFile=fullfile(args.folder, 'visual.properties');
                File.mkDir(args.folder);
            elseif ischar(file)
                file=WebDownload.GetExampleIfMissing(file);
                [p, f]=fileparts(file);
                propertyFile=fullfile(p, [f '.epp.fig.properties']);
            else
                propertyFile=[];
            end
            [fig,tb, personalized] = Gui.Figure(true, 'SuhEpp.fig', propertyFile);
            set(fig, 'name', [ SuhEpp.TITLE ' HierarchyExplorer'])
            if ~personalized
                pos=get(fig,'pos');
                set(fig, 'pos', [pos(1) pos(2) pos(3)*.66 pos(4)]);
            end
            if ~isempty(args.locate_fig)
                Gui.FollowWindow(fig, args.locate_fig);
                drawnow;
            end
            Gui.FitFigToScreen(fig);
            set(fig, 'visible', 'on');
            obj.fig=fig;
            obj.tb=tb;
            drawnow;
          
            [obj.busy, ~, obj.busyLbl]=Gui.ShowBusy(fig, ...
                Gui.YellowH3('Initializing EPP hierarchy'),...
                'CytoGenius.png', .66, false);            
            
        end
        
        function NodeExpanded(evd, tree, this)                           
            uiNode=evd.getCurrentNode;
            if ~tree.isLoaded(uiNode)
                childnodes = this.newUiNodes(uiNode.getValue);
                tree.add(uiNode, childnodes);
                tree.setLoaded(uiNode, true);
            end
        end
        
        function [pathAdded, umapFldr]=UmapAvailable
            try
                UmapUtil.LocalSamplesFolder;
                pathAdded=true;
            catch
                pathAdded=false;
            end
            umapFldr=fullfile(fileparts(fileparts(mfilename('fullpath'))), 'umap');
            if ~exist(umapFldr, 'dir')
                umapFldr=[];
            end
        end
    end
    
    properties(SetAccess=private)
        bullsEye;
        microScope; % tree leaf
        scissors; % tree branch
        hiD; % tree root
    end
    
    methods
        function keys=getChildren(this,key)
            if this.isLeaf(key)
                keys={};
            else
                keys={[key '1'], [key '2']};
            end
        end
        
        function nodes=newUiNodes(this, key)
            if this.isLeaf(key)
                nodes=[];
            else
                nodes(1)=get(true);
                nodes(2)=get(false);
            end
            
            function node=get(part1)
                if part1
                    key_=key;
                    nextKey=[key '1'];
                else
                    key_=[key '.B'];
                    nextKey=[key '2'];
                end
                isLeaf=this.isLeaf(nextKey);
                if isLeaf
                    name=this.map.get([nextKey '.name']);
                else
                    name=this.map.get([key_ '.name']);
                end
                size=String.encodeInteger(...
                    str2double(this.map.get([key_ '.size'])));
                txt=['<html>' name ', ' this.app.supStart ...
                    size this.countLeafHtml(nextKey) ...
                    this.app.supEnd '</html>'];
                if isLeaf
                    node=uitreenode('v0', nextKey, txt, ...
                        this.bullsEye, true);
                else
                    node=uitreenode('v0', nextKey, txt, ...
                        this.scissors, false);
                end
            end
        end
        
        function save(this, fileName)
            this.map.put('min_branch_size', java.lang.String(...
                num2str(this.args.min_branch_size)));
            this.splitter.saveProperties(this.map);
            File.SaveProperties2(fileName, this.map);
        end
        
        function load(this, fileName)
            this.map=File.ReadProperties(fileName);
            this.levels=str2double(this.map.get('levels'));
            this.leafCount=str2double(this.map.get('leafCount'));
            this.leafCount=str2double(this.map.get('branchCount'));
            this.args.min_branch_size=this.getNumeric('min_branch_size',0);
            this.splitter.loadProperties(this.map);
        end
        
        function value=getNumeric(this, prop, dflt)
            value=this.map.get(prop);
            if isempty(value)
                value=dflt;
            else
                value=str2double(value);
            end
        end
        function s=summary(this)
            s=sprintf('EPP on %s computed %s leaves AND %s branches<br>with %d levels in %s', ...
                this.fullSize, ...
                String.encodeInteger(this.getLeafCount), ...
                String.encodeInteger(this.getBranchCount),...
                this.getLevels, this.getDurationText);
        end
        
        function pu=buildAll(this, pu, fncVisit)
            if nargin<3
                fncVisit=[];
                if nargin<2
                    imgFile=Gui.GetResizedImageFile('wayneMoore2.png', .5);
                    pu=PopUp('', 'south', ...
                        ['Running EPP on ' this.fullSize],  ...
                        false, true,  imgFile);
                end
            end
            this.leafCount=0;
            this.branchCount=0;
            this.levels=0;
            this.pu=pu;
            if ~isempty(pu)
                pu.setTimeSpentTic;
                this.pu.initProgress(this.dataSet.R, 'split');
            end
            tm=tic;
            this.build('0', this.root, fncVisit, 0, 0, '');
            duration=toc(tm);
            this.map.put('levels', java.lang.String(num2str(this.levels)));
            this.map.put('leafCount', java.lang.String(num2str(this.leafCount)));
            this.map.put('branchCount', java.lang.String(num2str(this.branchCount)));
            this.map.put('duration', java.lang.String(num2str(duration)));
            if ~isempty(this.pu)
                this.pu.setText(Html.WrapHr(this.summary));
                this.pu.setAllDone('EPP finished');
            end
            this.pu=[];
        end
        
        function ok=isCharacterizedByLabels(this)
            ok=~isempty(this.dataSet.labels);
        end
        
        function [reduction, umap, clusterIdentifiers, extras]...
                =umap(this, option, varargin)
            reduction=[];
            umap=[];
            clusterIdentifiers=[];
            extras=[];
            if option<1
                return;
            end
            [pathAdded, umapFldr]=SuhEpp.UmapAvailable;
            if ~pathAdded
                if ~isempty(umapFldr)
                    addpath(umapFldr);
                else
                    msg('UMAP not installed');
                    web('https://www.mathworks.com/matlabcentral/fileexchange/71902-uniform-manifold-approximation-and-projection-umap', '-browser');
                end
            end
            locate=[];
            if ~isempty(this.figHierarchyExplorer)
                locate={this.figHierarchyExplorer, ...
                    'north east+', true};
            end
            this.initUmapArgs;
            if nargout<3
                clusterOutput='ignore';
            else
                clusterOutput='none';
            end
            uArgs=[{'save_output'}, {this.args.save_output},...
                {'output_folder'}, {this.args.output_folder},...
                {'output_suffix'}, {['_epp' num2str(option)]},...
                {'parameter_names'}, {this.dataSet.columnNames},...
                {'qf_tree'}, {this.args.qf_tree},...
                {'cluster_output'}, {clusterOutput},...
                {'locate_fig'}, {locate}, this.umapVarArgIn(:)'];
            uArgs{end+1}='verbose';
            if this.args.explore_hierarchy
                uArgs{end+1}='graphic';
            else
                uArgs{end+1}='text';
            end
            if option<3
                probabilityBins=option==2;
                [reduction, umap, clusterIdentifiers, extras]=...
                    run_umap(this.dataSet.data, ...
                    'fast_approximation', probabilityBins,...
                    uArgs{:});
            else
                if option==3 || option==4 
                    labels=this.getLeafIds;
                    data=[this.dataSet.data labels'];
                    probabilityBins=option==4;
                    if ~this.isCharacterizedByLabels
                        [reduction, umap, clusterIdentifiers, extras]=...
                            run_umap(data, 'label_column', 'end',...
                            'fast_approximation', probabilityBins,...
                            'plot_title', 'EPP supervises UMAP',...
                            uArgs{:});
                    else
                        file=this.getMatchedLabelFile;
                        [reduction, umap, clusterIdentifiers, extras]=...
                            run_umap(data, 'label_column', 'end', ...
                            'label_file', file,...
                            'fast_approximation', probabilityBins,...
                            'plot_title', 'EPP supervises UMAP',...
                            uArgs{:});
                    end
                else
                    if ~this.isCharacterizedByLabels
                        msg(Html.WrapHr(['The data needs a label '...
                            'identifier for each row.']));
                        return;
                    end
                    data=[this.dataSet.data this.dataSet.labels];
                    if option<7
                        probabilityBins=option==6;
                        [reduction, umap, clusterIdentifiers, extras]=...
                            run_umap(data, 'label_column', 'end', ...
                            'label_file', this.dataSet.label_file, ...
                            'match_scenarios', 4, ...
                            'match_predictions', this.args.match_predictions,...
                            'fast_approximation', probabilityBins,...
                            'plot_title', {'UMAP reduces & compares', 'to non-EPP labels'},...
                            'cluster_detail', 'most high', uArgs{:});
                    else
                        probabilityBins=option==8;
                        [reduction, umap, clusterIdentifiers, extras]=...
                            run_umap(data, 'label_column', 'end', ...
                            'label_file', this.dataSet.label_file,...
                            'locate_fig', locate, ...
                            'fast_approximation', probabilityBins,...
                            uArgs{:});
                    end
                end
            end
        end
       
        
        function file=getMatchedLabelFile(this)
           file=this.characterize; 
        end

        function [matchedLabelFile, match, matchTable]...
                =characterize(this, viewHistograms, viewQfTree, ...
                seePredictions)
            if nargin<3
                viewQfTree=false;
                if nargin<2
                    viewHistograms=false;
                end
            end
            if this.isCharacterizedByLabels
                if isempty(this.dataSet.match) ...
                        || (viewQfTree && isempty(this.dataSet.qfTree2))
                    go
                else
                    try
                        if viewQfTree 
                            if Gui.IsVisible(this.dataSet.qfTree1.fig) && ...
                                Gui.IsVisible(this.dataSet.qfTree2.fig) 
                                figure(this.dataSet.qfTree1.fig);
                                figure(this.dataSet.qfTree2.fig);
                            else
                                try
                                    delete(this.dataSet.qfTree1.fig);
                                catch
                                end
                                try
                                    delete(this.dataSet.qfTree2.fig);
                                catch
                                end
                                go
                            end
                        elseif viewHistograms
                            matchFig=this.dataSet.matchTable.fig;
                            if ~Gui.IsVisible(matchFig)
                                go
                            else
                                if nargin>3 && seePredictions
                                    if isempty(this.dataSet.predictions) ...
                                            || ~Gui.IsVisible(this.dataSet.predictions.fig)
                                        this.setPredictionListener(...
                                            this.dataSet.seePredictions());
                                    end
                                end
                                figure(matchFig);
                            end
                        end                
                    catch ex
                        ex.getReport
                    end
                end
            end
            matchedLabelFile=this.dataSet.matchedLabelFile;
            match=this.dataSet.match;
            matchTable=this.dataSet.matchTable;
            
            function go
                pu_=PopUp('Matching EPP to labels', 'center', ...
                    'Note...', false);
                priorArgs=this.args;
                this.args.match=true;
                
                this.args.match_table_fig=viewHistograms;
                this.args.match_histogram_figs=viewHistograms;
                this.args.qf_tree=viewQfTree;
                this.dataSet.characterize(this, pu_, ...
                    viewQfTree||viewHistograms);
                pu_.close(true, false);
                this.args=priorArgs;
            end
        end
    end
    
    methods(Access=private)
        function initFig(this, hierarchyExplorer)
            this.figHierarchyExplorer=hierarchyExplorer.fig;
            this.busyHierarchyExplorer=hierarchyExplorer.busy;
            this.busyLbl=hierarchyExplorer.busyLbl;
            
            this.tb=hierarchyExplorer.tb;
            fileMenu;
            viewMenu;
            if ~isempty(this.umapVersion)
                umapMenu;
            end
            function fileMenu
                f = this.figHierarchyExplorer;
                m = uimenu(f,'Label','File'); 
                uimenu(m,'Label', 'Export Gating-ML', ...
                    'Callback', @(h,e)gatingMl());
                uimenu(m,'Label', 'Specify general output folder', ...
                    'Callback', @(h,e)outputFolder(this));
                uimenu(m,'Label', 'Specify job watch folder', ...
                    'Callback', @(h,e)jobFolder());
                
            end
            
            function gatingMl
                if isempty(this.args.gating_ml_file)
                    this.args.gating_ml_file=fullfile(...
                        this.args.output_folder,...
                        'gatingMl.xml');
                end
                GatingMl.Run(this);
            end
            
            
            function jobFolder
                dflt=fullfile(File.Documents, 'run_epp');
                f=File.GetDir(dflt, SuhEpp.PROP_JOB_FOLDER, ...
                    'job watch folder');
                if ischar(f)
                    this.args.job_folder=f;
                    File.mkDir(this.job_folder);
                end
            end
            
            function viewMenu
                f = this.figHierarchyExplorer;
                m = uimenu(f,'Label','View'); 
                uimenu(m,'Label', 'Extreme subset sequences', ...
                    'Callback', @(h,e)extremeSequences());
                uimenu(m,'Label', 'Leaf sequences under selected subset', ...
                    'Callback', @(h,e)anySequence());
                uimenu(m,'Label', 'Parent sequence leading to selected subset in browser', ...
                    'Callback', @(h,e)browseParents(this, ...
                    {this.selectedKey}));
                uimenu(m,'Label', 'Sub-tree under selected subset in browser', ...
                    'Callback', @(h,e)browseChildren(this, ...
                    this.selectedKey));
                if ~this.justBuilt
                    if this.isCharacterizedByLabels
                        uimenu(m, 'Label', 'Similarity/overlap with prior classification', ...
                            'Separator', 'on', ...
                            'Callback', @(h,e)characterize(this, true));
                        uimenu(m, 'Label', 'Predictions of prior classification', ...
                            'Callback', @(h,e)seePredictions());
                        uimenu(m, 'Label', 'QfTree with labeled subsets', ...
                            'Separator', 'off', ...
                            'Callback', @(h,e)characterize(this, false,true));
                    end
                end
            end
            
            function seePredictions
                this.args.match_predictions=true;
                characterize(this, true, false, true);
            end
            
            function extremeSequences
                this.seeExtremes;
            end
            
            function anySequence
                this.openLeafRaker(this.selectedKey);
            end
            
            function umapMenu
                f = this.figHierarchyExplorer;
                m = uimenu(f,'Label','UMAP'); 
                uimenu(m,'Label', 'UMAP reduces same data', ...
                    'Callback', @(h,e)umap(this, 1));
                uimenu(m,'Label', 'UMAP reduces with fast approximation', ...
                    'Callback', @(h,e)umap(this, 2));
                uimenu(m,'Label', 'EPP supervises UMAP (UST)', ...
                    'Separator', 'on', ...
                    'Callback', @(h,e)umap(this, 3));
                uimenu(m,'Label', 'EPP supervises UMAP with fast approximation', ...
                    'Callback', @(h,e)umap(this, 4));
                if this.isCharacterizedByLabels                    
                    uimenu(m,'Label', ...
                        'UMAP reduces & compares clusters to prior classification',...
                        'Separator', 'on', ...
                        'Callback', @(h,e)umap(this, 5));
                    uimenu(m,'Label', ...
                        'UMAP reduces & compares with fast approximation',...
                        'Callback', @(h,e)umap(this, 6));
                    uimenu(m,'Label', 'Prior labels supervise UMAP (UST)', ...
                        'Separator', 'on', ...
                        'Callback', @(h,e)umap(this, 7));
                    uimenu(m,'Label', ...
                        'Prior labels supervise with fast approximation', ...
                        'Callback', @(h,e)umap(this, 8));
                end
                uimenu(m, 'Label', 'Alter key settings', ...
                    'Separator', 'on', ...
                    'Callback', @(h,e)alterUmapSettings(this));
            end
        end
        
        function sequenceFig=setSequenceFig(this, key, sequenceFig)
            this.leafFigs.set(key, sequenceFig);
        end
        
        function sequenceFig=getSequenceFig(this, key)
            sequenceFig=this.leafFigs.get(key);
            if ~isempty(sequenceFig)
                if ~ishandle(sequenceFig)
                    sequenceFig=[];
                end
            end
            %sequenceFig=[];
        end
        
        function ok=openLeafRaker(this, key, complain)
            if isempty(key)
                if nargin<3 || complain
                    SuhEpp.MsgSelect;
                end
                ok=false;
                return
            end
            ok=true;
            if ~isempty(this.leafRaker)
                this.leafRaker.close;
            end
            this.leafRaker=SuhLeafRaker(this, key);
        end
        
        function browseChildren(this, key)
            if isempty(key)
                SuhEpp.MsgSelect;
                return;
            end
            [~,cancelled]=this.hasPredictionSelections(true);
            if cancelled
                return;
            end
            
            fileName=this.getHtmlFile(key, false);
            if this.wantsPredictionSelections
                [fldr, fn, ext]=fileparts(fileName);
                fileName=fullfile(fldr, [fn '_P' ext]);
            end
            if this.wantsPredictionSelections ...
                        || ~exist(fileName, 'file') || SuhEpp.TESTING
                pu_=PopUp('Preparing sub-tree html', 'south',...
                    'Browsing EPP', true, true);
                len=this.countLeaves(key);
                pu_.initProgress(len);
                pu_.setTimeSpentTic;
                pu_.showTimeSpent
                startLength=length(key);
                sb=java.lang.StringBuilder(startLength*100);
                sb.append('<html>');
                browse(key);
                if pu_.cancelled
                    pu_.close;
                    return;
                end
                sb.append('</html>');
                File.WriteTextFile(fileName, char(sb.toString));
            end
            Html.BrowseFile(fileName);
            pu_.close;
            
            function browse(key)
                if pu_.cancelled
                    return;
                end
                indent='';
                N=length(key)-startLength;
                for i=1:N
                    indent=[indent '&nbsp;&nbsp;&nbsp;&nbsp;'...
                        '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'...
                        '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'];
                end
                sb.append(indent);
                [ok, isLeaf]=this.exists(key);
                if ~ok
                    key=key(1:end-1);
                end
                img=this.getHtmlImg(key, ok);
                sb.append(img);
                sb.append('<br>');
                if (ok)
                    browse([key '1']);
                    if ~isLeaf
                        browse([key '2']);
                    else
                        pu_.incrementProgress;
                        drawnow;
                    end
                end
            end
        end
    end
    
    properties(SetAccess=private)
        wantsPredictionSelections;
    end
    
    methods
        
        function pred=getPredictions(this)
            try
                pred=this.dataSet.matchTable.predictionsOfThese;
                if isempty(pred.fncSelected)
                    this.setPredictionListener(pred);
                end
            catch
                % no labels or no match table or something 
                pred=[];
            end
        end
        
        function [ok, cancelled]=hasPredictionSelections(this, ask)
            cancelled=false;
            this.wantsPredictionSelections=false;
            pred=this.getPredictions;
            ok=~isempty(pred) && ~isempty(pred.selectedData);
            if ok && nargin>1 && ask
                [ok, cancelled]=askYesOrNo(sprintf(Html.WrapHr([...
                    'Reflect the <b>%s</b> selections for <br>"<b>%s</b>"?'...
                    ]),  String.encodeK(sum(pred.selectedData)),...
                    pred.selectedName));
                this.wantsPredictionSelections=ok;
            end
        end
        
        function browseParents(this, keys, where)
            if isempty(keys) || isempty(keys{1})
                SuhEpp.MsgSelect;
                return;
            end
            pu_=[];
            nKeys=length(keys);
            [~,cancelled]=this.hasPredictionSelections(true);
            if cancelled
                return;
            end
            fileNames=cell(1, nKeys);
            for i=1:nKeys
                key=keys{i};
                fileName=this.getHtmlFile(key);
                if this.wantsPredictionSelections
                    [fldr, fn, ext]=fileparts(fileName);
                    fileName=fullfile(fldr, [fn '_P' ext]);
                end                    
                fileNames{i}=fileName;
                if this.wantsPredictionSelections ...
                        || ~exist(fileName, 'file') || SuhEpp.TESTING
                    len=length(key);
                    if isempty(pu_)
                        if nargin<3
                            where='south';
                        end
                        pu_=PopUp('Preparing sequence html', where, ...
                            'EPP sequences', true, true);
                        pu_.initProgress(len-1);
                        pu_.setTimeSpentTic;
                    else
                        pu_.initProgress(len-1);
                    end
                    if nKeys>1
                        pu_.setText(sprintf('Sequence %d/%d for subset "%s"',...
                            i, nKeys, key));
                    else
                        pu_.setText(['Sequence for subset "' key '"']);
                    end
                    sb=java.lang.StringBuilder(len*100);
                    sb.append('<html>');
                    sb.append('<h3>Sequence "');
                    sb.append(key);
                    sb.append('" ( ');
                    sb.append(this.getName(key));
                    sb.append(')</h3>')
                    for j=2:len
                        parentKey=key(1:j);
                        img=this.getHtmlImg(parentKey, true);
                        sb.append(img);
                        pu_.incrementProgress;
                        drawnow;
                        if pu_.cancelled
                            pu_.close;
                            return;
                        end
                    end
                    img=this.getHtmlImg(key, false);
                    sb.append(img);
                    sb.append('</html>');
                    File.WriteTextFile(fileName, char(sb.toString));
                end
            end
            if nKeys>1
                fileNameAll=fullfile(fileparts(fileName), 'manySeqs.html');
                sb=java.lang.StringBuilder(nKeys*100);
                sb.append('<html>');                
                for j=1:nKeys
                    sb.append(File.ReadTextFile(fileNames{j}));
                    sb.append('<hr>')
                end
                sb.append('</html>');
                File.WriteTextFile(fileNameAll, char(sb.toString));
                Html.BrowseFile(fileNameAll);
            else
                Html.BrowseFile(fileName);
            end
            if ~isempty(pu_)
                pu_.close;
            end
        end
    end
    methods(Access=private)
        function outputFolder(this)
            MatBasics.RunLater(@(h,e)explain(...
                'Specify output folder'),2);
            f=uigetdir(this.args.output_folder, ...
                'Folder for created csv & png file(s)');
            if ischar(f)
                this.args.output_folder=f;
                File.mkDir(this.args.output_folder);
                this.args.save_output=true;
                try
                    Gui.SavePng(this.dataSet.matchTable.qHistFig,...
                        fullfile(f, 'similarity_histogram.png'));
                    Gui.SavePng(this.dataSet.matchTable.fHistFig,...
                        fullfile(f, 'overlap_histogram.png'))
                catch
                end
                try
                    Gui.SavePng(this.dataSet.qfTree2.fig,...
                        fullfile(f, 'qf_tree.png'));
                catch
                end
            end
            function explain(txt)
                msg(txt, 8, 'north west+');
            end
        end

        function addSeeExtremesButton(this, fig_, lbl, width)
            if nargin<4
                width=.3;
                if nargin<3
                    lbl=' Extreme sequences ';
                end
            end
            uicontrol(fig_, 'style', 'pushbutton','String', lbl,...
                'Units', 'normalized', ...
                'FontWeight', 'bold', ...
                'ForegroundColor', 'blue',...
                'BackgroundColor', [1 1 .80],...
                'ToolTipString', Html.WrapHr(['See the sequences '...
                'that are longest and shortest<br>and that have '...
                'biggest and smallest final subset']),...
                'Position',[1-(width+.01), .008, width, .071],...
                'Callback', @(btn,event) seeExtremes(this));
        end        
    end
    
    methods(Static, Access=private)
        function MsgSelect
            msgError(Html.WrapHr(['First select a subset in the<br>'...
                'HierarchyExplorer tree of subsets...']), 8, 'north east+', ...
                'Selection required...');
        end
        function gpos=Rect(data, X, Y)
            if isempty(data)
                gpos=[0 0 1 1];
                return;
            end
            if X<1
                X=1;
            end
            if Y<1
                C=size(data,2);
                Y=X+1;
                if Y>C
                    Y=1;
                end
            end
            mn=min(data(:,[X Y]), [], 1);
            mx=max(data(:,[X Y]), [], 1);
            gpos=[mn(1) mn(2) mx(1)-mn(1) mx(2)-mn(2)];
            
            %now nudge edges to catch ALL
            gpos(1)=gpos(1)-.0002;
            if gpos(1)<0
                gpos(1)=0;
            end
            gpos(2)=gpos(2)-.0002;
            if gpos(2)<0
                gpos(2)=0;
            end
            gpos(3)=gpos(3)+.00041;
            gpos(4)=gpos(4)+.00041;            
        end
    end
    methods
        function build(this, key, subset, fncVisit, parentX, parentY, parentName)
            nEvents=subset.size;
            if ~isempty(this.pu)
                if this.pu.cancelled
                   return;
                end
                if isempty(subset.parent)
                    this.pu.setText(Html.WrapHr(...
                        ['Building hierarchy for ' this.fullSize ...
                        ' data points<br><br><center>' Html.WrapSmallTags(...
                        'Pursuing best 2-way splits...') '</center>']));
                    this.pu.dlg.pack;
                end
            end
            if nEvents>0
                [X, Y, selectedA, selectedB, splitA, splitB, leaf_cause]...
                    =this.splitter.getSplit(subset);
                if ~isempty(fncVisit)
                    ok=feval(fncVisit, this, key, subset, X, Y, splitA);
                else
                    ok=true;
                end                
                if ~isempty(selectedA) && sum(selectedA)==0 
                    warning('something is wrong with modal polygon!');
                    ok=false;
                end
                if nEvents<this.args.min_branch_size
                    ok=false;
                end
            else
                ok=false;
                splitA=[];
                leaf_cause=[];
            end
            if ~ok || isempty(selectedA)
                this.leafCount=this.leafCount+1;
                [leafKeySplit, leafKeySize, leafKeyCause]...
                    =SuhEpp.LeafKeys(this.leafCount);
                this.map.put(leafKeySplit, java.lang.String(key));
                this.map.put(leafKeySize, java.lang.String(num2str(nEvents)));
                this.map.put(['leaf.' key], java.lang.String(num2str(this.leafCount)));
                if ~isempty(leaf_cause)
                    this.map.put(leafKeyCause, java.lang.String(leaf_cause));
                end
                this.dataSet.finalizeSubset(subset, this.leafCount)
                if length(key)>this.levels
                    this.levels=length(key);
                end
                this.map.setProperty([key '.size'],  num2str(subset.size));
                this.map.setProperty([key '.name'], [parentName ' leaf']);
                rect=SuhEpp.Rect(subset.data, parentX, parentY);
                this.map.setProperty([key '.leaf'],  num2str(rect));
                if this.args.for_AutoGate
                    subset.dataSet.store_for_AutoGate(this, key, parentX, ...
                        parentY, rect, 'leaf');
                end
                this.store_split(key, parentX, parentY, splitA);
                %fprintf('Leaf size == %d\n', nEvents);
                if ~isempty(this.pu)
                    this.pu.setText(Html.WrapHr([...
                        '<font color=''blue''>Leaf #' ...
                        String.encodeInteger(this.leafCount) ...
                        ' has '  num2str(length(key)) ...
                        ' levels </font> ' subset.html(parentX, parentY) ...
                        '<br><br><center>' Html.WrapSmallTags([...
                        String.encodeInteger(this.branchCount) ...
                        ' branches and ' String.encodeInteger(this.leafCount)...
                        ' leaves so far, pursuing more ...']) '</center>']));
                    this.pu.incrementProgress(subset.size);
                end
            else
                this.store_split(key, X, Y, splitA, splitB);
                if this.args.for_AutoGate
                    subset.dataSet.store_for_AutoGate(this, key, ...
                        X, Y, splitA, 'branchA');
                    subset.dataSet.store_for_AutoGate(this, key,...
                        X, Y, splitB, 'branchB');
                end
                subsetA=SuhSubset(subset, selectedA);
                subsetB=SuhSubset(subset, selectedB);
                means=[...
                    MatBasics.DescriptiveStats(subsetA.data, [X Y])...
                    MatBasics.DescriptiveStats(subsetB.data, [X Y])];
                this.map.setProperty([key '.means'], num2str(means));
                names=edu.stanford.facs.swing.Dbm.GetGateNames(...
                    this.args.is_x_1st_name, means,...
                    subset.dataSet.columnPrefixes{X},...
                    subset.dataSet.columnPrefixes{Y});
                nameA=char(names.get(0));
                nameB=char(names.get(1));
                this.map.setProperty([key '.name'],  [nameA ' branch']);
                this.map.setProperty([key '.B.name'],  [nameB ' branch']);
                this.map.setProperty([key '.size'], num2str(subsetA.size));
                this.map.setProperty([key '.B.size'], num2str(subsetB.size));
                this.build([key '1'], subsetA, fncVisit, X, Y, nameA);
                this.build([key '2'], subsetB, fncVisit, X, Y, nameB);
            end
        end
        
        function num=getLevels(this)
            num=str2double(this.map.get('levels'));
        end
        
        function sequences=getSequences(this)
            sequences=this.getLeafCount;
        end

        function num=getBranchCount(this)
            num=str2double(this.map.get('branchCount'));
        end

        function num=getLeafCount(this)
            num=str2double(this.map.get('leafCount'));
        end
        
        function num=getDuration(this)
            num=str2double(this.map.get('duration'));
        end
        
        function s=getDurationText(this)
            s=String.HoursMinutesSeconds(this.getDuration);
        end
        
        function num=getMatchDuration(this)
            num=str2double(this.map.get('match_duration'));
        end
        
        function s=getMatchDurationText(this)
            s=String.HoursMinutesSeconds(this.getMatchDuration);
        end

        
    end
    properties(Access=private)
        extremeFigs=cell(1,4);
    end
    methods
        function seeExtremes(this)
            short='Shortest split sequence';
            long='Longest split sequence';
            big='Biggest final subset';
            small='Smallest final subset';
            [choices,cancelled]=...
                Gui.Ask('Select 1 or more...', {short, long, big,...
                small}, 'Epp.extremes', 'Extreme sequences...', [1 2 3 4],...
                 [], false);
            if ~cancelled && ~isempty(choices) && this.done
                [deep, shallow, big, small]=this.visitAll;
                go(1, shallow.first, 'Shortest sequence', 'northwest');
                go(2, deep.first, 'Longest sequence', 'southwest');
                go(3, big.first, 'Biggest final subset', 'northeast');
                go(4, small.first, 'Smallest final subset', 'southeast');
            end
            function go(i, leafId, word, where)
                if any(choices==i)
                    fig=this.extremeFigs{i};
                    if isempty(fig) || ~ishandle(fig)
                        this.extremeFigs{i}=this.showSequencePlots(...
                            leafId, word, where);
                    else
                        figure(fig);
                    end
                end
            end
        end
        
    end
    
    methods(Static)
        function [keySplit, keySize, keyCause]=LeafKeys(leaf)
            keySplit=['leaf.split.' num2str(leaf)];
            keySize=['leaf.size.' num2str(leaf)];
            keyCause=['leaf.cause.' num2str(leaf)];
        end
        
        function [X, Y, split_string]=Decode(s)
            i1=find(s=='/');
            i2=find(s==':');
            X=str2double(s(1:i1-1));
            Y=str2double(s(i1+1:i2-1));
            split_string=s(i2+2:end);
        end
        
        function s=Encode(X, Y, split_string)
            s=[num2str(X) '/' num2str(Y) ': ' split_string];
        end
        
        
        function H=Announce(ax, s)
            H=text(ax, .5, .5, s, 'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'middle', 'Color', 'blue',...
                'BackgroundColor', [.99 .99 .920], ...
                'FontWeight', 'bold', 'EdgeColor', 'red');
        end
        
        function epp=New(csvFileOrData, varargin)
            hierarchyExplorer=[];
            if ischar(csvFileOrData)
                csvFileOrData=File.ExpandHomeSymbol(csvFileOrData);
            end
            if nargin<1
                csvFileOrData='sample55k.csv';
            end
            try
                [args, argued, unmatched]=SuhEpp.GetArgs(varargin{:});
                if isempty(args.splitter)
                    if strcmpi('modal', args.create_splitter)
                        args.splitter=SuhModalSplitter(varargin{:});
                        if ~isempty(args.cytometer)
                            SuhEpp.HandleCytometerArgsForModal(args);
                        end
                    else
                        args.splitter=SuhDbmSplitter(varargin{:});
                    end
                end
            catch ex
                BasicMap.Global.reportProblem(ex);
                error(ex.message);
                return;
            end
            showHierarchyExplorer=args.explore_hierarchy ;
            if showHierarchyExplorer
                hierarchyExplorer=SuhEpp.InitHierarchyExplorer(...
                    args, csvFileOrData);
            end
            dataSet=SuhDataSet(csvFileOrData, args);
            if isempty(dataSet.data)
                epp=[];
                if exist('hierarchyExplorer', 'var')
                    close(hierarchyExplorer.fig);
                end
                return;
            end
            epp=SuhEpp(dataSet, args,  argued, unmatched, hierarchyExplorer);
        end
        
        function epp=Omip69_37D(varargin)
            epp=SuhEpp.New('omip69_lymphocytes_37D.csv', varargin{:});
        end
        
        function epp=Omip44(varargin)
            epp=SuhEpp.New('omip044Labeled.csv', ...
                'label_column', 'end', 'cytometer', 'conventional', ...
                'min_branch_size', 150, varargin{:});
        end
        
        function epp=Eliver12(varargin)
            epp=SuhEpp.New('sampleBalbcLabeled12k.csv', 'label_column', ...
                'end', 'cytometer', 'conventional', ...
                'min_branch_size',150, varargin{:});
        end
        

        function epp=Eliver12Umap(varargin)
            epp=SuhEpp.New('sampleBalbcLabeled12k.csv', 'label_column', ...
                'end', 'cytometer', 'conventional', 'min_branch_size', ...
                150,  'umap_option', [1 5], varargin{:});
        end
        
        function epp=Eliver55(varargin)
            epp=SuhEpp.New('sampleBalbcLabeled55k.csv', 'label_column', ...
                'end', 'cytometer', 'conventional', 'min_branch_size', ...
                150,  varargin{:});
        end

        function [file, varArgs]=EliverArgs
            file='eliverLabeled.csv';
            varArgs={'label_column', ...
                'end', 'cytometer', 'conventional', 'min_branch_size', ...
                150};
        end
        
        % command is 
        % run_epp('eliverLabeled.csv', 'label_column', 'end',  'cytometer',  'conventional', 'min_branch_size', 150, 'umap_option', [4 6], 'cluster_detail', 'medium');
        function epp=Eliver(varargin)
            [file, eliverArgs]=SuhEpp.EliverArgs;
            all=[eliverArgs(:)' varargin(:)'];
            epp=SuhEpp.New(file, all{:});
        end
        
        function epp=Holden(varargin)
            epp=SuhEpp.New('maeckerLabeled.csv', ...
                'label_column', 'end', 'cytometer', 'cytof', ...
                'min_branch_size', 150, varargin{:});
        end

        function epp=Genentech(varargin)
            epp=SuhEpp.New('genentechLabeled.csv', 'label_column', ...
                'end', 'cytometer', 'cytof', ...
                'min_branch_size', 150, varargin{:});
        end

        function epp=Omip69(varargin)
            epp=SuhEpp.New('omip69Labeled.csv', 'label_column',...
                'end', 'cytometer', 'spectral', ...
                'min_branch_size', 150, varargin{:});
        end

        function epp=Omip47(varargin)
            epp=SuhEpp.New('omipBLabeled.csv', 'label_column', ...
                'end', 'cytometer', 'conventional', ...
                'min_branch_size', 150, 'W', .015, varargin{:});
        end
        
        function epp=Panorama(varargin)
            epp=SuhEpp.New('panoramaLabeled.csv', 'label_column', ...
                'end', 'cytometer', 'cytof', ...
                'min_branch_size', 150, 'W', .024, varargin{:});
        end        

        function epp=EliverBalbc(varargin)
            epp=SuhEpp.New('sample55k.csv', varargin{:});
        end
        
        function HandleCytometerArgsForModal(args)
            cy=args.cytometer;
            sp=args.splitter;
            if strcmpi(cy, 'cytof')
                W=.02;
                sigma=4;
                k1=.16;
                k2=.16;
            elseif strcmpi(cy, 'spectral')
                W=.012;
                sigma=3;
                k1=.17;
                k2=0.17;
            else
                W=.01;
                sigma=3;
                k1=.16;
                k2=0.16;
            end
            do('W', W);
            do('sigma', sigma);
            do('KLD_normal_1D', k1);
            do('KLD_normal_2D', k2);
            do('KLD_exponential_1D', k1);
            
            function do(fld, value)
                if sp.argued.contains(java.lang.String(fld))
                    explicitValue=getfield(sp.args, fld);
                    if ~isequal(explicitValue, value)
                        warning(['%s cytometer setting of %s=%0.4f '...
                            'is overridden by explicit setting %0.4f'], ...
                            cy, fld, value, explicitValue);
                    end
                else
                    sp.args=setfield(sp.args, fld, value);
                end
            end
        end
        
        function epp=EliverModal(varargin)
            epp=SuhEpp.New('sample55k.csv', varargin{:});
        end
        
        function epp=EliverDbm(varargin)
            varargin{end+1}='create_splitter';
            varargin{end+1}='dbm';
            epp=SuhEpp.New('sample55k.csv', varargin{:});
        end
        
        function epp=LPM(varargin)
            epp=SuhEpp.New('EliverLPM.csv', varargin{:});
        end
        
        function epp=Cytof(varargin)
            epp=SuhEpp.New('cytofExample.csv', varargin{:});
        end
        
        function varargin=HandleUmapVerbose(varargin)
            verbose='verbose';
            value=Args.StartsWith(verbose, varargin{:});
            hasUmapVerbose= ~isempty(value) ...
                && ischar(value);
            if hasUmapVerbose
                if ~strcmpi(value,'graphic')
                    if strcmpi(value, 'text')
                        vFlag=5;
                    else
                        vFlag=0;
                    end
                    varargin=Args.Set(...
                            verbose, vFlag, varargin{:});
                    explore=false;
                else
                    varargin=Args.Set(...
                        verbose, 1, varargin{:});
                    explore=true;
                end
                [was, exploreHierarchy]=...
                    Args.StartsWith('explore_hierarchy', ...
                    varargin{:});
                if ~isempty(was) 
                    warning(['Arguing verbose="%s" '...
                        'overrides your explore_hierarchy'...
                        ' argument with %d'], value, explore);
                    varargin=Args.Set(exploreHierarchy, ...
                        explore, varargin{:});
                end
            end
        end
        
        function [args, argued, unmatchedArgs, ...
                argsObj]=GetArgs(varargin)
            varargin=SuhEpp.HandleUmapVerbose(...
                varargin{:});
            [args, argued, unmatchedArgs, argsObj]=...
                Args.NewKeepUnmatched(...
                SuhEpp.DefineArgs(), varargin{:});
        end
        
        function argsObj=GetArgsWithMetaInfo(csvFile, varargin)
            if isempty(csvFile)
                csvFile='sample10k.csv';
            end
            argsObj=Args.NewMerger({SuhEpp.DefineArgs, ...
                SuhModalSplitter.DefineArgs,...
                SuhDbmSplitter.DefineArgs}, varargin{:});
            argsObj.commandPreamble='suh_pipelines';
            argsObj.commandVarArgIn='''pipeline'', ''epp'', ';
            m=mfilename('fullpath');
            p=fileparts(m);
            argsObj.setSources(@run_epp, fullfile(p, 'run_epp.m'), m);
            argsObj.setPositionalArgs('csv_file_or_data');
            argsObj.update('csv_file_or_data', csvFile);
            argsObj.load;
        end
        
        function argsObj=SetArgsMetaInfo(argsObj) 
            try
                dtls=Density.DETAILS;
                dtls=dtls(1:end-1);
            catch ex
                ex.getReport
                dtls={'most high', 'very high', 'high', ...
                    'medium', 'low', 'very low', 'adaptive'};
            end
            argsObj.setMetaInfo('W', 'low', .001, 'high', .6, ...
                'type', 'double');
            argsObj.setMetaInfo('sigma', 'low', 1, 'high', 7, ...
                'type', 'double');
            
            argsObj.setMetaInfo('KLD_normal_1D', 'low', .02, 'high', .5, ...
                'label', '1D KLD normal distribution', 'type', 'double');
            argsObj.setMetaInfo('KLD_exponential_1D', 'low', .02, 'high', .5, ...
                'label', '1D KLD exponetial distribution', 'type', 'double');
            argsObj.setMetaInfo('KLD_normal_2D', 'low', .02, 'high', .5, ...
                'label', '2D KLD normal distribution', 'type', 'double');
            argsObj.setMetaInfo('create_splitter', ...
                'valid_values', {'dbm', 'modal'});
            argsObj.setMetaInfo('cluster_detail', ...
                'type', 'char', 'valid_values', dtls);
            argsObj.setMetaInfo('cytometer', ...
                'type', 'char', 'valid_values', SuhEpp.CYTOMETER_VALUES);
            
            argsObj.setMetaInfo('output_folder', 'type', 'folder');
            argsObj.setMetaInfo('properties_file', 'type', 'file_readable');
            argsObj.setArgGroup({'balanced', 'W', 'sigma', ...
                'max_clusters', 'min_branch_size'}, ...
                'Modal cluster settings');
            argsObj.setArgGroup({'balanced', 'cluster_detail', ...
                'trimLeaves', 'minLeafSize', ...
                'max_clusters', 'balancedNoisy'}, 'DBM cluster settings')
            argsObj.setArgGroup({'KLD_normal_2D', 'KLD_normal_1D', ...
                'KLD_exponential_1D'}, ...
                'Kullback-Leibler Divergence settings')
            argsObj.setFileFocus('EPP''s input data', 'csv_file_or_data');
            argsObj.setCsv('csv_file_or_data', true, 'label_column', 'label_file');
        end
        
        function p=DefineArgs()
            p = inputParser;
            addParameter(p,'splitter', [],  @(x) isa(x, 'SuhSplitter'));
            addParameter(p, 'create_splitter', 'modal', ...
                @(x)strcmpi(x, 'modal') || strcmpi(x, 'dbm'));
            addParameter(p, 'verbose_flags', 1,  ...
                @(x) Args.IsInteger(x, 'verbose_flags', 0, intmax/2));
            addParameter(p, 'rebuild_automatically', false, @islogical);
            addParameter(p, 'reuse_automatically', false, @islogical);
            addParameter(p, 'folder', [], @ischar);
            addParameter(p, 'column_names', {}, @Args.IsStrings);
            addParameter(p, 'column_ranges', [], @Args.IsColumnRanges);
            addParameter(p, 'column_external_indexes', [], @isnumeric);
            addParameter(p, 'training_ids', [], @isnumeric);
            addParameter(p, 'try_properties_download', false, @islogical);
            addParameter(p, 'pu', [], @(x)isa(x, 'PopUp'));
            addParameter(p, 'min_branch_size', 0, @(x)isnumeric(x) && x>2 && x<3000);
            addParameter(p, 'properties_file', '', @Args.IsFileOk);
            addParameter(p, 'see_extremes', false, @islogical);
            addParameter(p, 'for_AutoGate', false, @islogical);
            addParameter(p, 'is_x_1st_name', true, @islogical);
            addParameter(p, 'column_name_prefix', ':', @ischar);
            addParameter(p, 'color_file','colorsByName.properties',@(x) ischar(x));
            addParameter(p, 'color_defaults', false, @islogical);
            addParameter(p, 'label_column', [],...
                @(x) strcmpi(x, 'end') || (isnumeric(x) && x>0));
            addParameter(p, 'buildLabelMap', false, @islogical);
            addParameter(p, 'label_file',[], @ischar);
            addParameter(p, 'qf_tree', false, @islogical);
            addParameter(p, 'match', true, @islogical);
            addParameter(p, 'match_table_fig', true, @islogical);
            addParameter(p, 'match_histogram_figs', true, @islogical);
            addParameter(p, 'explore_hierarchy', true, @islogical);
            addParameter(p, 'gating_ml_file', [], @ischar);
            addParameter(p, 'cytometer', [], ...
                @(x) any(validatestring(x, SuhEpp.CYTOMETER_VALUES)));
            addParameter(p, 'umap_option', 0,  ...
                @(x) isnumeric(x) && all(x>0) && all(x<=8));
            addParameter(p, 'locate_fig', {}, ...
                @(x)Args.IsLocateFig(x, 'locate_fig' ));
            addParameter(p, 'save_output', false, @islogical);
            addParameter(p, 'output_folder', '',  @(x)Args.IsFolderOk(x));
            
            addParameter(p, 'match_predictions', false, @islogical);
            p.FunctionName='run_epp';
            
            SuhDataSet.AddNormalizedParameters(p);
        end
        
        
        function [file, fullFile, eppFolder]=LocateMex()
            file=['mexSptxModal.' mexext];
            if nargout>1
                eppFolder=fileparts(mfilename('fullpath'));
                fullFile=fullfile(eppFolder, file);
            end
        end

        function goodToGo=OfferFullDistribution(stop)
            if nargin<1
                stop=false;
            end
            goodToGo=false;
            rel=@(x)['<b><font color="blue">' x '</font></b> EPP'];
            full=rel('full');
            if stop
                br='<br>';
            else
                br=' ';
            end
             preamble=['EPP must have a MEX file to run but '...
                     '<b>MathWorks ' br 'File Exchange</b> does'...
                    ' <br>not distribute binary files.'...
                    '<hr><br><b>HOWEVER....you can do one of the following'...
                    '</b>'];
               
                choices={'Download the MEX file directly',...
                    'Build the MEX file from our open source',...
                    ['<html>Download our ' full ...
                    ' (eppDistribution.zip)</html>'],...
                    ['<html>Access our ' full ' &amp; examples '...
                    'on GoogleDrive</html>']};
                [choice, cancelled]=Gui.Ask(Html.Wrap(preamble), choices, ...
                    'eppFullDistribution', ...
                    'MathWorks File Exchange restrictions!', 1);
                if cancelled
                    return;
                end
                if choice==1
                    SuhEpp.DownloadAdditions(true, 'accelerants');
                elseif choice==2
                    goodToGo=build;
                elseif choice==3
                    SuhEpp.DownloadAdditions(true, 'full');
                elseif choice==4
                    SuhEpp.GoogleDrive([], true)
                end
            
            function ok=build(h)
                if nargin>0
                    wnd=Gui.WindowAncestor(h);
                end
                app=BasicMap.Global;
                msg(Html.Wrap(['Build results are reported in MATLAB ''Command window'''...
                    '<br><br>' app.smallStart '<b><font color="red">'...
                    'NOTE:&nbsp;&nbsp;</font>You must have done the MEX setup '...
                    'first to attach a C++ <br>compiler to MATLAB... '...
                    'Clang++ is the compiler we prefer for speed.</b>' ...
                    '<br><br>To do the setup type "<font color="blue">'...
                    'mex -setup cpp</font>" in MATLAB''s '...
                    'command window.' app.smallEnd '<hr>']));
                if nargin>0
                    wnd.dispose;
                end
                if ~SuhEpp.LibsExist
                    SuhEpp.DownloadAdditions(false, 'build');
                end
                ok=SuhModalSplitter.Build;
            end          
        end
        
        function ok=LibsExist(pc)
            if nargin<1
                pc=ispc;
            end
            eppFolder=fileparts(mfilename('fullpath'));
            if pc
                buildFolder=fullfile(eppFolder, 'cpp/mswin64');
                ok=exist(fullfile(eppFolder, 'libfftw3-3.dll'), 'file') ...
                    && exist(fullfile(eppFolder, 'libfftw3f-3.dll'), 'file') ...
                    && exist(fullfile(eppFolder, 'libfftw3l-3.dll'), 'file') ...
                    && exist(fullfile(buildFolder, 'libfftw3-3.lib'), 'file') ...
                    && exist(fullfile(buildFolder, 'libfftw3f-3.lib'), 'file') ...
                    && exist(fullfile(buildFolder, 'libfftw3l-3.lib'), 'file');
            else
                buildFolder=fullfile(eppFolder, 'cpp/mac');
                ok=exist(fullfile(buildFolder, 'libfftw3.a'), 'file') ...
                    && exist(fullfile(buildFolder, 'libfftw3f.a'), 'file');
            end
                
        end
        
          function ok=DownloadAdditions(ask, which, h)
            ok=false;
            if nargin<3
                h=[];
                if nargin<2
                    which='accelerants';
                    if nargin<1
                        ask=true;
                    end
                end
            end
            eppFolder=fileparts(mfilename('fullpath'));
            downloads=fullfile(File.Home, 'Downloads');
            if isequal(which, 'accelerants')
                exeSM=SuhEpp.LocateMex;
                if ~isempty(h)
                    wnd=Gui.WindowAncestor(h);
                    wnd.dispose;
                end
                if ismac
                    [from, to, cancelled]=gather(eppFolder, exeSM);
                else
                    [from, to, cancelled]=gather(eppFolder, exeSM,...
                        'libfftw3-3.dll','libfftw3l-3.dll', ...
                        'libfftw3f-3.dll');
                end
            elseif isequal(which, 'build')
                if ispc
                    [from, to, cancelled]=gather(...
                        fullfile(File.Home, 'Downloads'), ...
                        'libfftw3-3.dll', 'libfftw3-3.lib',...
                        'libfftw3l-3.dll','libfftw3l-3.lib', ...
                        'libfftw3f-3.dll', 'libfftw3f-3.lib');
                elseif ismac
                    [from, to, cancelled]=gather(downloads, ...
                        'libfftw3.a', 'libfftw3f.a');
                end
                
            else
                [from, to, cancelled]=gather(...
                    fullfile(File.Home, 'Downloads'), ...
                    'eppDistribution.zip');
                if isempty(from) && ~cancelled
                    instructUnzip
                end
            end
            if isempty(from)
                ok=~cancelled;
                return;
            end
            [cancelled, bad]=WebDownload.Get(from, to, false, true);
            if ~cancelled && ~bad 
                ok=true;
                if isequal(which, 'full')
                    instructUnzip;
                elseif isequal(which, 'build')
                    if ispc
                        dllFiles=fullfile(downloads, 'libfftw3*.dll');
                        movefile(dllFiles, eppFolder);
                        libFiles=fullfile(downloads, 'libfftw3*.lib');
                        dst=fullfile(eppFolder, 'cpp/mswin64');
                        movefile(libFiles, dst);
                    elseif ismac
                        dst=fullfile(eppFolder, 'cpp/mac');
                        libFiles=fullfile(downloads, 'libfftw3*.a');
                        movefile(libFiles, dst)
                    end
                else
                    msg(Html.WrapHr('<b>The accelerants are downloaded!</b>'),...
                        5, 'north+', '', 'genieSearch.png');
                end
            end
            
            function instructUnzip
                msg(Html.WrapHr(['<html>epp.zip has been '...
                    'downloaded to<br><b>' fullfile(File.Home, 'Downloads') ...
                    '</b><hr><br><b>Note</b>: you <b>must replace</b> the '...
                    'current basic UMAP by<br>unzipping this zip file over'...
                    ' top of this installation...']), 0, 'south++');
            end
            
            function [from, to, cancelled]=gather(toFolder, varargin)
                cancelled=false;
                from={};
                to={};
                N=length(varargin);
                have=false(1,N);
                haveAlready={};
                doNotHave={};
                for i=1:N
                    if exist(fullfile(toFolder, varargin{i}), 'file')
                        haveAlready{end+1}=varargin{i};
                        have(i)=true;
                    else
                        doNotHave{end+1}=varargin{i};
                    end
                end
                if ~ask
                    overwrite=false;
                elseif ~isempty(haveAlready)
                    if isempty(doNotHave)
                        [overwrite, cancelled]=askYesOrNo(Html.Wrap([...
                            'Overwrite the following...?<hr>'...
                            Html.ToList(haveAlready, 'ul') ...
                            ' in the folder <br>' ...
                            Html.WrapBoldSmall(toFolder) '??<hr>' ]));
                        if cancelled
                            return;
                        end
                    else
                        labels={['Only download the ' String.Pluralize2(...
                            'missing item', length(doNotHave))...
                            '...'], ['Download EVERYTHING '...
                            'including the ' String.Pluralize2(...
                            'pre-exisitng item', length(haveAlready)) ]};
                        [choice, cancelled]=Gui.Ask(Html.Wrap([...
                            'These files pre-exist...'...
                            Html.ToList(haveAlready, 'ul') ...
                            ' in the folder <br>' ...
                            Html.WrapBoldSmall(toFolder) ...
                            '<hr>HENCE I will ...' ]), ...
                            labels);
                        if cancelled
                            return;
                        end
                        overwrite=choice==2;
                    end
                else
                    overwrite=true;
                end
                if ~overwrite && all(have)
                    if isequal(which, 'accelerants')
                        msg('You were already fully up to date!');
                    end
                end
                for i=1:N
                    if overwrite || ~have(i)
                        from{end+1}=...
                            WebDownload.ResolveUrl(varargin{i}, 'run_epp');
                        to{end+1}=fullfile(toFolder, varargin{i});
                    end
                end
            end
          end

        %https://drive.google.com/drive/folders/1-6LjFisRv-a0q2ZOCj3lL-eppiatqadj?usp=sharing
        function GoogleDrive(btn, stop)
                if nargin<2
                    stop=false;
                    if nargin<1
                        btn=[];
                    end
                end
            url='https://drive.google.com/drive/folders/1-6LjFisRv-a0q2ZOCj3lL-eppiatqadj?usp=sharing';
            web(url, '-browser');
            MatBasics.RunLater(@(h,e)advise(btn), 3);
            function advise(btn)
                h2=Html.H2('Downloading from our Google Drive');
                font2='"<font color="blue">';
                fontEnd='</font>"';
                html=['<b>The full distribution ....</b><ol>'...
                    '<li>Is in ' font2 'eppDistribution.zip' fontEnd...
                    '<li>Contains all Java, C++, and MATLAB source code '...
                    '<li>Contains all binary MEX files'...
                    '<li>Contains all binary fftw3 libraries '...
                    '<br>f or building with C++'...
                    '</ol>'];
                
                html=[html '</ul><br>THANK YOU!'];
                ttl='Advice on downloading';
                if  stop 
                    if ~isempty(btn)
                        jw=Gui.WindowAncestor(btn);
                    else
                        jw=[];
                    end
                    msgTxt=Html.Wrap([h2 html '<hr>']);
                    msgModalOnTop(msgTxt, 'south east++', ...
                        jw, 'facs.gif', ttl);
                else
                    jd=msg(Html.Wrap([h2 html '<hr>']), 0, 'south++', ttl);
                    jd.setAlwaysOnTop(true);
                end
            end
        end
    end
end