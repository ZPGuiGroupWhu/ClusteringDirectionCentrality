classdef SuhPredictions < handle
    
%   AUTHORSHIP
%   Primary Developer: Stephen Meehan <swmeehan@stanford.edu> 
%   Math Lead & Secondary Developer:  Connor Meehan <connor.gw.meehan@gmail.com>
%   Bioinformatics Lead:  Wayne Moore <wmoore@stanford.edu>
%   Provided by the Herzenberg Lab at Stanford University 
%   License: BSD 3 clause
%

properties(Constant)
    JAVA=true;
    FALSE_NEG=.3;
    FALSE_POS=.2;
    TRUE_POS=.1;
    DEBUG=false;
    PROP_PREDICTIONS='SuhPredictions';  %used in AutoGate to store GID of student parent gate
    PROP_PREDICTED='SuhPredictor';%used in AutoGate to store GID of teacher subset predicted
    PROP_PREDICTION='SuhPrediction';%used in AutoGate to store 1 of "true +", "false +", "false -" 
    
end
properties(SetAccess=private)
    R;
    nTeachers;
    match; %instance of QfHiDM for original match on same data
    matchPosNeg;%instance of QfHiDM for predicted matches to true+ & true +/0
    tablePosNeg;
    sNames={};
    posNegLbls;
    posLbls;
    negLbls;
    sums;
    ids;
    contentPane;
    columnName;
    fncSelected;
    table; %instance of QfTable  for original match on same data
    extraComponent;
    remindReadings=true;
end

methods
    function this=SuhPredictions(match)
        this.sums=[];
        this.setMatch(match);
        this.R=size(this.match.tData,1);
        this.nTeachers=length(this.match.tNames);
        this.prepare;
    end
    
    
    function setSelectionListener(this, fncSelected)    
        this.fncSelected=fncSelected;
    end
    
    function addStackerComponent(this, cmp)
        this.extraComponent=cmp;
    end
    
    function clearMatchObject(this)
        this.match=[];
        this.table=[];
    end
    
    function setMatch(this, match)
        if isa(match, 'QfTable')
            this.match=match.qf;
            this.table=match;
        else
            this.match=match;
        end
    end
    
    function tName=getPredictedName(this, predictedId)
        ti=find(this.match.tIds==predictedId, 1);
        tName=this.match.tNames{ti};
    end
    
    function compress(this)
        this.matchPosNeg.compress;
    end

    function decompress(this)
        this.matchPosNeg.decompress;
    end

    function [similarity, overlap, tName, tId, ti, si, words]=describe(this, id)
        qf=this.matchPosNeg;
        tId=floor(id);
        ti=find(qf.tIds==tId,1);
        tName=qf.tNames{ti};
        strId=num2str(id);
        if endsWith(strId, '.3') % false -
            word='false-';
        elseif endsWith(strId, '.2') % false +
            word='false-';
        elseif endsWith(strId, '.1') % true +
            word='true+';
        else % training set
            similarity=nan;
            overlap=nan;
            words='';
            si=nan;
            return;
        end
        si=find(qf.sIds==id,1);
        overlap=1-qf.matrixUnmerged(si,ti);
        similarity=1-qf.distance(id, tId);
        if similarity<0
            fprintf(['For "%s %s" the similarity is %s... '...
                'less than zero...fast approximation effect.\n'], tName, ...
                word, String.encodeRounded(similarity, 2));
            similarity=0;
        end
        if nargout>6
            words=['<b>' word '</b> are ' ...
                ' <u>' String.encodePercent(similarity, 1,1) ...
                ' similar</u> to "<i>' String.RemoveTex( tName ) ...
                '</i>" (' String.encodePercent(overlap,1,1) ' overlap)'];
        end
    end
        
    function prepare(this)
        this.contentPane=[];
        [this.posLbls, this.negLbls, this.sNames, this.sums, this.ids]...
            =SuhPredictions.Get(this.match);
    end
    
    function sz=getSize(this, id)
        tId=floor(id);
        ti=find(this.sums(:,1)==tId,1);
        if ~isempty(ti)
            idx=2+int32((id-tId) *10);
            sz=this.sums(ti,idx);
        else
            warning('Classification label %d does not exist', tId);
            sz=0;
        end
    end
    
    function tablePosNeg=showTable(this, locate_fig, pu)
        if isempty(this.posLbls) || isempty(this.negLbls)
            error('Predictions could not be made');
        end
        if ~isempty(this.tablePosNeg)
            if Gui.IsVisible(this.tablePosNeg.fig)
                figure(this.tablePosNeg.fig);
                tablePosNeg=this.tablePosNeg;
                return;
            end
        end
        if nargin<3
            if ~isempty(this.table) && ishandle(this.table.fig)
                set(0, 'CurrentFigure', this.table.fig)
            end
            pu=PopUp('Matching predicted to predictions', 'center', ...
                'Analyzing prediction accuracy');
            if nargin<2
                locate_fig={};
            end
        end
        if isempty(this.posLbls)
            this.prepare;
        end
        if isempty(locate_fig)
            if ~isempty(this.table) && ishandle(this.table.fig)
                locate_fig={this.table.fig, 'south east+', true};
            else
                locate_fig=true;
            end
        end
        this.contentPane=[];
        this.jdStacked=[];
        this.jLblStacked=[];
        m=this.match;
        sIdPerRow=[this.posLbls;this.negLbls]';
        if isempty(this.matchPosNeg)
            if ~isempty(this.table) && ~Gui.IsVisible(this.table.fig)
                pu='none';
            end
            this.matchPosNeg=run_HiD_match(m.tData, m.tIdPerRow, ...
                m.tData, sIdPerRow, 'mergeStrategy', -1,...
                'trainingNames', m.tNames, 'matchStrategy', 2, ...
                'log10', true, 'testNames', this.sNames, ...
                'pu', pu, 'probability_bins', m.probability_bins);
        end
        this.tablePosNeg=QfTable(this.matchPosNeg, m.tClrs, [], ...
            get(0, 'currentFig'), locate_fig, [], '', this);
        listener=this.tablePosNeg.listen(m.columnNames, ...
            m.tData, m.tData, m.tIdPerRow, sIdPerRow, ...
            'predicted', 'true+|false+/- ');
        if isempty(this.columnName)
            listener.explorerName='Dimension';
        else
            listener.explorerName=this.columnName; %for window title
        end
        listener.fncSelected=@(l)hearSelections(this, l);
        if nargin<3
            if isa(pu, 'PopUp')
                pu.close(true, false);
            end
        end
        tablePosNeg=this.tablePosNeg;
        if ~isempty(this.table)
            this.table.setPredictionsTable(tablePosNeg);
        end
    end
