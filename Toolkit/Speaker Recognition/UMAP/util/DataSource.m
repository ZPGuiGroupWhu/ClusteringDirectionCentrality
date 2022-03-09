%   AUTHORSHIP
%   Primary Developer: Connor Meehan <connor.gw.meehan@gmail.com> 
%   Secondary Developer:  Stephen Meehan <swmeehan@stanford.edu>
%   Bioinformatics Lead:  Wayne Moore <wmoore@stanford.edu>
%   Provided by the Herzenberg Lab at Stanford University 
%   License: BSD 3 clause
%

classdef DataSource
    methods(Static)
        function DisplaySinglePub(which)
            refs = DataSource.RefURLs();
            
            if isKey(refs, which)
                disp('PLEASE NOTE: The sample data for this example are made public with the publication at this URL:');
                fprintf('%s\n\n', refs(lower(which)));
            else
                disp('Error: Failed to find requested publication');
            end
        end
        
        function DisplayMultiplePubs(which)
            refs = DataSource.RefURLs();
            
            if all(~isKey(refs, lower(which)))
                disp('Error: Failed to find requested publications');
            else
                if any(~isKey(refs, lower(which)))
                    disp('WARNING: Cannot find all requested publications');
                end
                disp('PLEASE NOTE: The sample data for these examples are made public with the publications at these URLs:');
                for strCell = which
                    str = strCell{1};
                    if ~isKey(refs, lower(str))
                        continue
                    else
                        fprintf('%s\n\n', refs(lower(str)));
                    end
                end
            end
        end
        
        function map=Refs()
            map = containers.Map;
            
            map('sample10k')=["sample10k.csv", "https://www.pnas.org/content/107/6/2568", "conventional"];
            
            map('ghosn 2010')=["eliverLabeled.csv", "https://www.pnas.org/content/107/6/2568", "conventional"];
            map('eliver')=map('ghosn 2010');
            
            map('samusik 2016') = ["panoramaLabeled.csv", "https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4896314/", "cytof"];
            map('panorama') = map('samusik 2016');
            
            map('mair 2018') = ["omip044Labeled400k.csv", "https://onlinelibrary.wiley.com/doi/10.1002/cyto.a.23331", "conventional"];
            map('omip-044') = map('mair 2018');
            
            map('leipold 2018') = ["maeckerLabeled.csv", "https://www.sciencedirect.com/science/article/pii/S0022175917304908", "cytof"];
            map('maecker') = map('leipold 2018');
            
            map('liechti 2018') = ["omipBLabeled.csv", "https://onlinelibrary.wiley.com/doi/full/10.1002/cyto.a.23488", "conventional"];
            map('omip-047') = map('liechti 2018');
                
            map('eshghi 2019')= ["genentechLabeled100k.csv", "https://www.frontiersin.org/articles/10.3389/fimmu.2019.01194/full", "cytof"];
            map('genentech')= map('eshghi 2019');
            
            map('park 2020') = ["omip69Labeled200k.csv", "https://onlinelibrary.wiley.com/doi/10.1002/cyto.a.24213", "spectral"];
            map('omip-069') = map('park 2020');
        end
        
        function map=RefURLs()
            map=DataSource.Refs();
            
            keySet = keys(map);
            for keyBox = keySet
                key = keyBox{1};
                tuple = map(key);
                map(key) = tuple(2);
            end
        end
        
        function map=RefCSVs()
            map=DataSource.Refs();
            
            keySet = keys(map);
            for keyBox = keySet
                key = keyBox{1};
                tuple = map(key);
                map(key) = tuple(1);
            end
        end
        
        function map=RefCytoms()
            map=DataSource.Refs();
            
            keySet = keys(map);
            for keyBox = keySet
                key = keyBox{1};
                tuple = map(key);
                map(key) = tuple(3);
            end
        end
    end
end