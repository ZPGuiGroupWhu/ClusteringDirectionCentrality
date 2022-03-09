%   AUTHORSHIP
%   Primary Developer: Stephen Meehan <swmeehan@stanford.edu> 
%   Provided by the Herzenberg Lab at Stanford University 
%   License: BSD 3 clause
%
classdef SuhSubset<handle
    properties(SetAccess=private)
        dataSet;
        selected;
        parent;
    end
    
    methods
        function this=SuhSubset(set, selectedInSubset)
            assert(nargin==2 || nargin==1, ...
                'SuhSubset constructor must be SuhSubset(dataSet) or SuhSubset(subSet, selectedInSubset)');
            if nargin==1
                assert(isa(set, 'SuhDataSet'),...
                    'set arg must be instance of SuhSubset');
                this.dataSet=set;
                this.selected=true(1,set.R);
            else
                assert(isa(set, 'SuhSubset'),...
                    'set arg must be instance of SuhSubset');
                this.dataSet=set.dataSet;
                assert(length(selectedInSubset)==sum(set.selected), ...
                    'selectedInSubset length==%d but sum(subset.selected)==%d',...
                    length(selectedInSubset), sum(set.selected));
                this.selected=false(1, this.dataSet.R);
                this.selected(set.selected)=selectedInSubset;
                this.parent=set;
            end
        end
        
        function data=filter(this, rows, cols)
            if ~isempty(rows)
                if nargin<3
                    cols=1:this.dataSet.C;
                end
                if size(rows,1)~=size(this.selected,1)
                    data=this.dataSet.data(this.selected & rows', cols);
                else
                    data=this.dataSet.data(this.selected & rows, cols);
                end
            else
                data=[];
            end
        end
        
        function data=data(this)
            data=this.dataSet.data(this.selected, :);
        end
        
        function data=dataXY(this, X, Y)
            data=this.dataSet.data(this.selected, [X Y]);
        end
        
        function sz=size(this)
            sz=sum(this.selected);
        end
        
        function s=html(this, X, Y)
            s=['X=<b>' this.dataSet.html(X) '</b>, Y=<b>' ...
                this.dataSet.html(Y) '</b>,  events=<b>' ...
                String.encodeInteger(this.size) '</b>'];
        end
    end
end