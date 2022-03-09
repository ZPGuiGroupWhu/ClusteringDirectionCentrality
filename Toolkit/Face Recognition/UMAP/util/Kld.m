classdef Kld<handle
%   AUTHORSHIP
%   Primary Developer: Stephen Meehan <swmeehan@stanford.edu> 
%   Math Lead & Secondary Developer:  Connor Meehan <connor.gw.meehan@gmail.com>
%   Bioinformatics Lead:  Wayne Moore <wmoore@stanford.edu>
%   Provided by the Herzenberg Lab at Stanford University 
%   License: BSD 3 clause
%
    properties(SetAccess=private)
        app;
        table;
        normalizingScales;
        columnNames;
        pendingData;
        recentData;
        recentRowIdxs;
        dataName;
        R;
        propertySuffix;
        needsRefresh=false;
        plotRows=1;
        plotCols=1;
        plotPanel;
        btnSeePlot;
        recentHighlighted;
        recentHighlightedName;
        densityBars;
    end
    
    properties(GetAccess=private)
        warnIfBig=true;
        ax;
        selectedRows;
        plottedRows;
        lastSingleSelection;
    end
    
    properties(Constant)
        COL_INPUT_COLUMN_NUM=1;
        COL_INPUT_COLUMN_NAME=2;
        COL_DISTRIBUTION=3;
        COL_KLD=4;
        COL_MEAN=5;
        COL_STD=6;
        COL_MDN=7;
        COL_MAD=8;
        COL_MIN=9;
        COL_MAX=10;
        UPDATING_COLS=3:Kld.COL_MAX;
    end
    
    methods
        function setDensityBars(this, densityBars)
            this.densityBars=densityBars;
        end
        
        function setExtraScreenCapture(this, fig)
            this.table.setParentFig(fig);
        end
        
        function ok=refresh(this, data, name, rowIdxs)
            if nargin<3
                name='';
            end
            if this.warnIfBig
                bigPu=Gui.WarnIfBig(size(data));
            else
                bigPu=[];
            end
            this.pendingData=data;
            this.recentData=data;
            if nargin>3
                this.recentRowIdxs=rowIdxs;
            end
            this.dataName=name;
            this.needsRefresh=true;
            this.table.notifyRefresh;
            if ~isempty(this.plotPanel)
                this.refreshPlotForSelected;
            end
            Gui.ClosePopUp(bigPu);
        end
        
        function ok=isValid(this)
            ok=isvalid(this.table.table.uit);
        end
        
        function initPlots(this, rows, cols)
            if nargin<2
                rows=1;
                cols=1;
            end
            this.plotRows=rows;
            this.plotCols=cols;
            if ~isempty(this.plotPanel)
                delete(this.plotPanel);
            end
            set(this.table.table.uit, 'pos', [.02 .50 .96 .49]);
            if this.plotCols==1 && this.plotRows==1
                this.plotPanel=uipanel('Parent', this.getFigure, ...
                    'position', [.29 .07 .42 .42]);
            else
                this.plotPanel=uipanel('Parent', this.getFigure, ...
                    'position', [.02 .07 .96 .42]);
                this.btnSeePlot.setVisible(false);
            end
            this.showPlotHelp;
        end
        
        function ax=getAxes(this, which)
            if nargin<2
                which=1;
            end
            if isempty(this.plotPanel)
                this.initAxes(1, which);
            end
            if this.plotRows>1||this.plotCols>1
                this.ax=subplot(this.plotRows, this.plotCols, which, ...
                    'Parent', this.plotPanel);
            elseif isempty(this.ax) || ~isvalid(this.ax)
                this.ax=Gui.Axes(this.getFigure);
                set(this.ax, 'Parent', this.plotPanel);
            end
            ax=this.ax;
        end
        
        function fig=getFigure(this)
            fig=this.table.table.fig;
        end        
        
        function setHighlights(this, data, name)
            this.recentHighlighted=data;
            this.recentHighlightedName=name;
        end
        
        function refreshPlotForSelected(this, expecting)
            if length(this.selectedRows)==2
                if nargin>1 
                    if ~isequal(expecting, this.selectedRows)
                        return;
                    end
                    if isequal(this.selectedRows, this.plottedRows)
                       return; 
                    end
                end
                if isempty(this.lastSingleSelection) ...
                        || this.lastSingleSelection(1)==this.selectedRows(1)
                    X=this.selectedRows(2);
                    Y=this.selectedRows(1);
                else
                    X=this.selectedRows(1);
                    Y=this.selectedRows(2);
                end
                ax_=this.getAxes(this.plotCols);
                showPolygon(this.recentData, X, Y, ...
                    [], ax_, this.columnNames);
                this.plottedRows=this.selectedRows;
                if ~isempty(this.recentHighlighted)
                    highlighted=this.recentHighlighted(:, [X Y]);
                    Gui.Flash(ax_, highlighted, this.recentHighlightedName);
                end
            elseif nargin==1 || isempty(expecting) % no expectations
                this.showPlotHelp;
                this.plottedRows=[];
            end
        end
    end
    
    methods(Access=private)
        function rowSelection(this, vrs, mrs)
            N=length(mrs);
            this.selectedRows=mrs;
            for i=1:N
                fprintf('Selected row# %d %s\n', vrs(i),...
                    this.columnNames{mrs(i)});
            end
            if N==1
                this.lastSingleSelection=mrs(1);
            end
            if ~isempty(this.plotPanel)
                if N==2
                    MatBasics.RunLater(...
                        @(h,e)refreshPlotForSelected(this, mrs), ...
                        .33);
                else
                    this.showPlotHelp;
                    this.plottedRows=[];
                end
            end
        end
        
        function showPlotHelp(this)
            ax_=this.getAxes(this.plotCols);
            cla(ax_, 'reset')
            xticklabels(ax_, []);
            yticklabels(ax_, []);
            H=text(.5, .5, {'Pick the Y axis \it\bffollowed \rm\itby X\rm', ...
                'axis in the table above to see',...
                ['a \color{blue}colored \color[rgb]{0 .6 .6}\bf'...
                'X/Y\color[rgb]{.7 .7 0} plot\color{red} \rmhere...']},...
                'parent', ax_, ...
                'HorizontalAlignment', 'center', ...
                'VerticalAlignment', 'middle');
            if this.app.highDef
                set(H, 'FontSize', 8);
            end
            title(ax_, 'X/Y plot needs 2 selections...');
        end
        function [data, names]=captureData(this, initializing)
            if nargin>1 && initializing
                data=[1 2];
                names={'1','2'};
                return;
            end
            try
                if sum(this.recentRowIdxs)==size(this.recentData,1)
                    ri=find(this.recentRowIdxs);
                    if size(ri,2)==1
                        data=[ri this.recentData];
                    else
                        data=[ri' this.recentData];
                    end
                    names=['Record #', this.columnNames];
                else
                    data=this.recentData;
                    names=this.columnNames;
                end
            catch ex
                ex.getReport
            end
        end
        
        function refreshCallback(this)
            if ~isempty(this.pendingData) || this.needsRefresh
                %this.table.setData(this.getData(this.pendingData));
                this.table.updateData(this.getData(this.pendingData), ...
                    Kld.UPDATING_COLS, false);
                this.table.setSizeInfo(size(this.pendingData), this.dataName);
                this.pendingData=[];
            end
        end

        function this=Kld(data, normalizingScales, columnNames,...
                columnNamesDescriptor, name, args, densityBars)
            this.app=BasicMap.Global;
            args=[args Kld.ColumnLabels(columnNamesDescriptor)];
            args{end+1}='object_name';
            args{end+1}='umapRoi';
            args{end+1}='refresh_callback';
            args{end+1}=@(obj)refreshCallback(this);
            args{end+1}='selection_background';
            args{end+1}=[.959 1 .731];
            args{end+1}='selection_foreground';
            args{end+1}=[.15, .21, .81];
            args{end+1}='capture_data_callback';
            args{end+1}=@(picker, initializing)captureData(this, initializing);
            args{end+1}='selection_callback';
            args{end+1}=@(table, vrs, mrs, ids)rowSelection(this, vrs, mrs);
            sz=size(data);
            this.normalizingScales=normalizingScales;
            if isempty(columnNames) %fabricate them
                C=sz(2);
                columnNames=cell(1,C);
                for i=1:C
                    columnNames{i}=['column ' num2str(i)];
                end
            end
            this.columnNames=columnNames;
            if nargin>6
                this.densityBars=densityBars;
            end
            this.table=TablePicker(this.getData(data), args{:});   
            this.table.setSizeInfo(size(data), name);
            this.recentData=data;
            this.recentRowIdxs=true(1,size(this.recentData,1));
        end
        
        function tableData=getData(this, data)
            badData=false;
            try
                [means, stds, medians, mads, mins, maxs, klds, bars]=...
                    Kld.Compute(data, this.normalizingScales, this.densityBars);
            catch ex
                ex.getReport;
                badData=true;
            end
            [dataRows, tableRows]=size(data); %input data colums are GUI table rows;
            tableData=cell(tableRows, Kld.COL_MAX);
            for r=1:tableRows
                tableData{r, Kld.COL_INPUT_COLUMN_NUM}=r;
                tableData{r, Kld.COL_INPUT_COLUMN_NAME}=this.columnNames{r};
                if badData
                    tableData{r, Kld.COL_DISTRIBUTION}='No data';                
                    tableData{r, Kld.COL_KLD}=nan;
                    tableData{r, Kld.COL_MEAN}=nan;
                    tableData{r, Kld.COL_STD}=nan;
                    tableData{r, Kld.COL_MDN}=nan;
                    tableData{r, Kld.COL_MAD}=nan;
                    tableData{r, Kld.COL_MIN}=nan;
                    tableData{r, Kld.COL_MAX}=nan;
                else
                    tableData{r, Kld.COL_DISTRIBUTION}=...
                        ['<html>' bars{r} '</html>'];
                    tableData{r, Kld.COL_KLD}=klds(r);
                    tableData{r, Kld.COL_MEAN}=means(r);
                    tableData{r, Kld.COL_STD}=stds(r);
                    tableData{r, Kld.COL_MDN}=medians(r);
                    tableData{r, Kld.COL_MAD}=mads(r);
                    tableData{r, Kld.COL_MIN}=mins(r);
                    tableData{r, Kld.COL_MAX}=maxs(r);
                end
            end
            this.R=dataRows;
        end
    end
    
    methods(Static, Access=private)
        function args=ColumnLabels(columnNameDescriptor)
            tips={...
                'position of column in dataset',...
                'header/descriptor of dimension', ...
                'density distribution of normalized <br>data for this dimension', ...
                'Kullback-Leibler Divergence,<br>1 is <b>informative</b> and 0 is <b>normal distribution</b>',...
                'conventional mean statistic', ...
                'conventional standard deviation statistic', ...
                'conventional median statistic', ...
                'median of absolute deviation from median', ...
                'lowest value found (not bottom of scale)', ...
                'highest value found (not top of scale)'};
            fmts=[4 0; 15 nan; 24 nan; ...
                7 2;  7 2; 7 2; 7 2; 7 2; 7 2; 7 2];
            labels={...
                '<html>Column<br>#</html>',...
                columnNameDescriptor,...
                '<html>Normalized data<br>distribution</html>',...
                '<html>KLD (&lt;<br>is&lt;info)</html>', ...
                '<html>Mean</html>', ...
                '<html>Standard<br>deviation.</html>', ...
                '<html>Median</html>', ...
                '<html>Median abs.<br>deviation.</html>', ...
                '<html>Minimum<br>value</html>', ...
                '<html>Maximum<br>value</html>'};
            args={...
                'column_labels', labels, ...
                'row_identifier_column', Kld.COL_INPUT_COLUMN_NUM,...
                'describe_columns', Kld.COL_INPUT_COLUMN_NAME,...
                'formats', fmts, ...
                'tips', tips, ...
                'max_selections', -1};
        end
    end
    
    methods(Static)
        function this=Table(data, columnNames,normalizingScales, ...
                parentFig, name, where, columnNamesDescriptor,  ...
                propertySuffix, modal, pickFnc, visible, ...
                warnIfBig, densityBars)
            if nargin<13
                densityBars=[];
                if nargin<12
                    warnIfBig=true;
                    if nargin<11
                        visible=true;
                        if nargin<10
                            pickFnc=[];%likely for EPP, UMAP and MDS
                            if nargin<9
                                modal=false;
                                if nargin<8
                                    propertySuffix='UMAP';
                                    if nargin<7
                                        columnNamesDescriptor='Dimension';
                                        if nargin<6
                                            where='south++';
                                            if nargin<5
                                                name='';
                                                if nargin<4
                                                    parentFig=[];
                                                    if nargin<3
                                                        normalizingScales=[];
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            if iscell(visible) && length(visible)==3 %locate_fig cell
                locate_fig=visible;
                visible=true;
            else
                locate_fig={};
            end
            prop=['Kld.' propertySuffix '.V25'];
            if warnIfBig
                bigPu=Gui.WarnIfBig(size(data));
            else
                bigPu=[];
            end
            try
                btn=Gui.ImageButton('pickGate.png', ...
                    'See X/Y plot for selections', @(h,e)showXyPlots());
                this=Kld(data, normalizingScales, columnNames,...
                    columnNamesDescriptor, name, {...
                    'visible', visible,...
                    'where', where,...
                    'modal', modal,...
                    'pick_callback', pickFnc,...
                    'property', prop,...
                    'default_row_order', [2 0 0],...
                    'toolbar_component', btn, ...
                    'locate_fig', locate_fig,...
                    'fig_name', [propertySuffix ' ' ...
                    columnNamesDescriptor 'Explorer']...
                    }, densityBars);
                this.btnSeePlot=btn;
                this.warnIfBig=warnIfBig;
            catch ex
                ex.getReport
                this=[];
                Gui.ClosePopUp(bigPu);
                return;
            end
            if ~isempty(parentFig) && ishandle(parentFig)
                this.setExtraScreenCapture(parentFig);
            end
            this.propertySuffix=propertySuffix;
            Gui.ClosePopUp(bigPu);
            function showXyPlots
                this.initPlots;
                this.refreshPlotForSelected;
            end
        end
        
        function [means, stds, medians, mads, mins, maxs, klds, bars]...
                =Compute(data, normalizingScales, densityBars)
            means=mean(data, 1);
            stds=std(data, 0, 1);
            medians=median(data, 1);
            mads=mad(data, 1, 1);
            mins=min(data, [],1);
            maxs=max(data, [],1);
            if nargin>1 && ~isempty(normalizingScales)
                [~, C]=size(normalizingScales);
                if C ~= 3
                    error('scales are %dx%d, expecting 3 columns for [idx min max]');
                end
                idxs=normalizingScales(:,1);
                mn=normalizingScales(:,2)';
                mx=normalizingScales(:,3)';
                data(:,idxs)=(data(:,idxs)-mn)./mx;
            end
            klds=Kld.ComputeNormalizedVectorized(data, false, 256);
            if nargout>7
                if nargin>2 && ~isempty(densityBars)
                    bars=densityBars.go(data);
                    %bars=MatBasics.Density1DQuickAndDirty(data);
                else
                    bars=MatBasics.Density1DQuickAndDirty(data);
                end
            end
        end
        
         function weight=Weigh(data, M, mn, mx)
            if nargin<4
                M=256;
                if nargin < 3
                    mx=max(data(:));
                    if nargin < 2
                        mn=min(data(:));
                    end
                end
            end
            weight=Kld.Weight(data,M,mn,mx,false)';
         end
        
        function [floorIdxs4Data, delta]=GetIdxs(data, M, mn, mx)
            delta=1/(M-1)*(mx-mn);
            floorIdxs4Data=floor((data-mn)/delta) + 1;
            floorIdxs4Data(floorIdxs4Data==M)=M-1;%this avoids going over grid boundary
        end
        
        function [weights, floorIdxs4Data, delta]=Weight(data, M, mn,mx, hasOffScale, fg)
            [floorIdxs4Data, delta]=Kld.GetIdxs(data, M, mn, mx);
            [R, C]=size(data);
            data4Idxs=linspace(mn, mx, M);
            deltaMat=repmat(delta,R,C);
            weights=zeros(M, C);
            shape=[M 1];
            for i=0:1  
                idxs=floorIdxs4Data+repmat(i,R,C);
                if hasOffScale
                    if any(idxs(:)>M)
                        idxs(idxs>M)=M;
                    end
                end
                if C==1
                    curIdxs4Data=data4Idxs(idxs)';
                else
                    curIdxs4Data=data4Idxs(idxs);
                end
                W=1-(abs(data-curIdxs4Data)./deltaMat);
                for j=1:C
                    weights(:,j)=weights(:,j)+accumarray(idxs(:,j),W(:,j),shape);
                end
            end
            %Debug.TestDensity1D(fg, 'CD48', data, floorIdxs4Data, weights)
        end
        
        function [KLDs, normals]=ComputeNormalizedVectorized(...
                data, doExponential, M)
            if nargin<3
                M=256;
                if nargin<2
                    doExponential=false;
                end
            end
            mx=max(data(:));
            mn=min(data(:));
            if mn>0 
                mn=0;
            end
            if mx<1
                mx=1;
            end
            [KLDs, normals]=Kld.ComputeNVectorized(...
                Kld.Weigh(data, M, mn, mx)', doExponential);
        end
        
        function [KLD, probabilityDensities]=ComputeNVectorized(...
                weights, doExponential)
            Wtotal=sum(weights);
            [N, C]=size(weights);
            r=zeros(N,C);
            for c=1:C
                r(:,c)=1:N;
            end
            mu=sum(weights.*r)./Wtotal;
            varX = sum(((r - mu).^2) .* weights)./Wtotal;
            sigma=sqrt(varX);
            nz=weights>0;
            KLD=zeros(1,C);
            probabilityDensities=cell(1,C);
            for c=1:C
                nz_=nz(:,c);
                if doExponential
                    Q=exppdf(r(nz_,c),mu(c));
                else
                    Q=normpdf(r(nz_,c),mu(c),sigma(c));
                end
                P=weights(nz_,c)./Wtotal(c);
                if any(Q==0)
                    Q=Q(Q~=0);
                    P=P(Q~=0);
                end
                KLD(c)=sum(P.*((log(P))-(log(Q/sum(Q))))) ;
                probabilityDensities{c}=Q;
            end
        end
        
        
        
        function tip=Tip(widthPixels)
            if nargin<1
                widthPixels=250;
            end
            if BasicMap.Global.highDef
                widthPixels=widthPixels*1.3;
            end
            tip=['<table cellpadding="8" width="' num2str(widthPixels) ...
                'px"><tr><td><u><b>Kullback-Leibler divergence</b></u> '...
                '(<font color="blue"><b>KLD</b></font>) measures '...
                'informativeness.<ul><li>Higher indicates the data '...
                'has<br>more informative structure. <li>ZERO '...
                'indicates the data resembles<br>the normal '...
                'distribution</ul></td></tr></table>'];
        end
    end
end