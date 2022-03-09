 %   AUTHORSHIP
%   Developer: Stephen Meehan <swmeehan@stanford.edu>
%   Funded by the Herzenberg Lab at Stanford University 
%   License: BSD 3 clause
%
classdef Mlp < handle
    properties(Constant)
        PROP='MLP';
        UPGRADE_TXT=['MATLAB''s fitcnet requires '...
                    'version r2021a or later'];
        EXT_TENSORFLOW='.h5';
        EXT_FITCNET='.mlp.mat';
        EXT_SCALE='_scale.pkl'; %required by Jonathan's mlp.py 
        EXT_DICT='_dict.pkl'; %required by Jonathan's mlp.py 
        EXT_COLUMNS='.mlp.columnNames';
        PROP_SERVER_FOLDER='Mlp.Server.SubFolder';
        PROP_SERVER_HOST='Mlp.Server.Host';
        PROP_LOCAL_FOLDER='Mlp.Local.SubFolder';
        DFLT_LOCAL_FOLDER=File.Documents('mlp');
    end

    methods(Static)

        function fldr=DefaultLocalFolder
            fldr=BasicMap.Global.get(Mlp.PROP_LOCAL_FOLDER, ...
                    Mlp.DFLT_LOCAL_FOLDER);
        end

        function ok=IsGoodArgs(x, argName)
            if ischar(x)
                ok=startsWith(lower(x), 'tensor') || startsWith(lower(x), 'fit');  
            elseif isstruct(x)
                ok=true;
            else
                ok=false;
                warning(['Expecting argument "%s" to match (case insensitve) "TensorFlow"  '...
                    'or "fitcnet" \n... or a struct '...
                    'with this in type field PLUS fields for args \n'...
                    '    documented at Mlp.Train (fitcnet) '...
                    'or MlpPython.Train (TensorFlow)!'], argName);
            end
        end

        function Assert2021aOrLater
            if verLessThan('matLab', '9.10')
                needed=[Mlp.UPGRADE_TXT ...
                    '<br>Please upgrade from ' ...
                    version('-release') ' to r2021a or later!'];
                msgError(Html.WrapHr(['<font color="red"><b>MLP'...
                    ' classification not done!</font></b><br><br>'...
                    '<font color="black">' needed ...
                    '</font>...']),25,'center', 'Problem....');
                error( needed );
           end
        end
        
        function file=DoModelFileExtension(file, forTraining)
            [p, f, e]=fileparts(file);
            if strcmpi(e, '.csv') || isempty(e)
                if forTraining
                    file=fullfile(p,[f Mlp.EXT_FITCNET]);
                else
                    file=fullfile(p, f);
                end
            end
        end
        
        function p=DefineArgs
            p = inputParser;
            addParameter(p,'model_file', '', ...
                @(x)isa(x, 'ClassificationNeuralNetwork')||Args.IsFileOk(x));
            addParameter(p,'model_default_folder', Mlp.DefaultLocalFolder,...
                @Args.IsFolderOk);
            
            addParameter(p,'confirm_model', true, @islogical);
            addParameter(p, 'pu', [], @(x)isempty(x)||isa(x, 'PopUp'))
            addParameter(p, 'column_names', {}, ...
                @(x)isempty(x)||Args.IsStrings(x));
            addParameter(p, 'props', BasicMap.Global);
            addParameter(p, 'property', Mlp.PROP);
            addParameter(p, 'class_limit', .1,...
                @(x)x>=2 || Args.IsNumber(x, 'class_limit', .01, .9));
        end

        function p=DefineArgsForTrain
            p = Mlp.DefineArgs;
            addParameter(p, 'holdout', .2, ...
                @(x)Args.IsNumber(x,'holdout', 0, .9));
            addParameter(p, 'validate', true, @islogical);
        end

        function p=DefineArgsForPredict
            p = Mlp.DefineArgs;
            addParameter(p, 'has_labels', true, @islogical);
        end

        function [modelFileName, model, accuracy]...
                =Train(csvFileOrData, varargin)
