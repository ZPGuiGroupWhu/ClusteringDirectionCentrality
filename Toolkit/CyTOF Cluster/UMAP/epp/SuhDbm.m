%   More efficient alternative to Density.FindClusters that ignores DBSCAN 
%   and does not incur the cost of transmitting large vector event cluster ids
%   AUTHORSHIP
%   Primary Developer: Stephen Meehan <swmeehan@stanford.edu> 
%   Math Lead & Secondary Developer:  Connor Meehan <connor.gw.meehan@gmail.com>
%   Bioinformatics Lead:  Wayne Moore <wmoore@stanford.edu>
%   Provided by the Herzenberg Lab at Stanford University 
%   License: BSD 3 clause
%

classdef SuhDbm < handle
    properties(Constant)
        DEBUG=true;
    end
    methods(Static)
        function dns=Test(fg)
            [~,dtl]=fg.describeClusterDetail;
            dns=SuhDbm.Find(fg.focusXy, dtl, ...
                fg.density.mins, fg.density.maxs);
            assert(isequal(dns.getEventData, fg.focusClusterIds));
            fprintf('\nGOOD test .. truncated=%d\n', dns.truncated);
        end
        
        function density=Find(data, detail, mins, maxs)
            if strcmpi(detail, 'low')
                    density=SuhDbm.ClusterLow(data, mins, maxs);
                elseif strcmpi(detail, 'most high')
                    density=SuhDbm.ClusterMostHigh(data, mins, maxs);
                elseif strcmpi(detail, 'very high')
                    density=SuhDbm.ClusterVeryHigh(data, mins, maxs);
                elseif strcmpi(detail, 'high')
                    density=SuhDbm.ClusterHigh(data, mins, maxs);
                elseif strcmpi(detail, 'medium')
                    density=SuhDbm.ClusterMedium(data, mins, maxs);
                elseif strcmpi(detail, 'very low')
                    density=SuhDbm.ClusterVeryLow(data, mins, maxs);
                elseif strcmpi(detail, 'adaptive')
                    density=SuhDbm.ClusterAdaptive(data, mins, maxs);
                elseif strcmpi(detail, 'nearest neighbor')
                    density=SuhDbm.ClusterNearestN(data, mins, maxs);
                else
                    warning([detail ' is not a DBM method, using medium']);
                    density=SuhDbm.ClusterMedium(data, mins, maxs);
                end
        end
        
        function [numClusts, density]=ClusterMostHigh(...
                xy, mins, maxs)
            if nargin<3
                maxs=[];
                mins=[];
            end
            density=SuhDbm.Cluster(...
                xy, 0.95, 256, 2, .1, false, mins, maxs);
        end

        
        function density=ClusterVeryHigh(...
                xy, mins, maxs)
            if nargin<3
                maxs=[];
                mins=[];
            end
            density=SuhDbm.Cluster(...
                xy, 1.5, 256, 2, .1, false, mins, maxs);
        end

        function density=ClusterHigh(...
                xy, mins, maxs)
            if nargin<3
                maxs=[];
                mins=[];
            end
            density=SuhDbm.Cluster(...
                xy, 1.6, 256, 1, 4.3, false, mins, maxs);
        end

        function density=ClusterMedium(...
                xy, mins, maxs)
            if nargin<3
                maxs=[];
                mins=[];
            end
            density=SuhDbm.Cluster(...
                xy, 2.3, 256, 1, 4.3, false, mins, maxs);
        end

        function density=ClusterLow(...
                xy, mins, maxs)
            if nargin<3
                maxs=[];
                mins=[];
            end
            density=SuhDbm.Cluster(...
                xy, 3.2, 256, 1, 4, false, mins, maxs);
        end

        function density=ClusterVeryLow(...
                xy, mins, maxs)
            if nargin<3
                maxs=[];
                mins=[];
            end
            density=SuhDbm.Cluster(...
                xy, 4, 256, 2, 1, true, mins, maxs);
        end
        
        %This clusters EXACTLY as described in 2009 publication
        %http://cgworkspace.cytogenie.org/GetDown2/demo/dbm.pdf
        function density=ClusterAdaptive(...
                xy, mins, maxs)
            if nargin<3
                maxs=[];
                mins=[];
            end
            density=SuhDbm.Cluster(...
                xy, 0, 256, 4, 4.3, false, mins, maxs);
        end
        
        function density=ClusterNearestN(...
                xy, mins, maxs)
            if nargin<3
                maxs=[];
                mins=[];
            end
            density=SuhDbm.Cluster(...
                xy, -1, 128, 4, 4.3, false, mins, maxs);
        end
        
        function density=Cluster(xy, ...
                bandWidth, M, backgroundType, backgroundFactor, ...
                slopeSignificance, mins, maxs)
            if nargin<8
                maxs=[];
                if nargin<7
                    mins=[];
                    if nargin<6
                        slopeSignificance=false;
                        if nargin<5
                            backgroundFactor=4.3;
                            if nargin<4
                                backgroundType=1;
                                if nargin<3
                                    M=256;
                                    if nargin<2
                                        bandWidth=2.3;
                                    end
                                end
                            end
                        end
                    end
                end
            end
            options.hWait=0;
            options.mergeSmallNeighboringClusters=1;
            options.DbmMsncPerc= 0;
            options.DbmMsncDist=2;
            options.DbmBandwidth=bandWidth;
            options.DbmM=M;
            options.DbmBackgroundFactor=backgroundFactor;
            options.DbmSlopeIsSignificant=slopeSignificance;
            options.DbmBackgroundType=backgroundType;
            options.DbmNmin=5000;
            if isempty(mins) || isempty(maxs)
                density=Density.Create(xy,options);
            else
                density=Density.CreateWithScale(xy, options,mins,maxs);
            end
            if ~SuhDbm.DEBUG
                density.clusterAnalyze(options);
            else
                [~, clusterIds]=density.clusterAnalyze(options);
                [eventClusterIds, pointersWithEvents]=density.getEventData;
                assert(isequal(clusterIds, eventClusterIds));
                assert(isequal(density.pointersWithEvents, pointersWithEvents));
            end
        end 
        
        
    end
end