classdef TestArgs <handle
    methods(Static)
        function argsObj=Umap
            argsObj=UmapUtil.GetArgsWithMetaInfo('eliverLabeled.csv', ...
                'label_column', 'end', 'n_neighbors', 17, ...
                'match_scenarios', [1 2 4]);
            msg(argsObj.getArgumentClinicPanel);
            help=argsObj.getHelp('fast_approximation', false);
            cmp=argsObj.getEditorComponent('match_scenarios');
            disp('done');
        end
        
        function argsObj=Epp
            argsObj=SuhEpp.GetArgsWithMetaInfo(...
                'eliverLabeled.csv', 'label_column', ...
                'end', 'cytometer', 'conventional', ...
                'min_branch_size',150, 'n_neighbors', 14);
            msg(argsObj.getArgumentClinicPanel);
            help=argsObj.getHelp('W', false);
            cmp=argsObj.getEditorComponent('KLD_normal_1D');
            disp('done');
        end
        
        function MergeArgs(varargin)
            Args.NewMerger({SuhEpp.DefineArgs, ...
                SuhModalSplitter.DefineArgs,...
                SuhDbmSplitter.DefineArgs}, varargin{:});
        end

        function argsObj=Match
            argsObj=SuhMatch.GetArgsWithMetaInfo();
            msg(argsObj.getArgumentClinicPanel);
            help=argsObj.getHelp('log10', false);
        end
    end
end