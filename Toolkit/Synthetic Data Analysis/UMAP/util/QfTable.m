%   Class for Hi-D matching with merging of data subsets using 
%       QFmatch or F-measure or both 
%   This produces a visual table and histogram of dissimilarities and
%   overlaps between subset matches.
%
%   The function getAverages answers the question of overall goodness 
%   by returning the median/mean dissimilarity or overlap
%
%
%   QF Algorithm is described in 
%   https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6586874/
%   and
%   https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5818510/
%
%   Bioinformatics lead: Darya Orlova <dyorlova@gmail.com>
%   Software Developer: Stephen Meehan <swmeehan@stanford.edu> 
%
%   Provided by the Herzenberg Lab at Stanford University 
%   License: BSD 3 clause
%
classdef QfTable < handle
    properties
        contextDescription;
        context;
        fcnFpnSubsets;
        fncSelect;
        btns;
        btnLbls;
    end
    
    properties(SetAccess=private)
        fig;
        data;
        unmatched;
        matchesStr;
        sortTable;
        tb;
        qf;
        tClrs;
        priorFig;
        fHistFig;
        qHistFig;
        falsePosNegFig;
        confusionFig;
        otherFigs={};
        R;
        externalArgs;
        app;
        histResize;
        predictions;
        predictionsOfThese;
        predictionsTable;
        listener;
        cbSyncKld;
        cbStackedPredictions;
        cbFlashlight;
        similarityIdx;
        overlapIdx;
        idIdx;
        fncPredictionSelected;
        gt;
    end
    
    properties(Constant)
        PROP_OUTER_POS2='OuterPosition2_V2';
        DEBUG=false;
        FIG_NAME='Hi-D match';
        FIG_NAME_PRED='PredictionAdjudicator';
    end
    
    methods
        function this=QfTable(qf, tClrs, props, priorFig, ...
                visible, externalArgs, propSuffix, predictions)
            if nargin<8
                predictions=[];
                if nargin<7
                    propSuffix='';
                    if nargin<6
                        externalArgs=[];
                        if nargin<5
                            visible=true;
                            if nargin<4
                                priorFig=get(0, 'currentFig');
                                if nargin<3
                                    props=[];
                                end
                            end
                        end
                    end
                elseif ~startsWith(propSuffix, '.')
                    propSuffix=['.' propSuffix];
                end
            end
            
            this.predictions=predictions;
            isForPrediction=~isempty(predictions);
            if isempty(propSuffix)
                if isForPrediction
                    propSuffix='.PredictionsV2';
                end
            end
            if iscell(visible)
                locate_fig=visible;
                visible=true;
            else
                locate_fig={};
            end
            
            this.externalArgs=externalArgs;
            app=BasicMap.Global;
            this.app=app;
            if app.highDef
                this.histResize=.76;
            else
                this.histResize=.66;
            end
            if isempty(props)
                props=app;
            end
            this.tClrs=tClrs;
            this.qf=qf;
            PROP_COL_W=['qftColumnWidthsV2' propSuffix];
            PROP_COL_ORD=['qftColumnOrderV1' propSuffix];
            PROP_SORT=['qftRowOrderV1' propSuffix];
            path=BasicMap.Path;
            if isForPrediction
                tableName=QfTable.FIG_NAME_PRED;
            else
                tableName=QfTable.FIG_NAME;
            end

            if visible
                if ~isempty(priorFig) && isempty(locate_fig)
                    pu=PopUp(['Preparing ' tableName ' table'],...
                        'north west+',  'Note...', false, true, ...
                        Gui.GetResizedImageFile('orlova.png', ...
                        .25, BasicMap.Global));
                else
                    pu=[];
                end
            else
                pu=[];
            end
            this.priorFig=priorFig;
            [this.fig, tb_]=Gui.Figure;
            this.tb=tb_;
            figName=[tableName ' ' ...
                num2str(length(qf.tIds)) ' X ' num2str(length(qf.sIds))...
                ' subsets'];
            set(this.fig, 'CloseRequestFcn', @(h, e)hush(h), ...
                'Name', figName);
            [this.data, labels, fmts, tips,  this.unmatched, groupIdx, ...
                freqIdx, rankIdx, symIdx, this.matchesStr, numIdx,...
                nameIdx, matchesIdx, similarityIdx, overlapIdx, ...
                idIdx,szIdx]=QfTable.Contents(qf, tClrs, pu);
            this.similarityIdx=similarityIdx;
            this.overlapIdx=overlapIdx;
            this.idIdx=idIdx;
            if isForPrediction
                labels{groupIdx}='<html>Subset<br>type</html>';
                labels{similarityIdx}='<html>Similarity<br>to predicted</html>';
                fmts(groupIdx,:)=[9 nan];
                fmts(idIdx,:)=[8 nan];
                fmts(nameIdx,:)=[26 nan];
                this.adjustForPredictions(predictions, rankIdx,  groupIdx,...
                    similarityIdx, overlapIdx, idIdx, nameIdx, szIdx, matchesIdx);
            end
            this.R=size(this.data);
            [sData, widths]=SortTable.ToSortableAlignedHtml(this.data, fmts);
            this.sortTable=SortTable(this.fig, sData, ...
                labels, [], @(h,e)select(e), tips);
            st=this.sortTable;
            jt=st.jtable;
            st.setSelectionBar;
            if ismac
                st.uit.FontSize=13;
            end
            N=length(widths);
            for i=1:N
                if app.highDef
                    factor=app.toolBarFactor;
                else
                    factor=1;
                end
                st.setColumnWidth(i, widths(i)*factor)
                st.setColumnWidth(i, widths(i)*factor)
            end
            preSorted=SortTable.SetRowOrder(jt, ...
                BasicMap.GetNumbers(props, PROP_SORT));
            if ~preSorted
                if ~isForPrediction
                    jt.sortColumn(rankIdx-1, true, true);
                    jt.sortColumn(groupIdx-1, false, true);
                    jt.sortColumn(freqIdx-1, false, false);
                else
                    jt.sortColumn(nameIdx-1, true, true); %names
                    jt.sortColumn(groupIdx-1, false, false);
                    jt.sortColumn(freqIdx-1, false, false);
                end
            end
            ToolBarMethods.addButton(tb_, ...
                fullfile(path, 'world_16.png'), ...
                ['<html>See matches and histograms<br>'...
                '(if showing) in default browser</html>'], ...
                @(h,e)browse(this, qf.matrixHtml));
            startingRowOrder=SortTable.GetRowOrder(jt);
            bb=ToolBarMethods.addButton(tb_,fullfile(path, 'table.gif'), ...
                'Restore default row and column order', ...
                @(h,e)defaultOrder());
            ToolBarMethods.addButton(tb_,fullfile(path, 'leftArrowNarrow.png'), ...
                'Shift sorted columns to the left', ...
                @(h,e)shiftSortLeft());
            pnlCb=Gui.FlowLeftPanel(2,0);
                
            img=Html.ImgXy('pseudoBarHi.png', [], .819);
            if isForPrediction
                pnlCb.add(javax.swing.JLabel('  '));
                img2=Html.ImgXy('pinFlashlightTransparent.png', [], .92);
                prop4='qfTable.Flashlight';
                this.cbFlashlight=Gui.CheckBox(...
                    ['<html>' img2 '</html>'], ...
                    app.is(prop4, true), app, prop4, [], ...
                    ['<html>See selections highlighted '...
                    'in other plots.</html>']);
                pnlCb.add(this.cbFlashlight);
                pnlCb.add(javax.swing.JLabel('  '));
                prop1='qfTable.Sync1';
                prop4='qfTable.Sync4';
                this.cbStackedPredictions=Gui.CheckBox(...
                    Html.WrapSmallBold(['4 ' img], app), ...
                    app.is(prop4, true), ...
                    [], '', @(h,e)syncKld([], prop4), ...
                    ['<html>Keep seeing DimensionStacker ' img ...
                    'stacked with <br>4 prediction subsets for 1st '...
                    'selection in <u>this</u> table.</html>']);
                pnlCb.add(this.cbStackedPredictions);
                syncWord=['1 ' img];
                syncDflt=false;
                jt.removeColumn(jt.getColumn(labels{matchesIdx}))
                jt.removeColumn(jt.getColumn(labels{rankIdx}))
                groupIdx=5; 
                freqIdx=6; 
                symIdx=8;
                similarityIdx=3; 
                overlapIdx=4; 
                szIdx=7;
            else
                prop1='qfTable.SyncKld';
                syncWord=['Sync ' img];
                syncDflt=true;
            end
            syncDflt=app.is(prop1, syncDflt);

            this.cbSyncKld=Gui.CheckBox(...
                Html.WrapSmallBold(syncWord, app), ...
                syncDflt, [], '', @(h,e)syncKld(prop1, []), ...
                ['<html>Keep seeing DimensionExplorer ' img ...
                ' for 1st selection in <u>this</u> table</html>']);
            pnlCb.add(this.cbSyncKld);
            ToolBarMethods.addComponent(tb_, pnlCb);
            ToolBarMethods.addSeparator(tb_);
            savedOrder=BasicMap.GetNumbers(props, PROP_COL_ORD);
            if ~isempty(savedOrder)
                try
                    SortTable.SetColumnOrder(jt, savedOrder,...
                        BasicMap.GetNumbers(props, PROP_COL_W));
                catch
                end
            else
                defaultColumnOrder;
            end
            PROP_OUTER_POS=[QfTable.PROP_OUTER_POS2 propSuffix];
            op=BasicMap.GetNumbers(props, PROP_OUTER_POS);
            if length(op)==4
                newFigPos=Gui.RepositionOnSameScreenIfRequired(op);
                set(this.fig, 'OuterPosition', newFigPos);
                Gui.FitFigToScreen(this.fig);
            elseif ~isempty(priorFig)
                Gui.SetToRight(this.priorFig, this.fig, false, 80);
            end
            if visible
                if ~isempty(pu)
                    pu.close;
                end
                if ~isempty(locate_fig)
                    SuhWindow.Follow(this.fig, locate_fig);
                    SuhWindow.SetFigVisible(this.fig);
                else
                    Gui.SetFigVisible(this.fig);
                end
                drawnow;
                if isForPrediction
                    Gui.ShowBusy(this.fig, ...
                        Gui.YellowSmall('Prediction results<br>true+/false+/false-'),...
                        'wayneMoore2.png', .61, false, 'South', 2);
                else
                    Gui.ShowBusy(this.fig, ...
                        Gui.YellowSmall('Darya''s QFMatch results'),...
                        'orlova.png', .33, false, 'South', 2);
                end
            end
            if preSorted
                jt.unsort;
                SortTable.SetRowOrder(jt, ...
                    BasicMap.GetNumbers(props, PROP_SORT));
            elseif isempty(savedOrder)
                bb.doClick;
            end
            drawnow;
            rowHeight=floor(jt.getRowHeight*1.33);
            set(this.fig, 'ResizeFcn', @(h,e)resizeQft())
            MatBasics.DoLater(@(h,e)heighten(), .31);
            this.qf.tClrs=this.tClrs;
            if ~isForPrediction
                try
                    ToolBarMethods.addButton(tb_, fullfile(path, 'histQF.png'), ...
                        'See QFMatch histogram (mass+distance similarity)', ...
                        @(h,e)doHistQF(this));
                    ToolBarMethods.addButton(tb_, fullfile(path, 'histF.png'), ...
                        'See overlap histogram based on F-measure', ...
                        @(h,e)doHistF(this, true));
                    if isempty(this.qf.falsePosNegs)
                        this.qf.getFalsePosNegRecords;
                    end
                    if ~isempty(this.qf.falsePosNegs)
                        try
                            this.qf.getFalsePosNegsTab(false, externalArgs);
                        catch ex
                            %this.qf is a structure and not an instance
                            %so the 2 getFalse*() methods were called and
                            %results are stored in structure
                            if ~isstruct(this.qf)
                                ex.getReport
                            end
                        end
                        ToolBarMethods.addButton(tb_, ...
                            fullfile(path, 'plusMinus.png'), ...
                            'See false positive/negative info', ...
                            @(h,e)showPredictionOptions(this, h));
                        QfHiDM.ReadingsToolBarBtn(tb_, app);
                        html=QfHiDM.ConvertMatchesTex2Html(this.matchesStr);
                        ToolBarMethods.addComponent(tb_, ...
                            javax.swing.JLabel(html))                        
                    end    
                catch ex
                    if ~isstruct(this.qf)
                        ex.getReport
                    else
                        this.qf.falsePosNegs=[];
                    end
                end
            else
                b1='<font color="blue">';b2='</font>';
                [testSetWins, nPredicted, means]=this.getPredictionSummary;
                txt=sprintf('False + <i>MORE similar</i> in %s%d/%d%s cases', ...
                    b1, testSetWins, nPredicted, b2);
                tip=sprintf([...
                    'In %s%d/%d%s cases the <b>false +</b> data has ' ...
                    '<i>greater</i> mass + distance similarity to the '...
                    'whole predicted class than does the <b>false -</b>' ...
                    ' data</td></tr><tr><td>'...
                    '<b>false +</b> == assignments '...
                    'made <i>only</i> by the 2nd classifier.<br>' ...
                    '<b>false -</b> == assignments made <i>only</i> '...
                    'by the 1st classifier.'...
                    '</td></tr><tr><td>Mean mass + distance similarity '...
                    'of <b>true +</b> / <b>false  +</b> / <b>false -'...
                    '</> is  %s%3.1f%% / %3.1f%% / %3.1f%%%s'], ...
                    b1, testSetWins, nPredicted, b2, ...
                    b1, means(1), means(2), means(3), b2 );
                tip=Html.WrapTable(tip, 3, 5.3, '1', 'left', 'in', app);
                
                [~, jl]=Gui.ImageLabel(Html.WrapSmallBold(txt, app), ...
                    'smallGenie.png', tip, @describeMoreSimilar);
                ToolBarMethods.addComponent(tb_, jl);
            end
            
            function describeMoreSimilar(h,~)
                jw=Gui.WindowAncestor(h);
                msg(struct( 'javaWindow', jw,'msg', tip, ...
                    'icon', 'genieSearch.png'), ...
                    14, 'north east+', 'Possibly useful info...');
            end

            function syncKld(prop1, prop4)
                go1=false; go4=false;
                if ~isempty(prop1)
                    if this.cbSyncKld.isSelected
                        go1=true;
                        app.set(prop1, 'true');
                    else
                        app.set(prop1, 'false');
                    end
                end
                if ~isempty(prop4)
                    if this.cbStackedPredictions.isSelected
                        go4=true;
                        app.set(prop4, 'true');
                    else
                        app.set(prop4, 'false');
                    end
                end
                if go1 || go4                    
                    try
                        this.listener.reselect;
                    catch ex
                        ex.message
                    end
                end
            end

            function resizeQft()
                MatBasics.DoLater(@(h,e)budge(), .31);
                function budge
                    jt.setRowHeight(rowHeight);
                    drawnow;
                end
            end

            function heighten
                drawnow;
                jt.setRowHeight(rowHeight);
                try
                    if props.multiProps.is('mds_figHistF', false)
                        this.doHistF;
                    end
                    if props.multiProps.is('mds_figHistQF', false)
                        this.doHistQF(visible);
                    end
                catch ex
                    %disp('Using QF table outside of CytoGenie''s AutoGate')
                    %ex.getReport
                end
            end
            
            function shiftSortLeft()
                if ~SortTable.MoveSortColumnsLeft(jt)
                    if ismac
                        key='command';
                    else
                        key='control';
                    end
                    msg(Html.Wrap(['There is no sort order currently.'...
                        '<br>To sort the table you<ul>'...
                        '<li>Click on a column to sort it'...
                        '<li>Click again for descending order'...
                        '<li>Hold ' key ' key for multi column</ul>']), ...
                        8, 'north', 'No sort order...');
                else
                    r=jt.getSelectedRow;
                    if r<0
                        r=0;
                    end
                    rect=jt.getCellRect(r,0, true);
                    jt.scrollRectToVisible(rect);
                end
            end
            
            function defaultOrder()
                defaultRowOrder;
                defaultColumnOrder;
            end
            
            function defaultRowOrder
                if isForPrediction
                   %NOT -1 for groupidx and freqIdx since we removed 
                   % matches column for predictions
                    SortTable.SetRowOrder(jt, [(nameIdx-1) true 0; ...
                        groupIdx false 0; freqIdx false 1]);
                else
                    SortTable.SetRowOrder(jt, [(rankIdx-1) true 0; ...
                        (groupIdx-1) false 0; (freqIdx-1) false 1]);
                end
            end
            
            function defaultColumnOrder()
                idxs=1:jt.getColumnCount;
                if isForPrediction
                    eliminate=[nameIdx, overlapIdx, similarityIdx,...
                        numIdx,  symIdx, szIdx, freqIdx];
                    %+1 since we removed matches column for predictions
                    startWith=[nameIdx, similarityIdx+1, szIdx+1, ...
                        freqIdx+1, overlapIdx+1];
                else
                    startWith=[rankIdx symIdx];
                    eliminate=startWith;
                        
                end
                eliminate=sort(eliminate, 'descend');
                idxs(eliminate)=[];
                idxs=[startWith idxs]-1;
                SortTable.SetColumnOrder(jt, idxs, [], true);
            end
            
            
            function hush(h)
                try
                    [columnOrder, widths]=SortTable.GetColumnOrder(jt);
                    props.set(PROP_COL_ORD, num2str(columnOrder));
                    props.set(PROP_COL_W, num2str(widths));
                    rowOrder=SortTable.GetRowOrder(jt);
                    if ~isequal(rowOrder, startingRowOrder)
                        props.set(PROP_SORT, MatBasics.Encode(...
                            rowOrder));
                    end
                    if exist('PROP_OUTER_POS', 'var') %r2017a thread issue
                        props.set(PROP_OUTER_POS, ...
                            num2str(get(h, 'OuterPosition')));
                    end
                catch 
                end
                if ~isempty(this.priorFig) && ishandle(this.priorFig)
                    figure(this.priorFig);
                    Gui.CloseFigs(this.otherFigs);
                end
                delete(h);
            end
            
            function select(e)
                if e.getValueIsAdjusting || isempty(this.fncSelect)
                    return
                end
                colIdx=st.jtable.getSelectedColumn;
                rowIdxs=st.jtable.getSelectedRows;
                if ~isempty(rowIdxs)
                    try
                        colIdx=jt.convertColumnIndexToModel(colIdx);
                        if isempty(this.predictions)
                            st.showTip(colIdx+1);
                        end
                        N_=length(rowIdxs);
                        isTeachers=zeros(1,N_);
                        qfIdxs=zeros(1,N_);
                        for j=1:N_
                            rowIdx=rowIdxs(j);
                            rowIdx=jt.getActualRowAt(...
                                jt.convertRowIndexToModel(rowIdx))+1;
                            nTid=length(this.qf.tIds);
                            isTeachers(j)=rowIdx<=nTid;
                            if isTeachers(j)
                                qfIdxs(j)=rowIdx;
                            else
                                qfIdxs(j)=rowIdx-nTid;
                            end
                        end
                        try
                            try
                                feval(this.fncSelect, this.qf, ...
                                    isTeachers, qfIdxs);
                            catch ex
                                %backward compatability
                                feval(this.fncSelect, this.qf, ...
                                    isTeachers(1), qfIdxs(1));
                            end
                        catch ex
                            ex.getReport
                            if isTeachers(1)
                                name=this.qf.tNames{qfIdxs(1)};
                            else
                                name=this.qf.sNames{qfIdxs(1)};
                            end
                            fprintf('rowIdx=%d, teacher=%d, name="%s"\n',...);
                                rowIdx, isTeachers(1), name);
                        end
                    catch ex
                        ex.getReport
                    end
                    return;
                else
                    try
                        feval(this.fncSelect, this.qf, ...
                            [], []);
                    catch ex
                        ex.getReport
                    end

                end
                st.showTip(0);
            end
        end
        
        function t=getTableData(this)
            t=this.sortTable.getTableData(this.data);
        end

        function setPredictionListener(this,fnc)
            this.fncPredictionSelected=fnc;
        end
        
        function adjustForPredictions(this, predictions, rankIdx, plotIdx,...
                    similarityIdx, overlapIdx,  idIdx, nameIdx, szIdx, matchesIdx)
            R_=size(this.data);
            nT=predictions.nTeachers;
            sfxPre=[this.app.supStart '&nbsp;&nbsp;<b><i>Predicted</i></b>' this.app.supEnd '</html>'];
            sfxFn=['</font>' this.app.supStart ' <b>false <font color="red">-</font></b>' this.app.supEnd '</html>'];
            sfxFp=['</font>' this.app.supStart ' <b>false <font color="red">+</b></font>' this.app.supEnd '</html>'];
            sfxTp=['</font>' this.app.supStart ' <b>true +</b>' this.app.supEnd '</html>'];
            for i=1:nT
                this.data{i, plotIdx}='predicted';
                this.data{i, rankIdx}=nan;
                this.data{i, similarityIdx}=nan;
                this.data{i, overlapIdx}=nan;
                this.data{i, matchesIdx}=nan;
                name=this.data{i,nameIdx};
                this.data{i, nameIdx}=['<html><' ...
                    strrep(strrep(name, '<',''),'>','') ...
                    ' _>' name sfxPre];
            end
            nPredictions=R_-nT;
            if SuhPredictions.DEBUG
                assert(nPredictions==length(predictions.sNames));
            end
            predictions.compress;
            for i=1:nPredictions
                i2=nT+i;
                this.data{i2, rankIdx}=nan;
                name=this.data{i2, nameIdx};
                strId=this.data{i2, idIdx};
                id=str2double(strId);
                [similarity, overlap]=predictions.describe(id);
                this.data{i2, similarityIdx}=similarity;
                this.data{i2, overlapIdx}=overlap;
                if endsWith(strId, '.3')
                    word='false -';
                    name=['<html><' ...
                        strrep(strrep(name, '<',''),'>','') ...
                        ' >&nbsp;&nbsp;<font color="#B66666">' name(1:end-7) sfxFn];
                elseif endsWith(strId, '.2')
                    word='false +';
                    name=['<html><' ...
                        strrep(strrep(name, '<',''),'>','') ...
                        ' >&nbsp;&nbsp;<font color="#B66666">' name(1:end-7) sfxFp];
                else
                    word='true +';
                    name=['<html><' ...
                        strrep(strrep(name, '<',''),'>','') ...
                        ' >&nbsp;&nbsp;<font color="#66B666">' name(1:end-6) sfxTp];
                end
                this.data{i2, nameIdx}=name;
                this.data{i2, plotIdx}=word;
                this.data{i2, matchesIdx}=nan;
                if SuhPredictions.DEBUG
                    if endsWith(strId, '.3')
                        sizeExact=sum(predictions.negLbls==id);
                    else
                        sizeExact=sum(predictions.posLbls==id);
                    end
                    c=int32(2+(id-floor(id))*10);
                    r=predictions.sums(:,1)==floor(id);
                    assert(sizeExact==predictions.sums(r,c))
                    sizeRough=this.data{i2,szIdx};
                    similarityRough=this.data{i2,similarityIdx};
                    overlapRough=this.data{i2,overlapIdx};
                    if sizeExact ~= sizeRough
                        fprintf('"%s" size, from %d to %d\n', ...
                            predictions.sNames{i}, sizeRough, sizeExact)
                    end
                    if similarityRough ~= similarity
                        fprintf('"%s" size, from %d to %d\n', ...
                            predictions.sNames{i}, similarityRough, ...
                            similarity)
                    end
                    if overlapRough ~= overlap
                        fprintf('"%s" size, from %d to %d\n', ...
                            predictions.sNames{i}, overlapRough, ...
                            overlap)
                    end
                end
            end
            predictions.decompress;
        end
            
        function listener=listen(this, columnNames, ...
                trainingSet, testSet, trainingIds, testIds, ...
                trainingSetName, testSetName, parseFileNameOut)
            if nargin>4
                if nargin<9
                    parseFileNameOut=false;
                    if nargin<8
                        testSetName='';
                        if nargin<7
                            trainingSetName='';
                        end
                    end
                end
                listener=SuhMatchListener(this, columnNames, ...
                    trainingSet, testSet, trainingIds, testIds, ...
                    trainingSetName, testSetName, parseFileNameOut);
            else
                if nargin<4
                    listener=SuhMatchListener(this, ...
                        columnNames, trainingSet);
                else
                    listener=SuhMatchListener(this, columnNames, ...
                        trainingSet, testSet);
                end
            end
            this.fncSelect=@(qf,isTeachers, idxs)select(...
                listener, qf,isTeachers,idxs);
            if ~isempty(this.qf) 
                if ~isstruct(this.qf) || isfield(this.qf, 'columnNames')
                    if isempty(this.qf.columnNames)
                        this.qf.columnNames=columnNames;
                    end
                end
            end
            this.listener=listener;
        end
        
        function [medianSimilarity, meanSimilarity, ...
                medianOverlap, meanOverlap]=getAverages(this)
            [~,medianSimilarity, meanSimilarity]=this.getData(true);
            [~,medianOverlap, meanOverlap]=this.getData(false);
        end

        function matrix=getMatrix(this, columnIndex)
            if nargin<2
                columnIndex=this.similarityIdx;
            end
            try
                matrix=cell2mat(this.data(:, columnIndex));
            catch ex
                ex.getReport
                matrix=[];
            end
        end
        
        function [testSetWins, nPredicted, means, stddevs, mdns, results]...
                =getPredictionSummary(this)
            if this.isPredictions                
                similarities=this.getMatrix;
                similarities=similarities*100;
                N=length(similarities);
                results=nan(N,4);
                nPredicted=0;
                notPredictedIdxs=[];
                for i=1:N
                    strId=this.data(i,this.idIdx);
                    id=str2double(strId);
                    predictedId=floor(id);
                    idx=find(results(:,1)==predictedId,1);
                    if isempty(idx)
                        nPredicted=nPredicted+1;
                        idx=nPredicted;
                        results(idx,1)=predictedId;
                    end
                    if endsWith(strId, '.3')
                        results(idx, 4)=similarities(i);
                        if similarities(i)==100
                            notPredictedIdxs(end+1)=idx;
                        end
                    elseif endsWith(strId, '.2')
                        results(idx, 3)=similarities(i);
                    elseif endsWith(strId, '.1')
                        results(idx, 2)=similarities(i);
                    end
                end
                results=results(1:nPredicted,:);
                nums=results(:, 2:4);
                testSetWins=0;
                for i=1:nPredicted
                    %nums(i,:)
                    if isnan(nums(i,1)) && isnan(nums(i,2))
                        % no + prediction true or false then training set wins
                    elseif isnan(nums(i,2)) % if NO false+ but true+ 
                        if nums(i,1)>nums(i,3)%IF true+ more similar than false-?
                            testSetWins=testSetWins+1;
                        end
                    elseif isnan(nums(i,3)) % NO false- then true+ MUST equal training set
                        testSetWins=testSetWins+1;
                    elseif nums(i,2)>=nums(i,3) 
                        % false+ more similar to training set than false-
                        % or tied then the test set wins
                         testSetWins=testSetWins+1;
                    else %false- more similar than false+ training set wins
                    end
                end
                if ~isempty(notPredictedIdxs)
                    nums(notPredictedIdxs,:)=[];
                    %either the training subset had zero matches 
                    % or had another stronger training subset in the same match
                    % group that stole all the matches ...
                    % Hence on Nov 7,2021 I figured out a sharing agreement
                    nPredicted=nPredicted-length(notPredictedIdxs);
                end
            else
                testSetWins=[];
                nPredicted=0;
                nums=[];
                results=[];
            end
            if nargout>2
                nums(isnan(nums))=0;
                means=mean(nums);
                if nargout>3
                    stddevs=std(nums);
                    if nargout>4
                        mdns=median(nums);
                    end
                end
            end
        end
        
        
        function [matrix, mdn, mn]=getData(this, similarity)
            if nargin<2 || similarity
                columnIndex=this.similarityIdx;
            else
                columnIndex=this.overlapIdx;
            end
            matrix=cell2mat(this.data(:, columnIndex))*100;
            matrix=matrix(~isnan(matrix));
            if any(matrix<0)
                matrix=matrix(matrix>=0);
            end
            mdn=median(matrix);
            mn=mean(matrix);
        end
        
        function yes=isPredictions(this)
            yes=~isempty(this.predictions);
        end
        
        function predictionsOfThese=getPredictionsOfThese(this)
            if ~isempty(this.predictionsOfThese)
                predictionsOfThese=this.predictionsOfThese;
            else
                if isstruct(this.qf)
                    if isfield(this.qf, 'predictions')
                        predictionsOfThese=this.qf.predictions;
                        if ~isempty(predictionsOfThese)
                            predictionsOfThese.setMatch(this);
                        end
                    else
                        msg('Re-build the match to see predictions');
                        predictionsOfThese=[];
                    end
                else
                    predictionsOfThese=SuhPredictions(this);
                end
                this.predictionsOfThese=predictionsOfThese;
            end
            if ~isempty(this.fncPredictionSelected)
                this.predictionsOfThese.setSelectionListener(...
                    this.fncPredictionSelected);
            end
        end
        
        function [table, predictions]=seePredictionOfThese(this)
            predictions=this.getPredictionsOfThese;
            if ~isempty(predictions)
                try
                    table=predictions.showTable;
                catch ex
                    table=[];
                    predictions=[];
                    ex.getReport
                    msg(Html.WrapHr(['Re-run the matching ... '...
                        '<br>the current cache is <br>'...
                        'based on an old version!']));
                end
            else
                table=[];
            end
            this.predictionsTable=table;
        end
        
        function setPredictionsTable(this,table)
            this.predictionsTable=table;
        end

        function showPredictionOptions(this, h)
            jMenu=PopUp.Menu;
            Gui.NewMenuItem(jMenu, 'False positive/negative charts', ...
                @(h,e)browseFalsePosNeg(this));
            Gui.NewMenuItem(jMenu, 'Prediction detail table', ...
                @(h,e)seePredictionOfThese(this));
            Gui.NewMenuItem(jMenu, 'Confusion chart', ...
                @(h,e)confusionChart(this));
            jMenu.show(h, 15, 25);
        end

        function fig=confusionChart(this)
            try
                if ~Gui.IsVisible(this.confusionFig)
                    [~, this.confusionFig]=QfHiDM.ConfusionChart(this.qf);
                    n=this.fig.Name;
                    prfx=QfTable.FIG_NAME;
                    if startsWith(n, prfx)
                        n=['Confusion chart' n(length(prfx)+1:end)];
                    else
                        n='Confusion chart';
                    end
                    this.confusionFig.Name=n;
                    SuhWindow.Follow(this.confusionFig, this.fig, 'south east+', true);
                    if Gui.IsVisible(this.fig)
                        SuhWindow.SetFigVisible(this.confusionFig);
                    end
                else
                    figure(this.confusionFig);
                end
                fig=this.confusionFig;
            catch ex
                ex.getReport
            end
        end

        function browseFalsePosNeg(this)
            if ~isempty(this.falsePosNegFig) ...
                    && ishandle(this.falsePosNegFig)
                figure(this.falsePosNegFig);
                return;
            end
            set(0, 'CurrentFigure', this.fig);
            busy=Gui.ShowBusy(this.fig, ...
                Gui.YellowSmall('Finding false positives & negatives'),...
                'wayneMoore1.png', .65, false);
            if isempty(this.externalArgs)
                descripts={'cell type', 'cells'};
            else
                try
                    descripts=this.externalArgs.class_descriptions;
                catch
                    descripts='';
                end
            end
            if isempty(busy)
                locatingFig=[];
            else
                locatingFig={this.fig, 'north east+', true};
            end
            [fig_,that]=FalsePositiveNegative.Plot([0 1], ...
                this.qf.falsePosNegFile, [], 2, descripts, ...
                'sample', false, false, true, locatingFig);
            if ~isempty(busy)
                figure(fig_);
            end
            that.predictions=this.getPredictionsOfThese;
            that.fcnMoreHtml=@()getFalsePosNegMatrixHtml(this);
            this.falsePosNegFig=fig_;
            Gui.HideBusy(this.fig, busy, true);
        end
        
        
        function html=getFalsePosNegMatrixHtml(this)
            html=FalsePositiveNegative.MatrixHtml(this.qf);
        end

        function addToWebPage(this, fileName)
            visible=Gui.IsVisible(this.fig);
            this.doHistQF(visible);
            if this.qf.areEqual
                this.doHistF(visible);
            end
            this.browse('', false, false, fileName, true);
        end

        function browse(this, matrixHtml, browseNow, ...
                addHeader, fileName, accumulate)
            if nargin<6
                accumulate=false;
                if nargin<5
                    fileName='';
                    if nargin<4
                        browseNow=true;
                        if nargin<3
                            addHeader=true;
                        end
                    end
                end
            end
            fh=this.fHistFig;
            fpn=this.falsePosNegFig;
            cc=this.confusionFig;
            try
                %earlier versions lack areEqual field in struct
                if ~this.qf.areEqual
                    fh=[];
                    fpn=[];
                    cc=[];
                end
            catch
            end
            predTable=[];
            try %not sure about every scenario
                %predTable=this.seePredictionOfThese; % =if ALWAYS want predictions (not sure)
                predTable=this.predictionsTable;
                if ~isempty(predTable)
                    predTable=predTable.sortTable.jtable;
                end
            catch ex
                ex.getReport
            end
            set(0, 'CurrentFigure', this.fig);
            QfTable.ToHtml(...
                this.sortTable.jtable, ...
                fh, ...
                this.qHistFig,...
                fpn,...
                predTable,...
                cc,...
                this.app, ...
                Html.remove(matrixHtml),...
                addHeader, ...
                browseNow, ...
                fileName, ...
                accumulate);
        end
        
        function ok=doHistQF(this, visible)
            if nargin<2
                visible=true;
            end
            ok=true;
            if ishandle(this.qHistFig)
                if visible
                    figure(this.qHistFig);
                end
            else
                fig_=Gui.NewFigure(true, 'off');
                fig_.Color='white';
                this.qHistFig=fig_;
                Gui.Resize(fig_, this.histResize);
                ax=Gui.Axes(fig_);
                [qfData, avgMdn, avgMn]=this.getData;
                if isempty(qfData)
                    ok=false;
                    return;
                end                    
                histogram(ax, qfData, length(unique(qfData)));
                set(ax, 'units', 'normalized', 'Position', ...
                    [.1 .16 .8 .7]);
                Gui.StretchUpper(ax, @ylim, .1);
                Gui.StretchUpper(ax, @xlim, .1);
                xlabel(ax, '% mass+distance similarity', 'FontName', 'Arial')
                xlim(ax, [-5 105]);
                ylabel(ax, '# of subset matches', 'FontName', 'Arial')
                figName='Similarity ^{(mass+distance)}';
                this.addTitleToHist(fig_, ax, ...
                    figName, avgMdn, avgMn);
                this.addFalsePosNegButton(fig_);
                drawnow;
                if ~isempty(this.fHistFig) && ishandle(this.fHistFig)
                    where='west++';
                    followed=this.fHistFig;
                else                    
                	followed=this.fig;
                    where='south west++';
                end
                SuhWindow.Follow(this.qHistFig, followed, where, true);
                if visible
                    SuhWindow.SetFigVisible(fig_);
                end                
            end            
        end
        
        function addTitleToHist(this, fig, ax, score, avgMdn, avgMn)
            ttl=[score ', median/mean=\color{blue}' ...
                String.encodeRounded(avgMdn, 1) ...
                '\color{black}/\color{blue}'...
                String.encodeRounded(avgMn, 1) '\color{black}% '];
            set(fig, 'name', String.RemoveTex(score), 'NumberTitle', 'off');
            if ~isempty(this.matchesStr)
                title(ax, {ttl, this.matchesStr},  'FontName', 'Arial');
            elseif this.unmatched>0
                title(ax, {ttl, [ ...
                    num2str(this.R-this.unmatched) ' subsets matched, ' ...
                    '\color{red}' num2str(this.unmatched) ...
                    ' \color{black}NOT matched ']},'FontName', 'Arial');
            else
                title(ax, {ttl, [ ...
                    num2str(this.R) ' matches']}, ...
                    'FontName', 'Arial');
            end
        end
        
        function ok=doHistF(this, visible)
            ok=true;
            if nargin<3
                if nargin<2
                    visible=true;
                end
            end
            if ishandle(this.fHistFig)
                if visible
                    figure(this.fHistFig);
                end
            else
                fig_=Gui.NewFigure(true, 'off');
                fig_.Color='white';
                this.fHistFig=fig_;
                Gui.Resize(fig_, this.histResize);
                ax=Gui.Axes(fig_);
                [fData, avgMdn, avgMn]=this.getData(false);
                if isempty(fData)
                    ok=false;
                    return;
                end
                histogram(ax, fData, length(unique(fData)));
                
                xlabel(ax, '% overlap', 'FontName', 'Arial')
                xlim(ax, [-5 105]);
                ylabel(ax, '# of subset matches', 'FontName', 'Arial')
                set(ax, 'xlim', [0 100]);
                this.addTitleToHist(fig_, ax, ...
                    'Overlap ^{(F-measure)}', avgMdn, avgMn);
                set(ax, 'units', 'normalized', 'Position', ...
                    [.1 .16 .8 .7]);
                Gui.StretchUpper(ax, @ylim, .1);
                this.addFalsePosNegButton(fig_);
                drawnow;
                if ~isempty(this.qHistFig) && ishandle(this.qHistFig)
                    where='east++';
                    followed=this.qHistFig;
                else                    
                	followed=this.fig;
                    where='south++';
                end
                SuhWindow.Follow(this.fHistFig,followed, where, true);
                if visible
                    SuhWindow.SetFigVisible(fig_);
                end                
            end
        end
        
        function addFalsePosNegButton(this, fig_, lbl, width)
            if nargin<4
                width=.2;
                if nargin<3
                    lbl='See false +/-';
                end
            end
            if isempty(this.qf.falsePosNegs)
                return;
            end
            uicontrol(fig_, 'style', 'pushbutton','String', lbl,...
                'Units', 'normalized', ...
                'FontWeight', 'bold', ...
                'ForegroundColor', 'blue',...
                'BackgroundColor', [1 1 .80],...
                'Position',[1-(width+.01), .015, width, .071],...
                'Callback', @(btn,event) browseFalsePosNeg(this));
            uicontrol(fig_, 'style', 'pushbutton', ...
                        'String', 'Confusion chart',...
                        'Units', 'normalized', ...
                        'FontWeight', 'bold', ...
                        'ForegroundColor', 'blue',...
                        'BackgroundColor', [1 1 .80],...
                        'Position',[.03, .015, width*1.33, .071],...
                        'Callback', @(btn,event) confusionChart(this));
        end
        
        function QF=save(this, qf, file) 
            QF.tIds=qf.tIds;
            QF.sIds=qf.sIds;
            %QF.matches=qf.matches;
            %QF.getStudNames=qf.getStudNames();
            QF.tNames=qf.tNames;
            QF.tSizes=qf.tSizes;
            QF.sSizes=qf.sSizes;
            QF.matrixHtml=qf.matrixHtml;
            QF.qfTableData=this.data;
            QF.unmatched=this.unmatched;
            QF.matchesStr=this.matchesStr;
            QF.tClrs=this.tClrs;
            QF.areEqual=qf.areEqual;
            if qf.areEqual
                qf.computeConfusion;
            end
            QF.confusionMatrix=qf.confusionMatrix;
            QF.confusionLabels=qf.confusionLabels;
            QF.falsePosNegs=qf.falsePosNegs;
            qf.relocateFalsePosNegFiles(file, true);
            QF.falsePosNegFile=qf.falsePosNegFile;
            QF.falsePosNegSubsetsFile=qf.falsePosNegSubsetsFile;
            QF.falsePosNegCnts=qf.falsePosNegCnts;
            QF.falsePosCulprits=qf.falsePosCulprits;
            QF.falseNegCulprits=qf.falseNegCulprits;
            QF.sNames=qf.sNames;
            QF.matches=qf.matches;
            QF.columnNames=qf.columnNames;
            QF.densityBars=qf.densityBars;
            [QF.tUnmatched, QF.tN, QF.sUnmatched, QF.sN]=qf.getMatchCounts;
            if ~isempty(qf.falsePosEvents)
                QF.predictions=SuhPredictions(qf);
                QF.predictions.clearMatchObject;
            else
                QF.predictions=[];
            end
            if nargin>2 && ~isempty(file)
                QF.densityBars.app=[];%don't save the APP ... infinite loop
                save(file, 'QF');
                QF.densityBars.app=BasicMap.Global;
            end
        end
        
        function addSuffixToFigs(this, suffix)
            renameFig(this.fig);
            renameFig(this.qHistFig);
            renameFig(this.fHistFig);
            function renameFig(fig)
                if ~isempty(fig)
                    set(fig, 'name', [ get(fig, 'name') ' ' suffix])
                end
            end
        end
        
        function closeFigs(this)
            Gui.CloseFig(this.fig);
            Gui.CloseFig(this.qHistFig);
            Gui.CloseFig(this.fHistFig);
        end

        function [tUnmatched, tN, sUnmatched, sN, nMatchGroups]=getMatchCounts(this)
            try
            [tUnmatched, tN, sUnmatched, sN]=this.qf.getMatchCounts;
            catch
                tUnmatched=this.qf.tUnmatched;
                tN=this.qf.tN;
                sUnmatched=this.qf.sUnmatched;
                sN=this.qf.sN;    
            end
            nMatchGroups=length(this.qf.matches);
        end
        
        function [meanSimilarity, meanOverlap, missingSubsets, ...
                newSubsets, medianSimilarity, medianOverlap]...
                =getSummary(this)
            [~,medianSimilarity, meanSimilarity]=this.getData(true);
            [~,medianOverlap, meanOverlap]=this.getData(false);
            [missingSubsets, ~, newSubsets]=this.getMatchCounts; 
        end
        
        
        function rowIdxs=getRankSortedRowIndexs(this, rankings)
            if isempty(rankings)
                matchData=cell2mat(this.data(:, 3)); % column 3 is match
                rowIdxs=find(matchData==0);
                return;
            end
            rankData=cell2mat(this.data(:, 10)); % column 10 is rank
            l=ismember(rankData, rankings);
            
            [~,I]=sort(rankData(l));
            idxs=find(l);
            rowIdxs=idxs(I);
            %this.data(rowIdxs,10)'
        end
        
        function fields=getFields(this, rowIndex)
            fields=QfTable.RowToFields(this.data(rowIndex,:));
        end

        function associateGatingTree(this, gt)
            set(this.fig, 'UserData', this);
            this.gt=gt;
            gt.otherFigs{end+1}=this.fig;
        end
    end
    
    methods(Static)
        function fields=RowToFields(row)
            fields.rank=row{10};
            fields.name=row{2};
            fields.similarity=row{4};
            fields.overlap=row{5};
            fields.trainingSet=row{6};
            fields.frequency=row{7};
            fields.count=row{8};
            fields.id=row{11};
            fields.matches=row{3};
            fields.row=row{1};
            fields.symbol=row{9};
        end

        
        function QF=Load(file, complain, tData, tIdPerRow)
            QF=[];
            try
                if exist(file, 'file')
                    load(file, 'QF');
                    if ~isempty(QF)
                        if ~isfield(QF, 'densityBars')
                            QF.densityBars=[];
                        else
                            QF.densityBars.app=BasicMap.Global;
                        end
                        if nargin>2
                            QF.tData=tData;
                            if nargin>3
                                QF.tIdPerRow=tIdPerRow;
                            end
                            if ~isfield(QF, 'probability_bins')
                                QF.probability_bins=[];
                            end
                        end
                    end
                end    
            catch ex
                if nargin==1 || complain
                    ex.getReport
                end
            end
        end
        
        
        function [data, names, widths, tips, unmatched, plotIdx, freqIdx,...
                rankIdx, symIdx, matchesStr, numIdx, nameIdx, matchesIdx, ...
                similarityIdx, overlapIdx, idIdx, szIdx]=Contents(qf, clrs, pu)            
            numIdx=1;
            nameIdx=2;
            matchesIdx=3;
            similarityIdx=4;
            overlapIdx=5;
            plotIdx=6;
            freqIdx=7;
            szIdx=8;
            idIdx=11;
            widths=[3 0; 19 nan; 5 0; 4 -1; 4 -1; ...
                    7 nan; 3 -1;  6 0; 3 nan; 5 0; 6 nan];
            names={'#', ...
                'Subset (class) name', ...
                Html.WrapSm('Mat-<br>ches '), ...
                Html.WrapSm('Similarity<br>(QFMatch)'), ...
                Html.WrapSm('Overlap<br>(F-measure)'),...
                Html.WrapSm('Train-<br>ing set?'), ...
                Html.WrapSm('<br>Freq.'), ...
                Html.WrapSm('# of <br>events'), ...
                '<html><font size="6"><font  color="blue">&bull;</font></font></html>', ...
                Html.WrapSm('Rank'),...
                Html.WrapSm('Subset<br>ID')};
            rankIdx=length(names)-1;
            symIdx=rankIdx-1;
            tips={...
                'The subset''s item # ',...
                'The name of the subset including match name if applicable`',...
                'The number of subsets in this match set',...
                'High % is high mass+distance similarity',...
                'High % is high overlap of cells (or bins)',...
                'yes for training set, no for test set ',...
                'The frequency of the subset within this selection of cells/events',...
                'The # of cells/events for the subset ',...
                'The subset''s frequency-sized symbol',...
                'The ranking of the match set',...
                'Numeric identifier of subset (class)'};
            try
                [data, unmatched, matchesStr]=qf.getTableData(clrs);
            catch ex
                matchesStr='';
                if isstruct(qf)
                    data=qf.qfTableData;
                    unmatched=qf.unmatched;
                    if isfield(qf, 'matchesStr')
                        matchesStr=qf.matchesStr;
                    end
                else
                    data=[];
                    unmatched=0;
                    ex.getReport
                end
            end
            if size(data,2)==10 % subset ID needs adding
                tN=length(qf.tIds);
                for i=1:tN
                    data{i, 11}=num2str(qf.tIds(i));
                end
                sN=length(qf.sIds);
                for i=1:sN
                    data{tN+i, 11}=num2str(qf.sIds(i));
                end 
            end
            if exist('pu', 'var') && ~isempty(pu)
                if ~isempty(pu.pb)
                    pu.pb.setValue(N);
                end
            end
        end

        function qft=RunWithGt(pidSupervised, supervisors, fg, ...
                gid, fcs, fcsIdxs, data, file, embedding, visible, pu)
            qft=[];
            pFig=get(0, 'currentFig');
            gt=fg.gt;
            sameSample=isequal(gt.tp.getParentFileId(gid), ...
                    gt.tp.getParentFileId(pidSupervised));
            if exist(file, 'file') && ~QfTable.DEBUG
                if sameSample
                    [gtData, ~, ~, gtIds]=...
                        QfHiDM.GetRequiredData2(fcs, ...
                        fcsIdxs, fg.gt, gid, pu, visible);
                    qf=QfTable.Load(file,false,gtData,gtIds);
                else
                    qf=QfTable.Load(file);
                end
                if ~isempty(qf.columnNames)
                    qft=QfTable(qf, qf.tClrs, [], pFig, visible);
                    qft.fncSelect=@(qf, isTeacher, qfIdx)select(qf, isTeacher, qfIdx);
                    qft.doHistQF(visible);
                    if ~isempty(qft.qf.falsePosNegs)
                        qft.doHistF(visible);
                    end
                    [~, sLbls]=supervisors.getQfTrained(embedding);
                    return;
                end
            end
            if isempty(fcsIdxs)
                return;
            end
            newPu=nargin<10||isempty(pu);
            if newPu
                path=BasicMap.Path;
                pu=PopUp('Computing mass+distance similarity', 'north', ...
                    'Note...', false, true, fullfile(path, 'genieSearch.png'));
                pu.setTimeSpentTic(tic);
            else
                pu.setText2('Computing mass+distance similarity');
            end
            [gtData, ~, columnNames, gtIds]=QfHiDM.GetRequiredData2(fcs, fcsIdxs, ...
                gt, gid, pu, visible);
            gtData=fcs.ensureLogicle(gtData, fcsIdxs);
            %overlap collisions distort final resort
            gtIds=LabelBasics.RemoveOverlap(gtIds);
            if isempty(gtData)
                if ~isempty(pu)
                    pu.close;
                end
                return;
            end
            resizeSupervised=false; % get the predictions table!!
            if sameSample
                if ~isequal(size(data), size(gtData))
                    if sum(fg.clusterContext.pidSampleSelectedRows)...
                            ==size(data,1)
                        resizeSupervised=true;
                        data=gtData;
                    end
                end
            end
            if isequal(gtData, data)
                matchStrategy=2;
            else
                matchStrategy=1;
            end
            gids=MatBasics.GetUniqueIdsAndCntIfGt0(gtIds);
            N=length(gids);
            gtNames=cell(1,N);
            for i=1:N
                id=num2str(gids(i));
                gtNames{i}=gt.tp.getDescription(id);
            end
            [sNames, sLbls, clrs]=supervisors.getQfTrained(embedding);
            if resizeSupervised
                sLbls=MatBasics.ExpandIfPossible( ...
                        fg.clusterContext.pidSampleSelectedRows, sLbls);
            end
            qf=run_HiD_match(gtData, gtIds, data, sLbls, ...
                'trainingNames', gtNames, ...
                'testNames', sNames, ...
                'matchStrategy', matchStrategy, 'log10', true, 'pu', pu);
            [~,~,tIdxForS]=qf.getMatches;
            qf.setColumnNames(columnNames)
            gtClrs=zeros(N, 3);
            for i=1:N
                clrIdx=find(tIdxForS==i, 1, 'first');
                if clrIdx>0
                    gtClrs(i,:)=clrs(clrIdx,:);
                else
                    gid=gids(i);
                    gtClrs(i,:)=gt.highlighter.getColor(num2str(gid));
                end
            end
            if ~isempty(qf)
                qft=QfTable(qf, gtClrs, [], pFig, visible);
                qft.fncSelect=@(qf, isTeacher, qfIdx)select(qf, isTeacher, qfIdx);
                qft.doHistQF(visible);
                if matchStrategy==2
                    qft.doHistF(visible);
                end
                supervisors.annotateQfTable(qft, ...
                    matchStrategy, size(data,2));
                if ~isempty(file) && ~exist(file, 'file')
                    qft.save(qf, file);
                end
            end
            if newPu
                pu.close;
            end
            function select(qf, isTeacher, qfIdx)
                [name, lbl, tLbl, sLbl]=QfHiDM.GetIds2(qf, isTeacher, qfIdx);
                fprintf('teacher=%d, tId=%d, name="%s"\n',...
                    isTeacher, tLbl, name);
                if ~isempty(supervisors.btns)
                    supervisors.btns.get( find(supervisors.btnLbls==sLbl, 1)-1).doClick
                end
                if ~isempty(supervisors.args.parameter_names) && ...
                        supervisors.args.roi_table>=2
                    if isTeacher
                        d=gtData(gtIds==lbl,:);
                    else
                        d=data(sLbls==lbl,:);
                    end
                    try
                        needToMake=isempty(supervisors.roiTable) ...
                            || ~ishandle(supervisors.roiTable.table.table.fig);
                    catch
                        needToMake=true;
                    end
                    if needToMake
                        supervisors.roiTable=Kld.Table(d, ...
                            supervisors.args.parameter_names, ...
                            supervisors.args.roi_scales, qft.fig, name);
                        Gui.Locate(supervisors.roiTable.table.table.fig, ...
                            qft.fig, 'east++', true, true);
                    else
                        supervisors.roiTable.refresh(d, name);
                    end
                end
            end
        end
        function qft=Run(fcs, fcsIdxs, gt, gid1, gid2, file, visible, pu)
            pFig=get(0, 'currentFig');
            qft=[];
            if exist(file, 'file')
                qf=QfTable.Load(file);    
                qft=QfTable(qf, qf.tClrs, [], pFig, visible);
                qft.doHistQF(visible);
                return;
            end
            if isempty(fcsIdxs)
                return;
            end
            newPu=nargin<8|| isempty(pu);
            if newPu
                path=BasicMap.Path;
                pu=PopUp('Computing mass+distance similarity', 'north', ...
                    'Note...', false, true, fullfile(path, 'genieSearch.png'));
                pu.setTimeSpentTic(tic);
            else
                pu.setText2('Computing mass+distance similarity table');
            end
            [data1, ids1, names1, clrs1]=go(gid1);
            if isempty(data1)
                return;
            end
            [data2, ids2, names2]=go(gid2);
            if isempty(data2)
                return;
            end
            matchStrategy=1;
            qf=run_HiD_match(data1, ids1, data2, ids2, ...
                'trainingNames', names1, 'testNames', names2, ...
                'matchStrategy', matchStrategy, 'log10', true, ...
                'pu', pu);
            if ~isempty(qf)
                qft=QfTable(qf, clrs1, [], pFig, visible);
                qft.doHistQF(visible);
                if ~isempty(file) && ~exist(file, 'file')
                    qft.save(qf, file);
                end
            end
            if newPu
                pu.close;
            end
            
            function [gtData, gtIds, names, clrs]=go(gid)
                [gtData, ~, ~, gtIds]=QfHiDM.GetRequiredData2(fcs, ...
                    fcsIdxs, gt, gid, pu, visible);
                if isempty(gtData)
                    return;
                end
                gids=MatBasics.GetUniqueIdsAndCntIfGt0(gtIds);
                hghl=gt.highlighter;
                N=length(gids);
                clrs=zeros(N, 3);
                names=cell(1,N);
                for i=1:N
                    id=num2str(gids(i));
                    names{i}=gt.tp.getDescription(id);
                    clrs(i,:)=hghl.getColor(id, Gui.HslColor(i, N));
                end
            end
        end        
        
        function [selectedLbls, selectedBtns]=GetSelectedLabels(btns, btnLbls)
            selectedLbls=[];
            selectedBtns={};
            
            N=btns.size;
            for i=1:N
                btn=btns.get(i-1);
                if btn.isSelected
                    selectedLbls(end+1)=btnLbls(i);
                    selectedBtns{end+1}=btn;
                end
            end
        end
        
        
         function [html, fileName, accumulate]...
                =ToHtml(jtable, fHist, qfHist,...
                falsePos, predTable, confusion,...
                props, additionalFooter,...
                addHeader, browseNow, fileName,...
                accumulate)
             if nargin<12
                 accumulate=false;
                 if nargin<11
                     fileName='';
                     if nargin<10
                         browseNow=true;
                         if nargin<9
                             addHeader=true;
                             if nargin<8
                                 additionalFooter=[];
                                 if nargin<7
                                     props=BasicMap.Global;
                                 end
                             end
                         end
                     end
                 end
             end
            prop='QfTable.Html.File';
            prop2='QfTable.Html.Folder';
            html='';
            figHtml='';
            try
                tableTitle=char(Gui.WindowAncestor(jtable).getTitle);
                mainFigIsVisible=true;
            catch 
                tableTitle=get(gcf, 'Name');
                mainFigIsVisible=false;
            end
            if addHeader
                btn=Gui.NewBtn(Html.WrapSmallBold(...
                    'Specify an<br>HTML file'), ...
                    @(h,e)putFile(), 'Put results into a specific file', ...
                    'file_open.png');
                cb=Gui.CheckBox(Html.WrapSmallBold(...
                    'Add if<br>file preexists'),  ...
                    false, props, 'QfMatch.AddHtml', [], ...
                    'Accumulate results of many matches in one html file');
                prop3='QfTable.Html.Title';
                props.set(prop3, tableTitle);
                [h1Header, cancelled]=inputDlg(...
                    struct('property', prop3,...
                    'properties', props, 'msg', ...
                    Gui.BorderPanel([], 2, 3, ...
                    'South', ['<html><hr><br>Enter a title for '...
                    'these match results...</html>'], ...
                    'West', btn, 'East', cb),...
                    'where', 'west'), 'Seeing match results in browser...', ...
                    'Describe this Hi-D match results');
                if cancelled
                    return;
                end
                accumulate=cb.isSelected;
                h1Header=['<hr><h2>' h1Header '</h2>'];
            else
                h1Header=['<hr><h2>' tableTitle '</h2>'];
            end
            if browseNow
                pu=PopUp('Generating webpage...');
            end
            html=SortTable.ToHtml(jtable);
            if ~isempty(predTable)
                if ~mainFigIsVisible || ~isempty(Gui.WindowAncestor(predTable))
                    %is table showing?
                    html=[html '<hr>' SortTable.ToHtml(predTable)];
                end
            end
            if isempty(fileName)
                fldr=tempdir;
            else
                fileName=File.ExpandHomeSymbol(fileName);
                fldr=fileparts(fileName);
                if isempty(fldr)
                    fldr=tempdir;
                end
            end
            if ~exist(fldr, 'dir')
                File.mkDir(fldr);
            end
            if ~isempty(fHist) ...
                    || ~isempty(qfHist) ...
                    || ~isempty(falsePos)
                histCount=0;
                figHtml=[figHtml ...
                    '<table border="0"><tr><td>'];
                figFile(fHist, 'F-Measure', .65);
                figFile(qfHist, 'QFMatch', .65);
                figHtml=[figHtml '</td></tr></table>'];
                if isempty(falsePos)
                    html=['<table border="1"><tr><td '...
                        'colspan="2" align="center">' ...
                        h1Header '</td></tr>'...
                        '<tr><td valign="top">'...
                        figHtml '</td><td valign="top" '...
                        'rowspan="2">' html '</td></tr>'...
                        '<tr><td valign="bottom">'...
                        '<center><small>(repeat of above '...
                        'histograms<br>for scrolling conv'...
                        'enience)</small></center>' figHtml ...
                        '</td></tr></table>' additionalFooter];
                else
                    img1=figHtml;
                    figHtml='';
                    figFile(falsePos, 'False +/-', .5);
                    html=['<table border="1"><tr><td '...
                        'colspan="2" align="center">' ...
                        h1Header '</td></tr>'...
                        '<tr><td valign="top">'...
                        img1 '</td><td valign="top" '...
                        'rowspan="2">' html '</td></tr>'...
                        '<tr><td valign="bottom">'...
                        '<center><small>False positive and'...
                        '<br>false negative)</small></center>' figHtml ...
                        '</td></tr></table>' ];
                end
            else
                html=[h1Header html ];
            end
            if ~isempty(confusion)
                figHtml='';
                figFile(confusion, 'confusion',.97);
                html=[html '' figHtml];
            end
            if ~isempty(additionalFooter)
                html=[html additionalFooter];
            end
            img1=Html.Img('epp.png', [], .10, true);
            img2=Html.Img('epp.png', [], .10, false);
            html=strrep(html, img2, img1);
            if isempty(fileName)
                if accumulate
                    fileName=props.get(prop);
                end
                if isempty(fileName)
                    fileName=File.SaveTempHtml(html);
                end
            end
            if accumulate
                if File.ExistsFile(fileName)
                    priorHtml=File.ReadTextFile(fileName);
                    html=[Html.remove(priorHtml) ...
                        html];
                end
            end
            File.SaveTextFile(fileName, ...
                ['<html>' html '</html>']);
            props.set(prop, fileName);
            props.set(prop2, fileparts(fileName));
            if browseNow
                web( fileName, '-browser');
                pu.close;
            end


            function putFile()
                defaultName=File.Time('QFMatch', 'html');
                [fldr2, file2]=uiPutFile(File.Documents, ...
                    defaultName, props, prop2,...
                    'Specify an HTML file....');
                if ~isempty(fldr2)
                    fileName=fullfile(fldr2, file2);
                end
            end
            
            function figFile(fig, filePrefix, scale)
                if ~isempty(fig) && (~mainFigIsVisible ...
                        || Gui.IsVisible(fig))
                    if isempty(fileName)
                        f='';
                    else
                        [~, f]=fileparts(fileName);
                        f=[f '_'];
                    end
                    histCount=histCount+1;
                    if histCount==2
                        br='</td></tr><tr><td>';
                    else
                        br='';
                    end
                    file=File.Time([f filePrefix], 'png');
                    saveas(fig, fullfile(fldr, file));
                    figHtml=[figHtml br Html.ImgXy(...
                        file, fldr, scale, true)];
                end
            end
        end
    end
end
