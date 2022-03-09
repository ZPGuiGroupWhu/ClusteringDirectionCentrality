classdef NameColoringDlg <handle
    properties(SetAccess=private)
        table; %SortTable
        t;
        jt;
        updating=false;
        colors;
        changed;
        names;
        N;
        app;
    end
    
    methods
        function this=NameColoringDlg(names, colors, itemName, fncRefresh)
            if nargin<3
                itemName='Cell Subset';
            end
            this.names=names;
            N_=length(names);
            columnNames={itemName, 'Red', 'Green', 'Blue', '*'};
            data=cell(N_,5);
            this.colors=zeros(N_,3);
            this.changed=false(N_,1);
            for i=1:N_
                [hex, this.colors(i,:)]=Html.Scatter(colors(i,:),8);
                data(i,:)={names{i}, this.colors(i,1)/255, this.colors(i,2)/255, ...
                    this.colors(i,3)/255, ...
                    ['<html>&nbsp;' hex '</html>']};
            end
            this.N=N_;
            this.table=SortTable([], data, columnNames, [], ...
                @(h,e)pickColor(this,h,e));
            this.jt=this.table.jtable;
            this.t=this.table.uit;
            this.t.set('ColumnEditable', [false true, true, true, false], ...
                'CellEditCallback',@(h,c)ear(this, h,c));
            this.resize;
            this.app=BasicMap.Global;
            if ~this.app.highDef
                this.t.FontSize=14;
            end
            set(this.table.fig, 'visible', 'on')
           
        end
        function resize(this)
            tcm=this.jt.getColumnModel;
            tcm.getColumn(0).setPreferredWidth(204)
            tcm.getColumn(1).setPreferredWidth(54)
            tcm.getColumn(2).setPreferredWidth(54)
            tcm.getColumn(3).setPreferredWidth(54)
            tcm.getColumn(4).setPreferredWidth(54)
        end
        
        function pickColor(this, H, E)
            if ~isempty(E.Indices)
                vc = E.Indices(2)-1;
                J=this.jt;
                c=J.convertColumnIndexToModel(vc)+1;
                if c~=5
                    return;
                end
                vr = E.Indices(1)-1;
                vN=J.convertColumnIndexToView(0);
                item=char(J.getValueAt(vr, vN));
                r=NameColoringDlg.GetModelRow(H, item);
                vR=J.convertColumnIndexToView(1);
                vG=J.convertColumnIndexToModel(2);
                vB=J.convertColumnIndexToModel(3);
                fprintf('Selecting "%s"  data{%d, %d} jTable view@%d/%d RGB@[%d %d %d]\n', item, r, c,...
                    vr, vc, vR, vG, vB);
                Gui.SetColor(Gui.JFrame(this.table.fig), ...
                    ['Edit "' item '" color' ], ...
                    this.colors(r,:)/255)
                
            end
        end
        
        
        function ear(this, H, E)
            if this.updating
                return;
            end
            try
                numval = eval(E.EditData);
            catch
                numval=0;
            end
             r = E.Indices(1);
             c = E.Indices(2);
             J=this.jt;
             item=H.Data{r, 1};
             vr=NameColoringDlg.GetVisualRow(J, item);
             vc=J.convertColumnIndexToView(c-1);
             vcB=J.convertColumnIndexToView(4);
             
             red=H.Data{r, 2};
             green=H.Data{r, 3};
             blue=H.Data{r, 4};
             color=[red green blue];
             color(c-1)=numval;
             [html, color]=Html.Scatter(color,8);
             this.updating=true;
             NameColoringDlg.RefreshRgb(J,vr, c-1, color);
             J.setValueAt(['<html>&nbsp;' html '</html>'], vr, vcB);
             drawnow;
             this.changed(r)=true;
             this.colors(r,:)=color;
             fprintf('Editing "%s"  data{%d,%d} jTable view@%d/%d ', ...
                 item, r, c, vr, vc);
             fprintf('... color=[red=%d green=%d blue=%d]\n', ...
                 color(1), color(2), color(3));
             this.updating=false;
        end
    end
    
    methods(Static)
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
            vc=J.convertColumnIndexToView(0);
            N=J.getRowCount;
            for row=0:N-1
                nm=char(J.getValueAt(row, vc));
                if isequal(name,nm)
                    return;
                end
            end
            row=-1;
        end
        function RefreshRgb(J, vr, c, color)
            vc=J.convertColumnIndexToView(c);
            if color(c)==255
                s='1.0';
            else
                s=num2str(color(c)/255);
            end
            J.setValueAt(s, vr, vc);
        end
    end
end