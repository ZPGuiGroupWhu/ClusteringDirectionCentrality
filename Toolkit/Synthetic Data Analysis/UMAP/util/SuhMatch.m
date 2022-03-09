classdef SuhMatch < handle
    %%SuhMatch.Run is a wrapper for run_HiD_match and
    %   run_QfTree. It preprocesses csv input files
    %   to marshall the data and label arguments for both.
    %
    %   The publication that introduces QfMatch is
    %   https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5818510/
    %
    %   A publication that further elaborates the algorithm and
    %   adds in QfTree is
    %   https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6586874/
    %
    %   [reduction,umap] = RUN_QF_MATCH(trainingSet, trainingIds,
    %       testSet, testIds, 'NAME1',VALUE1,..., 'NAMEN',VALUEN)
    %
    %   RETURN VALUES
    %   Invoking run_umap produces 2 return values:
    %   1)result; an instance of the QFHiDM class describing match results
    %       in the instance variable result.matches, result.matrixHtml
    %       is a web page description of the result
    %
    %   2)done indicating success
    %
    %
    %   REQUIRED INPUT ARGUMENT
    %   trainingSet row/col matrix of data for training set
    %   trainingIds numeric identifiers of training set subsets.  There is
    %       more than 1 column when subsets are overlapping,  run_qf_match
    %       asserts same number of rows in trainingSet and trainingIds.
    %   testSet row/col matrix of data for test set
    %   testIds numeric identifiers of test set subsets.  There is
    %       more than 1 column when subsets are overlapping,  run_qf_match
    %       asserts same number of rows in testSet and testIds.
    %
    %   OPTIONAL NAME VALUE PAIR ARGUMENTS
    %   The optional argument name/value pairs are:
    %
    %   Name                    Value
    %
    %   'test_set'                csv file containing  matrix of test set
    %                             data including header line of column
    %                             labels.
    %                             Default is 'panoramaSample10_labeled.csv'
    %
    %   'test_label_column'       The column # for column containing 
    %                             subset/population labels
    %                             Default is 'end'
    %
    %   'test_label_file'         Name of file with color/name properties for
    %                             each test set label.
    %                             Default is test_set file with extension
    %                             of '.properties' instead of '.csv'
    %
    %   'training_set'            csv file containing  matrix of test set
    %                             data including header line of column labels
    %                             Default is 'panoramaSample6_labeled.csv'
    %
    %   'training_label_column'   The column # for column containing 
    %                             subset/population labels in training set
    %                             csv file
    %                             Default is 'end'
    %
    %   'training_label_file'     Name of file with color/name properties for
    %                             each training set label.
    %                             Default is test_set file with extension
    %                             of '.properties' instead of '.csv'
    %
    %   'qf_tree'               Show a dendrogram plot that represents the
    %                           relatedness of data groupings in the
    %                           supervising and supervised embeddings. The
    %                           above documentation for the match_supervisors
    %                           argument defines "data groupings". The
    %                           publication that introduces the QF tree is
    %                           https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6586874/.
    %                           This uses phytree from MATLAB's Bioinformatics
    %                           Toolbox, hence changing this value to true
    %                           requires the Bioinformatics Toolbox.
    %                           Default is false.
    %                           run_umap only consults this argument when it
    %                           guides a reduction with a supervised
    %                           template.
    %

    %
    %
    %   AUTHORSHIP
    %   Primary inventor:      Darya Orlova <dyorlova@gmail.com>
    %   Primary Developer:     Stephen Meehan <swmeehan@stanford.edu>
    %
    %   Provided by the Herzenberg Lab at Stanford University
    %   License: BSD 3 clause
    %
    
    methods(Static)
        function [match, matchTable, trainingQfTreeMatch, ...
                trainingQfTree, testQfTreeMatch, testQfTree]...
                =Run(varargin)
            app=BasicMap.Global;
            MatBasics.WarningsOff;
            match=[]; matchTable=[]; trainingQfTreeMatch=[]; ...
                trainingQfTree=[]; testQfTreeMatch=[]; testQfTree=[];
            try
                html=Html.WrapHr(['<b>Activating SUH subset<br>'...
                    '<u>characterization</u> pipeline</b><br><br>' ...
                    Html.WrapBoldSmall( ...
                    '(<i>Darya''s QFMatch/QF-tree tools</i>)')]);
                pu=PopUp('Initializing...', ...
                    'center', 'Subset characterizing...',false,true,...
                    Gui.GetResizedImageFile('orlova.png', .2, app));
                pu.initProgress(3, 'data preparation');
                pu.setText(html);
                [argsObj, args]=SuhMatch.GetArgsWithMetaInfo(varargin{:});
                trainingSet=SuhDataSet.New(args.training_set, ...
                    'pu', pu,...
                    'column_names', args.column_names, ...
                    'label_column', args.training_label_column, ...
                    'label_file', args.training_label_file, ...
                    'normalized_range_test', ...
                    args.normalized_range_test,...
                    'fnc_normalize', ...
                    args.fnc_normalize);
                if isempty(trainingSet.data)
                    pu.close;
                    return;
                end
                pu.incrementProgress;
                [trainingNames, trainingClrs, trainingIds]...
                    =trainingSet.getLabelInfo;
                % check for use case scenario of 2 classifications on same
                % data
                if isempty(args.test_set) && ...
                        isnumeric(args.test_label_column) ...
                        && length(args.test_label_column)==trainingSet.R
                    args.test_set=trainingSet.data;
                end
                testSet=SuhDataSet.New(args.test_set, ...
                    'pu', pu,...
                    'column_names', args.column_names, ...
                    'label_column', args.test_label_column, ...
                    'label_file', args.test_label_file, ...
                    'normalized_range_test', ...
                    args.normalized_range_test,...
                    'fnc_normalize', ...
                    args.fnc_normalize);
                if isempty(testSet.data)
                    pu.close;
                    return;
                end
                pu.incrementProgress;
                [testNames, ~, testIds]=testSet.getLabelInfo;
                args=SuhMatch.CheckOutputFolder(args, trainingSet, testSet);
                folder=args.output_folder;
                savedFile=fullfile(folder, 'suh_match.mat');
                visible=args.visible;
                if isempty(testSet.data) || isempty(testSet.labels)
                    if args.qf_tree || askYesOrNo(...
                            Html.WrapHr(['No test set with labels... '...
                            '<br>Run QF-tree?']))
                        args.qf_tree=true;
                        SuhMatch.QfTreeTraining(trainingSet, args, ...
                            trainingIds, trainingNames, trainingClrs, pu);
                    end
                else
                    qf=QfTable.Load(savedFile, false, ...
                        trainingSet.data, trainingIds);
                    justDone=false;
                    if ~isempty(qf) && args.ask_if_preexists 
                        [reUse, cancelled]=askYesOrNo(...
                            'Re-use prior match calculations?');
                        if cancelled
                            pu.close;
                            return;
                        end
                        yes=~reUse;
                    else
                        yes=isempty(qf) || ~args.ask_if_preexists;
                    end
                    if yes
                        justDone=true;
                        pu.incrementProgress;
                        varArgIn=['trainingNames', {trainingNames}, ...
                            'testNames', {testNames}, 'pu', {pu},...
                            argsObj.extractFromThis(QfHiDM.DefineArgs, true)];
                        [match, done]=run_HiD_match(trainingSet.data, ...
                            trainingIds, testSet.data,testIds, varArgIn{:});
                        if ~done
                            pu.close;
                            match=[];
                            return;
                        end
                        match.setColumnNames( trainingSet.columnNames );
                    else
                        pu.incrementProgress;
                        match=qf;
                    end
                    if args.match_table_fig || args.match_histogram_figs
                        qfArgs=struct();
                        [~, qfArgs.training_set]...
                            =fileparts(args.training_label_file);
                        [~, qfArgs.test_set]=fileparts(args.test_label_file);
                        matchTable=QfTable(match, trainingClrs, [],...
                            get(0, 'currentFig'), visible, qfArgs, 'SuhMatch');
                        if justDone
                            matchTable.save(match, savedFile);
                        end
                        if args.match_histogram_figs
                            if ~matchTable.doHistF(visible)
                            else
                                if args.save_output
                                    Gui.SavePng(matchTable.fHistFig,...
                                        fullfile(args.output_folder, ...
                                        'overlap_histogram.png'));
                                end
                                if matchTable.doHistQF(visible)
                                    if args.save_output
                                        Gui.SavePng(matchTable.qHistFig,...
                                            fullfile(args.output_folder, ...
                                            'similarity_histogram.png'));
                                    end
                                end
                            end
                        end
                        matchTable.listen(trainingSet.columnNames, ...
                            trainingSet, testSet);
                    else
                        % awkward evolutionary history of QF
                        %   requires constructing gui element
                        %   to save NON gui data about matching ...sigh
                        matchTable=QfTable(match, trainingClrs, [], ...
                            get(0, 'currentFig'), false);
                        if ~isstruct(this.match)
                            matchTable.save(this.match, savedFile);
                        end
                    end
                    SuhMatch.SaveMatchedTestNamesClrs(trainingSet, ...
                        match, args.output_folder);
                    [testQfTreeMatch, testQfTree]=...
                        SuhMatch.QfTreeTest(testSet, args, testIds, ...
                        folder, pu, {matchTable.fig, 'north east++', true});
                    [trainingQfTreeMatch, trainingQfTree]=...
                        SuhMatch.QfTreeTraining(trainingSet, args, ...
                        trainingIds, trainingNames, trainingClrs, ...
                        pu, {matchTable.fig, 'south east++', true});
                end
            catch ex
                if exist('pu', 'var')
                    pu.close;
                end
                Gui.MsgException(ex);
            end
            pu.close;
            if ~isempty(match)
                try
                    match.args=args;
                catch
                end
            end
        end
        
        function SaveMatchedTestNamesClrs(trainingSet, match, folder)
            matchedLabelFile=fullfile(folder,  SuhDataSet.FILE_MATCH_LABEL);
            if ~exist(matchedLabelFile, 'file')
                matchedNamesClrsFile=fullfile(folder, SuhDataSet.FILE_MATCH_NAMES_CLRS);
                [matchedTestNames, matchedTestClrs]=...
                    match.getMatchingNamesAndColors(trainingSet.lblMap);
                save(matchedNamesClrsFile, 'matchedTestNames', 'matchedTestClrs');
                props=java.util.Properties;
                ids=match.sIds;
                N=length(ids);
                for i=1:N
                    id=num2str(ids(i));
                    name=matchedTestNames{i};
                    clr=num2str(matchedTestClrs(i,:)*256);
                    props.setProperty(id, name);
                    props.setProperty([id '.color'], clr);
                end
                File.SaveProperties2(matchedLabelFile, props);
            end
        end
        
        function [qfTreeMatch, qfTree]=QfTreeTest(testSet, args, sLbls,...
                folder, pu, locate_fig)
            qfTreeMatch=[]; qfTree=[];
            if args.qf_tree
                matchedNamesClrsFile=fullfile(folder, SuhDataSet.FILE_MATCH_NAMES_CLRS);
                [~,fileName]=fileparts(testSet.file);
                load(matchedNamesClrsFile, 'matchedTestNames', 'matchedTestClrs');
                if args.visible && nargin>5
                    [qfTreeMatch, qfTree]=run_QfTree(testSet.data,...
                        sLbls, {'Test set', fileName}, 'trainingNames', ...
                        matchedTestNames, 'log10', true, 'colors', matchedTestClrs, ...
                        'pu', pu, 'locate_fig', locate_fig);
                else
                    [qfTreeMatch, qfTree]=run_QfTree(testSet.data,...
                        sLbls, {'Test set', fileName}, 'trainingNames', ...
                        matchedTestNames, 'log10', true, ...
                        'colors', matchedTestClrs, 'pu', pu);
                    if args.visible
                        set(qfTree.fig, 'visible', 'on');
                    end
                end
                if args.save_output
                    Gui.SavePng(qfTree.fig,...
                        fullfile(args.output_folder, ...
                        'qf_tree_test.png'));
                end
            end
        end
        
        function [qfTreeMatch, qfTree]=QfTreeTraining(...
                trainingSet, args, tLbls, tNames, clrs, pu, ...
                locate_fig)
            qfTreeMatch=[]; qfTree=[];
            if args.qf_tree
                [~,fileName]=fileparts(trainingSet.file);
                if args.visible && nargin>6
                    [qfTreeMatch, qfTree]=run_QfTree(trainingSet.data, ...
                        tLbls, {'Training set', fileName},  'trainingNames', ...
                        tNames, 'log10', true, 'colors', clrs, 'pu', pu,...
                        'locate_fig', locate_fig);
                else
                    [qfTreeMatch, qfTree]=run_QfTree(trainingSet.data, ...
                        tLbls, {'Training set', fileName},  'trainingNames', ...
                        tNames, 'log10', true, 'colors', clrs, 'pu', pu);
                    if args.visible
                        set(qfTree.fig, 'visible', 'on');
                    end
                end
                if args.save_output
                    Gui.SavePng(qfTree.fig,...
                        fullfile(args.output_folder, 'qf_tree_training.png'));
                end
            end
        end
        
        function [argsObj, args]=GetArgsWithMetaInfo(varargin)
            qfArgs=Args(SuhMatch.DefineArgs);
            varArgIn=Args.Str2NumOrLogical(qfArgs.fields, varargin);
            [args,~, argsObj]=Args.New(SuhMatch.DefineArgs, varArgIn{:});
            if ~isempty(args.test_label_column)
                if isempty(args.test_label_file)
                    args.test_label_file=args.training_label_file;
                end
            end
            argsObj.commandPreamble='suh_pipelines';
            argsObj.commandVarArgIn='''pipeline'', ''match'', ';
            m=mfilename('fullpath');
            p=fileparts(m);
            argsObj.setSources(@SuhMatch.Run, {[m '.m'], fullfile(p, ...
                'run_HiD_match.m')}, m);
            argsObj.load;
        end
        
        function args=CheckOutputFolder(args, trainingSet, testSet)
            if isempty(args.output_folder)
                if ~isempty(trainingSet.data)
                    [p,f1]=trainingSet.fileParts;
                    if ~isempty(testSet.data)
                        [~,f2]=testSet.fileParts;
                        if isequal(f1,f2)
                            f2=['self_' ...
                                num2str( floor(mean(testSet.labels)))];
                        end
                        f1=[f1 '.matches'];
                        args.output_folder=fullfile(p, f1, f2);
                    else
                        f1=[f1 '.matches'];
                        args.ouput_folder=fullfile(p, f1);
                    end
                end
            end
            if ~isempty(args.output_folder)
                [ok, errMsg]=File.mkDir(args.output_folder);
                if ~ok
                    msgError(Html.Wrap(errMsg, 200), 20, ...
                        'south east+', 'Folder problem...');
                end
            end
        end
        
        function argsObj=SetArgsMetaInfo(argsObj)
            argsObj.setMetaInfo('mergeStrategy', 'low', 1, 'high', 8, ...
                'is_integer', true, 'label', 'Merge strategy');
            
            argsObj.setMetaInfo('mergeLimit', 'low', 1, 'high', 12, ...
                'is_integer', true, 'label', 'Merge limit');
            argsObj.setMetaInfo('matchStrategy', 'low', 1, 'high', 3, ...
                'is_integer', true, 'label', 'Match strategy');
            
            argsObj.setMetaInfo('normalized_range_test', ...
                'type', 'double',...
                'editor_columns', 2,  'is_integer', false, ...
                'text_columns', 2, 'type', 'double');
            argsObj.setMetaInfo('pu', 'command_only', true, ...
                'outsider', true);
            argsObj.setMetaInfo('testSetComp', 'command_only', true, ...
                'outsider', true);
            argsObj.setMetaInfo('trainingSetComp', 'command_only', true,...
                'outsider', true);
            argsObj.setMetaInfo('trainingNames', 'command_only', true,...
                'type', 'char', 'outsider', true);
            argsObj.setMetaInfo('testNames', 'command_only', true,...
                'type', 'char', 'outsider', true);
            
            argsObj.setMetaInfo('output_folder', 'type', 'folder');
            argsObj.setFileFocus('QFMatch/QF-tree training data', ...
                'training_set');
            argsObj.setCsv('training_set', true, 'training_label_column',...
                'training_label_file');
            argsObj.setFileFocus('QFMatch/QF-tree test data', 'test_set');
            argsObj.setCsv('test_set', true, 'test_label_column', ...
                'test_label_file');
        end
        
        function p=DefineArgs()
            p = inputParser;     
            addParameter(p,'training_set', ...
                'panoramaSample6_labeled.csv', ...
                @Args.IsDataOk);
            addParameter(p,'training_label_file', '', @Args.IsFileOk);
            addParameter(p,'training_label_column', 'end', @Args.IsLabelColumn);
            addParameter(p, 'column_names', {}, @Args.IsStrings);
            addParameter(p,'test_set', ...
                'panoramaSample10_labeled.csv', ...
                @Args.IsDataOk);
            addParameter(p,'test_label_file', '', @Args.IsFileOk);
            addParameter(p,'test_label_column', 'end', @Args.IsLabelColumn);
            
            addParameter(p, 'output_folder', '',  @Args.IsFolderOk);
            addParameter(p, 'qf_tree', false, @islogical);
            addParameter(p, 'match', true, @islogical);
            addParameter(p, 'visible', true, @islogical);
            addParameter(p, 'save_output', true, @islogical);
            addParameter(p, 'match_table_fig', true, @islogical);
            addParameter(p, 'match_histogram_figs', true, @islogical);
            addParameter(p, 'ask_if_preexists', true, @islogical);
            p.FunctionName='SuhMatch.Run()'; 
            SuhDataSet.AddNormalizedParameters(p, ...
                []);
            QfHiDM.DefineArgs(p);
        end
    end
end