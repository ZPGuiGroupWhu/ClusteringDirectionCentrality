%  AUTHORSHIP
%   Primary Developer: Stephen Meehan <swmeehan@stanford.edu> 
%   Math/Statistics:   Connor Meehan <connor.gw.meehan@gmail.com>
%                      Guenther Walther <gwalther@stanford.edu>
%   Primary inventors: Wayne Moore <wmoore@stanford.edu>
%                      David Parks <drparks@stanford.edu>
%   Provided by the Herzenberg Lab at Stanford University 
%   License: BSD 3 clause
%
classdef SuhMatchListener < handle
    properties(SetAccess=private)
        roiTableTraining=[];
        roiTableTest=[];
        trainingIds;
        testIds;
        trainingSet;
        testSet;
        trainingSetName='Training set';
        testSetName='Test set';
        table;
        columnNames;
        isTrainingSuhDataSet;
        isTestSuhDataSet;
        lastIsTeachers;
        lastQfIdxs;
        lastLbls;
        lastNames;
        selected;
    end
    
    properties
        explorerName='DImension';
        btnsObj;
        fncSelected;
    end
    
    methods
        function this=SuhMatchListener(matchTable, columnNames,...
                trainingSet, testSet, trainingIds,  testIds, ...
                trainingSetName, testSetName, parseFileNameOut)
            this.table=matchTable;
            this.columnNames=columnNames;
            this.trainingSet=trainingSet;
            this.isTrainingSuhDataSet=isa(trainingSet, 'SuhDataSet');
            if nargin>3
                this.testSet=testSet;
                this.isTestSuhDataSet=isa(testSet, 'SuhDataSet');
                if nargin>4
                    this.trainingIds=trainingIds;
                    this.testIds=testIds;
                    if nargin>6
                        if nargin>8 && parseFileNameOut
                            [~,trainingSetName]=fileparts(trainingSetName);
                            [~,testSetName]=fileparts(testSetName);
                        end
                        this.trainingSetName=[this.trainingSetName ': ' ...
                            trainingSetName];
                        this.testSetName=[this.testSetName ': ' ...
                            testSetName];
                    end
                end
            elseif this.isTrainingSuhDataSet
                this.testIds=this.trainingSet.getTestSetLabels;
            end
            if nargin<5
                if this.isTrainingSuhDataSet
                    [~,trainingSetName]=trainingSet.fileParts;
                    this.trainingSetName=[this.trainingSetName ': ' ...
                            trainingSetName];                            
                end
            end
        end
        
        function reselect(this)
            if ~isempty(this.lastIsTeachers)
                this.select(this.table.qf, this.lastIsTeachers, this.lastQfIdxs);
            end
        end
        
        function select(this, qf, isTeachers, qfIdxs)
            this.lastIsTeachers=isTeachers;
            this.lastQfIdxs=qfIdxs;
            hasPredictions=~isempty(this.table.predictions);
            hasTestSetSelections=~all(isTeachers);
            go1=true; 
            if ~isempty(this.table.cbSyncKld) 
                go1=this.table.cbSyncKld.isSelected;
                if ~hasPredictions
                    edu.stanford.facs.swing.Basics.Shake(this.table.cbSyncKld, 3);
                end
            end
            if hasPredictions
                go4=(this.table.cbStackedPredictions.isSelected);
                edu.stanford.facs.swing.Basics.Shake(this.table.cbStackedPredictions, 3);
            else
                go4=false;
            end
            [names,lbls]=QfHiDM.GetNamesLbls(qf, isTeachers, qfIdxs, ...
                this.btnsObj);
            studentSelections=[];
            if (go1)
                if hasTestSetSelections
                    this.updateRoi(names, isTeachers, false, lbls);
                end
                if any(isTeachers)
                    if hasTestSetSelections
                        studentSelections=this.selected;
                    end
                    this.updateRoi(names, isTeachers, true, lbls);
                end
            else
                if hasTestSetSelections
                    this.getTestSubset(lbls);
                end
                if any(isTeachers)
                    if hasTestSetSelections
                        studentSelections=this.selected;
                    end
                    this.getTrainingSubset(lbls, false);
                end
            end
            if length(studentSelections)==length(this.selected)
                % represent totality of selections 
                if size(this.selected,1) ~= size(studentSelections,1)
                    this.selected=this.selected|studentSelections';
                else
                    this.selected=this.selected|studentSelections;
                end
            end
            if (go4)
                this.table.predictions.computeStackedHtml(...
                    lbls, this.explorerName);
            end
            this.lastLbls=lbls;
            this.lastNames=names;
            if ~isempty(this.fncSelected)
                feval(this.fncSelected, this)
            end
        end
        
        function dataSubset=getTrainingSubset(this, lbls, isTestSet)
            
            if this.isTrainingSuhDataSet
                if isTestSet
                    this.selected=MatBasics.LookForIds2(this.testIds,lbls);
                elseif ~isempty(this.trainingIds)
                    this.selected=MatBasics.LookForIds2(this.trainingIds, lbls);
                else
                    this.selected=MatBasics.LookForIds2(this.trainingSet.labels, lbls);
                end
                if nargout>0
                    dataSubset=this.trainingSet.data(this.selected, :);
                end
            else
                if isTestSet
                    this.selected=MatBasics.LookForIds2(this.testIds,lbls);
                elseif isempty(this.trainingIds)
                    warn('Showing all data... no labels/ids for %s', ...
                        this.trainingName);
                    this.selected=true(1,size(this.trainingSet,1));
                else
                    this.selected=MatBasics.LookForIds2(this.trainingIds, lbls);
                end
                if nargout>0
                    dataSubset=this.trainingSet(this.selected, :);
                end
            end
        end

        function dataSubset=getTestSubset(this, lbls)
            if isempty(this.testSet)
                dataSubset=this.getTrainingSubset(lbls,true);
            elseif this.isTestSuhDataSet
                if ~isempty(this.testIds)
                    this.selected=MatBasics.LookForIds2(this.testIds, lbls);
                else
                    this.selected=MatBasics.LookForIds2(this.testSet.labels, lbls);                    
                end
                if nargout>0
                    dataSubset=this.testSet.data(this.selected,:);
                end
            else
                if isempty(this.testIds)
                    warn('Showing all data... no labels/ids for %s', ...
                        this.testName);
                    this.selected=true(1,size(this.testSet,1));
                else
                    this.selected=MatBasics.LookForIds2(this.testIds, lbls);
                end
                if nargout>0
                    dataSubset=this.testSet(this.selected, :);
                end
            end
        end

        function updateRoi(this, names, isTeachers, doTeacher, lbls)
            lbls=lbls(isTeachers==doTeacher);
            names=names(find(isTeachers==doTeacher));
            if isempty(lbls)
                return;
            end
            if doTeacher
                roiTable=this.roiTableTraining;
                dataSubset=this.getTrainingSubset(lbls, false);
            else
                roiTable=this.roiTableTest;
                dataSubset=this.getTestSubset(lbls);
            end
            try
                needToMake=isempty(roiTable) ...
                    || ~ishandle(roiTable.table.table.fig);
            catch
                needToMake=true;
            end
            name=names{1};
            nSubsets=length(names);
            if nSubsets>1
                name=sprintf('%s and %s', name, ...
                    String.Pluralize2('other', nSubsets-1));
            end
            if needToMake
                if doTeacher
                    dataSetName=this.trainingSetName;
                    where='south west++';
                    whereAssociate='west++';
                    otherTable=this.roiTableTest;
                else
                    if isequal(this.testSetName, 'Test set')
                        this.testSetName=strrep(this.trainingSetName, ...
                            'Training set', 'Test set');
                    end
                    dataSetName=this.testSetName;
                    where='south++';
                    whereAssociate='east++';
                    otherTable=this.roiTableTraining;
                end
                if isempty(otherTable) || ~Gui.IsFigure(otherTable.getFigure)
                    if Gui.IsFigure(this.table.qHistFig)
                        if ~isequal(where, 'south west++')
                            where='south east++';
                        end
                        followed=this.table.qHistFig;
                    elseif Gui.IsFigure(this.table.fHistFig)
                        if ~isequal(where, 'south west++')
                            where='south++';
                        end
                        followed=this.table.fHistFig;
                    else
                        followed=this.table.fig;
                    end
                else
                    where=whereAssociate;
                    followed=otherTable.getFigure;
                end
                roiTable=Kld.Table(dataSubset,  this.columnNames, ...
                    [], followed, name, where, this.explorerName, ...
                    dataSetName, false, [], {followed, where, true},...
                    true, this.table.qf.densityBars);
                if doTeacher
                    this.roiTableTraining=roiTable;
                else
                    this.roiTableTest=roiTable;
                end
            else
                figure(roiTable.getFigure);
                roiTable.refresh(dataSubset, name);
                figure(this.table.fig);
            end
        end
    end
end