end
properties(SetAccess=private)
    htmlStacked;
    jdStacked;
    jLblStacked;
    lblStacked;
    selectedData;
    selectedName;
    selectedIds;
    highlights={};
end

properties
    userData;
end

methods
    function rememberHighlights(this, H, ttl, ttlStr)
        this.highlights{end+1}...
            =struct('H', H, 'ttl', ttl, 'ttlStr', {ttlStr});
    end
    
    function removeHighlights(this)
        N=length(this.highlights);
        for i=1:N
            try
                delete(this.highlights{i}.H);
                set(this.highlights{i}.ttl, 'String', ...
                    this.highlights{i}.ttlStr);
            catch ex
                disp(ex);
            end
        end
        this.highlights={};
    end
    
    function hearSelections(this, listener)
        this.selectedIds=listener.lastLbls;
        [this.selectedName, nSelected]=...
            StringArray.FirstAndN(listener.lastNames);
        if nSelected>0
            this.selectedData=listener.selected;
        else
            this.selectedData=[];
        end
        if ~isempty(this.fncSelected)
            this.removeHighlights;
            try
                this.removeHighlights;
                if this.tablePosNeg.cbFlashlight.isSelected
                    feval(this.fncSelected, this);
                end
            catch ex
                ex.getReport
            end
        end

    end
    
    function html=computeStackedHtml(this, ids, columnName)
        if isempty(ids)
            html='';
            return;
        end
        tId=floor(ids(1));
        m=this.matchPosNeg;
        if isequal(tId, this.lblStacked)
            if ~isempty(this.jdStacked) && this.jdStacked.isVisible
                html=this.htmlStacked;
                setAlwaysOnTopTimer(this.jdStacked, ...
                    .15, this.tablePosNeg.fig, false);
                return;
            end
        end
        
        predictionSimilarity=zeros(1,4);
        tableIds=this.tablePosNeg.data(:,this.tablePosNeg.idIdx);
        similarities=this.tablePosNeg.data(:,this.tablePosNeg.similarityIdx);
        subsetIdx=1;
        subsets=cell(1,4);
        densityBars=this.match.densityBars;
        subsets{1}=fetch(tId, m.tIdPerRow);
        for decimal=.2:.1:.3
            subsetIdx=subsetIdx+1;
            subsets{subsetIdx}=fetch(tId+decimal, m.sIdPerRow);
        end
        subsetIdx=subsetIdx+1;
        subsets{4}=fetch(tId+.1, m.sIdPerRow);
        this.lblStacked=tId;
        ti=find(m.tIds==tId,1);
        subsetName=m.tNames{ti};
        subsetName=String.ToHtml(subsetName);
        if String.Contains(subsetName, '^{')
            subsetName=strrep(subsetName, '^{', '<sup>');
            subsetName=strrep(subsetName, '}', '</sup>');
        end        
        app=BasicMap.Global;
        sm1=app.smallStart;
        sm2=app.smallEnd;
        sb=java.lang.StringBuilder;
        sb.append(['<table cellspacing="1" cellpadding="1">'...
            '<thead><tr><th colspan="6">']);
        sb.append(app.h2Start);
        sb.append(subsetName);
        sb.append(app.h2End);
        if predictionSimilarity(2)>predictionSimilarity(3)
            fpStart='<font color="blue"><u>'; fpEnd='</font></u>';
            fnStart='<font color="#555555">'; fnEnd='</font>';
            winner='false +';
        else
            fnStart='<font color="blue"><u>'; fnEnd='</font></u>';
            fpStart='<font color="#555555">'; fpEnd='</font>';
            winner='false -';
        end
        sb.append(sprintf(['<font color="#555555">Similarity to '...
            '<i><font color="black">Predicted<font></i>:&nbsp;&nbsp;' ...
            '%sfalse <font color="red">+</font> is %s%%%s, '...
            '%sfalse <font color="red">-</font> is %s%%%s, '...
            '<font color="#555555">true + is %s%%</font><hr>'], ...
            fpStart, String.encodeRounded(100*predictionSimilarity(2),1), fpEnd, ...
            fnStart, String.encodeRounded(100*predictionSimilarity(3),1), fnEnd, ...
            String.encodeRounded(100*predictionSimilarity(4),1)));
        sb.append('</th></tr><tr><th>');
        sb.append(String.ToHtml(columnName));
        kld='<font color="blue"><u>KLD</U></font>';
        sb.append(['</th><th>Data distribution</th><th colspan="2">'...
            sm1 'Kullback-Leibler<br>divergence (' kld ')' ...
            sm2 '</th><th># of</th><th>Freq-</th></tr>'...
            '<tr><th><font color=#555555">' ...
            sm1 '(in order of best to<br>least ' kld ...
            ' for <i><font color="black">Predicted</font></i>)' ...
            sm2 '</font></th><th><font color="#555555"' ...
            sm1 '(normalized)</font>' sm2 '</th><th>' sm1 'Score' ...
            sm2 '</th><th>' sm1 'Rank' sm2 '</th><th>' sm1 ...
            'events' sm2 '</th><th>uency</th></tr></thead>']);
        subsetNames={'<html><i><b>Predicted</b></i></html>',...
            '<html>&nbsp;&nbsp;false <font color="red">+</font></html>', ...
            '<html>&nbsp;&nbsp;false <font color="red">-</font></html>', ...
            '<html>&nbsp;&nbsp;true +</html>'};
        totalEvents=size(m.tData, 1);
        nColumns=size(m.tData,2);
        sketch;
        sb.append('</table>');
        html=['<html>' char(sb.toString) '</html>'];
        this.htmlStacked=html;
        ttl=['DimensionStacker: ' subsetName ' (' winner ' more similar)'];
        if isempty(this.jdStacked) || ~this.jdStacked.isVisible
            fp=Gui.FlowLeftPanel(1,0);
            tip=SuhPredictions.Readings(fp, app, this.remindReadings);
            this.remindReadings=false;
            btn=Gui.NewBtn('Browse', @(h,e)browse(), ...
                'See in default browser', 'world_16.png');
            fp.add(btn);
            if ~isempty(this.extraComponent)
                fp.add(this.extraComponent);
            end
            [scroll, this.jLblStacked]=Gui.HtmlScrollLabel(html, 555, 500);
            figure(this.tablePosNeg.fig);
            was=app.currentJavaWindow;
            app.currentJavaWindow='none';
            this.jLblStacked.setToolTipText(...
                ['<html>' app.h3Start 'DimensionStacker logic...' ...
                app.h3End '<hr>' tip '<hr></html>']);
            this.jdStacked=msg(scroll, 0,'east+', ttl, [],[], false, fp);
            app.currentJavaWindow=was;
            SuhWindow.Follow(this.jdStacked, this.tablePosNeg.fig, ...
                'east+', true);
            Gui.SetJavaVisible(this.jdStacked.setVisible(true));
        else
            this.jLblStacked.setText(html);
            this.jdStacked.setTitle(ttl);
            setAlwaysOnTopTimer(this.jdStacked, ...
                .15, this.tablePosNeg.fig, false);
        end

        function rec=fetch(id, idPerRow)
            l=MatBasics.LookForIds(idPerRow, id);
            data=m.tData(l, :);
            nEvents=size(data,1);
            if nEvents>0
                tableIdx=StringArray.IndexOf(tableIds, num2str(id));
                predictionSimilarity(subsetIdx)=similarities{tableIdx};
                rec.nEvents=nEvents;
                rec.klds=Kld.ComputeNormalizedVectorized(data, false, 256);
                if isempty(densityBars)
                    densityBars=DensityBars.New(data);
                else
                    densityBars.go(data);
                end
                rec.bars=densityBars.bars;
                [~,rec.mostToLeastKLD]=sort(rec.klds, 'descend');
            else
                rec=[];
            end
        end
        
        function browse
            Html.BrowseString(this.htmlStacked);
        end
        
        function sketch
            mostToLeastKLD=subsets{1}.mostToLeastKLD;
            for rank=1:nColumns
                colIdx=mostToLeastKLD(rank);
                name=m.columnNames{colIdx};
                sb.append('<tr><td colspan="6" align="center"><hr><b><i>');
                sb.append(String.ToHtml(name));
                sb.append('</i></b></td></tr>');
                for subsetIdx=1:4
                    if isempty(subsets{subsetIdx})
                        continue;
                    end
                    sb.append('<tr><td>');
                    nEvents=subsets{subsetIdx}.nEvents;
                    sb.append(subsetNames{subsetIdx});
                    sb.append('</td><td bgcolor="white">');
                    sb.append(subsets{subsetIdx}.bars{colIdx});
                    sb.append('</td><td align="right">');
                    sb.append(strrep(String.encodeRounded(subsets{subsetIdx}.klds(colIdx), 2), '<', '&lt;'));
                    sb.append('</td><td align="right">');
                    thisRank=int32( find(subsets{subsetIdx}.mostToLeastKLD==colIdx, 1));
                    dif=abs(thisRank-rank);
                    if dif>0
                        sb.append('<b>');
                        if dif>2
                            sb.append('<font color="red">');
                        end
                    end
                    sb.append(thisRank);
                    if dif>2
                        sb.append('</font>');
                    end
                    if dif>0
                        sb.append('</b>');
                    end
                    sb.append('</td><td align="right">');
                    sb.append(String.encodeK(nEvents));
                    sb.append('</td><td align="right">');
                    sb.append(strrep(String.encodePercent(...
                        nEvents, totalEvents, 1), '<', '&lt;'));
                    sb.append('</td></tr>');
                end
            end
        end
    end    
