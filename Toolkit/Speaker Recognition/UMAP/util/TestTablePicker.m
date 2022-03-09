%   AUTHORSHIP
%   Primary Developer: Stephen Meehan <swmeehan@stanford.edu> 
%   Math Lead & Secondary Developer:  Connor Meehan <connor.gw.meehan@gmail.com>
%   Bioinformatics Lead:  Wayne Moore <wmoore@stanford.edu>
%   Provided by the Herzenberg Lab at Stanford University 
%   License: BSD 3 clause
%
classdef TestTablePicker <handle
    methods(Static)
        function args=Args2D
            args{1}='min_selections';
            args{end+1}=1;
            args{end+1}='max_selections';
            args{end+1}=2;
            args{end+1}='is_xy_selections';
            args{end+1}=true;
            args{end+1}='modal';
            args{end+1}=false;
            args{end+1}='pick_callback';
            args{end+1}=@pick;
            args{end+1}='selection_callback';
            args{end+1}=@selection;
            args{end+1}='default_selections';
            args{end+1}={2, 4};
            args{end+1}='describe_columns';
            args{end+1}=[3 4];
            args{end+1}='selection_background';
            args{end+1}=[.959 1 .731];
            args{end+1}='selection_foreground';
            args{end+1}=[.05, .11, .91];
            function ok=pick(tp, vrs, mrs, ids)
                ok=true;
                debug('pick', tp, vrs, mrs, ids);
            end
            
            function ok=selection(tp, vrs, mrs, ids)
                ok=true;
                debug('selection', tp, vrs, mrs, ids);
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
        
        function [data, labels, fmts, ric, tips]=Data
            data={...
                .52, 1, 'SSC-A', '', -1, .92;...
                102.32, 7, 'CD4', 'FITC', -200, .31; ...
                .05, 5, 'CD8', 'PE', 3, 1; ...
                .44, 2, 'FSC-A', '', -.12, .0913;...
                -.15, 4, 'CD123', 'PeCy5.5', .005, .882; ...
                -3.21, 9, 'IgM', 'APC', -5, .763 ...
                };
            labels={'<html>KLD (&lt;<br>is &lt; info)</html>', ...
                'Chan #', 'Marker', 'Stain', 'Dull', 'Similarity'};
            tips={'Kullback-Leibler Divergence detects informativeness', ...
                'FCS parameter #', 'Biomarker/specificity', ...
                'Fluorophor or metal tag', '# of sdu for ZERO', ...
                'Mass+distance similarity (EMD)'};
            fmts=[5 3; 3 0; 15 nan; 8 nan; 5 2; 3 -2];
            ric=2;
        end
        
        function Refresh3(this)
              data={...
                .642, 1, 'SSC-A', '', -1.2, .11;...
                .32, 7, 'CD4', 'FITC', -2.3, .77; ...
                .05, 5, 'CD8', 'PE', 3.1, .55; ...
                -.82, 2, 'FSC-A', '', -.92, -.22;...
                .17, 4, 'CD123', 'PeCy5.5', .805, .44; ...
                -2.31, 9, 'IgM', 'APC', -5.1, .99 ...
                };
            this.updateData(data, [1 5 6], false, {5, 9});
        end
        
        function Refresh2(this)
            data={...
                .132, 7, 'CD45', 'PE', 2, .9; ...
                .405, 5, 'CD8', 'FITC', -.78, .123; ...
                .244, 2, 'FSC-H', '', -.52, .434;...
                11.021, 9, 'IgD', 'APC', 95, .785 ...
               };
           this.setData(data, {9});
        end
        
        function Refresh1(this)
            this.refresh({7, .9, 4;9, -.6, -17}, [2 1 5], {1 2})
        end        
        
        function [data, labels, fmts, ric, args, tips]=Case1
            args=TestTablePicker.Args2D;
            [data, labels, fmts, ric, tips]=TestTablePicker.Data;
        end
        
        function this=RunTest(testCase)
            if nargin<1
                testCase=1;
            end
            switch testCase
                otherwise
                    [data, labels, fmts, ric, args, tips]=TestTablePicker.Case1;
                    args{end+1}='column_labels';
                    args{end+1}=labels;
                    args{end+1}='row_identifier_column';
                    args{end+1}=ric;     
                    args{end+1}='formats';
                    args{end+1}=fmts;
                    args{end+1}='property';
                    args{end+1}='TestV6';
                    args{end+1}='tips';
                    args{end+1}=tips;
                    args{end+1}='refresh_callback';
                    args{end+1}=@TestTablePicker.Refresh2;
            end
            this=TablePicker(data, args{:});
        end
        
        function [mtable, jtable, jscrollpane]=Yair1
            % Display the uitable and get its underlying Java object handle
            mtable = uitable(gcf, 'Data',magic(3), 'ColumnName',{'A', 'B', 'C'});
            jscrollpane = findjobj(mtable);
            jtable = jscrollpane.getViewport.getView;
            % Now turn the JIDE sorting on
            jtable.setSortable(true);		% or: set(jtable,'Sortable','on');
            jtable.setAutoResort(true);
            jtable.setMultiColumnSortable(true);
            jtable.setPreserveSelectionsAfterSorting(true);
        end
    end
end