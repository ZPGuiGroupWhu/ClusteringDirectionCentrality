%   AUTHORSHIP
%   Primary Developer: Stephen Meehan <swmeehan@stanford.edu> 
%   Math Lead & Secondary Developer:  Connor Meehan <connor.gw.meehan@gmail.com>
%   Bioinformatics Lead:  Wayne Moore <wmoore@stanford.edu>
%   Provided by the Herzenberg Lab at Stanford University 
%   License: BSD 3 clause
%
classdef LabelBasics
    methods(Static)
        function [labels, loss]=RemoveOverlap(labels)
            nCols=size(labels,2);
            if nCols>1
                y=labels(:,1);
                nCols=size(labels,2);
                
                for col=2:nCols
                    ll=y==0;
                    more=labels(ll, col);
                    y(ll)=more;
                end
                if nargout>1
                    lbls=unique(labels);
                    lbls=lbls(lbls>0);
                    h1=histc(sort(labels(:)), lbls);
                    h2=histc(sort(y), lbls);
                    loss=h2-h1;
                end
                labels=y;
            end
        end
        
        % assumes AutoGate modules are on path
        function map=GetLabelMap(gt, labels)
            ids=unique(labels);
            [names, N, strIds]=GatingTree.GetUniqueNames(gt.tp, ids);
            map=java.util.Properties;
            hl=gt.highlighter;
            for i=1:N
                dfltClr=Gui.HslColor(i,N);
                if ids(i)~=0
                    id=strIds{i};
                    name=names{i};
                    if isempty(name)
                        name=['label=' id];
                    end
                    if gt.tp.hasChildren(id)
                        name=[name ' (non specific)'];
                    end
                    map.put(java.lang.String(id), name);
                    clr=num2str(floor(hl.getColor(id, dfltClr)*256));
                    map.put([id '.color'], clr);
                end
            end
        end
        
    
        function [key, keyColor, keyTraining, keyTest]=Keys(lbl)
            key=num2str(lbl); % prevent java.lang.Character
            keyColor=[key '.color'];
            keyTraining=[key '.trainingFrequency'];
            keyTest=[key '.testFrequency'];
            key=java.lang.String(key);
        end
        
        function Frequency(lbls, lblMap, training, match, how)
            if nargin<5
                how=-1; %contains, 0=eq, 1 = startsWith
                if nargin<4
                    match='';
                    if nargin<3
                        training=true;
                    end
                end
            end
            [trainFreq, testFreq]=LabelBasics.HasFrequencies(lblMap);
            total=length(lbls);
            tab=sprintf('\t');
            u=unique(lbls);
            nLbls=length(u);
            frequencies=histc(sort(lbls), u);
            [sortFrequencies,II]=sort(frequencies, 'descend');
            if nargin>3
                if ~isempty(training) && training
                    disp([num2str(nLbls) ' training set labels']);
                else
                    disp([num2str(nLbls) ' test set labels']);
                end
            end
            for i=1:nLbls
                lbl=u(II(i));
                freq=sortFrequencies(i);
                pFreq=String.encodePercent(freq, total, 1);
                [key, ~, keyTraining, keyTest]=LabelBasics.Keys(lbl);
                if ~isempty(training)
                    if training
                        lblMap.put(keyTraining, pFreq);
                    else
                        lblMap.put(keyTest, pFreq);
                    end
                end
                if nargin>3
                    name=lblMap.get(key);
                    if trainFreq && ~training
                        start=['From ' lblMap.get(keyTraining) ' to '];
                    else
                        start='';
                    end
                    if ~isempty(match)
                        start=[tab start];
                        if how==-1
                            if String.Contains(name, match)
                                start=['* ' start];
                            end
                        elseif how==1
                            if String.StartsWith(name, match)
                                start=['* ' start];
                            end
                        else
                            if strcmp(name, match)
                                start=['* ' start];
                            end
                        end
                    end
                    sFreq=String.encodeInteger(freq);
                    fprintf(['%s%s=%s events for #%d="%s"\n'], start, ...
                        pFreq, sFreq, lbl, name);
                end
            end
            if nargin>3
                if ~isempty(training) && training
                    disp([num2str(nLbls) ' training set labels']);
                else
                    disp([num2str(nLbls) ' test set labels']);
                end
            end
            if ~isempty(training)
                if training
                    lblMap.put('hasTrainingFrequencies', 'yes');
                else
                    lblMap.put('hasTestFrequencies', 'yes');
                end
            end
        end
        
        function [training, test]=HasFrequencies(lblMap)
            if isempty(lblMap)
                training=false;
                test=false;
            else
                training=strcmpi('yes', lblMap.get('hasTrainingFrequencies'));
                test=strcmpi('yes', lblMap.get('hasTestFrequencies'));
            end
        end
        
        function [addTrainingHtml, sup1, sup2, trStart, trEnd]=...
                AddTrainingHtml(lblMap, needHtml)
            addTrainingHtml=false;
            if needHtml
                sup1=BasicMap.Global.supStart;
                sup2=BasicMap.Global.supEnd;
                if ~isempty(lblMap)
                    trStart=[sup1 '<font color="#11DDAA"><b> training '];
                    trEnd=['</b></font>' sup2];
                    [trainFreq, testFreq]=LabelBasics.HasFrequencies(lblMap);
                    addTrainingHtml=trainFreq&&testFreq;
                else
                    trStart=[]; trEnd=[];
                end
            else
                sup1=[]; sup2=[]; trStart=[]; trEnd=[];
            end

        end
        
        function[data, columnNames1]=Merge2Samples(...
                fileName, sample1, label1, sample2, label2, label3)
            [data1, columnNames1]=File.ReadCsv(sample1);
            [data2, columnNames2]=File.ReadCsv(sample2);
            if ~isequal(columnNames1(1:end-1), columnNames2(1:end-1))
                msgWarning('Training & test set labels do not match');
                return;
            end
            lblMap2=loadLabels(label2);
            lblMap1=loadLabels(label1);
            if isequal(label3, label1)
                lbls=data2(:,end);
                reLbls=LabelBasics.RelabelIfNeedBe(lbls, lblMap1, lblMap2);
                if size(reLbls,2)~=size(lbls,2)
                    data=[];
                    return;
                end
                data2(:,end)=reLbls;
            else
                lblMap3=loadLabels(label3);
                lbls=data1(:,end);
                reLbls=LabelBasics.RelabelIfNeedBe(lbls, lblMap3, lblMap1);
                if size(reLbls,2)~=size(lbls,2)
                    data=[];
                    return;
                end
                data1(:,end)=reLbls;
                lbls=data2(:,end);
                reLbls=LabelBasics.RelabelIfNeedBe(lbls, lblMap3, lblMap2);
                if size(reLbls,2)~=size(lbls,2)
                    data=[];
                    return;
                end
                data2(:,end)=reLbls;
            end
            data=[data1;data2];
            if ~isempty(fileName)
                try
                    fu=edu.stanford.facs.wizard.FcsUtil(fileName);
                catch ex
                    msgError('Cannot load java edu.stanford.facs.wizard.FcsUtil' );
                end
                problem=fu.createTextFile(fileName, [], data, [], columnNames1);
                copyfile(label1, File.SwitchExtension(fileName, '.properties')) 
                if ~isempty(problem)
                    msgError(problem, 12);
                end
            end
            
            function lblMap=loadLabels(lblFile)
                try
                    lblMap=java.util.Properties;
                    lblMap.load(java.io.FileInputStream(lblFile));
                catch ex
                    ex.getReport
                    lblMap=[];
                end
            end
        end
        
        function lbls=RelabelIfNeedBe(lbls, trainingMap, testMap)
            if isempty(trainingMap) || trainingMap.size()==0
                msgWarning('Training set map is empty');
                lbls=[];
                return;
            end
            if isempty(testMap) || testMap.size()==0
                msgWarning('Test set map is empty');
                lbls=[];
                return;
            end
            u=unique(lbls);
            N=length(u);
            trainingIdByName=LabelBasics.IdByName(trainingMap);
            for i=1:N
                lbl=u(i);
                if lbl ~= 0
                    key=java.lang.String(num2str(lbl));
                    if ~trainingMap.containsKey(key)
                        name=testMap.get(key);
                        if isempty(name)
                           warning(['Test set properties lack'...
                               ' name for label "' char(key) '"']); 
                        else
                            newLbl=trainingIdByName.get(name);
                            if ~isempty(newLbl)
                                newLbl=str2double(newLbl);
                                lbls(lbls==lbl)=newLbl;
                            else
                                warning(['Training set properties lack'...
                                    ' name for label "' char(key) '"'...
                                    'named "' name '"']);
                            end
                        end
                    end
                end
            end            
        end
        
        function map=IdByName(inMap)
            map=java.util.TreeMap;
            it=inMap.keySet.iterator;
            while it.hasNext
                key=char(it.next);
                if ~endsWith(key, '.color')
                    name=inMap.get(key);
                    if map.containsKey(key)
                        warning(['Duplicate use of ' name]);
                    else
                        map.put(java.lang.String(name), key);
                    end
                end
            end
        end
        
         
        function counts = DiscreteCount(x, labels)
            if isempty(labels)
                counts = [];
                return;
            end
            if ~any(isinf(labels))
                labels(end+1) = inf;
            end
            counts = histcounts(x, labels);
        end
        
        function [names, clrs, lbls]=GetNamesColorsInLabelOrder(...
                lbls, lblMap, minFrequency)
            lbls(lbls<0)=0;
            ids_=unique(lbls);
            N_=length(ids_);
            cnts_ = LabelBasics.DiscreteCount(lbls, ids_);
            if nargin>2
                isSigId = cnts_>=minFrequency;
            else
                isSigId=true(1, N_);
            end
            if all(size(ids_)== size(isSigId))
                ids_=ids_';
            end
            N_Names = sum(isSigId & (ids_ > 0)');
            names=cell(1,N_Names);
            clrs=zeros(N_Names,3);
            sig_idx=0;
            for i=1:N_
                id=ids_(i);
                if id>0
                    key=num2str(id);
                    name=lblMap.get(java.lang.String(key));
                    if isempty(name)
                        name=['Subset #' key];
                    end
                    if isSigId(i)
                        sig_idx=sig_idx+1;
                        key=num2str(id);
                        names{sig_idx}=name;
                        try
                            clrs(sig_idx,:)=str2num(...
                                lblMap.get([key '.color']))/256; %#ok<ST2NM>
                        catch 
                            clrs(sig_idx,:)=[.1 .1 .1];
                        end
                    else
                        if ~strcmpi(this.verbose, 'none')
                            warning('Ignoring "%s" since it has %d events...', ...
                                name, cnts_(i));
                        end
                        lbls(lbls==id)=0;
                    end
                else
                    lbls(lbls==id)=0;
                end
            end
        end
       
        function [map, halt, args]=GetOrBuildLblMap(lbls, args)
            halt=false;
            map=[];
            if isempty(args.label_file)
                warning(['label_column without label_file '...
                    'to match/supervise, will use default names/colors']);
                args.buildLabelMap=true;
            end
            if args.buildLabelMap
            else
                if ~exist(args.label_file, 'file')
                    label_file=WebDownload.GetExampleIfMissing(args.label_file);
                    if exist(label_file, 'file')
                        args.label_file=label_file;
                    end
                end
                if exist(args.label_file, 'file')
                    map=File.ReadProperties( args.label_file);
                    if isempty(map)
                        problem='load';
                    end
                elseif ~isempty(args.label_file)
                    problem='find';
                end
                if isempty(map)
                    globals=BasicMap.Global;
                    if askYesOrNo(['<html>Cannot ' problem ' the '...
                            ' label file <br><br>"<b>' globals.smallStart ...
                            args.label_file globals.smallEnd '</b>"<br><br>'...
                            '<center>Use default names & black/white colors?</center>'...
                            '<hr></html>'], 'Error', 'north west', true)
                        args.buildLabelMap=true;
                    else
                        halt=true;
                    end
                end
            end
            if args.buildLabelMap
                map=java.util.Properties;
                u=unique(lbls)';
                nU=length(u);
                if nU/args.n_rows > .2
                    if ~acceptTooManyLabels(nU, args.n_rows)
                        halt=true;
                        return;
                    end
                end
                for i=1:nU
                    key=num2str(u(i));
                    map.put(java.lang.String(key), ['Subset #' key]);
                    map.put([key '.color'], num2str(Gui.HslColor(i, nU)));
                end
            end
            if args.color_defaults
                ColorsByName.Override(map, args.color_file, beQuiet);
            end
            
            function ok=acceptTooManyLabels(nU, nRows)
                ok=true;
                txt=sprintf(['You have %s unique labels...<br>'...
                    'This is %s of the actual data rows...'], ...
                    String.encodeInteger(nU), String.encodePercent(...
                    nU/nRows, 1, 1));
                if ~askYesOrNo(Html.WrapHr(...
                        sprintf(['Interesting ....%s'...
                        '<br><br>So this then will be very SLOW ...'...
                        '<br><br><b>Continue</b>????'], ...
                        txt)))
                    ok=false;
                    return;
                end
            end
        end

        function [ok, cancelled]=Confirm(labels, limit, askToTreatAsData)
            if nargin<3
                askToTreatAsData=true;
            end
            cancelled=false;
            u=unique(labels);
            warningTxt='';
            nFound=length(u);
            strN=String.encodeInteger(nFound);
            total=length(labels);
            if limit<1
                if nFound/total>limit
                    warningTxt=sprintf(['<u>%s</u><br>...yet %s ' ...
                        '<i>is <u><b>%s</b></u> of %s</i><hr>'], ...
                        String.encodePercent(limit), strN, ...
                        String.encodePercent(nFound/total),  ...
                        String.encodeInteger(total));
                end
            else
                if nFound>limit
                    warningTxt=sprintf('<u>%s</u>!<hr>',...
                        String.encodeInteger(limit));
                end                
            end
            if ~isempty(warningTxt)
                question=[strN ' classification labels have been'...
                    ' <br>found in ' String.encodeInteger(total) ...
                    ' matrix rows!<br>...BUT the limit is ' warningTxt];
                if askToTreatAsData
                    [a, cancelled]=Gui.Ask(Html.WrapHr(question), {...
                        'These are labels', ...
                        'Treat as data',...
                        'STOP'}, 'LabelBasics.Confirm');
                    if ~cancelled
                        ok=a==1;
                        cancelled=a==3;
                    else
                        ok=false;
                    end

                else
                    ok=askYesOrNo(Html.WrapC([question '<br><br><b>'...
                        '<font color="red">Continue?</font></b>']));
                end
            else
                ok=true;
            end
        end

        function table=CompressTable(table, ...
                dataSetFactor, classFactor, columnNames)
            inData=table{:,1:end-1};
            labels=table{:,end};
            [inData, labels]=LabelBasics.Compress(...
                inData, labels, dataSetFactor, ...
                classFactor);
            table=array2table([inData labels], ...
                'VariableNames', columnNames);
        end

        function [data, labels]=Compress(data, labels, ...
                dataSetFactor, classFactor)
            if nargin<4
                classFactor=0;
            end
            R=size(data, 1);
            if dataSetFactor==1
                return;
            end
            if floor(dataSetFactor)~=dataSetFactor
                sz=floor(dataSetFactor*R);
            else
                sz=dataSetFactor;
            end
            if sz>=R
                warning('%s factor produces %d and data set has %d rows',...
                    String.encodeRounded(dataSetFactor,2), sz, sz);
                return;
            end
            r=randperm(R);
            r=r(1:sz);
            if ~isempty(labels)
                if classFactor>0
                    uOriginal=unique(labels)';
                    cntsOriginal=MatBasics.HistCounts(labels, uOriginal);
                    smallestSubset=min(cntsOriginal);
                    isRatio=floor(classFactor)~=classFactor;
                    if isRatio
                        minimum=classFactor*smallestSubset;
                    else
                        minimum=classFactor;
                        if any(minimum>cntsOriginal)
                            warning(...
                                ['BEFORE compression %d is > '...
                                'than %d subset(s):'...
                                '  labels=[%s]. Counts=[%s]'], ...
                                minimum, sum(minimum>cntsOriginal), ...
                                MatBasics.toString(...
                                uOriginal(minimum>cntsOriginal)), ...
                                MatBasics.toString(...
                                cntsOriginal(minimum>cntsOriginal))...
                                );
                        end
                    end
                    temp=labels(r);
                    uCompressed=unique(temp)';
                    cntsCompressed=MatBasics.HistCounts(temp, uCompressed);
                    missing=uOriginal(~ismember(uOriginal, uCompressed));
                    tooSmallR=uCompressed(minimum>cntsCompressed);
                    needToIncrease=[missing tooSmallR];
                    nTooSmallLabels=length(needToIncrease);
                    if nTooSmallLabels>0
                        r=r(~ismember(temp, needToIncrease));
                        for i=1:nTooSmallLabels
                            label=needToIncrease(i);
                            idxs=find(labels==label)';
                            nIdxs=length(idxs);
                            if nIdxs<=minimum
                                r=[r idxs];
                            else
                                r2=randperm(nIdxs);
                                r=[r idxs(r2(1:minimum))];
                            end
                        end
                    end
                    data=data(r,:);
                    labels=labels(r);
                    if nTooSmallLabels>0
                        cntsCompressedScaledUp=MatBasics.HistCounts(labels, uCompressed);
                        originalTooSmall=uOriginal(minimum>cntsOriginal);
                        newTooSmall=~ismember(needToIncrease, originalTooSmall);
                        if any(newTooSmall)
                            % make nice report for warning
                            newTooSmallLabels=needToIncrease(newTooSmall);
                            N2=length(newTooSmallLabels);
                            s='';
                            for j=1:N2
                                label=newTooSmallLabels(j);
                                cnt1=cntsOriginal(find(uOriginal==label,1));
                                idx2=find(uCompressed==label,1);
                                if idx2==0
                                    cnt2=0;
                                else
                                    cnt2=cntsCompressed(idx2);
                                end
                                s=[s sprintf('[%d %d %d] ', label, cnt1, cnt2)];
                            end
                            warning('labels=[%s]. Counts=[%s]', ...
                                MatBasics.toString(uCompressed), ...
                                MatBasics.toString(cntsCompressedScaledUp));
                            warning(...
                                ['AFTER compression %d subsets '...
                                'were scaled up to %d),'...
                                '  [label before compressed]:  %s'], ...
                                N2, minimum, s); 
                        end
                    end
                else
                    data=data(r,:);
                    labels=labels(r);
                end
            else
                data=data(r,:);
            end
        end
    end
end