end

methods(Static)
    function [pos, neg, names, sums, ids]=Get(qf)
        if ~isequal(qf.tIds, floor(qf.tIds))
            msg('Classification labels must be whole numbers');
            warning('Classification labels must be whole numbers');
            pos=[];
            neg=[];
            names=[];
            sums=[];
            ids=[];
            return;
        end
        if isempty(qf.falsePosEvents)
            qf.getFalsePosNegRecords
        end
        if isempty(qf.falsePosEvents)
            pos=[];
            neg=[];
            names=[];
            sums=[];
            ids=[];
            return;
        end
        N=length(qf.falsePosEvents);
        pos=zeros(1, N);
        neg=zeros(1, N);
        N1=length(qf.tIds);
        names={};
        sums=[];
        ids=[];
        done=0;
        for i=1:N1
            tId=qf.tIds(i);
            [ti, truePosIdxs, falsePosIdxs, falseNegIdxs]...
                =qf.getPredictions(tId, QfHiDM.DEBUG_LEVEL>0);
            if isempty(falsePosIdxs) && isempty(falseNegIdxs)...
                    && isempty(truePosIdxs) %don't rule out perfect prediction
                continue;
            end
            tName=qf.tNames{ti};
            done=done+1;
            sums(done,1)=tId;
            sums(done,2)=qf.tSizes(ti);
            addIdxs([tName ' true +'], 1, truePosIdxs);
            addIdxs([tName ' false +'], 2, falsePosIdxs);
            addIdxs([tName ' false -'], 3, falseNegIdxs);
            if SuhPredictions.DEBUG
                assert(isequal(qf.idxsFalseNeg{ti}, falseNegIdxs));
                assert(isequal(qf.idxsFalsePos{ti}, falsePosIdxs));
                assert(isequal(qf.idxsTruePos{ti}, truePosIdxs));
            end
        end
        
        function addIdxs(name, which, idxs)
            if isempty(idxs)
                return;
            end
            names{end+1}=name;
            ids(end+1)=tId+(which/10);
            
            if which<3
                pos(idxs)=ids(end);
            else
                neg(idxs)=ids(end);
            end
            sums(done, 2+which)=length(idxs);
        end
    end
    
    function [this, table]=New(qf, locate_fig, pu, columnName)
        this=[];
        table=[];
        if isstruct(qf)
            if isfield(qf, 'predictions')
                this=qf.predictions;
                qf.areEqual=true;
                qf.sData=[];
                this.setMatch(qf);
            end
        elseif isa(qf, 'QfHiDM')
            this=SuhPredictions(qf);
        end
        if nargin>3
            this.columnName=columnName;
        end
        if isempty(this)
            warning('Cannot instantiate SuhPredictions ?');
        else
            if nargin<3
                pu=[];
                if nargin<2
                    locate_fig=[];
                end
            end
            if ~isstruct(this)
                table=this.showTable(locate_fig, pu);
            end
        end
    end
    
    %next 5 functions only works if AutoGate is present
    function gid=GetPredictionGid(gtp, teachGid, studGid, predictingId)
        gid=SuhPredictions.GetPrediction(gtp,...
            SuhPredictions.GetPredictionParent(gtp, teachGid, studGid),...
            predictingId); 
    end

    function [pid, created, labelGater]=SetPredictionParent(...
            fg, teachPid, studPid, gateName, sampleLabels)
        %studPid would be typically something like top EPP gate
        %teachPid would be typically something like top of manual gate
        %hierarchy
        if nargin<4
            gateName='';
        end
        prop=SuhPredictions.PROP_PREDICTIONS;
        sid=fg.gt.tp.getParentFileId(studPid);
        rootId=GatingTree.GetOrganizer(fg, sid, ...
            prop, sid, true, 'Predictions (true+, false +/-)');
        if isempty(gateName)
            gateName=fg.gt.tp.getDescription(teachPid);
            gateName=sprintf('%s id=%s by id=%s)', ...
                gateName, teachPid, studPid);
        end
        [pid, created]=GatingTree.GetOrganizer(fg, ...
            {studPid, teachPid}, prop, ...
            rootId, true, gateName);
        labelGater=[];
        if SuhPredictions.JAVA
            if created
                LabelGater.Save(fg, pid, sampleLabels);
            end
            labelGater=fg.gt.tp.getLabelGater(pid);
        end
    end

    function [wasCreated, gid]=Create(fg, labelGater, gn, ...
            subset, tId, typeOfPrediction)
        sz=sum(subset);
        if isempty(labelGater)
            assert(~SuhPredictions.JAVA)
            if typeOfPrediction==3
                dsc='false -';
            elseif typeOfPrediction==2
                dsc='false +';
            else
                dsc='true +';
            end
            typeOfPrediction=num2str(typeOfPrediction);
            name=['labels: ' dsc ' for ' tId ' label=' ...
                tId '.' typeOfPrediction];
            [wasCreated, gid]=fg.createSpecificSampleSelectionGate(...
                name, subset, false, gn, [], false);
            if wasCreated
                fg.gt.tp.set([gid '.' ...
                    SuhPredictions.PROP_PREDICTED], tId);
                fg.gt.tp.set([gid '.' ...
                    SuhPredictions.PROP_PREDICTION], ...
                    typeOfPrediction);
            end
        else
            gid=labelGater.addPredictionGate(gn, ...
                sz, tId, typeOfPrediction);
            wasCreated=labelGater.isNew(gid);
            if ~wasCreated
                fprintf('Already have id=%s %s\n', gid, gn);
            end
            %fg.saveSpecificSampleSelectionsFile(newId, subset);
        end
    end
    function predictionPid=GetPredictionParent(gtp, teachPid, studPid)
        %studPid would be typically something like top EPP gate
        %teachPid would be typically something like top of manual gate
        %hierarchy        
        rootId=SuhPredictions.GetPredictionRoot(gtp, studPid);
        if isempty(rootId)
            predictionPid=[];
        else
            predictionPid=GatingTree.GetOrganizer(gtp, ....
                {studPid, teachPid}, ...
                SuhPredictions.PROP_PREDICTIONS, rootId);
        end
    end
    
    function rootId=GetPredictionRoot(gtp, studPid)
        %studPid would be typically something like top EPP gate
        sid=gtp.getParentFileId(studPid);
        rootId=GatingTree.GetOrganizer(gtp, sid, ...
            SuhPredictions.PROP_PREDICTIONS);
    end
    
    function child=GetPrediction(gtp, predictionParent, predictingId)
        child=[];
        if isempty(predictionParent)
            return;
        end
        predictedId=floor(predictingId);
        typeOfPrediction=num2str(int32((predictingId-predictedId)*10));
        predictedId=num2str(predictedId);
        it=gtp.getChildNodeList(predictionParent).iterator;
        while it.hasNext
            child=char(it.next);
            ok=SuhPredictions.IsPrediction(gtp, child, ...
                predictedId, typeOfPrediction);
            if ok
                return;
            end
        end
        child=[];
    end
    
    function ok=IsPrediction(gtp, gid, predictedId, typeOfPrediction)
        ok=false;
        predicted=gtp.get([gid '.' SuhPredictions.PROP_PREDICTED]);
        if isequal(predicted, predictedId)
            typeOf=gtp.get([gid '.' SuhPredictions.PROP_PREDICTION]);
            ok=isequal(typeOfPrediction, typeOf);
        end
    end
    
    function [idx, predictedId, str]=Type(predictingId)
        predictedId=floor(predictingId);
        idx=int32((predictingId-predictedId)*10);
        if nargout>2
            switch idx
                case 1
                    str='true+';
                case 2
                    str='false+';
                case 3
                    str='false-';
                otherwise
                    str='predicted';
            end
        end
    end
    
    
    function [tip, pnl]=Readings(fp, app, firstTime)
        if app.highDef
            factor=1.2;
        else
            factor=.97;
        end
        tip=[QfHiDM.Tip '<hr>' Kld.Tip];
        sm1=['<b>' app.smallStart];
        sm2=['</b>' app.smallEnd];
        dflt=2;
        lbl='';
        pnl=Gui.FlowLeftPanel(0,0);
        lbl=javax.swing.JLabel(['<html>' sm1 ...
            lbl sm2 '</html>']);
        pnl.add(lbl);
        combo=Gui.Combo(Html.WrapSmallBoldCell({'Select 1...<hr>',...
            [Html.ImgXy('help2.png', [], factor) ...
            '&nbsp;&nbsp;KLD' ], ...
            [Html.ImgXy('match16.png', [], factor) ...
            '&nbsp;&nbsp;QFMatch'],...
            [Html.ImgXy('emd.png', [], factor) ...
            '&nbsp;&nbsp;EMD'], 'Quadratic<br>form'}), dflt,...
            '',[], @(h,e)lookup(h), ['<html><font color="blue"><b>'...
            'Read background '...
            'materials...</b></font><hr>' tip '<hr></html>']);
        pnl.add(combo);
        Gui.SetTransparent(lbl);
        Gui.SetTransparent(combo);
        Gui.SetTransparent(pnl);
        fp.add(pnl);
        if firstTime
            MatBasics.RunLater(@(h,e)shake(), .5);
        end
        function shake
            edu.stanford.facs.swing.Basics.Shake(combo, 3);
            app.showToolTip(combo,[],-25,25);
        end
        function lookup(h)
            idx=h.getSelectedIndex;
            switch idx
                case 1
                    url='https://en.wikipedia.org/wiki/Kullback%E2%80%93Leibler_divergence';
                case 2
                    url='https://www.nature.com/articles/s41598-018-21444-4';
                case 3
                    url='https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0151859';
                case 4
                    url='http://www.cyto.purdue.edu/sites/default/files/PDFs/Bernas_quadratic_2008.pdf';
            end
            web(url, '-browser');
        end
    end
end
end