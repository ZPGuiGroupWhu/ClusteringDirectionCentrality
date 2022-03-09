classdef SortedStringMap < handle
%   AUTHORSHIP
%   Primary Developer: Stephen Meehan <swmeehan@stanford.edu> 
%   Math Lead & Secondary Developer:  Connor Meehan <connor.gw.meehan@gmail.com>
%   Bioinformatics Lead:  Wayne Moore <wmoore@stanford.edu>
%   Provided by the Herzenberg Lab at Stanford University 
%   License: BSD 3 clause
%

    properties(SetAccess=private)
        tm;
    end
    methods
        function this=SortedStringMap(caseInsensitive, varargin)
            if nargin==0 || ~caseInsensitive
                this.tm=java.util.TreeMap;
            else
                this.tm=java.util.TreeMap(java.lang.String.CASE_INSENSITIVE_ORDER);
            end
            if nargin>1
                if nargin>2
                    this.addAll(varargin{:});
                end
            end
        end
        
        function value=get(this, key)
            value=this.tm.get(java.lang.String(key));
        end
        
        function ok=containsKey(this, key)
            ok=this.tm.containsKey(java.lang.String(key));
        end
        
        function ok=put(this, key)
            ok=this.tm.add(java.lang.String(key));
        end
        
        function ok=remove(this, key)
            ok=this.tm.remove(java.lang.String(key));
        end
        
        function addAll(this, varargin)
            N=length(varargin);
            for i=1:2:N
                this.tm.put(java.lang.String(varargin{i}), varargin{i+1});
            end
        end
    end
end