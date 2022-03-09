%   AUTHORSHIP
%   Primary Developer: Stephen Meehan <swmeehan@stanford.edu> 
%   Math Lead & Secondary Developer:  Connor Meehan <connor.gw.meehan@gmail.com>
%   Bioinformatics Lead:  Wayne Moore <wmoore@stanford.edu>
%   Provided by the Herzenberg Lab at Stanford University 
%   License: BSD 3 clause
%


classdef SuhStruct < handle
    methods(Static)
        
        function to=AddNewValues(to,from)
            names=fieldnames(from);
            N=length(names);
            for i=1:N
                name=names{i};
                if ~isfield(to, name)
                    to=setfield(to, name, getfield(from, name));
                end
            end
        end
        
        function nv=ToNamedValueCell(struc)
            names=fieldnames(struc);
            values=struct2cell(struc);
            N=length(names);
            nv=cell(1, N*2);
            for i=1:N
                if i>1
                    idx=(i*2)-1;
                else
                    idx=1;
                end
                nv{idx}=names{i};
                nv{idx+1}=values{i};
            end
        end

        function items=FindUnequalFields(a,b, suffix)
            if isstruct(a)
                names=fieldnames(a);
            else
                names=properties(a);
            end
            items={};
            if isempty(names)
                return;
            end
            N=length(names);
            for i=1:N
                name=names{i};
                try
                    v1=a.(name);
                    v2=b.(name);
                    if ~isequal(v1,v2)
                        if isnumeric(v1)
                            if isequal(v1(~isnan(v1)), v2(~isnan(v2)))
                                continue;
                            end
                        end
                        items{end+1}=name;
                    end
                catch
                    items{end+1}=name;
                end
            end
        end
    end
end