%%Mlp.Train builds feedforward, fully connected neural networks using 
% MATLAB's fitcnet module introduced in their release r2021a
%
%   [modelFileName, model, accuracy]=Mlp.Train(csvFileOrData,...
%   'NAME1',VALUE1, 'NAMEN',VALUEN) 
%            
%RETURN VALUES
%   Invoking Mlp.Train produces 3 return values:
%   1)modelFilename: the path and name of file with fitcnet model
%   2)model:  the MATLAB fitcnet object
%   3)accuracy:  % accuracy based on amount of holdout input data
%   predictions
%
%
%   REQUIRED INPUT ARGUMENT
%   csvFileOrData is a CSV file containing a matrix or matrix where the
%   columns are numeric measurements and the last column MUST BE a numeric
%   identifier of the class of the matrix row
%
%   OPTIONAL NAME VALUE PAIR ARGUMENTS
%   Mlp.Train accepts ALL of the named arguments documented for MATLAB's
%   fitcnet at
%       https://www.mathworks.com/help/stats/fitcnet.html
%   Additional such arguments include:
%
%   Name                    Value
%   'column_names'          A cell of names for each column.
%                           This is only needed if csvFileOrData is a
%                           matrix.
%
%   'model_file'            Name of file to save model to.  If no argument
%                           is specified then this function saves the model
%                           where in the input CSV file is located
%                           substituting the extension csv with mlp.mat. If
%                           the input data is a matrix the file model is
%                           saved to ~/Documents/mlp with a generated name
%                           based on size and mean of classification label
%                           
%   'confirm_model'         true/false.  If true a file save window pops up
%                           to confirm the model file name
%
%   'holdout'               The percent of the input data to not use for
%                           training.  Valid entries are 0 to .9.
%                           Default is .2;
%
%   'validate'              Use the holdout % to validate the training of
%                           MLP.  This restricts over-fitting and
%                           accelerates the training by stopping when
%                           over-fitting is detected                        .
%
%   EXAMPLES
%
%   1.      Build a fitcnet model with a BALB/c sample.
%
%           modelFitcnet=Mlp.Train('balbc4FmoLabeled.csv', 'class', .12, 'confirm', false);
%
%   2.      Build a fitcnet model with the same data as in example 1, but
%           pass it as a numeric matrix and hold out 40% of the rows from
%           training and reeport progress in Command Window.
%
%           [trainingSet, trainingHdr]=File.ReadCsv('balbc4FmoLabeled.csv');
%           [modelFileFitcnet, model]=Mlp.Train(trainingSet,'column', trainingHdr, 'hold', .5, 'verbose', 1, 'VerboseFrequency', 50)
%
%   3.      Same as 2, except test for classification label check.
%
%           modelFitcnet=Mlp.Train(trainingSet(:,1:end-1),'column', trainingHdr(1:end-1), 'hold', .5, 'verbose', 1, 'VerboseFrequency', 50)
%
            Mlp.Assert2021aOrLater;
            try
                [args, ~,~, argsObj]...
                =Args.NewKeepUnmatched(Mlp.DefineArgsForTrain,varargin{:});
                if ~isempty(args.pu)
                    txt=['<html>MATLAB''s fitcnet is training '...
                        '<br>an MLP neural network...<hr></html>'];
                    args.pu.setText(txt);
                end
            catch ex
                BasicMap.Global.reportProblem(ex);
                throw(ex);
            end
            if nargin<1
                csvFileOrData='';
            end
            if isempty(csvFileOrData) %fav example from Eliver Ghosn
                csvFileOrData='balbc4FmoLabeled.csv';
            end            
            trainingLimit=Args.GetStartsWith(...
                'IterationLimit', 1251, varargin);
            [table, modelFileName, columnNames]=Mlp.ResolveData(...
                csvFileOrData, args.column_names, ...
                args.model_file, args.confirm_model, ...
                true, true, false, args.class_limit, ...
                args.props, args.property, ...
                args.model_default_folder, trainingLimit);
            accuracy=0;
            if isempty(table) || isempty(modelFileName)
                modelFileName='';
                model=[];
                return;
            end
            hdr=table.Properties.VariableNames;
            labelColumn=hdr{end};
            labels=table{:,labelColumn};
            if args.holdout>0
                c = cvpartition(labels, ...
                    "Holdout", args.holdout);
                trainingIdxs = training(c); % Indices for the training set
                testIdxs = test(c); % Indices for the test set
                trainingSet=table(trainingIdxs,:);
            else
                trainingSet=table;
                testIdxs=[];
            end
            disp('  >>> Training MLP neural network via MATLAB fitcnet');
            varArgIn=argsObj.getUnmatchedVarArgs;
            varArgIn=Args.SetDefaults(varArgIn, 'verbose', 1, ...
                    'VerboseFrequency', 50, ...
                    'LayerSizes', [100 50 25], ...
                    'IterationLimit', trainingLimit,...
                    'Standardize', true);
            if args.validate && args.holdout>0
                varArgIn{end+1}='ValidationData';
                testSet=table(testIdxs,:);
                varArgIn{end+1}=testSet;
            end
            if ~isempty(args.pu)
                if args.validate
                    word1 = 'Up to a maximum of ';
                    word2 = ['<br>with ' ...
                        String.encodePercent(args.holdout) ...
                        ' held for validation '];
                else
                    word1='';
                    word2=' ';
                end
                [R, C]=size(trainingSet);
                args.pu.setText2([word1 num2str(trainingLimit) ...
                    ' iterations ' word2 'for ' String.encodeInteger(R)...
                    ' x ' String.encodeInteger(C-1) ' values in: ' ...
                    Html.FileTree(modelFileName)])
            end
            x=tic;
            try
                model=fitcnet(trainingSet, labelColumn,  ...
                    varArgIn{:});
            catch ex
                if ~args.validate
                    throw(ex)
                end
                testSet=LabelBasics.CompressTable(table, ...
                    args.holdout, 1, columnNames);
                varArgIn=Args.Set('ValidationData', ...
                    testSet, varArgIn{:});
                trainingSet=LabelBasics.CompressTable(table, ...
                    1-args.holdout, 1, columnNames);
                
                model=fitcnet(trainingSet, labelColumn, ...
                    varArgIn{:});
            end
            took=toc(x);
            if ~isempty(modelFileName)
                try
                    f=Mlp.DoModelFileExtension(modelFileName, true);
                    save(f, 'model');
                catch ex
                    BasicMap.Global.reportProblem(ex);
                end
            end
            if nargout>2
                accuracy = 1 - loss(model, testSet, ...
                    labelColumn, 'LossFun', 'classiferror');
            end
            fprintf('Classification compute time %s\n',...
                String.HoursMinutesSeconds(took));

        end
        
        function [labels, modelFileName, model, confidence, qfTable]=Predict(csvFileOrData, varargin)
            %[testSet, testHdr]=File.ReadCsv('balbcFmoLabeled.csv');
            %lbls2=Mlp.Predict(testSet, 'model_file', modelFitcnet, 'columns', testHdr, 'confirm', false, 'test_label_file', 'balbc4FmoLabeled.properties', 'training_label_file', 'balbcFmoLabeled.properties', 'Acceleration', 'none');
            %lbls2=Mlp.Predict('balbcFmoLabeled.csv', 'model_file', modelFitcnet, 'confirm', false, 'test_label_file', 'balbc4FmoLabeled.properties', 'training_label_file', 'balbcFmoLabeled.properties', 'Acceleration', 'none');
            %lbls2=Mlp.Predict('rag10DLabeled148k.csv', 'model_file', modelFitcnet, 'confirm', false, 'test_label_file', 'balbc4FmoLabeled.properties', 'training_label_file', 'rag10DLabeled148k.properties');

            %l=Mlp.Predict('balbcFmoLabeled.csv', 'model_file', 'balbc4FmoLabeled', 'confirm', false, 'test_label_file', 'balbc4FmoLabeled.properties', 'training_label_file', 'balbcFmoLabeled.properties', 'Acceleration', 'none');
            %l=Mlp.Predict('rag10DLabeled148k.csv', 'model_file', 'balbc4FmoLabeled', 'confirm', false, 'test_label_file', 'balbc4FmoLabeled.properties', 'training_label_file', 'rag10DLabeled148k.properties');
            %l=Mlp.Predict('omip044Labeled.csv', 'model_file', 'ustOmip044Mlp', 'confirm', false, 'test_label_file', 'omip044Labeled.properties', 'training_label_file', 'omip044Labeled400k.properties');
            qfTable=[];
            confidence=[];
            Mlp.Assert2021aOrLater;
            try
                [args, ~,~, argsObj]=Args.NewKeepUnmatched(...
                    Mlp.DefineArgsForPredict,varargin{:});
            catch ex
                BasicMap.Global.reportProblem(ex);
                throw(ex);
            end
            if nargin<1
                csvFileOrData='';
            end
            if isempty(csvFileOrData)
                csvFileOrData='balbcFmoLabeled.csv';
            end
            if isempty(args.model_file)
                args.model_file='balbc4FmoLabeled';
            elseif ~isa(args.model_file, 'ClassificationNeuralNetwork')
                args.model_file=Mlp.DoModelFileExtension(args.model_file, false);
            end
            modelFileName='';
            [testSet, model, columnNames, predictedLabels]...
                =Mlp.ResolveData(csvFileOrData, args.column_names, ...
                args.model_file, args.confirm_model, ...
                false, args.has_labels, false, ...
                args.class_limit, args.props, args.property);
            if isempty(testSet) || isempty(model)
                labels=[];
                if ischar(args.model_file) && ~exist(args.model_file, 'file')
                    msgError(['<html>Can not open MLP neural network' ...
                        Html.FileTree(args.model_file) ...
                        '<hr></html>'], 0)
                end
                return;
            end
            if ischar(model)
                modelFileName=model;
                load([modelFileName Mlp.EXT_FITCNET], 'model');
            end
            %strong typing required for predicting
            assert(isa(model, 'ClassificationNeuralNetwork')); 
            varArgIn=argsObj.getUnmatchedVarArgs;
            [~, ~,~, argsObj]...
                    =Args.NewKeepUnmatched(SuhMatch.DefineArgs, varArgIn{:});
            matchArgIn=argsObj.getVarArgIn;
            varArgIn=argsObj.getUnmatchedVarArgs;
            x=tic;
            [labels, confidence]=predict(model, testSet, varArgIn{:});
            took=toc(x);
            if ~isempty(varargin) && args.has_labels
                [~, ~, ~, extras]=suh_pipelines('pipe', 'match', ...
                    'training_set', testSet,...
                    'training_label_column', predictedLabels, ...
                    'test_set', [], 'test_label_column', labels, ...
                    'column_names', columnNames, ...
                    'matchStrategy', 2, matchArgIn{:});
                qfTable=extras.qfd{1};
            end
            fprintf('Classification compute time %s\n',...
                String.HoursMinutesSeconds(took));
        end

        function [outFileOrData, model, columnNames, labels,...
                isTempFile]=ResolveData(fileOrData, columnNames, model,...
                confirmModelFile, isTraining, hasLabel, forPython,...
                classLimit, props, property, dfltFldr, limitIfTraining)
            if nargin<11
                dfltFldr='';
                if nargin<10
                    property=Mlp.PROP;
                    if nargin<9
                        props=BasicMap.Global;
                        if nargin<8
                            classLimit=.1;
                            if nargin<7
                                forPython=true;
                                if nargin<6
                                    hasLabel=true;
                                    if nargin<5
                                        isTraining=true;%else predicting
                                        if nargin<4
                                            confirmModelFile=false;
                                            if nargin<3
                                                model='';
                                                if nargin<2
                                                    columnNames={};
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            modelIsObject=~ischar(model) && ~isempty(model);
            if isTraining 
                assert(~modelIsObject); %model arg is file and not object!
                assert(hasLabel);
            end
            outFileOrData=[];
            labels=[];
            isTempFile=false;
            if ischar(fileOrData)
                fileOrData=File.ExpandHomeSymbol(fileOrData);
                fileOrData=WebDownload.GetExampleIfMissing(fileOrData);
                columnNames=File.ReadCsvHeader(fileOrData);
                if ~exist(fileOrData, 'file')
                    msgError(['<html>File does not exist '...
                        Html.FileTree(fileOrData) '<hr></html>'], 8);
                    return;
                end
                if nargout>2 && isempty(model) ...
                        || (ischar(model) && isempty(fileparts(model)))
                    [p,f]=fileparts(fileOrData);
                    if isempty(model)
                        model=fullfile(p, f);
                    else
                        model=fullfile(p, model);
                    end
                end
                if forPython
                    [data, columnNames]=File.ReadCsv(fileOrData);
                        
                    if hasLabel || isTraining
                        labels=data(:,end);
                    end
                    if ~isTraining && hasLabel
                        isTempFile=true;
                        data=data(:,1:end-1);
                        columnNames=columnNames(1:end-1);
                        outFileOrData=[tempname '.csv'];
                        File.WriteCsvFile(outFileOrData, ...
                            data, columnNames);
                    else
                        outFileOrData=fileOrData;
                    end
                else
                    if ~isTraining 
                        [outFileOrData, columnNames]=...
                            File.ReadCsv(fileOrData);
                        if hasLabel
                            labels=outFileOrData(:,end);
                            outFileOrData=outFileOrData(:,1:end-1);
                            columnNames=columnNames(1:end-1);
                        end
                    else
                        [outFileOrData, columnNames]=...
                            File.ReadTable(fileOrData);
                        labels=outFileOrData{:, outFileOrData.Properties.VariableNames{end}};
                    end
                end
            else
                [R, C]=size(fileOrData);
                if isTraining || hasLabel % and for predicting (not training)
                    labels=fileOrData(:,end);
                end
                if isTraining 
                    if isempty(model)
                        model=sprintf('mlp_%dx%d_%s_%d', R, C,...
                            strrep(num2str(mean(...
                            fileOrData(:,end))),'.','_'),...
                            limitIfTraining);
                    end
                    nNames=length(columnNames);
                    if ~(nNames==C || nNames==C-1)
                        error('%d column names for %d matrix columns?',...
                            nNames, C);
                    end
                    if nNames<C
                        columnNames{end+1}='Label';
                    end
                elseif hasLabel % and for predicting (not training)
                    fileOrData=fileOrData(:,1:end-1);
                    columnNames=columnNames(1:end-1);
                end
                if forPython
                    outFileOrData=[tempname '.csv'];
                    isTempFile=true;
                    File.WriteCsvFile(outFileOrData, ...
                        fileOrData, columnNames);
                else % for MATLAB fitcnet
                    if isTraining
                        outFileOrData=array2table(fileOrData, ...
                            'VariableNames', columnNames);
                    else
                        outFileOrData=fileOrData;
                    end
                end
            end
            if hasLabel || isTraining
                [ok,cancelled]=LabelBasics.Confirm(...
                    labels, classLimit, ~isTraining);
                if cancelled || (isTraining && ~ok)
                    model=[];
                    outFileOrData=[];
                    return;
                end
                if ~ok
                    labels=[];
                end
            end
            if modelIsObject
                return;
            end
            %now handle model for (training or predicting) and
            % (python-TensorFlow or matlab-fitcnet)
            model=Mlp.IdentifyModelFile(model, forPython, ...
                isTraining, confirmModelFile,...
                columnNames, true, props, property, dfltFldr);
            if isempty(model)
                outFileOrData=[];
            end
        end

        function [model, modelColumnNames, changedForPython]...
            =IdentifyModelFile(model, forPython, isTraining, ...
                confirm, columnNames, matchColumns,...
                props, property, dfltFldr)
            if nargin<9
                dfltFldr=[];
                if nargin<8
                    property=[];
                    if nargin<7
                        props=BasicMap.Global;
                        if nargin<6
                            matchColumns=false;
                            if nargin<5
                                columnNames=[];
                            end
                        end
                    end
                end
            end
            changedForPython=[];
            if isempty(dfltFldr)
                dfltFldr=Mlp.DefaultLocalFolder;
            end
            if isempty(property)
                property=Mlp.PROP;
            end
            modelColumnNames={};
            propertyFile=[property '.file'];
            propertyDir=[property '.dir'];
            [ext, suffix, dsc]=Mlp.Ext(forPython);
            if isempty(model)
                model=props.get(propertyFile);
                if isempty(model)
                    model='myMlpModel';
                end
            end
            [p, f, e]=fileparts(model);
            if isempty(p)
                File.mkDir(dfltFldr);
            else
                dfltFldr=p;
            end
            f=[f e];
            if  confirm
                advice=['MLP model<br><b>*'...
                        ext '</b> <i>' suffix ...
                        '</i>...</center></html>'];
                if isTraining
                    [p, f]=uiPutFile(dfltFldr, [f ext],...
                        props,  propertyDir, ...
                        ['<html><center>Save ' advice]);
                    if ~isempty(p)
                        if endsWith(f, '.mat') && ~endsWith(f, ext)
                            [~,f]=fileparts(f);
                        end
                        model=fullfile(p,f);
                    else
                        model=[];
                        return;
                    end
                else
                    while true
                        model=uiGetFile([f ext], dfltFldr,...
                            ['<html><center>Open ' advice], ...
                            props,  propertyDir);
                        if isempty(model)
                            model=[];
                            return;
                        elseif endsWith(model, '.umap.mat')
                            model=model(1:end-9);
                            if nargout>2 && isempty( changedForPython )
                                [ext2, suffix2, dsc2]=Mlp.Ext(~forPython);
                                if File.ExistsFile([model ext2])
                                    [yes, cancelled]= askYesOrNo(Html.WrapHr(['Switch'...
                                            ' the <i>type</i> of MLP from <b>' ...
                                            dsc '</b><br> to this UMAP template''s '...
                                            '<b>' dsc2 '</b>??']));
                                    if cancelled
                                        model=[];
                                        return;
                                    end
                                    if yes
                                        ext=ext2;
                                        suffix=suffix2;
                                        dsc=dsc2;
                                        forPython=~forPython;
                                        changedForPython=true;
                                        break;
                                    end
                                end
                            end
                            if ~File.ExistsFile([model ext])
                                msgError(['<html>This umap template ' ...
                                    'does not have the<br>' ...
                                    'associated MLP neural ' ...
                                    'network file we expected:' ...
                                    Html.FileTree([model ext]) '<hr></html>'], ...
                                    'modal', 'center', 'MLP file missing!');
                            else
                                break;
                            end
                        else
                            break;
                        end
                    end
                end
                if endsWith(model, ext)
                    model=model(1:end-length(ext));
                end
            else
                model=fullfile(dfltFldr, f);
            end
            modelColumnsFile=[model Mlp.EXT_COLUMNS];
            if isTraining
                File.WriteCsvFile(modelColumnsFile, [], columnNames)
            else            
                if ~isempty(model)
                    nMissing=WebDownload.GetMlpIfMissing(model, forPython);
                    if nMissing>0
                        model=[];
                        return;
                    end
                end
                if ~exist(modelColumnsFile, 'file')
                    model=[];
                    msgError(['<html>The MLP neural network ' ...
                        'file <b>MUST</b> exist'...
                        Html.FileTree(modelColumnsFile)...
                        '<hr></html>'], 8, ...
                        'center', 'MLP file missing!');
                    return;
                end
                if ~exist([model ext], 'file')
                    msgError(['<html>The MLP neural network ' ...
                        'file <b>MUST</b> exist'...
                        Html.FileTree([model ext])], 8, ...
                        'center', 'MLP file missing!');
                    model=[];
                    return;
                end
                modelColumnNames=File.ReadCsvHeader(modelColumnsFile);
                modelColumnNames=modelColumnNames(1:end-1);
                if matchColumns
                    if ~StringArray.Equals(modelColumnNames, columnNames)
                        model=[];
                        msgError(Html.Wrap(['<b><font color="red">MUST'...
                            '</font> have same column names</b>:'  ...
                            Html.To2Lists(modelColumnNames, columnNames, ...
                            'ol', 'Training set', 'Test set')]), 8);
                        modelColumnNames=[];
                    end
                elseif ~isempty(columnNames)
                    idxs=StringArray.IndexesOf2(...
                        columnNames, modelColumnNames);
                    if any(idxs==0)
                        model=[];
                        msgError(Html.Wrap(['<b><font color="red">MUST'...
                            '</font> have all model''s columns</b>:'  ...
                            Html.To2Lists(modelColumnNames, columnNames, ...
                            'ol', 'Training set', 'Test set')]), 8);
                        modelColumnNames=[];
                    end
                end
            end
            if ~isempty(model)
                props.set(propertyFile, model);
            end
        end

        function [ext, dsc, dscLong]=Ext(forPython)
            if forPython
                ext=Mlp.EXT_TENSORFLOW;
                dsc='(TensorFlow)';
                dscLong='Python TensorFlow';
            else
                ext=Mlp.EXT_FITCNET;
                dsc='(fitcnet)';
                dscLong='MATLAB fitcnet';
            end
        end

        function [confidence, pnl, jtf]=GetConfidence(...
                forDefault, props, confidence, show, h, ...
                where)
            if nargin<2 || isempty(props)
                props=BasicMap.Global;
            end
            prop='Mlp.Confidence';
            if nargin>2
                if confidence<=1
                    confidence=confidence*100;
                end
                props.set(prop, num2str(confidence));
            else
                confidence=props.getNumeric(prop, 80);
            end
            if ~forDefault
                txt='% confidence level';
            else
                txt=Html.WrapSmallBold(...
                    'Default % confidence<br>when <u>classifying</u>:');
            end
            [jtf, ~, pnl]=Gui.AddNumberField(...
                txt, 3,  ...
                80, props, prop, [], Html.WrapTable(...
                ['UMAP matching overrides MLP classifications ' ...
                'less sure than this'], 2,300,'1', 'center'), ...
                0, 100, true, 'int');
            if nargin==0 || (nargin>2 && show)
                if nargin>3
                    jw=Gui.WindowAncestor(h);
                else
                    jw=[];
                end
                if nargin<6
                    where='south east+';
                end
                MatBasics.RunLater(@(h,e)select(), .15)
                txt2=Html.WrapSmall( ...
                    ['<center><i>(classifications with confidence below'...
                    '<br>this level are overridden by UMAP)</i></center>']);
                [~,~,cancelled]=questDlg(struct('msg', Gui.BorderPanel([], 2, 7, ...
                    'Center', pnl, 'South', txt2), 'where', ...
                    where, 'javaWindow', jw), 'Adjust MLP confidence level', ...
                    'Ok', 'Cancel', 'Ok');
                if ~cancelled && ~isequal(jtf.getForeground, Gui.ERROR_COLOR)
                    confidence=str2double(char(jtf.getText))/100;
                else
                    confidence=[];
                end
            end

            function select
                jtf.requestFocus;
                jtf.selectAll;
            end
        end
    end
end
