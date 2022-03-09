%   AUTHORSHIP
%   Primary Developer: Stephen Meehan <swmeehan@stanford.edu> 
%   Math Lead & Secondary Developer:  Connor Meehan <connor.gw.meehan@gmail.com>
%   Bioinformatics Lead:  Wayne Moore <wmoore@stanford.edu>
%   Provided by the Herzenberg Lab at Stanford University 
%   License: BSD 3 clause
%

classdef MlpExamples < handle
    methods(Static)
        function [reduction, umap, clusterIds, extras]...
            =EliverTrain4Fmo(varargin)
            %to modify holdout and other things you would use the varargin
            %like this example which holds out 33% of the data
            %
            %MlpExamples.EliverTrain4Fmo('mlp_train', struct('holdout', .33), 'fast', false);
            
            [reduction, umap, clusterIds, extras]...
                =MlpExamples.Train(33, 31, varargin);
        end

        function [reduction, umap, clusterIds, extras]...
            =EliverPredictFmo(varargin)
            [reduction, umap, clusterIds, extras]=MlpExamples.Predict(...
                'balbcFmo.html', 34, 32, varargin);
        end

        function [reduction, umap, clusterIds, extras]...
            =EliverTrain4Rag(varargin)
            [reduction, umap, clusterIds, extras]...
                =MlpExamples.Train(35, 39, varargin);
        end

        function [reduction, umap, clusterIds, extras]...
            =EliverPredictRag(varargin)
            [reduction, umap, clusterIds, extras]=MlpExamples.Predict(...
                'rag.html', 36, 40, varargin);
        end

        
        function [reduction, umap, clusterIds, extras]...
            =EliverTrain4C57(varargin)
            [reduction, umap, clusterIds, extras]...
                =MlpExamples.Train(37, 41, varargin);
        end

        function [reduction, umap, clusterIds, extras]...
            =EliverPredictC57(varargin)
            [reduction, umap, clusterIds, extras]=MlpExamples.Predict(...
                'c57.html', 38, 42, varargin);
        end

        function [reduction, umap, clusterIds, extras]...
            =Omip044Train(varargin)
            [reduction, umap, clusterIds, extras]...
                =MlpExamples.Train(43, 55, varargin);
        end

        function [reduction, umap, clusterIds, extras]...
                =Omip044Predict(varargin)
            [reduction, umap, clusterIds, extras]=MlpExamples.Predict(...
                'omip044.html', 44, 56, varargin);
        end

        function [reduction, umap, clusterIds, extras]...
            =GenentechTrain(varargin)
            [reduction, umap, clusterIds, extras]...
                =MlpExamples.Train(45, 57, varargin);
        end

        function [reduction, umap, clusterIds, extras]...
                =GenentechPredict(varargin)
            [reduction, umap, clusterIds, extras]=MlpExamples.Predict(...
                'genentech.html', 46, 58, varargin);
        end

        function [reduction, umap, clusterIds, extras]...
                =PanoramaTrain(varargin)
            [reduction, umap, clusterIds, extras]...
                =MlpExamples.Train(47, 59, varargin);
        end

        function [reduction, umap, clusterIds, extras]...
                =PanoramaPredict(varargin)
            [reduction, umap, clusterIds, extras]=MlpExamples.Predict(...
                'panorama.html', 48, 60, varargin);
        end

        function [reduction, umap, clusterIds, extras]...
                =Omip069Train(varargin)
            [reduction, umap, clusterIds, extras]...
                =MlpExamples.Train(49, 61, varargin);
        end

        function [reduction, umap, clusterIds, extras]...
                =Omip069Predict(varargin)
            [reduction, umap, clusterIds, extras]=MlpExamples.Predict(...
                'omip069.html', 50, 62, varargin);
        end

        function [reduction, umap, clusterIds, extras]...
                =MaeckerTrain(varargin)
            [reduction, umap, clusterIds, extras]...
                =MlpExamples.Train(51, 63, varargin);
        end

        function [reduction, umap, clusterIds, extras]...
                =MaeckerPredict(varargin)
            [reduction, umap, clusterIds, extras]=MlpExamples.Predict(...
                'maecker.html', 52, 64, varargin);
        end

        function [reduction, umap, clusterIds, extras]...
                =Omip047Train(varargin)
            [reduction, umap, clusterIds, extras]...
                =MlpExamples.Train(53, 65, varargin);
        end

        function [reduction, umap, clusterIds, extras]...
                =Omip047Predict(varargin)
            [reduction, umap, clusterIds, extras]=MlpExamples.Predict(...
                'omip047.html', 54, 66, varargin);
        end

        function [reduction, umap, clusterIds, extras]=...
                Train(umapExample, umapExampleForPython, vArgs)
            [vArgs, usePython]=UmapUtil.SetMlpMaxLimit(vArgs, 1250, 400);
            if usePython
                if umapExampleForPython<30
                    msgError('No python example');
                    reduction=[]; umap=[]; clusterIds=[]; extras=[];
                    return;
                end
                umapExample=umapExampleForPython;
            end
            vArgs=Args.SetDefaults(vArgs, 'fast_approximation', false);
            [reduction, umap, clusterIds, extras]...
                =run_examples(umapExample, vArgs{:});
        end

        function [reduction, umap, clusterIds, extras]...
                =Predict(htmlFile, umapExample, umapExampleForPython,vArgs)
            vArgs=Args.SetDefaults(vArgs, 'fast_approximation', false);
            web=Args.GetStartsWith('web', true, vArgs);
            Args.RemoveArg(vArgs, 'web');
            if web
                vArgs=UmapUtil.AddFastMatchBrowseFileArgs(htmlFile, vArgs);
            end
            arg=Args.GetStartsWith('mlp_train', 'fitcnet', vArgs);
            usePython=UmapUtil.GetMlpTrainArg(arg);
            if usePython
                if umapExampleForPython<30
                    msgError('No python example');
                    reduction=[]; umap=[]; clusterIds=[]; extras=[];
                    return;
                end
                umapExample=umapExampleForPython;
            end
            [reduction, umap, clusterIds, extras]=run_examples(...
                umapExample, vArgs{:});
        end

    end
end