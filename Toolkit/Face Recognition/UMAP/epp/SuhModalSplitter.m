%   AUTHORSHIP
%   Primary Developer: Stephen Meehan <swmeehan@stanford.edu> 
%   Math Lead & Secondary Developer:  Connor Meehan <connor.gw.meehan@gmail.com>
%   Bioinformatics Lead:  Wayne Moore <wmoore@stanford.edu>
%   Provided by the Herzenberg Lab at Stanford University 
%   License: BSD 3 clause
%

classdef SuhModalSplitter < SuhSplitter
    
    properties(Constant)
        MEX_FILE='mexSptxModal';
        MEX_CPP_FOLDER_BRANCH='modal';
        MEX_CPP_FOLDER_MAIN='weighingMore';
    end
    
    
    methods        
        function this=SuhModalSplitter(varargin)
           this=this@SuhSplitter();
           this.type='modal';
           this.splitsWithPolygons=true;
           varargin=SuhEpp.HandleUmapVerbose(...
                varargin{:});
           [this.args, this.argued, this.unmatched]...
               =SuhModalSplitter.GetArgs(varargin{:});
        end
        
        function xy=qualifyXy(this,subset, kld1D, kld2D)
            if nargin<4
                kld2D=this.args.KLD_normal_2D;
                if nargin<3
                    kld1D=this.args.KLD_normal_1D;
                end
            end
            xy=mexSptxModal(...
                single(subset.data), ...'
                'service', 'kld',...
                'balanced', this.args.balanced, ...
                'W', this.args.W,...
                'sigma', this.args.sigma,...
                'KLD_normal_1D', kld1D,...
                'KLD_normal_2D', kld2D,...
                'max_clusters', this.args.max_clusters,...
                'threads', this.args.threads, ...
                'verbose_flags', this.args.verbose_flags);
        end
    end
    
    methods(Static)
        function xy=Test
            data=[.11 .21;.1 .2; .15 .42;.41 .32; .21 .12;...
                .31 .92; .81 .72; .8551 .742; .331 .82];
            polygon=[0 0; 1 0; 0 1];
            xy=SuhModalSplitter.InPolygon(data, polygon);
        end
        
        function H=TestPolygon(xys, M)
            p=SuhModalSplitter.ToPolygon(xys);
            ax=Gui.GetOrCreateAxes(figure);
            xlim(ax, [-2 M+2]);
            ylim(ax, [-2 M+2]);
            hold(ax, 'on');
            grid(ax, 'on');
            %p(:,1)=M-p(:,1)+1;
            H=impoly(ax, p);
        end
        
        function out=ToPolygon(xys)
            [R,C]=size(xys);
            assert(C==2);
            if R<3
                out=xys;
                return;
            end
            xys=xys(boundary(xys), :);
            R=size(xys,1);
            if R<3
                out=xys;
                return;
            end
            out=xys(1:2,:);
            
            for  i=3:R
                x=xys(i,1);
                y=xys(i,2);
                if out(end,1)==x && out(end-1, 1)==x
                    out(end,:)=[x y];
                elseif out(end,2)==y && out(end-1,2)==y
                    out(end,:)=[x y];
                else
                    out(end+1,:)=[x y];
                end
            end
        end
        
        function xy=InPolygon(data,polygon)
            xy=mexSptxModal(...
                single(data), ...'
                'service', 'inpolygon',...
                'polygon', polygon);
        end
    end
    
    
    methods(Access=protected)
        
        function [X, Y, polygonA, polygonB, leafCause]=split(this, subset)
            leafCause='';
            try
                [X, Y, polygonA, polygonB]=mexSptxModal(...
                    single(subset.data), ...
                    'balanced', this.args.balanced, ...
                    'W', this.args.W,...
                    'sigma', this.args.sigma,...
                    'KLD_normal_1D', this.args.KLD_normal_1D,...
                    'KLD_exponential_1D', this.args.KLD_exponential_1D,...
                    'KLD_normal_2D', this.args.KLD_normal_2D,...
                    'max_clusters', this.args.max_clusters,...
                    'threads', this.args.threads, ...
                    'verbose_flags', this.args.verbose_flags, ...
                    'simplify_polygon', this.args.simplify_polygon);
                 
            catch ex
                X=0; Y=0; polygonA=[]; polygonB=[];
                ex.getReport
                return;
            end
            if this.args.use_not_gate
                polygonB='';
            end
            if subset.size<12500
                if ~isempty(polygonA) %prevent splits with 1 cluster on small subsets
                    numClusters=Density.FindClusters(subset.dataXY(X, Y),...
                        'high', 'dbm', [], 5, 1, 'euclidean', ...
                        [0 0], [1 1]);
                    if numClusters<2
                        fprintf(['Treating as leaf ...since best split %d '...
                            'events on %d/%d has %d DBM cluster\n'],...
                            subset.size, X, Y, numClusters);
                        polygonA=[];
                        X=0;
                        Y=0;
                        leafCause='dbm';
                    end
                end
            end
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
            if this.args.balanced && this.args.max_clusters==-1 ...
                    && this.args.sigma==-1 && this.args.W==-1 ...
                    && this.args.KLD_normal_2D == -1 ...
                    && this.args.KLD_normal_1D == -1 ...
                    && this.args.KLD_exponential_1D == -1                     
                suffix='';
            else
                suffix=sprintf('_%d_%d_%s_%s_%s_%s_%s', ...
                    this.args.balanced, this.args.max_clusters,...
                    String.encodeRounded(this.args.sigma,2), ...
                    String.encodeRounded(this.args.W,4),...
                    String.encodeRounded(this.args.KLD_normal_2D,3), ...
                    String.encodeRounded(this.args.KLD_normal_1D,3), ...
                    String.encodeRounded(this.args.KLD_exponential_1D,3));
            end
        end
        
        function saveSubClassProperties(this, props)
            %TODO implement this
        end
        
        function loadSubClassProperties(this, props)
            %TODO implement this
        end
    end
    
    
    
    methods(Static)
        
        function Omip69_37D()
            SuhModalSplitter.Run('omip69_lymphocytes_37D.csv', 2);
        end
        
        function Eliver(doSix)
            if nargin<1 || doSix
                SuhModalSplitter.Run('sample55k.csv', 2);
            else
                SuhModalSplitter.Run('sample55k.csv');
            end
        end
        
        %[X1, Y1, polygonOnDataScale1, polygonOnGridScale1]=SuhModalSplitter.Run('sample55k.csv');
        %[X2, Y2, polygonOnDataScale2, polygonOnGridScale2]=SuhModalSplitter.Run('omip69_453k_35D.csv');
        function [X,Y,polygonA, polygonB]=Run(...
                csvFileOrData, show, varargin)
            if nargin<2
                show=1;
                if nargin<1
                    csvFileOrData=[];
                end
            end
            if isempty(csvFileOrData)
                csvFileOrData='sample55k.csv';
            end
            args=SuhModalSplitter.GetArgs(varargin{:});
            parameterNames=args.column_names;
            if ischar(csvFileOrData)
                csvFile=WebDownload.GetExampleIfMissing(  csvFileOrData );
                if ~exist(csvFile, 'file')
                    globals=BasicMap.Global;
                        msg(['<html>The csv file <br>"<b>' ...
                            globals.smallStart csvFile globals.smallEnd ...
                            '</b>"<br><center><font color="red"><i>cannot be found !!' ...
                            '</i></font><hr></center></html>'], 25, 'center', ...
                            'Error...', 'error.png');
                    return;
                end
                if args.verbose_flags>0
                    disp(['Loading ' csvFile]);
                end
                [inData, names]=File.ReadCsv(csvFile);
                if isempty(parameterNames)
                    parameterNames=names;
                end
                [~, f, e]=fileparts(csvFile);
                ttl=['Best split for ' f e];
            else
                inData=csvFileOrData;
                ttl='Best split';
            end
            [R,C]=size(inData);
            ttl=[ttl ' (' String.encodeInteger(R) ' X ' num2str(C) ')' ];
            if args.verbose_flags>0
                disp(['Finding best 2 way split on 2 parameters'...
                    ' for ' String.encodeInteger(R) ' events X ' num2str(C) ' measurements...']);
            end
            tm=tic;
            if show<2
                [X, Y, polygonA, polygonB]=mexSptxModal(...
                    single(inData), ...
                    'balanced', args.balanced, ...
                    'W', args.W,...
                    'sigma', args.sigma,...
                    'KLD_normal_1D', args.KLD_normal_1D,...
                    'KLD_exponential_1D', args.KLD_exponential_1D,...
                    'KLD_normal_2D', args.KLD_normal_2D,...
                    'max_clusters', args.max_clusters,...
                    'threads', args.threads, ...
                    'verbose_flags', args.verbose_flags, ...
                    'simplify_polygon', args.simplify_polygon);
                duration=toc(tm);
                if show>0
                    f=figure;
                    ax=subplot(1,2,1, 'Parent', f);
                    showPolygon(inData, X, Y, polygonA, ...
                        ax, parameterNames, ['Part 1: ' ttl]);
                    ax=subplot(1,2,2, 'Parent', f);
                    showPolygon(inData, X, Y, polygonB, ...
                        ax, parameterNames, ['Part 2: ' ttl]);

                end
            else
                f=figure('Name', ['Part 1: ' ttl]);   
                movegui(f, 'northwest');
                f2=figure('Name', ['Part 2: ' ttl]);
                movegui(f2, 'west');
                [X1, Y1, polygonA, polygonB, ...
                    X2, Y2, polygon2a, polygon2b, ...
                    X3, Y3, polygon3a, polygon3b, ...
                    X4, Y4, polygon4a, polygon4b, ...
                    X5, Y5, polygon5a, polygon5b, ...
                    X6, Y6, polygon6a, polygon6b ...
                    ]=mexSptxModal(...
                    single(inData), ...
                    'balanced', args.balanced, ...
                    'W', args.W,...
                    'sigma', args.sigma,...
                    'KLD_normal_1D', args.KLD_normal_1D,...
                    'KLD_exponential_1D', args.KLD_exponential_1D,...
                    'KLD_normal_2D', args.KLD_normal_2D,...
                    'max_clusters', args.max_clusters,...
                    'threads', args.threads, ...
                    'verbose_flags', args.verbose_flags, ...
                    'simplify_polygon', args.simplify_polygon);
                    duration=toc(tm);
                    ax=subplot(2,3,1, 'Parent', f);
                    showPolygon(inData, X1, Y1, polygonA, ax, parameterNames);
                    ax=subplot(2,3,1, 'Parent', f2);
                    showPolygon(inData, X1, Y1, polygonB, ax, parameterNames);
                    ax=subplot(2,3,2, 'Parent', f);
                    showPolygon(inData, X2, Y2, polygon2a, ax, parameterNames);
                    ax=subplot(2,3,2, 'Parent', f2);
                    showPolygon(inData, X2, Y2, polygon2b, ax, parameterNames);

                    ax=subplot(2,3,3, 'Parent', f);
                    showPolygon(inData, X3, Y3, polygon3a, ax, parameterNames);
                    ax=subplot(2,3,3, 'Parent', f2);
                    showPolygon(inData, X3, Y3, polygon3b, ax, parameterNames);
                    
                    ax=subplot(2,3,4, 'Parent', f);
                    showPolygon(inData, X4, Y4, polygon4a, ax, parameterNames);
                    ax=subplot(2,3,4, 'Parent', f2);
                    showPolygon(inData, X4, Y4, polygon4b, ax, parameterNames);
                    
                    ax=subplot(2,3,5, 'Parent', f);
                    showPolygon(inData, X5, Y5, polygon5a, ax, parameterNames);
                    ax=subplot(2,3,5, 'Parent', f2);
                    showPolygon(inData, X5, Y5, polygon5b, ax, parameterNames);
                    
                    ax=subplot(2,3,6, 'Parent', f);
                    showPolygon(inData, X6, Y6, polygon6a, ax, parameterNames);
                    ax=subplot(2,3,6, 'Parent', f2);
                    showPolygon(inData, X6, Y6, polygon6b, ax, parameterNames);
                    
            end
            fprintf('%s milli secs to do modal clustering  split\n', String.encodeRounded(duration,3));
        end
        
        function ok=BuildForAutoGate
            %This invokes your C++ compiler to build a Mac or Windows MEX
            %file for modal separatrix algorithm.
            %If you have not yet installed a compiler,
            %then use the command "mex -setup" in the MATLAB Command
            %Window.
            curPath=fileparts(mfilename('fullpath'));
            cppPath=fullfile(fileparts(curPath), SuhModalSplitter.MEX_CPP_FOLDER_BRANCH);
            cppFile=fullfile(cppPath, 'mexModal2WaySplit.cpp');
            warning('CVS history keeps C++ under "matlabsrc" .. but it is NOT dependent on AutoGate');
            outputFldr=fullfile(fileparts(curPath), 'util');
            if ~exist(cppFile, 'file')
                error(['Mex C++ source does not exist: ' cppFile]);
            end
            buildFile=fullfile(cppPath, [SuhModalSplitter.MEX_FILE '.' mexext]);
            priorPwd=pwd;
            try
                cd(cppPath);
                if ismac
                    fftFldr=['../' SuhModalSplitter.MEX_CPP_FOLDER_MAIN '/mac/'];
                    includePath1=['-I' fftFldr ];
                    includePath2='-I../eppCpp_files';
                    mex('-v', includePath1, includePath2, ...% lib1, lib2, ...
                        'mexModal2WaySplit.cpp', 'Modal2WaySplit.cpp',...
                        'Polygon.cpp', 'addPolygonPoints.cpp',...
                        'MATLAB.cxx', '../eppCpp_files/MxArgs.cpp',...
                        [fftFldr 'libfftw3.a'], ...
                        [fftFldr 'libfftw3f.a'], ...
                        '../eppCpp_files/suh.cpp', ...
                        'COMPFLAGS=''$COMPFLAGS -std=c++14''', '-output', SuhModalSplitter.MEX_FILE);
                    
                else 
                    lib1='-lfftw3f-3';
                    lib2='-lfftw3-3';
                    lib3='-lfftw3l-3';
                    fftFldr=['../' SuhModalSplitter.MEX_CPP_FOLDER_MAIN '/mswin64/'];
                    includePath1=['-I' fftFldr ];
                    includePath2='-I../eppCpp_files';
                    libPath=['-L' fftFldr];
                    mex('-v', includePath1, includePath2, libPath, lib1, lib2, lib3, ...
                        'mexModal2WaySplit.cpp', 'Modal2WaySplit.cpp',...
                        'Polygon.cpp', 'addPolygonPoints.cpp',...
                        'MATLAB.cxx', '../eppCpp_files/MxArgs.cpp',...
                        '../eppCpp_files/suh.cpp', '-output', SuhModalSplitter.MEX_FILE);
                end
                movefile(buildFile, outputFldr);
                cd(priorPwd);
                disp(['Success ! ... mex-ecutable file is ' ...
                    SuhModalSplitter.MexFile])
            catch ex
                cd(priorPwd);
                ex.getReport
                disp('You may need to set up your C++ compiler with "mex -setup C++"!');
            end
            ok=true;
        end
        
        
        function ok=Build
            %This invokes your C++ compiler to build a Mac or Windows MEX
            %file for modal separatrix algorithm.
            %If you have not yet installed a compiler,
            %then use the command "mex -setup" in the MATLAB Command
            %Window.
            curPath=fileparts(mfilename('fullpath'));
            cppPath=fullfile(curPath, 'cpp');
            cppFile=fullfile(cppPath, 'mexModal2WaySplit.cpp');
            outputFldr=curPath;
            if ~exist(cppFile, 'file')
                SuhModalSplitter.BuildForAutoGate
                return;
            end
            buildFile=fullfile(cppPath, [SuhModalSplitter.MEX_FILE '.' mexext]);
            priorPwd=pwd;
            try
                cd(cppPath);
                includePath2='-Isuh';
                disp('Building MEX-ecutable for EPP !!!')
                if ismac
                    fftPath=[cppPath '/mac/'];
                    includePath1=['-I' fftPath ];
                    mex(includePath1, includePath2,...% lib1, lib2, ...
                        'mexModal2WaySplit.cpp', 'Modal2WaySplit.cpp',...
                        'Polygon.cpp', 'addPolygonPoints.cpp',...
                        'MATLAB.cxx', 'suh/MxArgs.cpp',...
                        [fftPath 'libfftw3.a'], ...
                        [fftPath 'libfftw3f.a'], ...
                        'suh/suh.cpp', ...
                        'COMPFLAGS=''$COMPFLAGS -std=c++14''', '-output', SuhModalSplitter.MEX_FILE);
                    
                else 
                    lib1='-lfftw3f-3';
                    lib2='-lfftw3-3';
                    lib3='-lfftw3l-3';
                    fftPath=[cppPath '/mswin64/'];
                    includePath1=['-I' fftPath ];
                    libPath=['-L' fftPath];
                    mex(includePath1, includePath2, libPath, lib1, lib2, lib3, ...
                        'mexModal2WaySplit.cpp', 'Modal2WaySplit.cpp',...
                        'Polygon.cpp', 'addPolygonPoints.cpp',...
                        'MATLAB.cxx', 'suh/MxArgs.cpp',...
                        'suh/suh.cpp', '-output', SuhModalSplitter.MEX_FILE);
                end
                movefile(buildFile, outputFldr);
                cd(priorPwd);
                disp(['Success ! ... mex-ecutable file is ' ...
                    SuhModalSplitter.MexFile])
            catch ex
                cd(priorPwd);
                ex.getReport
                disp('You may need to set up your C++ compiler with "mex -setup C++"!');
            end
            ok=true;
        end

        function mexFile=MexFile()
            mexFile=fullfile(fileparts(mfilename('fullpath')),...
                [SuhModalSplitter.MEX_FILE '.' mexext ]);
        end
        
        function mexFile=MexFileUtil()
            fl=fileparts(fileparts(mfilename('fullpath')));
            mexFile=fullfile(fl, 'util',  [SuhModalSplitter.MEX_FILE '.' mexext ]);
        end
        
        function Quarantine(mexFile)
            try
                if nargin<1
                    mexFile=SuhModalSplitter.MexFile;
                end
                if ismac
                    if ~exist(mexFile, 'file')
                        
                    else
                        system(['xattr -r -d com.apple.quarantine ' ...
                            String.ToSystem(mexFile)]);
                    end
                end
            catch ex
                disp(ex)
            end
            if nargin<1 % quarantine EVERY possible location of mex
                SuhModalSplitter.Quarantine(SuhModalSplitter.MexFileUtil);
            end
        end


        function [args, argued, unmatched]=GetArgs(varargin)
             [args, argued, unmatched]=Args.NewKeepUnmatched(...
                 SuhModalSplitter.DefineArgs(), varargin{:});            
        end
        
        function p=DefineArgs(varargin)
            p = inputParser;
            % the defalt -1 simply means use the 
            % current best default that Wayne Moore has found
            addParameter(p,'balanced', true, @(x)islogical(x));
            addParameter(p,'W', .01, ...
                @(x) Args.IsNumber(x, 'W', .001, .6));
            addParameter(p,'sigma', 3, ...
                @(x) Args.IsNumber(x, 'sigma', 1, 7));
            addParameter(p,'KLD_exponential_1D', .16, ...
                @(x) Args.IsNumber(x, 'KLD_exponential_1D', 0, .5));
            addParameter(p,'KLD_normal_1D', .16, ...
                @(x) Args.IsNumber(x, 'KLD_normal_1D', 0, .5));
            addParameter(p,'KLD_normal_2D', .16, ...
                @(x) Args.IsNumber(x, 'KLD_normal_2D', 0, 2.25));
            addParameter(p,'max_clusters', 12,  ...
                @(x) Args.IsInteger(x, 'max_clusters', 3, 30));
            
            addParameter(p,'verbose_flags', 0,  ...
                @(x) Args.IsInteger(x, 'verbose_flags', 0, intmax/2));
            addParameter(p,'threads', -1,  ...
                @(x) Args.IsInteger(x, 'threads', -1, 330));
            addParameter(p,'simplify_polygon', true, @(x)islogical(x));
            addParameter(p, 'use_not_gate', true, @(x)islogical(x));
            addParameter(p, 'column_names', {}, @Args.IsStrings);            
        end
    end
end