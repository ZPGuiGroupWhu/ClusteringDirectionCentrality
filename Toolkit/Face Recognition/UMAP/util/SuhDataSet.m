%   AUTHORSHIP
%   Primary Developer: Stephen Meehan <swmeehan@stanford.edu> 
%   Provided by the Herzenberg Lab at Stanford University 
%   License: BSD 3 clause
%
classdef SuhDataSet < handle
    
    properties(Constant)
        FILE_MATCH='epp_match.mat';
        FILE_MATCH_LABEL='matchedLabelFile.properties';
        FILE_MATCH_NAMES_CLRS='matchedNamesClrs.mat';
    end
    
    properties(SetAccess=private)
        R;
        C;
        finalSubsetIds; % one per data row
        columnNames;
        columnPrefixes;
        columnExternalIndexes;
        ttl;
        file;
        nNames;
        labels;
        lblMap;
        match;
        matchTable;
        predictions;
        qfTree1;
        qfTree1Match
        qfTree2;
        qfTree2Match;
        matchedLabelFile;
        label_file;
        normalized_range_test;
        fnc_normalize;%(reverse, col, data)
    end
    
    properties
        columnRanges;
        data;
    end
    
    methods(Static)
        
        function p=DefineArgs()
            p=inputParser;     
            addParameter(p, 'column_name_prefix', ':', @ischar);
            addParameter(p, 'column_names', {}, @(x)isempty(x)||Args.IsStrings(x));
            addParameter(p, 'column_ranges', [], @Args.IsColumnRanges);
            addParameter(p, 'training_ids', [], @isnumeric);
            addParameter(p, 'label_column', [],...
                @Args.IsLabelColumn);
            addParameter(p, 'buildLabelMap', false, @islogical);
            addParameter(p, 'label_file',[], @ischar);
            addParameter(p, 'verbose_flags', 1,  ...
                @(x) Args.IsInteger(x, 'verbose_flags', 0, intmax/2));
            addParameter(p, 'color_file','colorsByName.properties',@(x) ischar(x));
            addParameter(p, 'color_defaults', false, @islogical);
            SuhDataSet.AddNormalizedParameters(p);
            addParameter(p, 'pu', [], @(x)isa(x, 'PopUp'));
        end
        
        function this=New(csvFileOrData, varargin)  
            this=SuhDataSet(csvFileOrData, ...
                Args.New(SuhDataSet.DefineArgs, varargin{:}));
        end
        
        function AddNormalizedParameters(p, ...
                dfltRangeTest, dfltFnc)
            if nargin<3
                dfltFnc='';
                if nargin<2
                    dfltRangeTest=[-100 1.2]; %Logicle
                end
            end
            addParameter(p, 'normalized_range_test', ...
                dfltRangeTest, ...%crazy range for logicle
                @(x)isempty(x) || (isnumeric(x) && x(1)<x(2)));
            addParameter(p, 'fnc_normalize', dfltFnc, ...
                @(x)isa(x, 'function_handle') ||isempty(x));
        end
    end
    
    methods
        function this=SuhDataSet(csvFileOrData, args)  
            this.columnNames=args.column_names;
            this.columnRanges=args.column_ranges;
            this.normalized_range_test=...
                args.normalized_range_test;
            this.fnc_normalize=args.fnc_normalize;
            if nargin<1 || isempty(csvFileOrData)
                return;
            end
            pu=[];
            if ischar(csvFileOrData)
                csvFile=WebDownload.GetExampleIfMissing(...
                    csvFileOrData);
                if ~exist(csvFile, 'file')
                    jd=msg(struct('javaWindow', 'none', ...
                        'msg', ['<html>The csv file ' ...
                        Html.FileTree(csvFile)...
                        '<br><center><font color='...
                        '"red"><i>cannot be found !!' ...
                        '</i></font><hr></center>'...
                        '</html>']), 25, 'center', ...
                        'Error...', 'error.png');
                    jd.setVisible(true);
                    return;
                end
                de=dir(csvFile);
                html=['<html>Loading '...
                        '<b><i>' String.encodeGb(de.bytes,[],2) ...
                        '</i></b> from' Html.FileTree(csvFile) ...
                        '<br><br>'...1
                        Gui.UnderConstructionImg  '<hr></html>'];
                if ~isempty(args.pu)
                    pu=char(args.pu.label.getText);
                    args.pu.setText(html);
                else
                    pu=PopUp(html, 'north+');
                end
                if args.verbose_flags>0
                    disp(['Loading ' csvFile]);
                end
                [this.data, names]=File.ReadCsv(csvFile);
                this.file=csvFile;
                if isempty(this.columnNames)
                    this.columnNames=names;
                end
                [~, f, e]=fileparts(csvFile);
                ttl=[f e];
            else
                this.data=csvFileOrData;
                ttl=' ';
            end      
            [this.R, this.C]=size(this.data);
            label_column=args.label_column;
            if ~isempty(label_column)
                if ~isempty(args.training_ids)
                    warning(['Both training_ids and label_column '...
                        'argued ... ignoring training_ids']);
                end
                if strcmpi(label_column, 'end')
                    label_column=this.C;
                end
                if length(label_column)>1
                    this.labels=label_column;
                elseif label_column>0                    
                    if  label_column>this.C
                        msg(Html.WrapHr(['The input data has ' ...
                            sCols ' columns ...<br>'...
                            'THUS the label_column must be >=1 and <= '...
                            sCols]));
                        assert(label_column>0 && label_column<=nCols, [...
                            'label_column must be >=1 and <= ' sCols]);
                    end
                    this.labels=this.data(:, label_column);
                    this.data(:, label_column)=[];
                    if length(this.columnNames)==this.C
                        this.columnNames(label_column)=[];
                    end
                    this.C=this.C-1;
                end
            elseif ~isempty(args.training_ids)
                if length(args.training_ids) ~= this.R
                    warning('Ignoring %d training_ids for %d data rows',...
                        length(args.training_ids), this.R);
                else
                    this.labels=args.training_ids;
                end
            end
            if ~isempty(this.labels)
                if (isempty(args.label_file) || (~isempty(args.label_file) ...
                        && ~exist(args.label_file, 'file') ) )...
                        && ischar(csvFileOrData)
                    [p,fn]=fileparts(csvFile);
                    good=false;
                    if ~isempty(args.label_file)
                        [lblP, lblF, lblE]=fileparts(args.label_file);
                        if isempty(lblP)
                            lblFile=[lblF lblE];
                            args.label_file=fullfile(p, lblFile);
                            good=exist(args.label_file, 'file');
                            if ~good
                                args.label_file=...
                                    WebDownload.GetExampleIfMissing(lblFile);
                                good=exist(args.label_file, 'file');
                            end
                        end
        
                    end
                    if ~good
                        lblFile=[fn '.properties'];
                        args.label_file=fullfile(p, lblFile);
                        if ~exist(args.label_file, 'file')
                            args.label_file=...
                                WebDownload.GetExampleIfMissing(lblFile);
                        end
                    end
                end
                args.n_rows=this.R;
                [lblMap_,halt, args]=LabelBasics.GetOrBuildLblMap(...
                    this.labels, args);
                if halt
                    this.labels=[];
                else
                    this.lblMap=lblMap_;
                    this.label_file=args.label_file;
                end
            end
            this.finalSubsetIds=zeros(1,this.R);
            this.ttl=[ttl ' ' String.encodeInteger(this.R) ...
                'x' String.encodeInteger(this.C)];
            this.initColumnNamePrefixes(args.column_name_prefix);
            this.normalize;
            if ~isempty(pu)
                if isa(pu, 'PopUp')
                    pu.close;
                else
                    args.pu.setText(pu);
                end
            end
        end
        
        function finalizeSubset(this, subset, id)
            this.finalSubsetIds(subset.selected)=id;
        end
        
        function s=html(this, idx, prefix)
            if nargin<3
                prefix=true;
            end
            s=num2str(idx);
            if idx>0 && idx<=this.nNames 
                if prefix
                    s=[s ': ' String.ToHtml(this.columnPrefixes{idx})];
                else
                    s=[s ': ' String.ToHtml(this.columnNames{idx})];
                end
            end
        end
        
        function initColumnNamePrefixes(this, prefix)
            if nargin<2
                prefix=':';
            end
            N=length(this.columnNames);
            this.nNames=N;
            if N<1
                return;
            end
            this.columnPrefixes=cell(1,N);
            for i=1:N
                name=this.columnNames{i};
                l=find(name==prefix);
                if isempty(l)
                    this.columnPrefixes{i}=name;
                else
                    this.columnPrefixes{i}=name(1:l(1)-1);
                end
            end
        end
        
        function ok=normalize(this)
            ok=true;
            if ~isempty(this.columnRanges)
                adjust
                return
            end
            if isempty(this.normalized_range_test)
                return;
            end
            mx=max(this.data);
            mn=min(this.data);
            badCols=find(...
                mx> this.normalized_range_test(2) ...
                | mn < this.normalized_range_test(1)); 
            %believe it or not logicle sometimes produced values slightly over 1
            if ~isempty(badCols)
                nBad=length(badCols);
                msg(Html.WrapHr(sprintf(['%d column(s)'...
                    ' NOT within normalized_range_test...'...
                    'of %d to %d!<br>(adjusting now however'...
                    ' results may be odd)'],  nBad, ...
                    this.normalized_range_test(1),...
                    this.normalized_range_test(2))));
                this.columnRanges=zeros(1, nBad*3);
                for iBad=0:nBad-1
                    idxBad=iBad*3+1;
                    bad=badCols(iBad+1);
                    this.columnRanges(idxBad)=bad;
                    this.columnRanges(idxBad+1)=mn(bad);
                    this.columnRanges(idxBad+2)=mx(bad);
                end
                adjust;
            end
            
            function adjust
                N=length(this.columnRanges);
                cols=N/3;
                for i=0:cols-1
                    idx=i*3+1;
                    col=this.columnRanges(idx);
                    if col>this.C
                        warning('triplet # %d has # > %d data coumns',...
                            i, col, this.C);
                        ok=false;
                    else
                        if isempty(this.fnc_normalize)
                            mn=this.columnRanges(idx+1);
                            mx=this.columnRanges(idx+2);
                            range=mx-mn;
                            this.data(:, col)=(this.data(:, col)-mn)/range;
                        else
                            this.data(:,col)=feval(...
                                this.fnc_normalize, false, col,...
                                this.data(:,col));
                        end
                    end
                end

            end
        end
        
        function xyData=denormalizePolygon(this, X, Y, xyData)
            if ~isempty(this.columnRanges)
                columns=[X Y];
                N=length(this.columnRanges);
                cols=N/3;
                for i=0:cols-1
                    idx=i*3+1;
                    col=this.columnRanges(idx);
                    if col>this.C
                        warning('triplet # %d has # > %d data columns',...
                            i, col, this.C);
                    else
                        xyIdx=find(columns==col, 1);
                        if ~isempty(xyIdx)
                            if isempty(this.fnc_normalize)
                                mn=this.columnRanges(idx+1);
                                mx=this.columnRanges(idx+2);
                                range=mx-mn;
                                xyData(:, xyIdx)=(...
                                    xyData(:, xyIdx)*range)+mn;
                            else
                                xyData(:, xyIdx)=feval(...
                                    this.fnc_normalize, true, col,...
                                    xyData(:, xyIdx));
                                
                            end
                        end
                    end
                end
            end    
        end
        
        function ok=isNormalized(this, X, Y)
            if isempty(this.columnRanges)
                ok=false;
            end
            columns=[X Y];
            N=length(this.columnRanges);
            cols=N/3;
            for i=0:cols-1
                idx=i*3+1;
                col=this.columnRanges(idx);
                if col>this.C
                    warning('triplet # %d has # > %d data columns',...
                        i, col, this.C);
                else
                    xyIdx=find(columns==col, 1);
                    if ~isempty(xyIdx)
                        ok=true;
                        return;
                    end
                end
            end    
            ok=false;
        end
        
        function [xy,data]=denormalize(this, X, Y, data, isPolygonString)
            if (this.isNormalized(X, Y))
                if isPolygonString
                    ff=this.denormalizePolygon(X, Y, MatBasics.StringToXy(data));
                    data=num2str(ff(:)');
                else
                    fakePolygon=[data(1) data(2); data(3) data(4)];
                    ff=this.denormalizePolygon(X,Y,fakePolygon);
                    data=num2str([ff(1) ff(3) ff(2) ff(4)]);
                end
            else
                if ~isPolygonString
                    data=num2str(data);
                end
            end
            N=length(this.columnExternalIndexes);
            if N>0
                if X==0 || Y==0
                    warning('Nothing found by EPP?');
                else
                    X=this.columnExternalIndexes(X);
                    Y=this.columnExternalIndexes(Y);
                end
            end
            xy=num2str([X Y]);
        end
        
        function store_for_AutoGate(this, suhEpp, eppKey, X, Y, data, which)
            if isempty(data) 
                return;
            end
            [xy, data]=this.denormalize(X, Y, data, ~strcmpi(which, 'leaf'));
            if strcmpi(which, 'branchB')
                prop1=[eppKey '.autoGate.B'];
            else
                prop1=[eppKey '.autoGate'];
                length(xy);
                suhEpp.map.setProperty([eppKey '.xy.autoGate'], xy);
            end
            suhEpp.map.setProperty(prop1, data);
        end
        
        function [sLbls,mx]=getTestSetLabels(this)
            mx=max(this.labels);
            sLbls=this.finalSubsetIds+mx+1;
        end
        
        function setProperties(this, props, columnExternalIndexes)
            if nargin<3
                columnExternalIndexes=[];
            end
            N=length(this.columnPrefixes);
            if N>0
                for i=1:N
                    props.setProperty(['columnName.' num2str(i)], ...
                        this.columnPrefixes(i));
                end
            else
                N=length(this.columnNames);
                for i=1:N
                    props.put(['columnName.' num2str(i)], ...
                        java.lang.String(this.columnNames(i)));
                end
            end
            N=length(this.columnRanges);
            if N>0
                props.put('columnRanges', ...
                    java.lang.String(num2str(this.columnRanges(:)')));
            end
            N=length(columnExternalIndexes);
            if N>0
                this.columnExternalIndexes=columnExternalIndexes;
                for i=1:N
                    props.setProperty(['columnExternalIndex.' num2str(i)], ...
                        num2str(columnExternalIndexes(i)));
                end
            end
        end
        
        function [names, clrs, lbls]=getLabelInfo(this)
            if isempty(this.lblMap)
                names={}; clrs=[]; lbls=[];
            else
                [names, clrs, lbls]=LabelBasics.GetNamesColorsInLabelOrder(...
                    this.labels, this.lblMap);
            end
        end
        
        function [path, fileName, ext]=fileParts(this)
            if isempty(this.file)
                path=File.Downloads;
                fileName=sprintf('data_%dx%d_%s', this.R, ...
                    this.C, String.encodeRounded(...
                    mean(this.data(:)), 2));
                ext='.csv';
            else
                [path,fileName, ext]=fileparts(this.file);
            end
        end
        
        function predictions=seePredictions(this)
            if ~isempty(this.matchTable)
                this.predictions=this.matchTable.seePredictionOfThese;
            end
            predictions=this.predictions;
        end

        function [qf, matchTable]=characterize(this, epp, pu, visible)
            if isempty(this.labels) % no labels with which to characterize 
                qf=[];
                matchTable=[];
                return;
            end
            args=epp.args;
            if ~args.match && ~args.qf_tree
                return;
            end
            if ~args.match_table_fig && ...
                ~args.match_histogram_figs  && ~args.qf_tree
                qf=[];
                matchTable=[];
                return;
            end
            this.matchedLabelFile=fullfile(epp.folder, ...
                SuhDataSet.FILE_MATCH_LABEL);
            closePu=false;
            if nargin<4
                visible=true;
                if nargin<3 || isempty(pu)
                    pu=PopUp('Characterizing EPP results');
                    pu.setTimeSpentTic;
                    closePu=true;
                else
                    pu.setText2('Characterizing EPP results');
                end
            end
            if isempty(this.finalSubsetIds) || all(this.finalSubsetIds==0)
                epp.rakeLeaves;
            end
            matchStrategy=3; % match by QFMatch accelerated by overlap
            [tNames, clrs, tLbls]=LabelBasics.GetNamesColorsInLabelOrder(...
                this.labels, this.lblMap);
            [sLbls,mx]=this.getTestSetLabels;
            eppLeafNames=epp.getLeafNames;
            savedFile=fullfile(epp.folder, SuhDataSet.FILE_MATCH);
            qf=QfTable.Load(savedFile, false,this.data, tLbls); 
            if isempty(qf)
                tm=tic;
                this.match=run_HiD_match(this.data, tLbls,...
                    this.data, sLbls, 'trainingNames', tNames, ...
                    'testNames', eppLeafNames, 'matchStrategy', matchStrategy,....
                    'log10', true, 'pu', pu);
                duration=toc(tm);
                epp.map.put('match_duration', java.lang.String(num2str(duration)));
                epp.save(epp.properties_file);
            else
                this.match=qf;
            end
            matchedNamesClrsFile=fullfile(epp.folder, ...
                SuhDataSet.FILE_MATCH_NAMES_CLRS);
            if args.match_table_fig || args.match_histogram_figs
                if visible
                    this.matchTable=QfTable(this.match, clrs, [],...
                        get(0, 'currentFig'), ...
                        {epp.figHierarchyExplorer, 'north east++', true});
                else
                    this.matchTable=QfTable(this.match, clrs, [],...
                        get(0, 'currentFig'), false);
                end
                if isempty(qf)
                    this.matchTable.qf.setColumnNames( this.columnNames );
                    this.matchTable.save(this.match, savedFile);
                    epp.copyToOutputIfArgued(fullfile(...
                        fileparts(savedFile), ...
                        SuhDataSet.FILE_MATCH));
                end
                if args.match_histogram_figs
                    if ~this.matchTable.doHistF(visible)
                        this.matchTable=[];
                    else
                        if epp.args.save_output
                            Gui.SavePng(this.matchTable.fHistFig,...
                                fullfile(epp.args.output_folder, ...
                                'epp_overlap_histogram.png'));
                        end
                        this.matchTable.doHistQF(visible);
                        if epp.args.save_output
                             Gui.SavePng(this.matchTable.qHistFig,...
                                fullfile(epp.args.output_folder, ...
                                'epp_similarity_histogram.png'));
                        end
                    end
                end
                listener=this.matchTable.listen(this.columnNames, this);
                this.matchTable.fncSelect=@matchTableSelect;
                if args.match_predictions
                    this.predictions=this.matchTable.seePredictionOfThese;
                    epp.setPredictionListener(this.predictions);
                end
            else % awkward evolutionary history of QF 
                 %   requires constructing gui element 
                 %   to save NON gui data about matching ...sigh
                this.matchTable=QfTable(this.match, clrs, [], ...
                    get(0, 'currentFig'), false);
                if ~isstruct(this.match)
                    this.matchTable.save(this.match, savedFile);
                end
            end
            if ~exist(this.matchedLabelFile, 'file')
                [eppLeafNames, eppLeafClrs]=...
                    this.match.getMatchingNamesAndColors(this.lblMap);
                save(matchedNamesClrsFile, 'eppLeafNames', 'eppLeafClrs');
                props=java.util.Properties;
                ids=this.match.sIds;
                N=length(ids);
                for i=1:N
                    id=num2str(ids(i)-(mx+1));
                    name=eppLeafNames{i};
                    clr=num2str(eppLeafClrs(i,:)*256);
                    props.setProperty(id, name);
                    props.setProperty([id '.color'], clr);
                end
                File.SaveProperties2(this.matchedLabelFile, props);
            end
            if args.qf_tree
                load(matchedNamesClrsFile, 'eppLeafNames', 'eppLeafClrs');
                if ~visible
                    [this.qfTree1Match, this.qfTree1]=run_QfTree(this.data,...
                        sLbls, {'EPP test set'}, 'trainingNames', ...
                        eppLeafNames, 'log10', true, 'colors', eppLeafClrs, ...
                        'pu', pu);
                else
                    [this.qfTree1Match, this.qfTree1]=run_QfTree(this.data,...
                        sLbls, {'EPP test set'}, 'trainingNames', ...
                        eppLeafNames, 'log10', true, 'colors', eppLeafClrs, ...
                        'pu', pu, 'locate_fig', ...
                        {epp.figHierarchyExplorer, 'south east+', true});
                end
                if epp.args.save_output
                    Gui.SavePng(this.qfTree2.fig,...
                        fullfile(epp.args.output_folder, ...
                        'qf_tree_test.png'));
                end
                if ~visible
                    [this.qfTree2Match, this.qfTree2]=run_QfTree(this.data, ...
                        tLbls, {'EPP training set'},  'trainingNames', ...
                        tNames, 'log10', true, 'colors', clrs, 'pu', pu);
                else
                    [this.qfTree2Match, this.qfTree2]=run_QfTree( ...
                        this.data, tLbls, {'EPP training set'}, ...
                        'trainingNames',  tNames, 'log10', true, ...
                        'colors', clrs,'pu', pu, ...
                        'locate_fig', {this.qfTree1.fig, 'east+', true});
                end
                if epp.args.save_output
                    Gui.SavePng(this.qfTree2.fig,...
                        fullfile(epp.args.output_folder, ...
                        'qf_tree_training.png'));
                end
            end
            if closePu
                pu.close;
            end
            jBtn=Gui.NewBtn('Browse sequence', @(h,e)browseEppLeaves(), ...
                'See EPP sequences in browser'); 
            sLbls=[];jdSlbls=[];
            
            function matchTableSelect(qf, isTeachers, qfIdxs)
                listener.select(qf, isTeachers, qfIdxs);
                [~, sLbls]=QfHiDM.GetNamesLbls(qf, isTeachers, qfIdxs);
                sLbls=sLbls(~isTeachers);
                if ~isempty(sLbls)
                    if ~isempty(jdSlbls)
                        jdSlbls.dispose;
                    end
                    jBtn.setText(sprintf(['<html><center><font color="blue">'...
                        '<b>See %s<br>(<i>in browser</i>)</b></font></center></html>'],...
                        String.Pluralize3('EPP sequence',length(sLbls))));
                    jdSlbls=msg(...
                        struct('msg', jBtn, 'javaWindow', ...
                        Gui.JWindow(listener.roiTableTest.getFigure)), ...
                        12, 'south east+', 'See EPP sequene?', 'none');
                    selectEppLeaves;
                end
            end
            
            function selectEppLeaves()
                N_=length(sLbls);
                if N_<1
                    return;
                end
                for j=1:N_
                    sLbl=sLbls(j)-(mx+1);
                    key=epp.getLeaf(sLbl);
                    if j>1 
                        epp.suhTree.ensureVisible(key, 2, j==N_);
                    else
                        epp.suhTree.ensureVisible(key, 1);
                    end
                end 
            end
            
            
            
            function browseEppLeaves()
                N_=length(sLbls);
                if N_<1
                    return;
                end
                keys=cell(1, N_);
                for j=1:N_
                    sLbl=sLbls(j)-(mx+1);
                    keys{j}=epp.getLeaf(sLbl);
                end
                epp.browseParents(keys);
                MatBasics.RunLater(@(h,e)focus(), 2);
                jdSlbls.dispose;
            end
            
            function focus
                figure(this.matchTable.fig);
                disp('re-focussed');
            end
        end
    end
end