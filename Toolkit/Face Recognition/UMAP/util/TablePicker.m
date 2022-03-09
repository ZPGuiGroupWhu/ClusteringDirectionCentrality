%   AUTHORSHIP
%   Primary Developer: Stephen Meehan <swmeehan@stanford.edu> 
%   Math Lead & Secondary Developer:  Connor Meehan <connor.gw.meehan@gmail.com>
%   Bioinformatics Lead:  Wayne Moore <wmoore@stanford.edu>
%   Provided by the Herzenberg Lab at Stanford University 
%   License: BSD 3 clause
%
classdef TablePicker <handle
    properties(Constant)
        DEBUG=true;
    end
    
    properties(SetAccess=private)
        table;
        T;
        J; %the jtable
        unfilteredJ;% no row iding
        columnLabels;
        rowIdentifiers;
        originalData;
        R;
        C;
        args;
        argued;
        mrById;
        ric;
        tb;
        tb2;
        cbAll;
        btnPick;
        btnCancel;
        cancelled=false;
        updating=false;
        pickedRowIds;
        pickedMrs;
        pickedVrs;
        app;
        prop_w;
        idIsNumeric=false;
        xVr=-1;
        
        jLabel;
        sizeInfo;
        needToRefresh=0;
        alwaysRefresh;
        cbAlwaysRefresh;
        cbCaptureCsv;
        btnRefresh;
        btnBrowse;
        btnCamera;
        btnFolder;
        btnOpenFolder;
        lastFile
        extraScreenCapture;
        folderSpecified=false;
        parentFig;
        sizeR;
        sizeFmt;
        btnTable;
    end
    
    methods
        
        function ok=notifyRefresh(this, force)
            if this.alwaysRefresh || (nargin>1&&force)
                ok=true;
                feval(this.args.refresh_callback, this);
                this.btnRefresh.setEnabled(false);
                this.btnRefresh.setText('   ');                
            else
                this.needToRefresh=this.needToRefresh+1;
                this.btnRefresh.setEnabled(true);
                this.btnRefresh.setForeground(java.awt.Color.RED);
                this.btnRefresh.setText(num2str(this.needToRefresh));
                this.app.showToolTip(this.btnRefresh)
                edu.stanford.facs.swing.Basics.Shake(this.btnRefresh, 2);
                this.app.showToolTip(this.btnRefresh)
            end
        end
        
        function this=TablePicker(data, varargin)
            this.app=BasicMap.Global;
            this.sizeFmt=Html.WrapSmallBold('%s X %d %s %s');
            this.originalData=data;
            [this.R, this.C]=size(data);
            assert(this.R>0);
            [this.args, this.argued]=...
                Args.New(this.defineArgs, varargin{:});
            this.ric=this.args.row_identifier_column;
            if this.ric>0
                this.rowIdentifiers=data(:, this.ric);
            end
            refFig=get(0, 'CurrentFigure');
            [fig, this.tb]=Gui.Figure;
            
            if ~isempty(this.args.where)
                Gui.Locate(fig, refFig, this.args.where);
            end
            set(fig, 'Name', this.args.fig_name);
            if isempty(this.args.column_labels)
                this.args.column_labels=String.ColumnLetters(this.C);
            end
            %this.tb2=ToolBar.New(fig, false);
            if isempty(this.args.formats)
                this.table=SortTable(fig, data, ...
                    this.args.column_labels,...
                    [.02 .08 .96 .92], [],...
                    this.args.tips);
            else
                [this.originalData, widths]=SortTable.ToSortableAlignedHtml(data, this.args.formats);
                this.table=SortTable(fig, this.originalData, ...
                    this.args.column_labels,...
                    [.02 .08 .96 .92], [], ...
                    this.args.tips);
                st=this.table;
                N=length(widths);
                for i=1:N
                    if this.app.highDef
                        factor=this.app.toolBarFactor;
                    else
                        factor=1;
                    end
                    st.setColumnWidth(i, widths(i)*factor)
                    st.setColumnWidth(i, widths(i)*factor)
                end
            end
            this.mapData;
            T=this.table.uit;
            if ~this.app.highDef
                if ispc
                    %T.FontSize=12;
                elseif ismac
                    T.FontSize=12;
                end
            else
                T.FontSize=11;
            end
            this.T=T;
            this.J=this.table.jtable;
            this.J.setNonContiguousCellSelection(false)
            set(this.J.getSelectionModel, 'ValueChangedCallback', ...
                @(h,e)rowSelectionHeard(this,h,e));
            set(T, 'RowStriping', 'off');

            this.J.setAutoscrolls(false)
            this.J.setAutoResort(false);
            if ~isempty(this.args.selection_background)
                try
                    this.J.setSelectionBackground(java.awt.Color(...
                    this.args.selection_background(1), ...
                    this.args.selection_background(2), ...
                    this.args.selection_background(3)));
                catch ex
                    ex.getReport
                end
            end
            if ~isempty(this.args.selection_foreground)
                try
                    this.J.setSelectionForeground(java.awt.Color(...
                    this.args.selection_foreground(1), ...
                    this.args.selection_foreground(2), ...
                    this.args.selection_foreground(3)));
                catch ex
                    ex.getReport
                end
            end
            if this.args.is_xy_selections
                txt='Set X/Y';
            else
                txt='Pick ( 0 )';
            end
            [~,this.btnPick]=Gui.NewBtn(txt, @(h,e)pick(this, h, e), ...
                'Choose the selected rows', Gui.Icon('yes10.png', this.app));
            if this.args.is_xy_selections
                if this.argued.contains('min_selections')
                    warning('min_selections has no effect if is_xy_selections==true');
                end
                if this.argued.contains('max_selections')
                    warning('max_selections has no effect if is_xy_selections==true');
                end
                this.args.max_selections=2;
                this.args.min_selections=1;
            end
            if this.args.modal
                txtCancel='Cancel';
                iconCancel='cancel.gif';
            else
                txtCancel='Close';
                iconCancel='close16.png';
            end
            
            [~,this.btnCancel]=Gui.NewBtn(txtCancel, ...
                @(h,e)cancel(this, h, e), 'Close window', ...
                Gui.Icon(iconCancel, this.app));
            set(fig, 'CloseRequestFcn', @(h, e)hush(this, h));
            this.cbAll=Gui.CheckBox(...
                    sprintf('All (0/%d) ', this.R), false,  [], '', ...
                    @(h,e)allHeard(this,h), 'Click to select/deselect all');
            if this.args.max_selections>0
                this.cbAll.setEnabled(false);
            end
            this.initToolBar;
            if ~isempty(this.args.toolbar_component)
                try
                    this.tb.jToolbar.add(this.args.toolbar_component);
                catch ex
                    ex.getReport
                end
            end

            jp=Gui.Panel;
            jp.add(this.btnCancel);
            if ~isempty(this.args.pick_callback)
                jp.add(this.btnPick);
            end
            if this.args.modal
                if ~isempty(this.args.default_selections)
                    MatBasics.RunLater(@(h,e)selectDflts, .25);
                    this.selectRows(this.args.default_selections)
                end
                set(fig, 'WindowStyle', 'modal');
                %T.Position=[.02 .08 .96 .86];
            else
                if ~isempty(this.args.default_selections)
                    this.selectRows(this.args.default_selections)
                end
            end
            if this.args.visible
                this.restoreTablePreferences;
                this.restoreWindowPreferences;
                if ~isempty(this.args.locate_fig)
                    SuhWindow.Follow(fig, this.args.locate_fig);
                end
                SuhWindow.SetFigVisible(fig);
            end
            drawnow;
            rowHeight=floor(this.J.getRowHeight*1.33);
            
            if this.args.max_selections>-1                
                ps=jp.getPreferredSize;
                H2=Gui.AlignRight(fig, jp, 0);
                ps2=this.cbAll.getPreferredSize;
                Gui.AlignLeft(fig, this.cbAll,0);
                resizeFcn;
                set(fig, 'ResizeFcn', @(h,e)resizeFcn());
                MatBasics.DoLater(@(h,e)resizeHeight(), .31);
            else
                this.cbAll.setVisible(false);
                set(fig, 'ResizeFcn', @(h,e)resizeHeight);
                resizeHeight;
            end
            
            Gui.SetFigButtons(fig, this.btnPick, this.btnCancel);
            if ~isempty(this.table.uil)                
                if this.args.modal
                    fs=10;
                else
                    fs=11;
                end
                if this.app.highDef
                    fs=fs-2;
                end
                set(this.table.uil, ...
                    'position', [.07 .01 .75 .05], ...
                    'FontSize', fs, ...
                    'ForegroundColor', [0 .4 .6], ...
                    'FontAngle', 'italic', ...
                    'FontWeight', 'bold');
                job=findjobj_fast(this.table.uil);
                Gui.SetTransparent(job);
                this.table.putTipInFigNameToo('TablePicker -->');
            end

            function selectDflts
                this.selectRows(this.args.default_selections)
            end
            
            function resizeHeight()
                MatBasics.DoLater(@(h,e)budge(), .31);
                function budge
                    this.J.setRowHeight(rowHeight);
                    drawnow;
                end
            end

            function resizeFcn()
                delete(H2);
                try
                    jp.setPreferredSize(ps)
                    H=Gui.AlignRight(fig, jp, 0);
                    Gui.SetTransparent(jp);
                    Gui.SetTransparent(this.btnPick);
                    Gui.SetTransparent(this.btnCancel);
                    set(H, 'units', 'normalized');
                    this.cbAll.setPreferredSize(ps2);
                    H=Gui.AlignLeft(fig, this.cbAll,0);
                    set(H, 'units', 'normalized');
                catch ex
                end
                resizeHeight;
            end 
        end
        
        
        function refresh(this, refreshData, originalColumns, selectRowIds)
            [R2, C2]=size(refreshData);
            this.R=R2;
            this.saveTablePreferences;
            assert(C2<=this.C, ...
                'refreshData columns %d > originalData %d', C2, this.C);
            assert(all(originalColumns<=this.C), ...
                'ALL originalColumns must be >0 and <= %d', this.C);
            if this.ric==0 
                assert(R2==this.R, ['refreshData rows (%d) ~= '...
                    'originalData rows (%d) but row_identifier_column==0'], ...
                    R2, this.R)
            else
                ricIdx=find(originalColumns==this.ric, 1);
                assert(~isempty(ricIdx) || R2==this.R, ...
                    ['TablePicker.refresh() requires '...
                    'row identifier column or refreshData rows %d '...
                    'must equal originalData rows %d!'], R2, this.R);
            end
            j=this.J;
            fmts=this.args.formats;
            hasFmts=~isempty(fmts);
            if this.ric>0
                mrs=zeros(1, R2);
                for r=1:R2
                    rowId=refreshData{r,ricIdx};
                    if this.idIsNumeric
                        rowId=num2str(rowId);
                    else
                        if ~hasFmts
                            rowId=char(rowId);
                        else
                            rowId=SortTable.ToSortableAlignedHtml({rowId}, fmts(this.ric,:));
                            rowId=rowId{1};
                        end
                    end
                    mrs(r)=this.mrById.get(rowId);
                end
            else
                mrs=1:this.R;
            end
            original=this.originalData;
            for r=1:R2
                for c=1:C2
                    if c~=ricIdx
                        value=refreshData{r,c};
                        mc=originalColumns(c);
                        if hasFmts
                            value=SortTable.ToSortableAlignedHtml({value},fmts(mc,:));
                            value=value{1};
                        end
                        original{mrs(r), mc}=value;
                    end
                end
            end
            set(this.T, 'Data', original);
            drawnow;
            this.restoreTablePreferences;
            drawnow;
            if nargin>3
                this.selectRows(selectRowIds);
            end
            this.setSizeInfo;
        end
        
        function updateData(this, data, modelColumns, ...
                refreshSizeInfo, selectRowIds, useJava, name)
            if nargin<7
                name='';
                if nargin<6
                    useJava=true;
                    if nargin<5
                        selectRowIds=[];
                        if nargin<4
                            refreshSizeInfo=true;
                        end
                    end
                end
            end
            [R2,C2]=size(data);
            assert(R2==this.R, 'Must be updating same data');
            assert(this.C==C2, 'Data must have %d columns!', this.C);
            if ~isempty(this.args.formats)
                data=SortTable.ToSortableAlignedHtml(data, this.args.formats);
            end
            mrs=this.getModelRows(0:R2-1);
            J_=this.J;
            if useJava
                edu.stanford.facs.swing.SwingUtil2.updateTable(...
                    J_, data, modelColumns-1, mrs-1);
            else
                N=length(modelColumns);
                vcs=zeros(1, N);
                for mc=1:N
                    vcs(mc)=J_.convertColumnIndexToView(modelColumns(mc)-1);
                end
                for vr=0:R2-1
                    mr=mrs(vr+1);
                    for c=1:N
                        value=data{mr, modelColumns(c)};
                        if ~isempty(value)
                            J_.setValueAt(value, vr, vcs(c));
                        else
                            J_.setValueAt(java.lang.String, vr, vcs(c))
                        end
                    end
                end
            end
            this.originalData=data;
            drawnow;
            if ~isempty(selectRowIds)
                this.selectRows(selectRowIds);
            end
            if refreshSizeInfo
                this.setSizeInfo([], name);
            end
            MatBasics.RunLater(@(h,e)J_.resort, .25);
        end
        
        function setData(this, data, selectRowIds)
            [R2,C2]=size(data);
            this.R=R2;
            assert(this.C==C2, 'Data must have %d columns!', this.C);
            this.saveTablePreferences;
            fmts=this.args.formats;
            hasFmts=~isempty(fmts);
            if this.ric>0
                this.rowIdentifiers=data(:,this.ric);
            end
            if hasFmts
                data=SortTable.ToSortableAlignedHtml(data,fmts);
            end
            this.originalData=data;
            [this.R, this.C]=size(data);
            this.mapData;
            set(this.T, 'Data', data);
            drawnow;
            this.restoreTablePreferences;
            if nargin>2
                this.selectRows(selectRowIds);
            end
            this.setSizeInfo;
        end
        
        function selectRows(this, selectRowIds, scroll)
            if this.updating
                return;
            end
            if nargin<3
                scroll=true;
            end
            this.updating=true;
            S=length(selectRowIds);
            j=this.J;
            vrs=zeros(1,S);
            for s=1:S
                key=selectRowIds{s};
                vrs(s)=TablePicker.GetVisualRow(j, key, ...
                    this.ric, this.idIsNumeric, this.args.formats);
            end
            drawnow;
            vrs
            j.clearSelection;
            for s=1:s
                j.changeSelection(vrs(s), 0, true, false);
            end
            [~, tip]=TablePicker.SelectRows(j, vrs, ...
                this.args.min_selections, ...
                this.args.max_selections, ...
                this.args.force_selections);
            N2=j.getSelectedRowCount;
            if ~this.args.is_xy_selections
                this.btnPick.setText(sprintf('Pick (%d)', N2));
            end
            this.cbAll.setText(sprintf('All (%d/%d)', N2, j.getRowCount));
            if ~isempty(tip)
                this.app.showToolTip(this.J, tip)
            end
            if scroll
                rect=j.getCellRect(vrs(end),0, true);
                j.scrollRectToVisible(rect);
            end
            drawnow;
            this.updating=false;
        end
        
        function [vrs, mrs, rowIds]=getSelectedRows(this)
            vrs=this.J.getSelectedRows';
            if this.args.is_xy_selections
                N=length(vrs);
                if N==1
                    this.xVr=vrs;
                else
                    ii=find(vrs==this.xVr, 1);
                    if ~isempty(ii)
                        newVrs=this.xVr;
                        for i=1:N
                            if i~=ii
                                newVrs(end+1)=vrs(i);
                            end
                        end
                        vrs=newVrs;
                    end
                end
            end
            mrs=this.getModelRows(vrs);
            if nargout>2
                if this.ric>0
                    N=length(vrs);
                    rowIds=cell(1,N);
                    for i=1:N
                        rowIds{i}=this.rowIdentifiers{mrs(i)};
                    end
                else
                    rowIds={};
                end
            end
        end
        
        function mrs=getModelRows(this, vrs)
            N_=length(vrs);
            j=this.J;
            mrs=zeros(1,N_);
            vRowId=j.convertColumnIndexToView(this.ric-1);
            for i=1:N_
                key=j.getValueAt(vrs(i), vRowId);
                mr=this.mrById.get(char(key));
                if ~isempty(mr)
                    mrs(i)=mr;
                end
            end
        end
        
        function ok=isClosed(this)
            ok=~isempty(this.table) && ~isempty(this.table.fig) ...
                && ~ishandle(this.table.fig);
        end
        
        function ok=focus(this)
            ok=~this.isClosed;
            if ok
                figure(this.table.fig);
            end
        end
        
        function cnt=getSelectedCount(this, rowIds)
            cnt=0;
            N1=length(rowIds);
            [~,~,selectedRowIds]=this.getSelectedRows;
            N2=length(selectedRowIds);
            for i=1:N1
                rowId=rowIds{i};
                for j=1:N2
                    if isequal(rowId, selectedRowIds{j})
                        cnt=cnt+1;
                        break;
                    end
                end
            end
        end
        
        function setParentFig(this, fig)
            this.extraScreenCapture=fig;
            this.parentFig=fig;
        end
        
        function setSizeInfo(this, sz, name)
            if nargin<3
                name='';
            else
                name=Html.WrapSmallTags( ...
                    [' <font color="blue">' ...
                    name '</font>']);
            end
            if nargin<2 || isempty(sz)
                sz=[this.R this.C];
            else
                this.sizeR=sz(1);
            end
            txt=sprintf(this.sizeFmt, String.encodeInteger(sz(1)),...
                sz(2), name);
            this.jLabel.setText(txt);
            this.sizeInfo=txt;
        end
        
    end
    
    methods(Access=private)
        function mapData(this)
            this.mrById=java.util.HashMap;
            if this.ric>0
                this.idIsNumeric=isnumeric(this.originalData{1, this.ric});
                for r=1:this.R
                    if this.idIsNumeric
                        this.mrById.put(num2str(this.originalData{r, this.ric}), r);
                    else
                        this.mrById.put(char(this.originalData{r, this.ric}), r);
                    end
                end
            end
        end
        
        function restoreTablePreferences(this)
            j=this.J;
            columnOrder=BasicMap.GetNumbers(this.app, ...
                this.getPropCO, this.args.default_column_order);
            if ~isempty(columnOrder)
                try
                    SortTable.SetColumnOrder(j, columnOrder,...
                        BasicMap.GetNumbers(this.app, this.getPropW));
                catch ex
                    ex.getReport
                end
            end
            rowOrder=BasicMap.GetNumbers(this.app, this.getPropRO, ...
                this.args.default_row_order);
            SortTable.SetRowOrder(j, rowOrder);            
        end
        
        function restoreWindowPreferences(this)
            fig=this.table.fig;
            op=fig.OuterPosition;
            op(3)=floor(op(3)*1.175);
            fig.OuterPosition=op;
            op=BasicMap.GetNumbers(this.app, this.getPropOP);
            if ~isempty(op)
                set(fig, 'OuterPosition', Gui.FitToScreen(op));
            end
        end
        
        function p=getPropCO(this)
            p=['TablePicker.CO.' this.args.property];
        end
        
        function p=getPropRO(this)
            p=['TablePicker.RO.' this.args.property];
        end
        
        function p=getPropW(this)
            p=['TablePicker.W.' this.args.property];
        end
        
        function p=getPropOP(this)
            p=['TablePicker.OP.' this.args.property];
        end
        
        function saveTablePreferences(this)
            j=this.J;
            props=this.app;
            [columnOrder, widths]=SortTable.GetColumnOrder(j);
            props.set(this.getPropCO, num2str(columnOrder));
            props.set(this.getPropW, num2str(widths));
            rowOrder=SortTable.GetRowOrder(j);
            props.set(this.getPropRO, MatBasics.Encode(rowOrder));
        end
        
        function hush(this, h)
            this.saveTablePreferences;
            this.app.set(this.getPropOP, num2str(get(h, 'OuterPosition')));
            delete(this.table.fig)
            if ~isempty(this.parentFig)
                if ishandle(this.parentFig)
                    setAlwaysOnTopTimer(this.parentFig);
                end
            end
        end
        
        function allHeard(this, h)            
            if h.isSelected
                this.updating=false;
                J_=this.J;
                J_.clearSelection;
                R_=J_.getRowCount;
                for vr=0:R_-2
                    J_.changeSelection(vr, 0, true, false);
                end
                drawnow;
                wasUpdating=this.updating;
                this.updating=true;
                J_.changeSelection(R_-1,0,true,false);
                drawnow;
                this.updating=wasUpdating;
            else
                this.J.clearSelection;
            end
            this.updatePickBtn('');
        end
        
        function rowSelectionHeard(this, h, e)
            if this.updating
                return;
            end
            this.updating=true;
            [vrs, mrs, ids]=this.getSelectedRows;
            [changed, tip]=TablePicker.SelectRows(this.J, vrs, ...
                this.args.min_selections, this.args.max_selections, ...
                this.args.force_selections);
            N=length(vrs);
            if ~isempty(this.args.selection_callback)
                if changed
                    [vrs, mrs, ids]=this.getSelectedRows;
                end
                feval(this.args.selection_callback, this, vrs, mrs, ids);
            end
            this.updating=false;
            this.updatePickBtn(tip);
            vCol=this.J.getSelectedColumn;
            if vCol>=0
                this.table.showTip(this.J.convertColumnIndexToModel(...
                    vCol)+1)
            end
        end
        
        function ok=updatePickBtn(this, tip)
            if nargin<2
                tip=[];
            end
            j=this.J;
            N=j.getSelectedRowCount;
            if ~this.args.is_xy_selections
                this.btnPick.setText(sprintf('Pick (%d)', N));
            else
                this.btnPick.setText('Set X/Y');
            end
            ok=N>=this.args.min_selections && ...
                (this.args.max_selections<=0||N<=this.args.max_selections);
            this.btnPick.setEnabled(ok);
            if ok
                if isempty(tip)
                    if this.args.is_xy_selections
                        vrs=this.getSelectedRows;
                        N2=length(vrs);
                        N3=length(this.args.describe_columns);
                        s='XY';
                        tip='<html>';
                        for r=1:N2
                            vr=vrs(r);
                            tip=[tip '<font color="blue">' s(r) ...
                                '</font>=<b>'];
                            if N3>0
                                for k=1:N3
                                    mc=this.args.describe_columns(k)-1;
                                    vc=j.convertColumnIndexToView(mc);
                                    tip=[tip Html.remove(...
                                        char(this.J.getValueAt(vr, vc)))];
                                    if k<N3
                                        tip=[tip ','];
                                    end
                                end
                            else
                                tip=[tip 'row #' num2str(vr+1)];
                            end
                            if r<N2
                                tip=[tip '</b> and '];
                            else
                                tip=[tip '</b>'];
                            end
                        end
                        if N2==1
                            tip=[tip '...   please ADD a '...
                                '<font color="red"><b>'...
                                'Y selection</b></font>!!'];
                            this.btnPick.setEnabled(false);
                        else
                            this.btnPick.setEnabled(true);
                        end
                        tip=[tip '</html>'];
                        this.btnPick.setToolTipText(tip);
                    end
                end
                if this.btnPick.isEnabled
                    edu.stanford.facs.swing.Basics.Shake(this.btnPick, 2 )
                end
            end
            if ~isempty(tip)
                this.app.showToolTip(this.btnPick, tip, 15, 25);
            else
                this.app.closeToolTip;
            end
            this.cbAll.setText(sprintf('All (%d/%d)', N, this.R));
        end
        
        function cancel(this, h, e)
            this.cancelled=true;
            close(this.table.fig);
        end
        
        function ok=pick(this, h, e)
            ok=false;
            [this.pickedVrs, this.pickedMrs, this.pickedRowIds]=...
                this.getSelectedRows;
            if ~isempty(this.args.pick_callback)
                h.setEnabled(false);
                try
                    ok=feval(this.args.pick_callback, this, ...
                        this.pickedVrs,...
                        this.pickedMrs, ...
                        this.pickedRowIds);
                catch ex
                    ex.getReport
                end
                h.setEnabled(true);
                if ~this.args.modal
                    this.app.showToolTip(this.btnCancel, ...
                        'Click to close window', -5, 25);
                end
            elseif this.args.modal
                close(this.table.fig);
            end
        end
        
        
        function p=defineArgs(this)
            p = inputParser;
            addParameter(p,'column_labels', {}, @(x)checkLabels(x));
            addParameter(p,'row_identifier_column', 0, @(x)isnumeric(x) && ...
                x>-1 && x<this.C);
            addParameter(p,'describe_columns', [], @(x)isnumeric(x) && ...
                all(x>0) && all(x<=this.C));
            addParameter(p,'max_selections', 0, @(x)isnumeric(x) && x>=-1);
            addParameter(p,'min_selections', 0, @(x)isnumeric(x) && x>=0);
            addParameter(p,'is_xy_selections', false, @islogical);
            addParameter(p,'force_selections', false, @islogical);
            addParameter(p, 'default_selections', {}, @(x)iscell(x) ...
                && (isempty(x) || any(1==size(x)==1)));
            addParameter(p,'pick_callback', [], ...
                @(x)validateCallback('pick', x));
            addParameter(p,'capture_data_callback', [], ...
                @(x)validateCallback('capture_data', x));
            
            addParameter(p,'refresh_callback', [], ...
                @(x)validateCallback('refresh', x));
            addParameter(p,'selection_callback', [], ...
                @(x)validateCallback('selection', x));
            addParameter(p,'modal', true, @islogical);
            addParameter(p,'visible', true, @islogical);
            addParameter(p,'widths', [], @(x)isnumeric(x) && all(x>5));
            addParameter(p,'property', 'dflt', @(x)ischar(x));
            addParameter(p,'object_name', 'tablePicker', @(x)ischar(x));
            
            addParameter(p,'fig_name', 'TablePicker', @(x)ischar(x));
            addParameter(p, 'formats', [], @checkFormats);
            addParameter(p, 'toolbar_component',[]);
            addParameter(p, 'where',[]);
            addParameter(p, 'tips',{},@validateTips);
            
            addParameter(p,'default_column_order', [], @(x)isnumeric(x) ...
                && all(x>=0));
            addParameter(p,'default_row_order', [], @(x)isnumeric(x) ...
                && all(x>=0));
            addParameter(p, 'selection_background', [.959 1 .731], ...
                @(x)isnumeric(x)...
                && length(x)==3 && all(x>=0) && all(x<=1));
            addParameter(p, 'selection_foreground', [.05, .11, .91],...
                @(x)isnumeric(x)...
                && length(x)==3 && all(x>=0) && all(x<=1));
            addParameter(p, 'root_folder', [], @ischar);
            addParameter(p, 'locate_fig', {}, ...
                @(x)Args.IsLocateFig(x, 'locate_fig' ));
            
            
            function ok=validateTips(x)
                ok=true;
                if ~iscell(x) || length(x)~=this.C || ~ischar(x{1})
                    error('''tips'' arg must be cell of %d strings for each column!!', this.C);
                end
            end
            
            function ok=checkFormats(x)
                ok=false;
                if ~isnumeric(x)
                    warning('formats must be numeric Rx2');
                    return;
                end
                [R2, C2]=size(x);
                if R2~=this.C || C2 ~= 2
                    warning('formats must be a %dx2 matrix', this.C);
                    return;
                end
                ok=true;
            end
            
            function ok=checkLabels(labels)
                ok=false;
                if ~iscell(labels)
                    warning('column_labels must be cell of strings');
                    return;
                end
                nLabels=length(labels) ;
                
                if nLabels>0 && nLabels ~= this.C
                    warning('# of column_labels == %d but # of columns==%d',...
                        length(labels), this.C);
                    return;
                end
                ok=true;
            end
            
            function ok=validateCallback(txt, x)
                ok=false;
                if isequal('function_handle', class(x))
                    %test input and output arguments
                    try
                        if strcmp(txt, 'capture_data')
                            [data, names]=feval(x, this, true);
                            if size(data,2)~=length(names)
                                warning('capture_data %d rows ~= %d names',...
                                    size(data,2), length(names));
                                ok=false;
                            else
                                ok=true;
                            end
                        elseif ~strcmpi(txt, 'refresh')
                            feval(x, this, 1, 1, {''});
                        end
                        ok=true;
                    catch ex
                        ex.getReport
                        warning('%s_callback exception "%s"', txt, ex.message);
                    end
                else
                    ok=isempty(x);
                end
            end
        end
        
        function openFolder(this, ask)
            if isempty(this.lastFile)
                dflt=this.getFldr;
                if isempty(dflt)
                    msg('No file saved from this table yet');
                else
                    File.OpenFolderWindow(fullfile(dflt, 'dummy'), ...
                    'TablePicker.capture', ask);
                end
            else
                File.OpenFolderWindow(this.lastFile, ...
                    'TablePicker.capture', ask);
            end
        end
        
        function [fldr, prop]=getFldr(this)
            prop=[this.args.property '.folder'];
            fldr=this.app.get(prop);
        end
        
        function [actual, prop, dflt]=specifyFolder(this, chooseNow)
            [dflt, prop]=this.getFldr;
            actual=this.app.get(prop, dflt);
            if nargin==1 || chooseNow
                MatBasics.RunLater(@(h,e)explain,2);
                f=uigetdir(actual, ...
                    ['Folder for ' this.args.object_name ' png file(s)']);
                if ischar(f)
                    this.app.set(prop, f);
                    actual=f;
                    this.folderSpecified=true;
                else
                    actual='';
                end
            end
            function explain
                msg(this.getPngFileMsg, 8, 'north west+');
            end
        end
        
        function txt=getPngFileMsg(this)
            txt=['<html>Indicate folder for screen<br>capture '...
                    'of ' this.args.object_name '*png file(s)<hr></html>'];
        end
        
        function ok=captureScreens(this)
            ok=false;
            fldr=this.specifyFolder(~this.folderSpecified);
            if isempty(fldr)
                return;
            end
            if isempty(this.sizeR)
                R_=this.R;
            else
                R_=this.sizeR;
            end
            file=[this.args.object_name '_' num2str(R_)];
            fullFile=fullfile(fldr, [file '_kld.png']);
            if exist(fullFile, 'file')
                if ~askYesOrNo(Html.WrapHr(['Overwrite prior file "' ...
                        Html.WrapSmallTags(file) '"<br>in folder "'...
                        Html.WrapSmallTags(fldr) '" ?']))
                    file=[this.args.object_name '_' num2str(R_) ...
                        '_' num2str(this.needToRefresh)];
                    [~, prop]=this.getFldr;
                    [fldr, file]=uiPutFile(fldr, [file '_kld.png'], ...
                        this.app, prop, this.getPngFileMsg);
                    if isempty(fldr)
                        return;
                    end
                    fullFile=fullfile(fldr, file );
                end
            end
            Gui.SavePng(this.table.fig, fullFile);
            if ~isempty(this.extraScreenCapture)...
                    && ishandle(this.extraScreenCapture)
                Gui.SavePng(this.extraScreenCapture, fullfile(fldr, ...
                    [file '_extra.png']));
            end
            
            if ~isempty(this.args.capture_data_callback) ...
                    && this.cbCaptureCsv.isSelected
                [p,f]=fileparts(fullFile);
                csvFile=fullfile(p, [f '.csv']);
                if exist(csvFile, 'file')
                    fl=Html.WrapBoldSmall(csvFile) ;
                    msg(Html.Wrap(['The pre-existing csv file has  '...
                        'been overwritten... <br>('  fl ')' ]), ...
                        5, 'south east+');
                end
                try
                    [data, names]=feval(...
                        this.args.capture_data_callback, this, false);
                    File.WriteCsvFile(csvFile, data, names);
                catch ex
                    ex.getReport
                end 
            end
            ok=true;
            ask=isempty(this.lastFile);
            this.lastFile=fullFile;
            this.openFolder(ask);
        end
        
        function openTable(this)
            tn=tempname;
            
            fl=[tn '.txt'];
            try
                [choice, cancelled]=Gui.Ask(struct(...
                    'msg', 'View the measurement details', ...
                    'remember', 'Kld.table' ), ...
                    {'In our sort table', 'In Microsoft Excel '}, ...
                    'Kld.table', 'Confirm ....', 1);
                if cancelled
                    return;
                end
                pu=PopUp('Gathering table data...');
                [data, names]=feval(...
                    this.args.capture_data_callback, this, false);
                File.WriteTabFile(fl, data, names, '%0.1f');
                if choice==1
                    propFile=[];
                    if isempty(this.args.root_folder)
                        fldr=this.getFldr;
                        if ~isempty(fldr)
                            propFile=fullfile(fldr, 'ReagentTable.properties');
                        end
                    else
                        propFile=fullfile(...
                            this.args.root_folder, 'ReagentTable.properties');
                    end
                    if isempty(propFile)
                        com.MeehanMetaSpace.swing.TabBrowser.NewFcsData(fl);
                    else
                        com.MeehanMetaSpace.swing.TabBrowser.NewFcsData(...
                            fl, propFile);
                    end
                elseif choice==2
                    xFl=[tn '.xls'];
                    makeXlsExternal(fl, xFl, 1, 1, []);
                    if ismac
                        system(['open ' String.ToSystem(xFl)]);
                    else
                        system(String.ToSystem(xFl));
                    end
                end
            catch ex
                ex.getReport
            end
            pu.close;
        end
        function ok=browse(this)
            ok=false;
            fldr=this.specifyFolder(~this.folderSpecified);
            if isempty(fldr)
                return;
            end
            fileSpec=fullfile(fldr, [this.args.object_name '_*_kld.png']);
            prop=[this.args.property '_browse'];
            files=File.Ask(fileSpec, false, prop);
            N=length(files);
            if N<1
                return;
            end
            ok=true;
            html='<html><table border="1">';
            for i=1:N
                fl=files(i).name;
                fldr=files(i).folder;
                file1=Html.ImgXy(fl, fldr, 1.1, true);
                [~,fl]=fileparts(fl);
                if endsWith(fl, '_kld')
                    fl=fl(1:end-4);
                end                    
                if exist(fullfile(fldr, [fl '_extra.png']), 'file')
                    file2=Html.ImgXy([fl '_extra.png'], fldr, 1.1, true);
                else
                    file2='';
                end
                html=[html '<tr><td>' file1 '</td><td>' file2 '</tr>'];
            end
            html=[html '</table></html>'];
            Html.Browse(html);
        end
        

        
        function hearAlwaysRefresh(this, h)
            this.alwaysRefresh=h.isSelected;
            this.app.setBoolean([this.args.property '.always'], ...
                this.alwaysRefresh)
            if this.alwaysRefresh
                if this.needToRefresh>0
                    this.btnRefresh.doClick;
                    return;
                end
            end
            this.btnRefresh.setEnabled(~this.alwaysRefresh ...
                && this.needToRefresh>0);
        end
        
        function initToolBar(this)
            if ~this.args.modal
                pp=this.app.contentFolder;
                if ~isempty(this.args.refresh_callback)
                    prop=[this.args.property '.always'];
                    this.alwaysRefresh=this.app.is(prop, true);
                    this.cbAlwaysRefresh=Gui.CheckBox(...
                        Html.WrapSmallBold('Always refresh'),...
                        this.alwaysRefresh,...
                        this.app, prop,...
                        @(h,e)hearAlwaysRefresh(this, h), ...
                        'Select to auto-refresh');
                    ToolBarMethods.addComponent(this.tb, this.cbAlwaysRefresh);
                    drawnow;
                    this.btnRefresh=ToolBarMethods.addButton(this.tb, ...
                        fullfile(pp, 'refresh.png'),...
                        'Synchronize with plot selections',...
                        @(h,e)notifyRefresh(this, true));
                    this.btnRefresh.setText('   ');
                    this.btnRefresh.setEnabled(false);
                end
                ToolBarMethods.addSeparator(this.tb);
                this.btnFolder=ToolBarMethods.addButton(this.tb, ...
                    fullfile(pp, 'foldericon.png'),...
                    'Specify folder for screen capture png file(s)', ...
                    @(h,e)specifyFolder(this));
                this.btnCamera=ToolBarMethods.addButton(this.tb, ...
                    fullfile(pp, 'camera.png'), ...
                    'Capture this information in png file(s)', ...
                    @(h,e)captureScreens(this));
                if ~isempty(this.args.capture_data_callback)
                    this.cbCaptureCsv=Gui.CheckBox(...
                        Html.WrapSmallBold('Csv?'), ...
                        this.app.is('tablePicker.csv', true), ...
                        this.app, 'TablePicker.csv', [], ['<html>Select '...
                        'if you want a camera click to ALSO <br>deposit '...
                        'associated data into a csv file</html>']);
                    ToolBarMethods.addComponent(this.tb, this.cbCaptureCsv);
                    this.btnOpenFolder=ToolBarMethods.addButton(this.tb, ...
                        fullfile(pp, 'foldericonNone.png'),...
                        'Open folder containing screen/csv capture file(s)', ...
                        @(h,e)openFolder(this, false));
                        if Gui.HasMeehanMetaSpaceJars
                            this.btnTable=ToolBarMethods.addButton(this.tb, ...
                                fullfile(pp, 'table.gif'),...
                                '<html>See <i>underlying</i> data in table</html>', ...
                                @(h,e)openTable(this));
                        end
                end
                this.btnBrowse=ToolBarMethods.addButton(this.tb, ...
                    fullfile(pp, 'world_16.png'), ...
                    'Browse screen captures in folder', ...
                    @(h,e)browse(this));
                ToolBarMethods.addSeparator(this.tb);
                drawnow; 
            end
            this.initSizeInfo;
        end
        
        function initSizeInfo(this)
            this.jLabel=javaObjectEDT('javax.swing.JLabel');
            this.setSizeInfo;
            ToolBarMethods.addComponent(this.tb, this.jLabel);
            this.app.showToolTip(this.J, this.sizeInfo, 50, 55);
        end
        
        
    end
    
    methods(Static)        
        function row=GetVisualRow(J, rowId, mc, idIsNumeric, fmts)
            if ~isempty(fmts)
                rowId=SortTable.ToSortableAlignedHtml({rowId}, fmts(mc,:));
                rowId=rowId{1};
            end
            if idIsNumeric
                rowId=num2str(rowId);
            end
            vc=J.convertColumnIndexToView(mc-1);
                
            N=J.getRowCount;
            for row=0:N-1
                id=char(J.getValueAt(row, vc));
                if isequal(rowId, id)
                    return;
                end
            end
            row=-1;
        end
        
        function [outOfRange, tip]=SelectRows(J, vrs, min_, max_, force)
            if nargin<4
                max_=0;
                if nargin<3
                    min_=0;
                    if nargin<2
                        vrs=J.getSelectedRows';
                    end
                end
            end
            tip='';
            R=length(vrs);
            startVrs=vrs;
            if R<min_
                outOfRange=true;
                tip=sprintf('<html>You <font color="red">must</font> select at <b>least %d row(s)!!</b></html>', min_);
                if force
                    R2=J.getRowCount;
                    selections=R;
                    for r=0:R2-1
                        if isempty(find(vrs==r,1))
                            selections=selections+1;
                            if selections==min_
                                break;
                            end
                        end
                    end
                    vrs(end+1)=r;
                end
            elseif max_>0 && R>max_
                outOfRange=true;
                tip=sprintf('<html>You can <font color="red">NOT</font> select <b>more than %d rows!!</b></html> ', max_);
                if force
                    remove=R-max_;
                    for r=remove:-1:1
                        vrs(1)=[];
                    end
                end
            else
                outOfRange=false;
            end
            if ~isequal(startVrs, vrs)
                R=length(vrs);
                J.clearSelection;                
                for r=1:R
                    J.changeSelection(vrs(r), 0, true,false);
                end
            end
            drawnow;
        end
    end
end