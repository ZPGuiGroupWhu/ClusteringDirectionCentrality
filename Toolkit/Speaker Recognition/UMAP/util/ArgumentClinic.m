%   AUTHORSHIP
%   Primary Developer: Stephen Meehan <swmeehan@stanford.edu> 
%   Provided by the Herzenberg Lab at Stanford University 
%   License: BSD 3 clause
%

classdef ArgumentClinic < handle
    properties(Constant)
        VERSION='2.0';
        PROP_UPDATE_CHECK_TIME='suh_pipelines.CheckUpdateTime';
        HOURS_BETWEEN_UPDATE_CHECK;
    end
    
    properties(SetAccess=private)
        fig;
        app;
        H;
        argsObjs=cell(1,3);
        jDlgClinics=cell(1,3);
    end
    
    methods
        function this=ArgumentClinic
            this.app=BasicMap.Global;
            MatBasics.WarningsOff;
            [this.fig, ~, personalized]=Gui.Figure(...
                true, 'ArgumentClinic.figV5', [], 'north', false);
            this.fig.Name=[' Stanford University''s '...
                'Herzenberg pipelines (v' ...
                ArgumentClinic.VERSION ')'];
            pnl=ArgumentClinic.TopPanel(this.app,...
                @(idx)selectClinic(this, idx));
            Gui.SetJavaInFig(.01, .01, pnl, [], ...
                this.fig, this.app, ~personalized);
            Gui.SetFigVisible(this.fig, true, false);
            ArgumentClinic.CheckForUpdate(false);
        end
        
        function selectClinic(this, idx)
            if ~isempty(this.jDlgClinics{idx})
                this.jDlgClinics{idx}.setVisible(true);
                this.jDlgClinics{idx}.requestFocus;
            elseif ~isempty(this.argsObjs{idx})
                argsObj=this.argsObjs{idx};
            else
                try
                    if idx==3
                        argsObj=SuhMatch.GetArgsWithMetaInfo();
                        where='south++';
                        forRunningWhat='for running QFMatch/QF-tree';
                        ttl='subset characterization';
                    elseif idx==1
                        [file, example]=SuhEpp.EliverArgs;
                        argsObj=SuhEpp.GetArgsWithMetaInfo(file, example{:});
                        where='south east++';
                        forRunningWhat='for running EPP';
                        ttl='unsupervised subset identification';
                    else
                        example={'label_column', 'end', ...
                            'match_scenarios', 2};
                        argsObj=UmapUtil.GetArgsWithMetaInfo(...
                            'eliverLabeled.csv',  example{:});
                        forRunningWhat='for running UMAP/UST';
                        ttl='unsupervised & supervised subset identification';
                        where='south west++';
                    end
                    
                    jd=javax.swing.JDialog;
                    jd.getContentPane.add(Gui.FlowPanelCenter(15,11,...
                        argsObj.getArgumentClinicPanel(forRunningWhat)));
                    jd.setTitle(['SUH ' ttl]);
                    jd.pack;
                    argsObj.javaWindow=jd;
                    this.jDlgClinics{idx}=jd;
                    SuhWindow.Follow(this.jDlgClinics{idx}, ...
                        this.fig, where, true);
                    jd.setVisible(true)
                catch ex
                    msgError(['<html>' Html.Exception(ex, BasicMap.Global) '</html>']);
                    ex.getReport
                end
            end
        end
    end
    
    methods(Static)
        function pnl=TopPanel(app, fnc)
            if nargin<2
                app=BasicMap.Global;
                if nargin<1
                    fnc=[];
                end
            end
            [~,leonard]=Gui.ImageLabel(Html.Wrap(Html.ImgXy(...
                'Leonard.png', [], .5, false, false, app)), [], ...
                'See about our lab''s founder', @seeLen);
            
            arthur=Gui.Label(['<html>'...
                Html.ImgXy('facs.gif',[], .94, false,false, app) ...
                '</html>']);
            btnUpdate=Gui.NewBtn(Html.WrapSmallBold(...
            '<font color="blue">Check for<br>Updates</font>'),...
                @(h,e)ArgumentClinic.CheckForUpdate(true),...
                'Click to checker for newer version of pipelines');
            pipeline=Gui.Label(['<html>'...
                Html.ImgXy('pipeline.png',[], .94, false,false, app) ...
                '</html>']);
            wayne=html('wayneMoore2.png', .39, ...
                '<u>unsupervised</u> identification', ...
                'exhaustive projection pursuit (EPP)', 'Wayne Moore');
            connor=html('connor.png',.15, ...
                ['unsupervised & <u>supervised</u> '...
                '<br>&nbsp;&nbsp;&nbsp;identification'], ...
                'parameter reduction (UMAP/UST)', 'Connor Meehan');
            orlova= html('darya.png',.2, ...
                'characterization', 'QFMatch/QF-tree', 'Darya Orlova');
            items={ wayne, connor, orlova, connor};
            jRadio=Radio.PanelAndCallback(@resolve, true, items);
            normalFont=javax.swing.UIManager.getFont('Label.font');
            font=java.awt.Font(normalFont.getName, ...
                normalFont.ITALIC, normalFont.getSize+3);
            pnlLen=Gui.BorderPanel([], 0, 8, ...
                'North', leonard, 'South', ...
                Html.WrapSmallBold('Len Herzenberg'));
            pnlSouthWest=Gui.BorderPanel;
            pnlSouthWest.add(pnlLen, 'West');
            pnlSouthWestEast=Gui.BorderPanel([],0,4, 'North', ...
                Gui.Panel(arthur), 'South', Gui.Panel(btnUpdate));
            pnlSouthWest.add(pnlSouthWestEast, 'East');
            if app.highDef
                pnl=Gui.Panel( Gui.BorderPanel([], 2, 15, ...
                    'North', pipeline, 'South', ...
                    pnlSouthWest), Gui.BorderPanel([], 0, 2, 'North',...
                    Html.WrapHr(['<font color="blue"><b>'...
                    'Choose a data subsetting pipeline</b></font>']),...
                    'Center', jRadio));
            else
                pnl=Gui.Panel( Gui.BorderPanel([], 2, 15, ...
                    'North', pipeline, 'South', ...
                    pnlSouthWest), jRadio);
                Gui.SetTitledBorder('Choose a data subsetting pipeline', pnl, font);
            end
            function str=html(img, scale, words, via, provider)
                img=Html.ImgXy(img,[], scale, ...
                    false,false,app);
                str=Html.Wrap(['<table cellspacing="5"><tr><td>' ...
                    img '</td><td><font color="blue"><b>Subset '...
                    words '</b></font><br>via <i>', via ...
                    '</i><br>' Html.WrapBoldSmall([' ' provider])...
                    '</td></tr></table>']);
            end
            
            function seeLen(h,e)
                web('https://www.pnas.org/content/110/52/20848', '-browser');
            end
            
            function resolve(h,e)
                item=char(e.getActionCommand);
                idx=StringArray.IndexOf(items, item);
                if isempty(fnc)
                    fprintf('Index %d chosen\n', idx);
                else
                    feval(fnc, idx);
                end
            end
        end
        
        function CheckForUpdate(userIsAsking, app)
            if nargin<2
                app=BasicMap;
            end
            app.setAppVersion([], UMAP.VERSION, SuhEpp.VERSION);
            SuhWebUpdate.Check(app, userIsAsking, .25, [], [], ...
                ArgumentClinic.PROP_UPDATE_CHECK_TIME, 36);
        end
        
        function jobWatch=RunJobs(folder)
            if ~isempty(folder)
                jobWatch=SuhJob(folder, [], false, ... %accept all args
                    @(this, job)go(job), 'south', ...
                    'ArgumentClinic.JobWatch', ...
                    {'suh_pipelines', 'run_umap', ...
                    'run_epp', 'run_match'});
            else
                jobWatch=[];
            end
            
            function finalArgs=go(job)
                finalArgs=[];
                if isfield(job, 'command')
                    cmd=job.command;
                    isPipeArgNeeded=true;
                    if strcmp(cmd, 'run_umap')
                        pipe='umap';
                    elseif strcmp(cmd, 'run_epp')
                        pipe='epp';
                    elseif strcmp(cmd, 'run_match')
                        pipe='match';
                    else %suh_pipelines
                        pipe=Args.GetIfNotPairs(...
                            'pipeline', job.args{:});
                        isPipeArgNeeded=false;
                        if isempty(pipe)
                            pipe='epp';%epp by default
                        end
                    end
                    if strcmpi(pipe, 'umap')...
                            || strcmp(pipe, 'epp')
                        job.props.set('data', job.args{1});
                        job.varArgs=job.args(2:end);
                    else
                        job.varArgs=job.args;
                    end
                    job.props.set('pipeline', pipe);  
                    if isPipeArgNeeded
                        job.varArgs=[job.varArgs 'pipe', pipe];
                    end
                end
                csv=job.props.get('data');
                if ~isempty(csv)
                    varArgs=Args.RemoveArg(job.varArgs, 'data');
                    obj=suh_pipelines(csv, varArgs{:});
                else
                    pipe=job.props.get('pipeline');
                    if isempty(pipe)
                        pipe=job.props.get('pipe');
                    end
                    if isempty(pipe)||~strcmpi(pipe,'match')
                        warn=sprintf(['<html>Received '...
                            'job with no data for pipeline '...
                            '%s in file %s<hr></html>'], ...
                            pipe, Html.FileTree(...
                            job.props.fileName));
                        msg(warn);
                        warn=sprintf(['Received job with no data '...
                            'for pipeline %s in file %s'], pipe,...
                            job.props.fileName);
                        
                        warning(warn);
                        return;
                    else
                        varArgs=Args.RemoveArg(...
                            job.varArgs, 'pipeline');
                        varArgs=[...
                            'pipeline', pipe, varArgs];
                        obj=suh_pipelines(varArgs{:});
                    end
                end
                if ~isempty(obj)
                    finalArgs=obj.args;
                    finalArgs.done=true;
                end
            end
        end
    end
end
