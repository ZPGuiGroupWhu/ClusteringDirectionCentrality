classdef SuhDbmSplitter < SuhSplitter
    properties(Constant)
        MEX_FILE='mexSptxDbm';
        MEX_CPP_FOLDER='eppCpp_files';
    end
    
   
    
    methods(Static)
        function ok=Build
            %This invokes your C++ compiler to build a Mac or Windows MEX
            %file for modal separatrix algorithm. 
            %If you have not yet installed a compiler,
            %then use the command "mex -setup" in the MATLAB Command
            %Window.
            curPath=fileparts(mfilename('fullpath'));
            cppPath=fullfile(curPath, SuhDbmSplitter.MEX_CPP_FOLDER);
            cppFile=fullfile(cppPath, 'mexSptx.cpp');
            if ~exist(cppFile, 'file') 
                cppPath=fullfile(fileparts(curPath), SuhDbmSplitter.MEX_CPP_FOLDER);
                cppFile=fullfile(cppPath, 'mexSptx.cpp');
                warning('CVS history keeps C++ under "matlabsrc" .. but it is NOT dependent on AutoGate');
            end
            if ~exist(cppFile, 'file')
                error(['Mex C++ source does not exist: ' cppFile]);
            end
            buildFile=fullfile(cppPath, [SuhDbmSplitter.MEX_FILE '.' mexext]);
            priorPwd=pwd;
            try
                cd(cppPath);
                mex('-v', 'mexSptx.cpp',  'Separatrix.cpp',  ...
                    'ClusterSummary.cpp', 'GridClusterEdge.cpp',...
                    'suh.cpp', 'MxArgs.cpp', '-output', SuhDbmSplitter.MEX_FILE);
            catch ex
                ex.getReport
                disp('You may need to set up your C++ compiler with "mex -setup C++"!');
            end
            movefile(buildFile, curPath);
            disp(['Success ! ... mex-ecutable file is ' ...
                SuhDbmSplitter.MexFile])
            cd(priorPwd);
            ok=true;
        end
        
        function mexFile=MexFile()
            mexFile=fullfile(fileparts(mfilename('fullpath')),...
                [SuhDbmSplitter.MEX_FILE '.' mexext ]);
        end
        
    end
    
    methods
        function this=SuhDbmSplitter(varargin)
           this=this@SuhSplitter();
           this.splitsWithPolygons=true;
           this.type='dbm';
           varargin=SuhEpp.HandleUmapVerbose(...
                varargin{:});
           [this.args, this.argued, this.unmatched]...
               =SuhDbmSplitter.GetArgs(varargin{:});
        end
        
        function xy=qualifyXy(this,subset)
            switch this.args.cluster_detail
                case 'very high'
                    W=.005;
                case 'high'
                    W=.007;
                case 'medium'
                    W=.009;
                otherwise
                    W=.011;
            end
            xy=mexSptxModal(...
                single(subset.data), ...'
                'service', 'kld',...
                'balanced', this.args.balanced, ...
                'W', W,...
                'sigma', 3,...    
                'KLD_normal_1D', this.args.KLD_normal_1D,...
                'KLD_normal_2D', this.args.KLD_normal_2D,...
                'max_clusters', this.args.max_clusters);
        end
    end
    
    methods(Access=protected)
        function [X, Y, polygonA, polygonB, leafCause]=split(this, subset)
            pairs=this.qualifyXy(subset);
            N=size(pairs,1);
            bestScore=intmax;
            X=0;
            Y=0;
            bestSptx=[];
            startingDtl=StringArray.IndexOf(Density.DETAILS, this.args.cluster_detail);
            for i=1:N
                density=SuhDbm.Find(subset.dataXY(pairs(i,1), pairs(i,2)),...
                    this.args.cluster_detail, [0 0], [1 1]);
                if density.numClusters<2
                    continue;
                end
                if density.numClusters>this.args.max_clusters
                    dtl=startingDtl;
                    while true
                        dtl=dtl+1;
                        if dtl==6
                            break;
                        end
                        cluster_detail=Density.DETAILS{dtl};
                        density=SuhDbm.Find(...
                            subset.dataXY(pairs(i,1), pairs(i,2)),...
                            cluster_detail, [0 0], [1 1]);
                        if density.numClusters<=this.args.max_clusters
                            break;
                        end
                    end
                end
                try
                    [score, sptx]=SuhSptx.New(density, this.args.balanced, ...
                        this.args.minLeafSize, this.args.balancedNoisy, ...
                        this.args.trimLeaves);
                    if ~isnan(score) && score<bestScore
                        bestScore=score;
                        bestSptx=sptx;
                        X=pairs(i,1);
                        Y=pairs(i,2);
                    end
                catch ex
                    ex.getReport
                end
            end
            if ~isempty(bestSptx) ...
                    && ~isempty(bestSptx.java.getBestClusterGroup)
                [polygonA, polygonB]=bestSptx.getPolygons;
                if SuhSplitter.TEST_2_POLYGONS
                    [this.alternateSplitA, this.alternateSplitB]...
                        =bestSptx.getPolygons(true);
                end
                if isempty(polygonA)
                    X=0;
                    Y=0;
                    polygonA=[];
                    polygonB=[];
                elseif this.args.use_not_gate
                    polygonB=[];
                end
            else
                X=0;
                Y=0;
                polygonA=[];
                polygonB=[];
            end
            leafCause='';
        end

        function selected=select(this, subset, X, Y, polygon)
            data=subset.data;
            selected=inpolygon(data(:,X), data(:, Y), ...
                polygon(:,1), polygon(:,2));
        end
        
        function polygon=to_data(this, split_string)
            polygon=MatBasics.StringToXy(split_string);
        end

        function showSplit(this, ax, polygon)
            hold(ax, 'on');
            plot(ax, polygon(:,1), polygon(:,2), ...
                'LineWidth',1,...
                'Color', [1 0 1],...
                'Marker', 'd', ...
                'MarkerSize',2,...
                'MarkerEdgeColor','black',...
                'MarkerFaceColor',[0.5,0,0.5]);
        end

        function suffix=getSubClassFileNameSuffix(this)
            if isempty(this.args.cluster_detail) 
                suffix='';
            else
                suffix=sprintf('_%s_%d_%d_%d_%d', ...
                    strrep(this.args.cluster_detail, ' ', '_'), ...
                    this.args.balanced,...
                    this.args.balancedNoisy, ...
                    this.args.max_clusters,...
                    this.args.minLeafSize);
            end
        end
    end
    
    methods(Static)
        
        function [args, argued, unmatched]=GetArgs(varargin)
             [args, argued, unmatched]=Args.NewKeepUnmatched(...
                 SuhDbmSplitter.DefineArgs(), varargin{:});            
        end
        
        function p=DefineArgs(varargin)
            p = inputParser;
            % the defalt -1 simply means use the
            % current best default that Wayne Moore has found
            addParameter(p,'balanced', true, @(x)islogical(x));
            addParameter(p,'cluster_detail', 'high', @Density.ValidateDetail);
            addParameter(p,'KLD_normal_1D', .16, ...
                @(x) Args.IsNumber(x, 'KLD_normal_1D', 0, .5));
            addParameter(p,'KLD_normal_2D', .16, ...
                @(x) Args.IsNumber(x, 'KLD_normal_2D', 0, 2.25));
            addParameter(p,'max_clusters', 12,  ...
                @(x) Args.IsInteger(x, 'max_clusters', 3, 30));
            addParameter(p,'balancedNoisy', true, @(x)islogical(x));
            addParameter(p, 'use_not_gate', false, @(x)islogical(x));
            addParameter(p,'trimLeaves', false, @(x)islogical(x));
            addParameter(p, 'minLeafSize', 0, ...
                @(x)isnumeric(x) && x>=0 && x< 1000);
        end
    end
end
