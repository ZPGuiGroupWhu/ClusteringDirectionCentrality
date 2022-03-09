classdef SuhLeafRaker < handle
    properties(SetAccess=private)
        epp;
        topKey;
        leafKeys;
        leafIds;
        sizes;
        figTable;
        table;
        data;
        args;
        cbBrowser;
    end
    
    methods
        function this=SuhLeafRaker(epp, topKey)
            this.epp=epp;
            this.topKey=topKey;            
            this.initialize;
            this.table=TablePicker(this.data, this.args{:});
            this.figTable=this.table.table.fig;
            this.table.btnPick.setToolTipText('View the EPP subset sequence in browser or figure');
        end
        
        function close(this)
            try
                close(this.figTable);
            catch
            end
        end
        
        function [data, args]=initialize(this)
            [this.leafKeys, this.leafIds]=this.epp.getLeaves(this.topKey);
            this.cbBrowser=Gui.CheckBox(...
                Html.WrapSmallBold('See picks in browser (faster)' ), ...
                this.epp.app.is('SuhLeafRaker.Browser', true), ...
                this.epp.app, 'SuhLeafRaker.Browser', '', ...
                ['<html>Select to view picks in browser</html>']);
            args=this.getArgs;
            labels={'Subset ID', 'Name of leaf',  'Leaf ID', 'Splits', 'Size'};
            fmts=[12 nan; 25 nan; 4 0; 4 0; 6 0];
            ric=3;
            tips={...
                'Internal identifier for subset', ...
                'Name of final subset computed from splitting column names', ...
                'Leaf internal identifier', ...
                '# of parent 2-way splits',...
                '# of rows in data table'};
            N=this.leafKeys.size;
            data={};
            for i=1:N
                key=this.leafKeys.get(i-1);
                id=this.leafIds.get(i-1);
                [ok,isLeaf, sz, name]=this.epp.exists(key);
                data(end+1,:)={ key, name, id, length(key)-1, sz};
            end
            this.data=data;
            args{end+1}='column_labels';
            args{end+1}=labels;
            args{end+1}='row_identifier_column';
            args{end+1}=ric;
            args{end+1}='formats';
            args{end+1}=fmts;
            args{end+1}='property';
            args{end+1}='SuhLeafRaker';
            args{end+1}='tips';
            args{end+1}=tips;
            this.args=args;
        end
        
        function args=getArgs(this)
            jp=Gui.Panel;
            jp.add(this.cbBrowser);
            args={'min_selections', 1,...
                'max_selections', intmax,...,
                'is_xy_selections', false,...
                'modal', false,...
                'pick_callback', @pick,...
                'selection_callback',@selection,...
                'describe_columns', 2,...
                'toolbar_component', jp,...
                'locate_fig', {this.epp.figHierarchyExplorer, ...
                'east++', true},...
                'fig_name', 'EPP LeafRaker'};
            
            function ok=pick(tp, vrs, mrs, ids)
                ok=true;
                N=length(mrs);
                if N>0 && isempty(ids{1})
                    return;
                end
                edu.stanford.facs.swing.Basics.Shake(this.cbBrowser, 6);
                if ~this.cbBrowser.isSelected
                    figs=cell(1,N);
                    for i=1:N
                        id=ids{i};
                        figs{i}=this.epp.showSequencePlots(id, ...
                            ['Leaf #' num2str(id)], ...
                            {this.figTable, 'east++', true});
                        Gui.Cascade(Gui.JWindow(figs{i}), i,N+1)
                    end
                else
                    keys=cell(1,N);
                    for i=1:N
                        idx=mrs(i);
                        keys{i}=this.data{idx,1};
                    end
                    this.epp.browseParents(keys, 'east');
                end
            end
            
            function ok=selection(tp, vrs, mrs, ids)
                ok=true;
                debug('selection', tp, vrs, mrs, ids);
                N=length(mrs);
                for j=1:N
                    i=mrs(j);
                    key=this.leafKeys.get(i-1);
                    if j>1
                        this.epp.suhTree.ensureVisible(key, 2, j==N);
                    else
                        this.epp.suhTree.ensureVisible(key, 1);
                    end
                end
            end
            
            function debug(txt, tp, vrs, mrs, ids)
                try
                    fprintf('%s mrs=%s: [', txt, num2str(mrs));
                    if ~isempty(tp.J)
                        col3=tp.J.convertColumnIndexToView(2);
                        N=length(vrs);
                        for ii=1:N
                            value=tp.J.getValueAt(vrs(ii), col3);
                            fprintf('chan#%d={"%s", "%s"}', ...
                                ids{ii}, char(value), tp.originalData{mrs(ii), 4});
                            if ii<N
                                fprintf(' & ');
                            end
                        end
                    end
                    fprintf('] (vrs=%s)\n ', num2str(vrs));
                catch ex
                    ex.getReport
                end
            end
        end
        
        
    end
end