%   AUTHORSHIP
%   Primary Developer: Stephen Meehan <swmeehan@stanford.edu> 
%   Math Lead & Secondary Developer:  Connor Meehan <connor.gw.meehan@gmail.com>
%   Bioinformatics Lead:  Wayne Moore <wmoore@stanford.edu>
%   Provided by the Herzenberg Lab at Stanford University 
%   License: BSD 3 clause
%
classdef SortTable < handle
    properties(SetAccess=private)
        uit;
        jscrollpane;
        jtable;
        fig;
        tips;
        tipsHtml;
        uil;
        tipOnFigNameToo=false;
        figNamePrefix;
        columnNames;
        fncSelect;
    end
    methods
        
        function setSelectionBar(this)
            jt=this.jtable;
            jt.setNonContiguousCellSelection(false)
            set(jt.getSelectionModel, 'ValueChangedCallback', this.fncSelect);
            jt.setSelectionBackground(java.awt.Color(.959, 1, .73));
            jt.setSelectionForeground(java.awt.Color(.15, .21, .81));
        end
        
        function putTipInFigNameToo(this, prefix)
            this.tipOnFigNameToo=true;
            this.figNamePrefix=prefix;
        end
        
        function this=SortTable(fig, data, columnNames, ...
                normalizedPosition, fncSelect, tips)
            if nargin<6
                tips={};
                if nargin<5
                    fncSelect=[];
                    if nargin<4
                        normalizedPosition=[];
                        if nargin<3
                            columnNames=[];
                            if nargin<2
                                data={...
                                    'Pepper', 225, 14, 'Golden retriever';...
                                    'Fergie-roo', 44, 4, 'Golden retriever'; ...
                                    'Killarney', 4, 100, 'Black lab'};
                                columnNames={'Top dog', 'IQ', 'Age', 'Breed'};
                                if nargin<1
                                    fig=[];
                                end
                            end
                        end
                    end
                end
            end
            if isempty(fig)
                fig=Gui.Figure;
            end
            nTips=length(tips);
            if nTips>0                
                this.tips=cell(1,nTips);
                this.columnNames=cell(1,nTips);
                jj=edu.stanford.facs.swing.Basics;
                for col=1:nTips
                    this.columnNames{col}=char(java.lang.String(...
                        Html.remove(columnNames{col})).replaceAll(...
                        '-<br>', '').replaceAll('<br>', ' '));
                    this.tips{col}=['"' char(jj.RemoveXml(...
                        this.columnNames{col})) '": ' ...
                        char(jj.RemoveXml(tips{col}).trim)];
                end
                this.uil=uicontrol('style', 'text', 'parent', fig, ...
                    'units', 'Normalized', ...
                    'ForegroundColor', [0 .4 .9], ...
                    'FontWeight', 'bold', ...
                    'Position', [.01 .01 .97 .04]);
                this.tipsHtml=tips;
            end
            if isempty(normalizedPosition)
                if isempty(tips)
                    y=.04;
                    height=.94;
                else
                    y=.06;
                    height=.92;
                end
                normalizedPosition=[.03 y .94 height];
            end
            on=get(fig, 'visible');
            uit = uitable(fig, 'Data',data,'units', 'normalized', ...
                'Position', normalizedPosition, 'RowName', []);
            set(uit, 'fontName', 'arial');
            set(fig, 'visible', on);
            if ~isempty(columnNames)
                uit.ColumnName=columnNames;
            end
            this.uit=uit;
            this.fig=fig;
            [this.jtable, this.jscrollpane]=SortTable.Go(uit, fig);
            this.fncSelect=fncSelect;
            if ~isempty(fncSelect)
                set(uit, 'CellSelectionCallback', fncSelect);
                set(uit, 'RowStriping', 'off');
            end
            this.jtable.setSortOrderForeground(java.awt.Color.blue); % this works ok
            this.jtable.setShowSortOrderNumber(true);

            set(fig, 'visible', on);
            if ismac
                pause(.25);
            end
            
        end
        
        function showTip(this, col)
            if col<=length(this.tips)
                app=BasicMap.Global;
                if col==0
                    set(this.uil, 'String', '');
                    app.closeToolTip;
                else
                    set(this.uil, 'String', this.tips{col});
                    if this.tipOnFigNameToo
                        set(this.fig, 'Name', ...
                            [this.figNamePrefix this.tips{col}]);
                    end
                    px=Gui.GetPixels(this.fig);
                    app.showToolTip(this.jtable, ['<html><table ' ...
                        'cellspacing="10" cellpadding="10"><tr><td> '...
                        this.columnNames{col} '<hr>' this.tipsHtml{col}...
                        '</td></tr></table>'], ...
                        px(3)-190, px(4)-150, 0, [], true, 1);
                end
            end
        end
        
        function setColumnWidth(this,col, width)
            tcm=this.jtable.getColumnModel;
            t=tcm.getColumn(col-1);
            t.setPreferredWidth(width*8);
        end

        function labels=prepareTableLabels(this)
            J=edu.stanford.facs.swing.Basics;
            N=length(this.columnNames);
            labels=cell(1,N);
            for i=1:N
                if isempty(this.columnNames{i})
                    labels{i}=['Column ' num2str(i)];
                else
                    labels{i}=char(J.RemoveXml(this.columnNames{i}));
                    if isempty(labels{i})
                        if contains(this.columnNames{i}, '>*<') ...
                            || isequal(this.columnNames{i}, '*')
                            %TODO figure out odd issue with RemoveXml()
                            labels{i}='*';
                        else
                            labels{i}=['Column ' num2str(i)];
                        end
                    end
                end
            end
        end

       function t=getTableData(this, data)
            [R,C]=size(data);
            vNames=this.prepareTableLabels;
            inputs=cell(1, C+2);
            for c=1:C
                if all(cellfun(@isnumeric,data(:,c)))
                    column=zeros(R,1);
                    for r=1:R
                        column(r)=data{r,c};
                    end
                else
                    column=cell(R,1);
                    for r=1:R
                        column{r}=data{r,c};
                    end
                end
                inputs{c}=column;
            end
            inputs{C+1}='VariableNames';
            inputs{C+2}=vNames;
            try
                t=table(inputs{:});
            catch ex
                try
                    if verLessThan('matlab', '9.8') %works on r2020a NOT r2019a
                        for c=1:C
                            vNames{c}=matlab.lang.makeValidName(vNames{c});
                        end
                        inputs{C+2}=vNames;
                        t=table(inputs{:});
                    else
                        ex.getReport;
                    end
                catch
                    t=[];
                end
            end
       end

    end
    
    methods(Static)

        function [data, widths]=ToSortableAlignedHtml(data, fmts, useJava)
            
        %This solves sorting and right aligning of numbers for uitable.
        %The underlying data of the new uitable (r2008
        %with com.jidesoft.grid.SortableTable) is an internal Matlab
        %Java class that is not recognized by the sorter. 
        %For this reason, the sorter automatically converts all the 
        %data into a string representation (using each cell object’s
        %toString method) and then uses simple lexical sorting. 
        %This means that a numeric value of 12 will be sorted before 
        %a numeric value of 5. The simple workarounds for this is to 
        %convert numeric data values into space-padded strings. However
        %as Yair Altman says "the data does not appear entirely right-
        %justified (although the space-padding helps), but at least it will 
        %be sortable. If you want more "native" behavior you can modify
        %%matlabroot%\toolbox\matlab\codetools\arrayviewfunc.m,
        %but this should not be done by the faint-of-heart..."
        
            [R, C]=size(data);
            widths=zeros(1,C);
            if BasicMap.Global.highDef
                charSize=10;
            else
                charSize=5;
            end
            sortBase=1000000000000;%billion
            isNonNumeric=isnan(fmts(:,2));
            widths(isNonNumeric)=fmts(isNonNumeric,1);
            numCols=find(~isNonNumeric)';
            %first compute widths
            for c=numCols
                sig=fmts(c, 1);
                if sig>3
                    commas=floor(sig/3);
                else
                    commas=0;
                end
                dec=fmts(c,2);
                if dec==0
                    widths(c)=sig+commas;
                elseif dec>0
                    widths(c)=sig+commas+1+dec;
                elseif dec<-6
                    widths(c)=sig+commas+1; %1 for K
                elseif dec<-3
                    widths(c)=sig+commas+2; %2 for Mb
                else
                    widths(c)=sig+commas+2+(0-dec);
                end
            end
            if nargin<3 || useJava
                data(:, ~isNonNumeric)=cell(...
                    edu.stanford.facs.swing.Numeric.encodeForUitable(...
                    cell2mat(data(:, ~isNonNumeric)), ...
                    int32(fmts(~isNonNumeric, 2)), ...
                    int32(widths(~isNonNumeric)), ...
                    int32(charSize)));
            else
                %now convert numeric data to right aligned sortable strings
                for r=1:R
                    for c=numCols
                        dec=fmts(c,2);
                        num=data{r,c};
                        if isnan(num)
                            data{r,c}='<html>  N/A</html>';
                            continue;
                        end
                        if dec==0
                            sNum=String.encodeInteger(num);
                        elseif dec>0
                            sNum=String.encodeRounded(num, dec);
                        elseif dec<-6
                            sNum=String.encodeMb(num);
                        elseif dec<-3
                            sNum=String.encodeK(num);
                        else
                            sNum=[String.encodeRounded(num/1*100,0-dec) '%'];
                        end
                        sort=num2str(sortBase+(1000*num));
                        if num<0
                            sort=['N' sort(2:end)];
                        else
                            sort=['P' sort(2:end)];
                        end
                        data{r,c}=['<html><table width="' ...
                            num2str(widths(c)*charSize) ...
                            'px"><tr><td align="right">' ...
                            '<' sort '>' sNum '</td></tr></table>'];
                    end
                end
            end
        end
        
        function [jtable, jscrollpane]=Go(uit, fig)
            app=BasicMap.Global;
            jscrollpane = javaObjectEDT(findjobj_fast(uit));
            jtable = javaObjectEDT(jscrollpane.getViewport.getView);
            % Now turn the JIDE sorting on
            jtable.setSortable(true);
            jtable.setAutoResort(true);
            jtable.setMultiColumnSortable(true);
            jtable.setPreserveSelectionsAfterSorting(true);
            if app.highDef
                jtable.setRowHeight(35)
                jtable.setIntercellSpacing(java.awt.Dimension(10, 6))
            else
                jtable.setRowHeight(25)
                jtable.setIntercellSpacing(java.awt.Dimension(5,3))
            end
            if false
                filter=net.coderazzi.filters.gui.TableFilterHeader(jtable);
                filter.setAutoChoices(...
                    net.coderazzi.filters.gui.AutoChoices.ENABLED);
                if app.highDef
                    f=filter.getFont;
                    filter.setFont(java.awt.Font('arial', 0, 14));
                    filter.setRowHeightDelta(16)
                end
            elseif false
                tableHeader = com.jidesoft.grid.AutoFilterTableHeader(jtable); 
                tableHeader.setAutoFilterEnabled(true);
                tableHeader.setShowFilterName(true);
                tableHeader.setShowFilterIcon(true);
                jtable.setTableHeader(tableHeader)
            end
            jtable.getTableHeader.setReorderingAllowed(true);
            
        end
        
        function rowIdxs=ModelRows(jtable)
            rows=jtable.getRowCount;
            rowIdxs=zeros(1,rows);
            for row=0:rows-1
                rowIdxs(row+1)=1+jtable.getActualRowAt(jtable.convertRowIndexToModel(row));
            end
        end
        
        function colIdxs=ModelCols(jtable)
            cols=jtable.getColumnCount;
            colIdxs=zeros(1,cols);
            for row=0:cols-1
                colIdxs(row+1)=1+jtable.convertColumnIndexToModel(row);
            end
        end
        
        function html=ToHtml(jtable, header, footer)
            if nargin<3
                footer='';
                if nargin<2
                    header='';
                end
            end
            rowClr='"#FFFFDD"';
            colClr='"#AABDFF"';
            html=[header '<table><thead>'];
            R=jtable.getRowCount;
            C=jtable.getColumnCount;
            for j=1:C
                v=Html.remove(char(jtable.getColumnName(j-1)));
                html=[html '<th bgcolor=' colClr '>' v '</th>'];
            end
            html=sprintf('%s </thead>\n', html);
            for i=1:R
                html=[html '<tr>'];
                for j=1:C
                    v=jtable.getValueAt(i-1,j-1);
                    if ischar(v)
                        v=Html.remove(v);
                    else
                        v=num2str(v);
                    end
                    if j>1
                        html=[html '<td>' v '</td>'];
                    else
                        html=[html '<td bgcolor=' rowClr '>' v '</td>'];
                    end
                end
                html=sprintf('%s</tr>\n', html);
            end
            html=[html '</table>' footer '<hr><small>'...
                'Generated on ' char(datetime) '</small>'];
            
        end

        function [order, widths, changed]=GetColumnOrder(jt)
            C=jt.getColumnCount;
            order=zeros(1,C);
            widths=zeros(1,C);
            tcm=jt.getColumnModel;
            for c=0:C-1
                mi=jt.convertColumnIndexToModel(c);
                order(c+1)=mi;
                widths(c+1)=tcm.getColumn(c).getPreferredWidth;
            end
            naturalOrder=1:C;
            naturalOrder=naturalOrder-1;
            changed=~isequal(order, naturalOrder);
        end
        
        
        function SetColumnOrder(J, order, widths, force)
            if nargin<4
                force=false;
            end
            C=length(order);
            naturalOrder=1:C;
            naturalOrder=naturalOrder-1;
            tcm=J.getColumnModel;
            cols=J.getColumnCount;
            inRange=true(C);
            if force || ~isequal(order, naturalOrder)
                for c=0:C-1
                    o=order(c+1);
                    if o<cols
                        v=J.convertColumnIndexToView(o);
                        if v>=0
                            J.moveColumn(v, c);
                        else
                            fprintf('JTable has removed column %d\n', o)
                        end
                    else
                        inRange(c+1)=false;
                    end
                end
            end
            if ~isempty(widths)
                for c=0:C-1
                    if inRange(c+1)
                        tcm.getColumn(c).setPreferredWidth(...
                            widths(c+1));
                    end
                end
            end

        end
        
        function order=GetRowOrder(jt)
            m=jt.getModel;
            C=jt.getColumnCount;
            order=[];
            for c=0:C
                if m.isColumnSorted(c)
                    order(end+1,:)=[c ...
                        m.isColumnAscending(c) m.getColumnSortRank(c)];
                end
            end
        end
        
        function [ok, C]=SetRowOrder(jt, order)
            [C,~]=size(order);
            if C<1
                ok=false;
                return;
            end
            drawnow;
            jt.unsort;
            ok=true;
            m=jt.getModel;
            [~,I]=sort(order(:,3));
            for c=1:C
                idx=I(c);
                jt.sortColumn(order(idx,1), c==1, order(idx,2));
            end
        end
        
        function ok=MoveSortColumnsLeft(jt)
            order=SortTable.GetRowOrder(jt);
            [C,~]=size(order);
            if C<1
                ok=false;
                return;
            end
            ok=true;
            m=jt.getModel;
            [~,I]=sort(order(:,3));
            for c=C:-1:1
                idx=I(c);
                o=order(idx, 1);
                v=jt.convertColumnIndexToView(o);
                jt.moveColumn(v, 0);
            end
        end

        function [idxs, gotUnselected]=SelectedRows(jt, orUnselectedToo)
            if nargin<2
                orUnselectedToo=false;
            end
            gotUnselected=false;
            rows=jt.getSelectedRows;
            N=length(rows);
            if N==0
                if orUnselectedToo
                    N=jt.getRowCount;
                    rows=0:N-1;
                    gotUnselected=true;
                else
                    idxs=[];
                    return;
                end
            end
            idxs=zeros(1, N);
            for i=1:N
                idx=rows(i);
                idxs(i)=jt.getActualRowAt(jt.convertRowIndexToModel(idx))+1;
            end
        end
        
    end
    
end