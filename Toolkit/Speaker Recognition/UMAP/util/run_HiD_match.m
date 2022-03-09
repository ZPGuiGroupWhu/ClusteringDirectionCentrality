function [qf, done]=run_HiD_match(trainingSet, trainingIds, testSet, ...
    testIds, varargin)
%%RUN_HiD_MATCH runs the QF match algorithm 
%   on the subsets found within a training test set of data.
%
%   The publication that introduces the algorithm is 
%   https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5818510/
%
%   A publication that further elaborates the algorithm is
%   https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6586874/
%
%   [result, done] = run_HiD_match(trainingSet, trainingIds, 
%       testSet, testIds, 'NAME1',VALUE1,..., 'NAMEN',VALUEN) 
%   
%
%   RETURN VALUES
%   Invoking run_umap produces 2 return values:
%   1)qf; an instance of the QFHiDM class describing match results
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
%   'pu'                      instance of PopUp.  run_qf_match uses 
%                           this to describe computing progress.  
%                           if 'none' is provided then no progress
%                           reporting occurs, otherwise the default is
%                           is an internal PopUp for reporting progress.
%   'trainingNames'           names of subsets in the test set.  Used
%                           for result.matrixHtml and is retained 
%                            in result.tNames.
%   'testNames'               names of subsets in the training set.  Used
%                           to annotate result.matrixHtml and is retained 
%                            in result.sNames.
%   'trainingSetComp'       The compensated data if appicable for testing
%                           standard deviation unit distance.  Must be
%                           same size as trainingSet. Default is empty.
%   'testSetComp'           The compensated data if appicable for testing
%                           standard deviation unit distance.  Must be
%                           same size as testSet. Default is empty.
%   'log10'                 If true then data columns where max > 1 
%                           is converted to log10
%   'mergeLimit'            1 if unlimited else 2-12 for 7-17 
%                           maximum merge candidates.  The # of merge
%                           candidates increases the processing load
%                           quadratic (half N squared).  When a limit is 
%                           set then the merge candidates are seleced by a 
%                           probability bin  overlap test.
%                           Default is 6 for maximum of 11 merge candidates.
%
%   'matchStrategy'         1 if quadratic form (QF), 2 if F-measure and
%                           3 if QF + F-measure optimizing for merging.
%                           1 is default
%
%   'mergeStrategy'         1 if best QF matches, 2 - 8  if
%                           percent of top matches is 150% to 500% in 
%                           steps of 50%.
%                           Default is 2.
%
%   'check_equivalence'     logical indicating need to check for data 
%                           equivalence IF data only differs in
%                           insignificant 6th or less decimal digits.
%                           This was noticed with our MLP pipeline 
%                           creating text files.
%                           Default is false.
%
%   AUTHORSHIP
%   Primary inventor:      Darya Orlova <dyorlova@gmail.com>
%   Primary Developer:     Stephen Meehan <swmeehan@stanford.edu> 
%   Math/Statistics:       Connor Meehan <connor.gw.meehan@gmail.com>
%                          Guenther Walther<gwalther@stanford.edu>
%                          Wayne Moore <wmoore@stanford.edu>
%
%   Provided by the Herzenberg Lab at Stanford University 
%   License: BSD 3 clause
%
ml=BasicMap.Global.getNumeric(QfHiDM.PROP_MERGE_LIMIT, 1);
p=parseArguments();
parse(p,varargin{:});
[args, hadPu]=checkArgs(p.Results);
bins=QfHiDM.BinsCode(args.probabilityBinSize);
if args.check_equivalence
    if ~isempty(testSet)
        if MatBasics.IsEquivalent(trainingSet, testSet)
            testSet=trainingSet;
            args.testSetComp=args.trainingSetComp;
        end
    end
end
teachC=size(trainingSet, 2);
studC=size(testSet, 2);
if teachC ~=studC
    error('Training & test set columns unequal...%d != %d', teachC, studC);
end
qf=QfHiDM(trainingSet, args.trainingSetComp, trainingIds, ...
    testSet, args.testSetComp, testIds, bins, args.binStrategy);
qf.tNames=args.trainingNames;
qf.sNames=args.testNames;
qf.matchStrategy=args.matchStrategy;
qf.mergeStrategy=args.mergeStrategy;
qf.maxDeviantParameters=args.maxDeviantParameters;
if qf.matchStrategy==1 && args.mergeLimit==0
    tCnt=length(qf.tIds);
    sCnt=length(qf.sIds);
    [percentDiff, mergeCandidates]=MatBasics.Bigger(sCnt, tCnt);
    if percentDiff>2 || mergeCandidates>13
        if ~args.ask_to_accelerate || askYesOrNo('Accelerate merge phase?')
            qf.matchStrategy=3; %emd + f-measure optimizing
        end
    end
end
if isempty(args.probability_bins)
    done=qf.compute(args.pu, true, 4, 1, args.html);
else
    try %not sure if new acceleration
        qf.compress(args.probability_bins);
        done=qf.compute(args.pu, true, 4, 1, args.html);
        qf.decompress();
    catch ex % not working yet? ... use older slow programming
        ex.getReport
        try
            qf.decompress();
            done=qf.compute(args.pu, true, 4, 1, args.html);
        catch
        end
    end
end
if ~hadPu
    args.pu.close;
end
BasicMap.Global.setNumeric(QfHiDM.PROP_MERGE_LIMIT, num2str(ml));

    function [args, hadPu]=checkArgs(args)
        hadPu=~isempty(args.pu);
        [trainers, trainingIds]=checkSet(trainingSet, trainingIds, args.trainingNames);
        [testees, testIds]=checkSet(testSet, testIds, args.testNames);
        if args.log10
            trainingSet=QfHiDM.Log10(trainingSet);
            testSet=QfHiDM.Log10(testSet);
        end
        if isempty(args.trainingSetComp)
            args.trainingSetComp=trainingSet;
        end
        if isempty(args.testSetComp)
            args.testSetComp=testSet;
        end
        if isempty(args.pu)
            args.pu=PopUp(['Matching with ' num2str(length(trainers)) ...
                ' training sets & ' num2str(length(testees)) ...
                ' test sets'], 'north', 'Running QF Match', false, true);
            args.pu.setTimeSpentTic(tic);
        elseif isequal('none', args.pu)
            args.pu=[];
        end
        BasicMap.Global.setNumeric(QfHiDM.PROP_MERGE_LIMIT, ...
            num2str(args.mergeLimit));
    end

    function [u, ids]=checkSet(dataSet, ids, names)
        [R1,~]=size(dataSet);
        [R2, C2]=size(ids);
        assert((R1==R2) || (R1==C2 ), 'Need same # of data rows and id rows');
        if R1==C2 && R2==1
            ids=ids';
        end
        u=unique(ids(ids ~= 0));
        if ~isempty(names)
            R3=length(names);
            assert(length(u)==R3, 'Need same # of names as non zero IDs');
        end
    end

    function p=parseArguments(varargin)
        p=inputParser;
        addParameter(p,'trainingSetComp', [], @isnumeric);
        addParameter(p,'testSetComp', [], @isnumeric);
        addParameter(p,'trainingNames', {}, @(x)StringArray.IsOk(x));
        addParameter(p,'testNames', {}, @(x)StringArray.IsOk(x));
        addParameter(p,'ask_to_accelerate', true, @islogical);
        addParameter(p,'pu',[], @(x)isempty(x) || isequal('none', x) || isa(x,'PopUp'));
        addParameter(p,'probability_bins',[], @(x)isempty(x) ...
            || isa(x,'SuhProbabilityBins'));
        QfHiDM.DefineArgs(p);
    end

    

end