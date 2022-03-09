classdef ColorsEditor <handle
%   AUTHORSHIP
%   Primary Developer: Stephen Meehan <swmeehan@stanford.edu> 
%   Math Lead & Secondary Developer:  Connor Meehan <connor.gw.meehan@gmail.com>
%   Provided by the Herzenberg Lab at Stanford University 
%   License: BSD 3 clause
%

    properties(SetAccess=private)
        table; %SortTable
        originalColors;
        colors;
        changed;
        names;
        N;
        app;
        fig;
        tb;
        cbn;
        btnCopy;
        btnPaste;
        btnRefresh;
        btnResort;
        btnPick;
        btnChangeDflts;
        btnUseDflts;
        btnAddDflts;
        btnHideDflts;
        btnRestoreBackup;
        nNonDflts;
        fncRefresh;
        fncSelection;
        hideDflts;
        hasDflts;
        itemName;
        synonymHints;
        alwaysRefresh;
        changedDflts=0;
        mrByName;
        statuses;
        context;
        syncCnt=0;
        originalDfltChange;
        priorFig;
        priorJavaFig;
        tb2;
    end
    
    properties(GetAccess=private)
        other;
        updating=false;
        pastedColor;
        mrDflts; %model row for defaults
    end

    
    properties(Constant)
        AUTO_REFRESH_SORT=0;
        COL_NAME=0;
        COL_RED=1;
        COL_GREEN=2;
        COL_BLUE=3;
        COL_RGB=[ColorsEditor.COL_RED ColorsEditor.COL_GREEN ...
                ColorsEditor.COL_BLUE];
        COL_SCATTER=4;
        COL_COLORS=[ColorsEditor.COL_RED, ColorsEditor.COL_GREEN, ...
            ColorsEditor.COL_BLUE, ColorsEditor.COL_SCATTER];
        COL_DFLT_STATUS=5;
        COL_USED_HERE=6;
        SYM_DFLT='<font size="5" color="889988">&#10004;</font>';
        SYM_DFLT_NEW='<font size="5" color="888899">&#10010;</font>';
        SYM_DFLT_NEW_TIP='<font size="5" color="blue">&#10010;</font>';
        SYM_DFLT_NEW_TIP_HD='<font size="8" color="blue">&#10010;</font>';
        SYM_DFLT_CHANGE='<font size="5" color="888899">&#9986;</font>';
        SYM_DFLT_CHANGE_TIP='<font size="5" color="blue">&#9986;</font>';
        SYM_DFLT_CHANGE_TIP_HD='<font size="8" color="blue">&#9986;</font>';
        SYM_RECYCLE=Html.remove(Html.RECYCLE);
        STATUS_DFLT=1;
        STATUS_DFLT_CHANGE=2;
        STATUS_DFLT_NEW=3;
        PROP_W='colorsEditor.W.v1.3';
        PROP_CO='colorsEditor.CO';
        PROP_RO='colorsEditor.RO';
        PROP_OP='colorsEditor.OP.v1.21';
    end
    
    methods
        function this=ColorsEditor(inNames, inColors, itemName, ...
                dflts, hideDflts, fncRefresh, fncSelection,...
                visible, alwaysRefresh, context)
            if nargin<10
                context='Global Colors';
                if nargin<9
                    alwaysRefresh=false;
                    if nargin<9
                        visible=true;
                        if nargin<8
                            fncSelection=[];
                            if nargin<6
                                fncRefresh=[];
                                if nargin<5
                                    hideDflts=true;
                                    if nargin<4
                                        dflts=[];
                                        if nargin<3
                                            itemName=[];
                                            if nargin<2
                                                inNames=[];
                                                InColors=[];
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            this.alwaysRefresh=alwaysRefresh;
            this.priorFig=get(0, 'currentFig');
            if isempty(itemName)
                itemName='Cell subset';
            end
            this.itemName=lower(itemName);
            if isempty(inNames)
                inNames={'T cells', 'Memory B cells', ...
                    'Naive B', 'Plasmoblasts', 'Monocytes effector',...
                    'naive b'};
                inColors=[.63 .6 0; 0 40 215; .15 .3 .55; 0 70 183; ...
                    15 244 233; .2 .3 .5];
            end
            this.context=context;
            R=length(inNames);
            names={};
            colors=[];
            nonDflts=java.util.HashSet;
            for i=1:R
                inName=inNames{i};
                key=java.lang.String(lower(inName));
                if nonDflts.contains(key)
                    warning('Case insensitve duplicate %s', char(key));
                else
                    nonDflts.add(key);
                    names{end+1}=inName;
                    clr255=ColorsByName.Get255(inColors(i,:), inName, false);
                    colors(end+1,:)=clr255;
                end
            end
            try
                this.app=BasicMap.Global;
            catch ex
                this.app.toolBarFactor=1;
                this.app.highDef=false;
            end
            this.names=names;
            if islogical(dflts) && dflts
                this.readGlobalColors(true);
            else
                this.cbn=dflts;
            end
            this.hideDflts=hideDflts;
            this.hasDflts=~isempty(dflts);
            this.fncRefresh=fncRefresh;
            this.fncSelection=fncSelection;
            R=length(names);
            this.nNonDflts=R;
            if this.hasDflts
                if this.app.highDef
                    factor=1.5;
                else
                    factor=.9;
                end
                scatterColName=['<html>' Html.ImgXy('colorWheel16.png',[],...
                    factor) '</html>'];
                if ~hideDflts
                    this.colors=zeros(R,3);
                    it=this.cbn.props.keySet.iterator;
                    while it.hasNext
                        k=it.next;
                        if ~nonDflts.contains(java.lang.String(lower(k)))
                            color=this.getDflt(k);
                            try
                                this.colors(end+1,:)=str2num(color);
                                this.names{end+1}=char(...
                                    this.cbn.spellProps.get(java.lang.String(k)));
                            catch ex
                                fprintf('Odd color %s for "%s"\n', char(k));
                            end
                        end
                    end
                    R=length(this.names);
                    columnNames={itemName, 'Red', 'Green', 'Blue', ...
                        scatterColName, '<html>Is de-<br>fault?</html>', ...
                        '<html>Used<br>here</html>'};
                    C=7;
                else
                    columnNames={itemName, 'Red', 'Green', 'Blue', ...
                        scatterColName, '<html>Is de-<br>fault?</html>',};
                    C=6;
                end
            else
                scatterColName=['<html>' Html.ImgXy('colorWheel.png',[],.5) '</html>'];
                columnNames={itemName, 'Red', 'Green', 'Blue', scatterColName};
                C=5;
                this.colors=zeros(R,3);
            end
            data=cell(R, C);
            this.statuses=zeros(1,R);
            this.statuses(:)=ColorsEditor.STATUS_DFLT;
            this.changed=false(R,1);
            if this.hasDflts 
                if ~hideDflts
                    for i=1:this.nNonDflts
                        [hex, clr, this.colors(i,:)]=Html.Scatter(colors(i,:),8);
                        data(i,:)={names{i}, clr(1), clr(2), clr(3),...
                            ['<html>&nbsp;' hex '</html>'], ...
                            this.getDfltStatusSym(i), true};
                    end
                    sym=['<html>' ColorsEditor.SYM_DFLT '</html>'];
                    for i=this.nNonDflts+1:R                        
                        [hex, clr, this.colors(i,:)]=Html.Scatter(this.colors(i,:),8);
                        data(i,:)={this.names{i}, clr(1), clr(2), clr(3), ...
                            ['<html>&nbsp;' hex '</html>'], sym, false};
                    end
                else
                    for i=1:this.nNonDflts
                        [hex, clr, this.colors(i,:)]=Html.Scatter(colors(i,:),8);
                        data(i,:)={names{i}, clr(1), clr(2), clr(3),...
                            ['<html>&nbsp;' hex '</html>'], ...
                            this.getDfltStatusSym(i)};
                    end
                end
            else
                for i=1:R
                    [hex, clr, this.colors(i,:)]=Html.Scatter(colors(i,:),8);
                    data(i,:)={names{i}, clr(1), clr(2), clr(3), ...
                        ['<html>&nbsp;' hex '</html>']};
                end
            end
            this.N=R;
            [fig, this.tb]=Gui.Figure;
            this.tb2=ToolBar.New(fig, false);
            this.initClrBtns(25);
            this.tb2.setEnabled(false)
            if hideDflts || strcmpi(context, 'Global Colors')
                and='';
            else
                and=' & defaults';
            end
            set(fig, 'Name', ['ColorsEditor for ' context ...
                and ' (' String.Pluralize2('color', R) ')']);
            this.table=SortTable(fig, data, columnNames,...
                [.02 .12 .96 .88], @(h,e)pick(this,h,e));
            this.resize;
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
            this.originalColors=this.colors;
            T.set('ColumnEditable', [false true, true, true, false], ...
                'CellEditCallback',@(h,c)editRgb(this, h,c));
            this.initSlider;
            this.initBtns;
            set(fig, 'CloseRequestFcn', @(h, e)hush(this, h));
            J=this.table.jtable;
            J.setAutoResort(false);
            if visible
                savedOrder=BasicMap.GetNumbers(this.app, this.getPropCO);
                if ~isempty(savedOrder)
                    try
                        SortTable.SetColumnOrder(J, savedOrder,...
                            BasicMap.GetNumbers(this.app, this.getPropW));
                    catch
                    end
                end
                SortTable.SetRowOrder(J, ...
                    BasicMap.GetNumbers(this.app, this.getPropRO));
                op=fig.OuterPosition;
                op(3)=floor(op(3)*1.175);
                fig.OuterPosition=op;
                op=BasicMap.GetNumbers(this.app, this.getPropOP);
                if ~isempty(op)
                    set(fig, 'OuterPosition', Gui.FitToScreen(op));
                end
                set(fig, 'visible', 'on');
            end
            this.mrByName=Map;
            for i=1:this.N
                this.mrByName.set(lower(this.names{i}), i);
            end
            if ~isempty(this.cbn)
                this.cbn.addListener(this);
            end
            this.originalDfltChange=...
                find(this.statuses==ColorsEditor.STATUS_DFLT_CHANGE);
        end
        
        function setPriorFig(this, fig)
            if ~isempty(this.other)
                obj=this.other;
            else
                obj=this;
            end            
            obj.priorFig=fig;
        end

        function setPriorJavaFig(this, priorJavaFig)
            if ~isempty(this.other)
                obj=this.other;
            else
                obj=this;
            end            
            obj.priorJavaFig=priorJavaFig;
        end

        function [color, original, changed]=get(this, name)
            if ~isempty(this.other)
                obj=this.other;
            else
                obj=this;
            end            
            idx=this.getModelRowChecked(name);
            if idx>0
                color=obj.colors(idx,:)/255;
                original=obj.originalColors(idx,:)/255;
                changed=obj.changed(idx);
            else
                color=[];
                original=[];
                changed=false;
            end
        end
        
        function idxs=getChangedIdxs(this, defaultsToo)
            idxs=[];
            if nargin>2 && defaultsToo
                N_=this.N;
            else
                N_=this.nNonDflts;
            end
            for i=1:N_
                if this.changed(i)
                    idxs(end+1)=i;
                end
            end
        end
        
        function ok=set(this, name, color)
            if ~isempty(this.other)
                obj=this.other;
            else
                obj=this;
            end
            J=obj.table.jtable;
            obj.updating=true;
            vStatus=J.convertColumnIndexToView(ColorsEditor.COL_DFLT_STATUS);
            mr=this.getModelRowChecked(name);
            if mr<1
                ok=false;
                return;
            end
            if all(color<=1)
                color=color*255;
                if all(color==1)
                    warning('Assuming "%s" with [1 1 1] means  white (not black?)', name);
                end
            end
            if isequal(round(color), round(this.colors(mr,:)))
                return;
            end
            name=obj.names{mr};
            vr=ColorsEditor.GetVisualRow(J, name);
            obj.setColor(color, mr, vr, ColorsEditor.COL_RGB, false);
            if this.hasDflts
                J.setValueAt(obj.getDfltStatusSym(mr), vr, vStatus);
            end
            if obj.alwaysRefresh
                obj.refresh;
            end
            obj.updateBtnsAndDfltStatus;
            drawnow;
            obj.updating=false;
            ok=true;
        end

        function ok=toFront(this)
            if ~isempty(this.other)
                obj=this.other;
            else
                obj=this;
            end
            if ishandle(obj.table.fig)
                set(obj.table.fig, 'visible', 'on');
                figure(obj.table.fig);
                ok=true;
            else
                ok=false;
            end
        end
        
        function close(this)
            if ~isempty(this.other)
                obj=this.other;
            else
                obj=this;
            end
            if ishandle(obj.table.fig)
                close(obj.table.fig);
            end
        end
        
        function ok=syncDflts(this, names, colors)
            J=this.table.jtable;
            this.updating=true;
            vStatus=J.convertColumnIndexToView(ColorsEditor.COL_DFLT_STATUS);
            [mrs, vrs]=this.getRowsByName(names);
            cnt=length(mrs);
            lookupColor=isempty(colors);
            for i=1:cnt
                mr=mrs(i);
                vr=vrs(i);
                if this.statuses(mr)==ColorsEditor.STATUS_DFLT
                    if mr>this.nNonDflts
                        if ~lookupColor
                            color=colors(i,:);
                        else
                            color=this.getDflt(mr);
                        end
                        this.setColor(color, mr, vr, ...
                            ColorsEditor.COL_RGB, false);
                    end
                end
                sym=this.getDfltStatusSym(mr);
                J.setValueAt(sym, vr, vStatus);
            end
            this.updateBtnsAndDfltStatus;
            drawnow;
            this.updating=false;
            ok=true;
            this.syncCnt=this.syncCnt+1;
        end

        function actionPerformed(this, H, event)
            if ~strcmp(event.type, 'changed')
                return;
            end
            this.syncDflts(event.names, event.colors);
        end
    end
    
    methods(Access=private)        
        function initBtns(this)
            path=BasicMap.Path;
            this.btnCopy=ToolBarMethods.addButton(this.tb, ...
                fullfile(path, 'Copy.png'), 'Copy selected row'' color for pasting',...
                @(h,e)copy(this));
            this.btnPaste=ToolBarMethods.addButton(this.tb, ...
                fullfile(path, 'Paste.png'), 'Paste copied color to selected row(s)',...
                @(h,e)pick(this, true));
            this.btnPaste.setForeground(java.awt.Color.RED);
             this.btnPick=ToolBarMethods.addButton(this.tb, ...
                fullfile(path, 'colorWheel16.png'), ...
                'Pick color from popup editor', ...
                @(h,e)pick(this), 'Pick');
            [~,H, this.btnRefresh]=Gui.ImageButton(fullfile(path, 'refresh.png'),...
                'Refresh use of changed colors',...
                @(h,e)refresh(this), this.table.fig);
            this.btnRefresh.setForeground(java.awt.Color.BLUE);
            this.btnRefresh.setEnabled(~this.alwaysRefresh);            
            set(H, 'Units', 'normalized', 'position', [0 .01 .18 .06]);
            [~,H]=javacomponent(Gui.CheckBox(...
                'Always refresh', this.alwaysRefresh,...
                this.app, ['ColorsEditor.AlwaysRefresh.' this.context],...
                @(h,e)hearAlwaysRefresh(this, h), 'Select to auto-refresh'));
            set(H, 'Units', 'normalized', 'position', [.19 .01 .23 .06]);
            this.btnResort=ToolBarMethods.addButton(this.tb, ...
                fullfile(path, 'table.gif'), ...
                'Resort', ...
                @(h,e)resort(this), 'Resort');
            if ColorsEditor.AUTO_REFRESH_SORT>0
                this.btnResort.setVisible(false);
            end
            this.mrDflts=cell(1,3);
            if ~isempty(this.cbn)
                this.initDfltBtns;
            end    
            this.updating=true;
            
            this.updateBtnsAndDfltStatus;
            drawnow;
            this.updating=false;
        end
        
        function initClrBtns(this, cnt)
            if nargin<2
                cnt=11;
            end
            j=Html.JET;
            N_=size(j,1);
            per=floor(N_/cnt);
            for i=1:cnt
                if i==1
                    row=1;
                else                    
                    row=i*per;
                end
                clr=j(row,:);
                cloud=ColorsEditor.Cloud(clr);
                ToolBarMethods.addButton(this.tb2, ...
                    [], ['<html>Set selections to color ' cloud '</html>'],...
                    @(h,e)recolorSelections(clr), ['<html>' cloud '</html>']);
            end
            
            function recolorSelections(newColor)
                this.updating=true;
                [mrs, vrs]=this.getSelectedRows;
                if isempty(mrs)
                    return;
                end
                this.setColor(newColor, mrs, vrs, ColorsEditor.COL_RGB, false);
                if this.alwaysRefresh
                    this.refreshLater;
                end
                this.updateBtnsAndDfltStatus(mrs, vrs);
                drawnow;
                this.updating=false;                
            end
        end
        
        function resort(this)
            J=this.table.jtable;
            ro=SortTable.GetRowOrder(J);
            J.unsort;
            SortTable.SetRowOrder(J, ro);
            vrs=J.getSelectedRows;
            if ~isempty(vrs)
                rect=J.getCellRect(vrs(end),0, true);
                J.scrollRectToVisible(rect);
            end
            if ColorsEditor.AUTO_REFRESH_SORT>0
                this.btnResort.setVisible(false);
            end
            drawnow;
        end
        
        function refresh(this, source)
            disp('refreshing ......');
            if nargin<2
                source=[];
            end
            this.updating=true;            
            if ~isempty(this.fncRefresh)
                try
                    feval(this.fncRefresh, this, source);
                catch ex
                    ex.getReport
                end
            end
            if this.hasDflts
                J=this.table.jtable;
                vStatus=J.convertColumnIndexToView(ColorsEditor.COL_DFLT_STATUS);
                mrs=find(this.changed);
                nChanges=length(mrs);
                for i=1:nChanges
                    mr=mrs(i);
                    name=this.names{mr};
                    this.changed(mr)=false;
                    vr=ColorsEditor.GetVisualRow(J, name);
                    J.setValueAt(this.getDfltStatusSym(mr), vr, vStatus);
                end
            else
                this.changed(:)=false;
            end
            this.updateBtnsAndDfltStatus;
            drawnow;
            this.updating=false;
        end
        
        function hearAlwaysRefresh(this, h)
            this.alwaysRefresh=h.isSelected;
            nChanges=sum(this.changed);
            if this.alwaysRefresh
                if nChanges>0
                    this.btnRefresh.doClick;
                    return;
                end
            end
            this.btnRefresh.setEnabled(~this.alwaysRefresh && nChanges>0);
        end
        
        function initDfltBtns(this)
            path=BasicMap.Path;
            ToolBarMethods.addComponent(this.tb, ...
                Gui.Label('    Defaults:  '));
            this.btnChangeDflts=...
                ToolBarMethods.addButton(this.tb, ...
                fullfile(path, 'scissors.png'), '',...
                @(h,e)alterDflts(this, ...
                ColorsEditor.STATUS_DFLT_CHANGE), 'Change    ');
            this.btnUseDflts=ToolBarMethods.addButton(this.tb, ...
                fullfile(path, 'reset.png'), '',...
                @(h,e)useDflts(this), 'Reset    ');
            this.btnAddDflts=ToolBarMethods.addButton(this.tb, ...
                fullfile(path, 'plus.gif'), ...
                ['<html>' ColorsEditor.SYM_DFLT_NEW ...
                'Add new defaults</html>'],...
                @(h,e)alterDflts(this, ColorsEditor.STATUS_DFLT_NEW), 'Add    ');
            this.btnRestoreBackup=ToolBarMethods.addButton(this.tb, ...
                    fullfile(path, 'recycle.png'), 'Restore all previous defaults',...
                    @(h,e)restoreBackup(this), 'Reset    ');
            if isempty(this.cbn)
                this.btnRestoreBackup.setVisible(false);
            end
            this.btnHideDflts=ToolBarMethods.addButton(this.tb, ...
                fullfile(path, 'hide.png'), ...
                'Show/hide default colors', ...
                @(h,e)showHideDflts(this, h, e));
            this.setDfltHideBtn;
            f=this.btnHideDflts.getFont;
            this.btnHideDflts.setFont(java.awt.Font(f.getFontName, f.BOLD, f.getSize*.7))
        end
        
        function restoreBackup(this)
            choice=Gui.Ask(Html.WrapHr([...
                String.Pluralize2('change', this.changedDflts) ' to '...
                ' defaults']), {'Restore prior', 'See changes'}, ...
                'ColorsEditor.restoreBackup', 'Defaults backup', 1);
            if isempty(choice) || choice==0
                return;
            end
            switch choice
                case 1
                    [ok, names_, colors_]=this.cbn.restoreBackup;
                    if ~ok
                        return;
                    end
                case 2
                    this.cbn.compareBackup
                    return;
            end
            this.changedDflts=0;
            this.cbn.notify(this, names_, colors_, true, true);
            
        end

        function readGlobalColors(this, makeBackup)
            prior=this.cbn;
            cbn_=this.app.colorsByName;
            if makeBackup
                cbn_.backup;
            else
                cbn_.backupFile=prior.backupFile;
            end
            this.cbn=cbn_;
        end
        
        function setDfltHideBtn(this)
            b=this.btnHideDflts;
            if this.hideDflts
                b.setText(' See defaults not used here');
                b.setIcon(Gui.Icon('eye.gif'));
            else
                b.setText(' Hide defaults not used here');
                b.setIcon(Gui.Icon('hide.png'));
            end
        end
        
        function ok=warnAboutGlobalEffects(this, N_)
            if N_>1
                s=['these ' num2str(N_) ' ' this.itemName ' colors'];
                s2='these names are';
            else
                s=['this 1 ' this.itemName ' color'];
                s2='this name is';
            end
            question=Html.WrapHr(['If you update defaults with ' s '<br>'...
                '<b>then</b> this affects <b><u><font color="red">every '...
                'where</font></u></b> that ' s2 ' used ... <br>Continue?']);
            ok=askYesOrNo(struct('msg', question, ...
                    'icon', 'warning.png'), ['Overriding ' s], 'north', ...
                    true, 'colorsEditor.globalWarning');
        end
        
        function done=alterDflts(this, status, overrideMrs)
            done=false;
            if nargin<3
                mrs=this.mrDflts{status};
            else
                mrs=overrideMrs;
            end
            N_=length(mrs);
            if status==ColorsEditor.STATUS_DFLT_CHANGE
                if ~this.warnAboutGlobalEffects(N_)
                    return;
                end
            end
            done=true;
            this.updating=true;
            J=this.table.jtable;
            vStatus=J.convertColumnIndexToView(ColorsEditor.COL_DFLT_STATUS);
            for i=1:N_
                mr=mrs(i);
                name=this.names{mr};
                this.cbn.update1(name, this.colors(mr,:));
                vr=ColorsEditor.GetVisualRow(J, name);
                J.setValueAt(this.getDfltStatusSym(mr), vr, vStatus);
            end
            if ~isempty(this.cbn)
                this.changedDflts=this.changedDflts+1;
                this.cbn.notify(this, this.names(mrs),...
                    this.colors(mrs,:), true);
                this.cbn.save;
            end
            this.updateBtnsAndDfltStatus;
            drawnow;
            this.updating=false;
        end
        
        function useDflts(this)
            mrs=this.mrDflts{ColorsEditor.STATUS_DFLT_CHANGE};
            N_=length(mrs);
            J=this.table.jtable;
            this.updating=true;
            vStatus=J.convertColumnIndexToView(ColorsEditor.COL_DFLT_STATUS);
            clrs=[ColorsEditor.COL_RGB];
            for i=1:N_
                mr=mrs(i);
                name=this.names{mr};
                dfltColor=str2num(this.getDflt(name));
                vr=ColorsEditor.GetVisualRow(J, name);
                this.setColor(dfltColor, mr, vr, clrs, i==N_);
                J.setValueAt(this.getDfltStatusSym(mr), vr, vStatus);
            end
            this.updateBtnsAndDfltStatus;
            drawnow;
            this.updating=false;
            if this.alwaysRefresh
                this.refreshLater;
            end
        end
        
        function resortLater(this)
            MatBasics.RunLater(@(h,e)resort(this), .15);
        end

        function refreshLater(this)
            disp('refreshing LATER......');
            MatBasics.RunLater(@(h,e)refresh(this), .15);
        end

        function ok=queryChangedDflts(this)
            finalDfltChange=find(this.statuses==ColorsEditor.STATUS_DFLT_CHANGE);
            ok=true;
            if strcmpi('on', this.table.fig.Visible) ...
                    && ~isequal(this.originalDfltChange, finalDfltChange)
                l1=false(1, length(this.statuses));
                l2=false(1, length(this.statuses));
                l1(this.originalDfltChange)=true;
                l2(finalDfltChange)=true;
                nChanges=sum(l2 & ~l1);
                
                if nChanges>0
                    ttl=String.Pluralize2('color change', ...
                        nChanges);
                    
                    if nChanges>1
                        str=['are ' num2str(nChanges) ...
                            ' color changes for items that have <br>'...
                            'global defaults with the same name...<br>'...
                            'Update these globals'];
                        
                    else
                        str=['is 1 color change for an item<br>that '...
                            'has a global default with the same'...
                            ' name...<br>Update this global'];
                    end
                    [yes, cancelled]=askYesOrNo(Html.WrapHr( ...
                        ['There  ' str '?']), ['You have ' ttl '...'], ...
                        'center', false, ...
                        [], 'ColorsEditor.Hush');
                    if cancelled
                        ok=false;
                        return;
                    end
                    if yes
                        if ~this.alterDflts(...
                                ColorsEditor.STATUS_DFLT_CHANGE,...
                                finalDfltChange)
                            ok=false;
                            return
                        end
                    end
                end
            end
        end
        
        function hush(this, h)
            if ~this.queryChangedDflts
                return;
            end
            J=this.table.jtable;
            props=this.app;
            [columnOrder, widths]=SortTable.GetColumnOrder(J);
            props.set(this.getPropCO, num2str(columnOrder));
            props.set(this.getPropW, num2str(widths));
            rowOrder=SortTable.GetRowOrder(J);
            props.set(this.getPropRO, MatBasics.Encode(...
                rowOrder));
            props.set(this.getPropOP, num2str(get(h, 'OuterPosition')));
            set(h, 'visible', 'off');
            if ~isempty(this.cbn)
                this.cbn.removeListener(this);
            end
            delete(this.table.fig)
            if ~isempty(this.other)
                delete(this.other.table.fig);
            end
            if ~isempty(this.priorJavaFig) && this.priorJavaFig.isVisible
                this.priorJavaFig.requestFocus;
                this.priorJavaFig.toFront;
            elseif ~isempty(this.priorFig) && ishandle(this.priorFig)
                figure(this.priorFig);
            end
        end
        
        function showHideDflts(this, h, e)
            if ~this.queryChangedDflts
                return;
            end
            hide=~this.hideDflts;
            pu=PopUp('Re-populating ColorsEditor table');
            %names, colors, itemName, dflts, hideDflts, fncRefresh, visible
            r=1:this.nNonDflts;
            mrs=this.getSelectedRows;
            creatingNew=isempty(this.other);
            if ~creatingNew
                that=this.other;
                that.other=[];
                this.other=[];
                if this.syncCnt>0
                    try
                        that.syncDflts(...
                            StringArray.Cell(this.cbn.props.keySet),[]);
                        that.syncCnt=0;
                    catch ex
                        ex.getReport
                    end
                end
                if ~isempty(that.cbn)
                    this.cbn.removeListener(this);
                    that.cbn.addListener(that);
                end
            else
                if isempty(this.cbn)
                    dfltsArg=[];
                else
                    dfltsArg=this.cbn;
                end
                if ~isempty(this.cbn)
                    this.cbn.removeListener(this);
                end
                that=ColorsEditor(this.names(r), this.colors(r,:), ...
                    this.itemName, dfltsArg, hide, ...
                    this.fncRefresh, this.fncSelection, false, ...
                    this.alwaysRefresh, this.context);
                that.other=this;
                this.other=that;
                that.originalDfltChange=this.originalDfltChange;
                that.priorFig=this.priorFig;
                that.priorJavaFig=this.priorJavaFig;
            end
            that.updating=true;
            J=that.table.jtable;
            if length(this.changed)<length(that.changed)
                r=1:this.nNonDflts;
                that.changed(r)=this.changed(r);
            else
                that.changed=this.changed;
            end
            vStatus=J.convertColumnIndexToView(ColorsEditor.COL_DFLT_STATUS);
            for mr=1:that.N
                if that.changed(mr)
                    name=that.names{mr};
                    vr=ColorsEditor.GetVisualRow(J, name);
                    J.setValueAt(that.getDfltStatusSym(mr), vr, vStatus);
                end
            end
            that.table.fig.OuterPosition=this.table.fig.OuterPosition;
            [columnOrder, widths]=SortTable.GetColumnOrder(this.table.jtable);
            try
                SortTable.SetColumnOrder(J, columnOrder, widths, true);
            catch ex
                ex.getReport
            end
            J.unsort;
            SortTable.SetRowOrder(J, ...
                SortTable.GetRowOrder(this.table.jtable));
            nSelections=length(mrs);
            if nSelections>0
                vName=J.convertColumnIndexToView(ColorsEditor.COL_NAME);
                lastVr=-1;
                for i=1:nSelections
                    if mrs(i)<=that.N
                        name=that.names{mrs(i)};
                        vr=ColorsEditor.GetVisualRow(J, name);
                        if vr>=0
                            J.changeSelection(vr, vName, true, false);
                            lastVr=vr;
                        end
                    end
                end
                if lastVr>=0
                    rect=J.getCellRect(vr, 0, true);
                    J.scrollRectToVisible(rect);
                end
            end
            that.updateBtnsAndDfltStatus;
            drawnow;
            that.updating=false;
            set(that.table.fig, 'Visible', 'on');
            if ~creatingNew
                delete(this.table.fig);
            else
                set(this.table.fig, 'Visible', 'off');
            end
            pu.close;
        end
        
        function copy(this)
            [mrs, vrs]=this.getSelectedRows;
            cnt=length(vrs);
            if cnt<1
                msg('First select a row...', 5, 'north east+');
                return;
            end
            this.updating=true;
            
            this.pastedColor=this.colors(mrs(1), :);
            this.btnPaste.setEnabled(~isempty(this.table.jtable.getSelectedRow));
            tip=['<html>Click to paste' Html.Scatter(this.pastedColor,8) '</html>'];
            this.btnPaste.setToolTipText(tip);
            this.updateBtnsAndDfltStatus;
            drawnow;
            this.updating=false;
        end
        
        function resize(this)
            tcm=this.table.jtable.getColumnModel;
            factor=1;
            try
                if this.app.highDef
                    factor=this.app.toolBarFactor*.82;
                elseif ispc
                    factor=2;
                end
            catch
            end
            tcm.getColumn(ColorsEditor.COL_NAME).setPreferredWidth(255*factor)
            tcm.getColumn(ColorsEditor.COL_RED).setPreferredWidth(54*factor)
            tcm.getColumn(ColorsEditor.COL_GREEN).setPreferredWidth(54*factor)
            tcm.getColumn(ColorsEditor.COL_BLUE).setPreferredWidth(54*factor)
            if ispc
                tcm.getColumn(ColorsEditor.COL_SCATTER).setPreferredWidth(50*factor)
            else
                tcm.getColumn(ColorsEditor.COL_SCATTER).setPreferredWidth(74*factor)
            end
            if this.hasDflts
                tcm.getColumn(ColorsEditor.COL_DFLT_STATUS).setPreferredWidth(87*factor)
                if ~this.hideDflts
                    tcm.getColumn(ColorsEditor.COL_USED_HERE).setPreferredWidth(44*factor)
                end
            end
        end
        
        function pick(this, H, E)
            if this.updating 
                return;
            end
            this.updating=true;
            if nargin>2 && isempty(E.Indices)
                this.updateBtnsAndDfltStatus;
                drawnow;
                this.updating=false;
                this.tb2.setEnabled(false)
                return;
            end
            J=this.table.jtable;
            vScatter=J.convertColumnIndexToView(ColorsEditor.COL_SCATTER);
            if nargin>2
                scatterRow=find(E.Indices(:,2)==vScatter+1,1);
                if isempty(scatterRow) 
                    this.updateBtnsAndDfltStatus;
                    drawnow;
                    this.updating=false;
                    Html.remove(char(J.getValueAt(E.Indices(1,1)-1, vScatter)))
                    if ~isempty(this.fncSelection)
                        try
                            feval(this.fncSelection, this, this.getSelectedRows);
                        catch ex
                            ex.getReport
                        end
                    end
                    this.tb2.setEnabled(true)
                    return;
                end
                vr=E.Indices(scatterRow,1)-1;
            end
            [mrs, vrs]=this.getSelectedRows;
            cnt=length(vrs);
            if cnt<1
                msg('First select a row...', 5, 'north east+');
                drawnow;
                this.updating=false;
                return;
            end
            if cnt<2
                cnt='';
            else
                cnt=['( + ' String.Pluralize2('other', cnt-1) ')'];
            end
            vName=J.convertColumnIndexToView(ColorsEditor.COL_NAME);
            if nargin==2 
                if isempty(this.pastedColor)
                    msg('First copy a row''s color...', 5, 'north east+');
                    drawnow;
                    this.updating=false;
                    return;
                end
                newColor=this.pastedColor;
            else
                if nargin<3
                    vr=vrs(1);
                end
                item=char(J.getValueAt(vr, vName));
                r=this.getModelRow(item);
                newColor=Gui.SetColor(Gui.JFrame(this.table.fig), ...
                    ['Pick for "' item '"' cnt ], ...
                    this.colors(r,:)/255);
            end
            if ~isempty(newColor)
                this.setColor(newColor, mrs, vrs, ColorsEditor.COL_RGB, false);
                if this.alwaysRefresh
                    this.refreshLater;
                end
            end
            this.updateBtnsAndDfltStatus(mrs, vrs);
            if nargin>2
                vName=J.convertColumnIndexToView(ColorsEditor.COL_NAME);
                J.changeSelection(vr, vName, true, false);
                J.changeSelection(vr, vScatter, true, false);
                drawnow;
                this.updateBtnsAndDfltStatus;
            end
            drawnow;
            this.updating=false;
            if ~isempty(this.fncSelection)
                try
                    feval(this.fncSelection, this, mrs);
                catch ex
                    ex.getReport
                end
            end
        end
        
        
        function [mrs, vrs]=getSelectedRows(this, editRow)
            % Get selected rows 
            % RETURNS
            %   vrs is 0 based visual format for JTable getValueAt
            %   rs is 1 based for MatLab uitable Data model
            vrs=this.table.jtable.getSelectedRows';
            if nargin>1
                r=int32(editRow);
                if isempty(find(vrs==r, 1))
                    vrs=[editRow this.table.jtable.getSelectedRows'];
                end
            end
            mrs=this.getModelRows(vrs);
        end
        
        function editRgb(this, H, E)
            if this.updating
                return;
            end
            try
                numval = eval(E.EditData);
            catch
                numval=0;
            end
            c = E.Indices(2);
            switch c-1
                case ColorsEditor.COL_RED
                case ColorsEditor.COL_GREEN
                case ColorsEditor.COL_BLUE
                otherwise
                    return;
            end
            J=this.table.jtable;
            set(this.table.uit, 'CellEditCallback', []);
            this.updating=true;
            r = E.Indices(1);
            red=this.colors(r, 1);
            green=this.colors(r, 2);
            blue=this.colors(r, 3);
            color=[red green blue];
            if numval<=1
                color(c-1)=numval*255;
            else
                color(c-1)=numval;
            end
            vr=int32(ColorsEditor.GetVisualRow(J, this.names{r}));
            [mrs, vrs]=this.getSelectedRows(vr);
            this.setColor(color, mrs, vrs, c-1, false);
            this.updateBtnsAndDfltStatus(mrs, vrs);
            drawnow;
            if length(vrs)==1
                vcs=J.getSelectedColumns;
                if length(vcs)==1
                    vScatter=J.convertColumnIndexToView(ColorsEditor.COL_SCATTER);
                    if vcs(1)==vScatter
                        J.changeSelection(vrs(1), vScatter, true, false);
                        drawnow;
                    end
                end                
            end
            this.updating=false;
            set(this.table.uit, 'CellEditCallback',@(h,c)editRgb(this, h,c));
            if this.alwaysRefresh
                this.refreshLater;
            end
        end
        
        function [mrs, vrs]=getRowsByName(this, names)
            N_=length(names);
            if N_>0
                mrs=[];
                for i=1:N_
                    name=lower(names{i});
                    if this.mrByName.containsKey(name)
                        mrs(end+1)=this.mrByName.get(name);
                    end
                end
            else
                mrs=1:this.N;
            end
            if nargout>1
                J=this.table.jtable;
                N_=length(mrs);
                vrs=zeros(1, N_);
                for i=1:N_
                    mr=mrs(i);
                    vr=ColorsEditor.GetVisualRow(J, this.names{mr});
                    if vr<0
                        vr=ColorsEditor.GetVisualRow(J, lower(this.names{mr}));
                    end
                    vrs(i)=vr;
                end
            end
        end
        
        function mrs=getModelRows(this, vrs)
            N_=length(vrs);
            mrs=zeros(1,N_);
            J=this.table.jtable;
            vName=J.convertColumnIndexToView(ColorsEditor.COL_NAME);
            for i=1:N_
                %name=char(J.getValueAt(vr(i), vName));
                %for row=1:this.N
                %    if isequal(this.names{row}, name)
                %        mrs(i)=row;
                %        row
                %        break;
                %    end
                %end
                %this.mrByName.get(name)
                mrs(i)=this.mrByName.get(lower(...
                    char(J.getValueAt(vrs(i), vName))));
            end
        end
        
        function mr=getModelRow(this, name)
            mr=this.mrByName.get(lower(name));
            %for row=1:this.N
            %    if isequal(this.names{row}, name)
            %        row
            %        this.mrByName.get(name)
            %        return;
            %    end
            %end
            %row=0;
            this.names{mr}
        end
        
        function row=getModelRowChecked(this, name)
            row=this.mrByName.get(lower(name));
            if isempty(row)
                row=0;
            end
        end
        
        function prop=getPropOP(this)
            prop=[ColorsEditor.PROP_OP '.' this.context];
        end
        
        function prop=getPropRO(this)
            prop=[ColorsEditor.PROP_RO '.' this.context];
        end
        
        function prop=getPropCO(this)
            prop=[ColorsEditor.PROP_CO '.' num2str(...
                this.table.jtable.getColumnCount) '.' this.context];
        end
        
        function prop=getPropW(this)
            prop=[ColorsEditor.PROP_W '.' num2str(...
                this.table.jtable.getColumnCount) '.' this.context];
        end
    end
    
    methods(Static, Access=private)
        function s=Cloud(color)
            if ispc
                s=['<font ' Gui.HtmlHexColor(color) ...
                    ' size="8">&#9729;</font>'];
            else
                s=['<font ' Gui.HtmlHexColor(color) ...
                    ' size="5">&#9729;</font>'];
            end
        end
        
        function row=GetModelRow(H, name)
            N=size(H.Data, 1);
            for row=1:N
                if isequal(H.Data{row, 1}, name)
                    return;
                end
            end
            row=0;
        end
        
        function row=GetVisualRow(J, name)
            vc=J.convertColumnIndexToView(ColorsEditor.COL_NAME);
            N=J.getRowCount;
            for row=0:N-1
                nm=char(J.getValueAt(row, vc));
                if isequal(name,nm)
                    return;
                end
            end
            row=-1;
        end
        
        
        function [r, vr, N]=GetModelRows(vr, H, J)
            vr=unique(vr)';
            N=length(vr);
            r=zeros(1,N);
            vN=J.convertColumnIndexToView(ColorsEditor.COL_NAME);
            for i=1:N
                r(i)=ColorsEditor.GetModelRow(H, ...
                    char(J.getValueAt(vr(i), vN)));
            end
            disp(r)
            disp(vr)
        end
        
        function SetRgb(J, vr, rgbIdx, color)
            %NOTE rgb index is same as 1 based model column index
            visualColumn=J.convertColumnIndexToView(rgbIdx);
            if color(rgbIdx)>=255
                s='1.0';
            elseif color(rgbIdx)<=0
                s='0.0';
            else
                s=num2str(color(rgbIdx)/255);
            end
            J.setValueAt(s, vr, visualColumn);
        end
    end
    
    methods(Access=private)
        function setColor(this, color, mrs, vrs, rgbIdxs, forceResort)
            assert(this.updating, 'Set this.updating=true, when done drawnow + updating=false!!!');
            J=this.table.jtable;
            vScatter=J.convertColumnIndexToView(ColorsEditor.COL_SCATTER);
            if all(color<=1)
                color=color*255;
                if all(color==1)
                    warning('Assuming "%s" [1 1 1] is white (not black?)', this.names{mr(1)});
                end
            end
            this.colors(mrs, :)/255
            nRgb=length(rgbIdxs);
            nRows=length(mrs);
            for row=1:nRows
                for col=1:nRgb
                    rgbIdx=rgbIdxs(col);
                    ColorsEditor.SetRgb(J, vrs(row), rgbIdx, color);
                    this.colors(mrs(row), rgbIdx)=color(rgbIdx);
                end
                html=Html.Scatter(this.colors(mrs(row), :),8) ;
                disp([ this.names{mrs(row)} '==' html])
                J.setValueAt(['<html>&nbsp;' html '</html>' ], ...
                    vrs(row), vScatter);
                this.changed(mrs(row))=true;
            end
            if ColorsEditor.AUTO_REFRESH_SORT>0
                rowOrder=SortTable.GetRowOrder(J);
                if any(ismember(rowOrder, ColorsEditor.COL_COLORS))
                    if ColorsEditor.AUTO_REFRESH_SORT==1
                        if nRows>1 || forceResort
                        this.btnResort.setVisible(true);
                    end
                    if nRows==1 && ~forceResort
                        this.btnResort.setVisible(true);
                    end
                    else
                        this.resortLater;
                    end
                end
            end
            this.colors(mrs, :)/255
        end
        
        function [strColor, color]=getDflt(this, name)
            strColor=this.cbn.getStrColor255(name);
            if nargout>1
                color=str2num(color);
            end
        end
        
        function [sym, status]=getDfltStatusSym(this, mr)
            addCloud=false;
            strClr=this.getDflt(this.names{mr});
            if isempty(strClr)
                status=ColorsEditor.STATUS_DFLT_NEW;
                sym=ColorsEditor.SYM_DFLT_NEW;
            else
                color=str2num(strClr);
                % properties defaults and this.colors are 0 to 255
                if all(abs(this.colors(mr,:)-color)<=1.1)
                    status=ColorsEditor.STATUS_DFLT;
                    sym=ColorsEditor.SYM_DFLT;
                else
                    status=ColorsEditor.STATUS_DFLT_CHANGE;
                    sym=ColorsEditor.SYM_DFLT_CHANGE ;
                    addCloud=true;
                end
            end
            if ispc && this.app.highDef
                sym=strrep(sym, '"5"', '"8"');
            elseif mr<=this.nNonDflts && this.changed(mr) %indicate refresh neede
                sym=strrep(sym, '"5"', '"7"');
            end
            if addCloud
                sym=[sym ColorsEditor.Cloud(color)];
            end
            sym=['<html>' sym '</html>'];
            this.statuses(mr)=status;
        end
        
        function updateBtnsAndDfltStatus(this, mrs, vrs)
            if nargin<3
                [mrs, vrs]=this.getSelectedRows;
            end
            nChanges=sum(this.changed);
            if nChanges==0
                this.btnRefresh.setEnabled(false);
                this.btnRefresh.setText('');
            else
                this.btnRefresh.setEnabled(true);
                this.btnRefresh.setText(['Refresh ' num2str(nChanges)]);
            end
            if isempty(vrs)
                this.btnCopy.setEnabled(false);
                this.btnPaste.setEnabled(false);
                this.btnPick.setEnabled(false);
                this.btnPaste.setText('');
                this.btnPick.setText('');
                if this.hasDflts
                    this.mrDflts=cell(1,3);
                    for i=ColorsEditor.STATUS_DFLT:ColorsEditor.STATUS_DFLT_NEW
                        this.mrDflts{i}=find(this.statuses==i);
                    end
                    this.resolveDfltBtns;
                end
                this.updateSlider(mrs, vrs);
                return;
            end
            cnt=length(mrs);
            strCnt=num2str(cnt);
            this.btnCopy.setEnabled(true);
            if ~isempty(this.pastedColor)
                this.btnPaste.setText(strCnt);
                this.btnPaste.setEnabled(true);
            else
                this.btnPaste.setText('');
                this.btnPaste.setEnabled(false);
            end
            this.btnPick.setEnabled(true);
            this.btnPick.setText(strCnt);
            if ~this.hasDflts
                return;
            end
            this.mrDflts=cell(1,3);
            J=this.table.jtable;
            vStatus=J.convertColumnIndexToView(ColorsEditor.COL_DFLT_STATUS);
            for i=1:cnt
                mr=mrs(i);
                vr=vrs(i);
                [sym, status]=this.getDfltStatusSym(mr);
                J.setValueAt(sym, vr, vStatus);
                this.mrDflts{status}=[this.mrDflts{status} mr];
            end
            this.resolveDfltBtns;
            this.updateSlider(mrs, vrs);
        end
        
        function resolveDfltBtns(this)
            if this.table.jtable.getSelectedRowCount>0
                w=' the selected ';
            else
                w=' the relevant ';
            end
            cntChange=length(this.mrDflts{ColorsEditor.STATUS_DFLT_CHANGE});
            this.btnChangeDflts.setEnabled(cntChange>0);
            this.btnUseDflts.setEnabled(cntChange>0);
            strCntChange=num2str(cntChange);
            s=String.Pluralize2(this.itemName, cntChange);
            this.btnChangeDflts.setText(strCntChange);
            if ispc && this.app.highDef
                symTip=ColorsEditor.SYM_DFLT_CHANGE_TIP_HD;
            else
                symTip=ColorsEditor.SYM_DFLT_CHANGE_TIP;
            end
            this.btnChangeDflts.setToolTipText(['<html>Click ' ...
                symTip ' to update default colors<br>for' w ...
                s '.</html>']);
            this.btnUseDflts.setText(strCntChange);
            this.btnUseDflts.setToolTipText(['<html>' ...
                ColorsEditor.SYM_DFLT ...
                ' Reset ' s ' to their default colors.</html>']);
            cntNew=length(this.mrDflts{ColorsEditor.STATUS_DFLT_NEW});
            this.btnAddDflts.setEnabled(cntNew>0);
            this.btnAddDflts.setText(num2str(cntNew));
            s=String.Pluralize2(this.itemName, cntNew);
            if ispc && this.app.highDef
                symTip=ColorsEditor.SYM_DFLT_NEW_TIP_HD;
            else
                symTip=ColorsEditor.SYM_DFLT_NEW_TIP;
            end
            this.btnAddDflts.setToolTipText(['<html>Click ' symTip ...
                ' to add default colors<br>for' w s '.</html>']);
            this.btnRestoreBackup.setEnabled(this.changedDflts>0);
            this.btnRestoreBackup.setText(num2str(this.changedDflts));
            if ~isempty(this.mrByName)
                if ispc && this.app.highDef
                    xTip=40;
                    yTip=-120;
                else
                    xTip=20;
                    yTip=-70;
                end
                if cntChange>0
                    this.app.showToolTip(this.btnChangeDflts, [], ...
                        xTip, yTip, 10, [], false);
                elseif cntNew>0
                    this.app.showToolTip(this.btnAddDflts, [], ...
                        xTip, yTip, 10, [], false);
                else
                    this.app.closeToolTip;
                end
            end
        end
    end
    
    methods(Static)
        function this=NewFromPlot(htmlNames, Hs, btns, sortI, ...
                priorJavaFig, itemName)
            if nargin<6
                itemName='UMAP Supervisor';
                if nargin<5
                    priorJavaFig=[];
                end
            end
            FONT='<font  color="';
            FONT_LEN=length(FONT);
            N=length(htmlNames);
            names=cell(1,N);
            colors=zeros(N,3);
            bullIdxs=zeros(1,N);
            for i=1:N
                name=htmlNames{i};
                idxs=strfind(name, '<sup>');
                if ~isempty(idxs)
                    name=strtrim(name(1:idxs(end)-1));
                end
                names{i}=char(edu.stanford.facs.swing.Basics.RemoveXml(name));
                colors(i,:)=get(Hs(i), 'MarkerEdgeColor');
                bullIdxs(i)=btns.get(i-1).getText.indexOf(FONT)+1;
            end
            this=ColorsEditor(names, colors, ...
                itemName, true, true, @refresh, @(ce, E)select(E), ...
                true, true, 'UMAP');
            this.priorJavaFig=priorJavaFig;
            function select(mrs)
                if length(mrs)~=1
                    return;
                end
                if mrs(1)<N
                    btn=btns.get(find(sortI==mrs(1))-1);
                    btn.doClick;
                    btn.doClick;
                end
            end

            function click(btn)
                btn.doClick;
            end
            
            function refresh(CE, source)
                if ~isempty(source)
                    return;
                end
                mrs=CE.getChangedIdxs;
                nMrs=length(mrs);
                for ii=1:nMrs
                    mr=mrs(ii);
                    old=CE.originalColors(mr,:)/255;
                    color=CE.colors(mr,:)/255;
                    set(Hs(mr), 'MarkerEdgeColor', color);
                    changeBtn(mr, color);
                end
            end
            
            function changeBtn(mr, color)
                if nargin<2
                    color=colors(mr,:);
                end
                btn=btns.get(find(sortI==mr)-1);
                b=char(btn.getText);
                newStr=[b(1:bullIdxs(mr)+FONT_LEN-1) Gui.HexColor(color) ...
                        '">' b(bullIdxs(mr)+FONT_LEN+9:end) ];
                btn.setText(newStr);
            end
        end
    end
    
    properties(Constant)
        START_COLOR=[0 0 0];
        END_COLOR=[1 1 1];
        DEBUG_SLD=false;
    end
    
    properties(SetAccess=private)
        sldClrs;
        sld;
        sldClrsStart=ColorsEditor.START_COLOR;
        sldClrsEnd=ColorsEditor.END_COLOR;
        sldClrStartJ;
        sldClrEndJ;
        sldMrs;
        sldVrs;
        sldPnl;
        sldCnt;
    end
    
    methods(Access=private)
        function initSlider(this)
            fig_=this.table.fig;
            bgc=fig_.Color .*.91;
            u=uipanel(gcf, 'units', 'normalized', ...
                'position', [.42 .01 .58 .105], ...
                'BackgroundColor', fig_.Color);
            this.sldClrStartJ=Gui.NewLabel(...
                .01, .01, ['<html>' ...
                ColorsEditor.Cloud(ColorsEditor.START_COLOR) '</html>'], ...
                u, bgc);
            this.sldClrEndJ=Gui.NewLabel(.94, .01, ['<html>' ...
                ColorsEditor.Cloud(ColorsEditor.END_COLOR) '</html>'], ...
                u, bgc);
            this.sld=uicontrol(u, 'style', 'slider', ...
                'Units', 'Normalized', 'Position', [.085 .01 .83 .551], ...
                'Callback', @(h,e)sldChanged(this));
            addlistener(this.sld, 'ContinuousValueChange', ...
                @(h,e)sldChanging(this));
            this.sldPnl=u;
            this.updateSlider([],[]);
        end

        function [clrs, tip, exceededMin]=sldTip(this, perc, word)
            MAX_SHOW1=4;
            if nargout>0
                MAX_SHOW2=10;
            else
                MAX_SHOW2=MAX_SHOW1;
            end
            img='&#10140;';%Html.Img('rightArrowNarrow.png');%'&#10140;'
            cnt=this.sldCnt;
            exceededMin=cnt>MAX_SHOW1;
            clrs=zeros(cnt, 3);
            str='';
            for i=1:cnt
                clr=this.sldClrsStart(i,:)+...
                    ((this.sldClrsEnd(i,:)-this.sldClrsStart(i,:))*perc);
                
                if i<=MAX_SHOW2
                    str=[str ColorsEditor.Cloud(this.sldClrs(i,:)) img ...
                        ColorsEditor.Cloud(clr) ', ' ];
                elseif i==MAX_SHOW2+1
                    str=[str '+' num2str(cnt-MAX_SHOW2) ' more '];
                    if nargout==0
                        break;
                    end
                end
                if MAX_SHOW2>MAX_SHOW1 && i== MAX_SHOW1+1
                    str=[str '</td></tr><tr><td>'];
                end
                clrs(i,:)=clr;
            end
            tip=['<html><center>' word ' ' String.Pluralize2('color', ...
                cnt) ' from ' img ' to:'...
                '<hr><table><tr><td>' str ...
                '</td></tr></table><hr></center></html>'];
            if nargout==0
                this.app.showToolTip(this.sldClrStartJ, tip, 200, -80);
            end
        end
        
        function sldChanging(this)
            this.sldTip(this.sld.Value, 'Shading');
        end

        function sldChanged(this)
            [clrs, tip, exceededMin]=this.sldTip(this.sld.Value, 'Shaded');
            mrs=this.sldMrs;
            vrs=this.sldVrs;
            cnt=this.sldCnt;
            this.updating=true;
            if ColorsEditor.DEBUG_SLD
                [this.sldClrs nan(cnt,1) this.sldClrsStart nan(cnt, 1)...
                    this.sldClrsEnd nan(cnt,1) clrs]
            end
            for i=1:cnt
                this.setColor(clrs(i,:), mrs(i), vrs(i), ...
                    ColorsEditor.COL_RGB, false);
            end
            if this.alwaysRefresh
                this.refreshLater;
            end
            if exceededMin
                msg(tip, 5, 'north east+', 'Your slider shading results...', 'none');
            end
            drawnow;
            this.updateBtnsAndDfltStatus(mrs, vrs);
            drawnow;
            this.updating=false;            
        end
        
        function updateSlider(this, mrs, vrs)
            cnt=length(mrs);
            if cnt==0
                set(this.sldPnl, 'Visible', 'off');
            else
                set(this.sldPnl, 'Visible', 'on');
            end
            clrs=this.colors(mrs,:)/255;
            if cnt>0
                canNotShade=sum((clrs==0)')>=1 & sum((clrs==1)')>=1;
                if any(canNotShade)
                    clrs=clrs(~canNotShade, :);
                    cnt=size(clrs,1);
                    mrs=mrs(~canNotShade);
                    vrs=vrs(~canNotShade);
                end
            end
            this.sldMrs=mrs;
            this.sldVrs=vrs;
            if cnt<1
                this.sldClrs=[];
                this.sldClrsStart=ColorsEditor.START_COLOR;
                this.sldClrsEnd=ColorsEditor.END_COLOR;
                perc=0;
                canSlide=false;
            else
                this.sldClrsStart=clrs;
                this.sldClrsEnd=clrs;
                for i=1:cnt
                    clr=clrs(i,:);
                    mn=min(clr);
                    this.sldClrsStart(i,:)=clr-mn;
                    mx=max(clr(:));
                    this.sldClrsEnd(i,:)=clr+(1-mx);
                end
                if ColorsEditor.DEBUG_SLD
                    if cnt>2
                        [clrs nan(cnt,1) this.sldClrsStart nan(cnt, 1) ...
                            this.sldClrsEnd ]
                    else
                        [clrs;nan(1,3);this.sldClrsStart;nan(1,3);...
                            this.sldClrsEnd ]
                    end
                end
                this.sldClrs=clrs;
                mn=min(clrs(:));
                mx=max(clrs(:));
                rng=mn+(1-mx);
                if mn==0 && mx==1
                    canSlide=false;
                    perc=1;
                else
                    canSlide=true;
                    if mn==0
                        perc=0;
                    elseif mx==1
                        perc=1;
                    else
                        perc=mn/rng;
                    end
                end
            end
            this.sld.Value=perc;
            if cnt==1
                startClr=this.sldClrsStart;
                endClr=this.sldClrsEnd;
            else
                [~,iMn]=min(sum(this.sldClrsStart'));
                startClr=this.sldClrsStart(iMn,:);
                [~,iMx]=max(sum(this.sldClrsEnd'));
                endClr=this.sldClrsEnd(iMx,:);
            end
            this.sldClrStartJ.setText(['<html>'  ColorsEditor.Cloud(...
                startClr) '</html>']);
            this.sldClrEndJ.setText(['<html>'  ColorsEditor.Cloud(...
                endClr) '</html>']);
            this.sldCnt=cnt;
            if ~canSlide
                this.sldPnl.Title='No color range for slider to shade!';
                this.sld.Enable='off';
                this.sldPnl.BackgroundColor=[1 .90 .90];
            else
                str=String.Pluralize2('color', cnt);
                this.sldPnl.Title=['Shade ' str ' from [' ...
                    String.Num2Str(round(startClr,2), ' ') '] to [' ...
                    String.Num2Str(round(endClr,2), ' ') ']'];
                this.sld.Enable='on';
                this.sldPnl.BackgroundColor=[.9 .91 .9];
            end
        end
    end
end