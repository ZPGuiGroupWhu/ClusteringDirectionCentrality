%   AUTHORSHIP
%   Primary Developer: Stephen Meehan <swmeehan@stanford.edu> 
%   Provided by the Herzenberg Lab at Stanford University 
%   License: BSD 3 clause
%

classdef SuhJob < handle
    properties(Constant)
        DFLT_TITLE=['<html><hr><b>'...
            'What''s in the pipeline?</b>'...
            '&nbsp;&nbsp;&nbsp;</html>'];
    end
    methods(Static)
        function [fig, jPending, jTitle, hMainPanel]...
                =Figure(txtTitle, prop, where, priority)
            if nargin<4
                figName='Job watch...';
                if nargin<3
                    where='south west';
                    if nargin<2
                        prop='SuhJob.figDflt';
                        if nargin<1
                            txtTitle=SuhJob.DFLT_TITLE;
                        end
                    end
                end
            else
                figName=[ 'JobWatch (v' ...
                    ArgumentClinic.VERSION ' ' priority...
                    ' priority)'];
            end
            app=BasicMap.Global;
            [fig, ~, personalized]=Gui.Figure(...
                true, prop, [], where, false);
            fig.Name=figName;
            bg=Gui.LIGHT_YELLOW_COLOR;
            ic=Gui.NewLbl(['<html>'...
                Html.ImgXy('pipeline.png',[], .74, false,false, app) ...
                '</html>'], '', bg);
            
            jTitle=Gui.NewLbl(txtTitle, [], bg);
            jPending=Gui.NewLbl('  0 job(s) pending...',  ...
                'eye.gif',  bg);
            center=Gui.BorderPanel([],0,4, ...
                'North', jTitle, 'Center', jPending);
            bp=Gui.BorderPanel([], 4, 4, 'West', ic, 'Center', center);
            hMainPanel=Gui.SetJavaInFig(.02, .02, bp, bg, fig, app,...
                ~personalized);
            Gui.SetFigVisible(fig, true, false);
        end
        
        
        function[command, args, statement]...
                =Parse(statement, logToConsole)
            %% SuhJob.Parse takes 1 input text command, 
            %   and creates output statement after 
            %   resolving it into legal command line syntax
            %   that lacks function call delimiters
            %   such as ( or , or ' or ).
            %   If input statement appears  coding syntax
            %   then currently only sinqle quote for strings 
            %   is supported.
            % 
            %   For example this statement
            %       run_umap('sampleBalbcLabeled55k.csv', 'label_column', 'end', 'label_file', 'balbcLabels.properties', 'save_template_file', 'ustBalbc2D.mat')
            %   is resolved into
            %       sampleBalbcLabeled55k.csv label_column end label_file balbcLabels.properties save_template_file ustBalbc2D.mat
            %
            % Input parameter
            % 'statement'     A statement using syntax for MATLAB
            %            command line.  If the statement
            %            appears function call syntax with characters (,' 
            %            THEN SuhJob. Run translates into 
            %            the command line syntax if possible.
            %            A string like 'file name.txt' will fail
            %           since command line interpreter will see 2 tokens
            %           and not one
            %
            %   Examples
            %   SuhJob.Run('run_match training_set sampleBalbcLabeled12k.csv  training_label_file balbcLabels.properties test_set sampleBalbc12k_mlp.csv')
            %   SuhJob.Run("run_umap('eliverLabeled.csv', 'label_column', 'end', 'match_scenarios', 3, 'cluster_detail', 'medium', 'match_predictions', true, fast_approximation, true);");
            %
            
            if nargin<2 || logToConsole
                [command, args, statement]=...
                    Args.CommandLineSyntax(statement);
                fprintf('Running\n   %s\n', statement);
            else
                [command, args]=...
                    Args.CommandLineSyntax(statement);
            end
        end
    end
    
    properties(SetAccess=private)
        toDo={};
        folder;
        watch;
        expectedArgs;
        onlyArgs;
        callBack;
        dispatchingJobs=false;
        fig;
        jPending;
        jTitle;
        supportedCommands;
        runUnsupportedCommand;
    end
    
    methods
        function this=SuhJob(folderAndFileSpec, definedArgs, ...
                onlyArgs, callBack, where, prop, ...
                supportedCommands, runUnsupportedCommand,...
                txtTitle)
            if nargin<9
                txtTitle=SuhJob.DFLT_TITLE;
                if nargin<8
                    runUnsupportedCommand=true;
                    if nargin<7
                        supportedCommands={};%all allowed
                        if nargin<6
                            prop='SuhJob.figEye';
                            if nargin<5
                                where=[];
                                if nargin<4
                                    callBack=[];
                                    if nargin<3
                                        onlyArgs=true;
                                        if nargin<2
                                            definedArgs=[];
                                            if nargin<1
                                                %duh most useful test folder for jobs
                                                folderAndFileSpec='~/Downloads';
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            this.supportedCommands=supportedCommands;
            if isempty(supportedCommands)
                runUnsupportedCommand=true;
            end
            this.runUnsupportedCommand=runUnsupportedCommand;
            [priority, fldr, fileSpec]...
                =File.ParseWatchFolder(folderAndFileSpec);
            this.folder=fldr;
            htmlFolder=Html.FileTree(fldr);
            if ~exist(fldr, 'dir')
                if exist(fldr, 'file')
                    word=' a <b><u>file</u></b> and ';
                    msgError(['<html><b><font color="red">'...
                        'No ' priority ' priority jobs will be'...
                        ' processed!!!</font></b><br>....'...
                        '<br>This is ' word '<b>NOT</b> a file folder'...
                        '<br>on your computer:<br>'...
                        htmlFolder '</html>'], 15, 'south east+');
                    return;
                end
                File.mkDir(fldr);
            end
            if ~isempty(where)
                [this.fig, this.jPending, this.jTitle]...
                    =SuhJob.Figure(txtTitle, prop, ...
                    where, priority);
                tip=['<html>Watching for ' fileSpec ...
                    'files in ' htmlFolder '<hr></html>'];
                this.jTitle.setToolTipText(tip);
                this.jPending.setToolTipText(tip)
            end
            if ~isempty(definedArgs)
                args=Args(definedArgs);
                this.expectedArgs=args.fields;
            end
            this.callBack=callBack;
            this.onlyArgs=onlyArgs;
            this.watch=File.WatchForNewFiles...
                (@parseJobs, folderAndFileSpec);
            priorClose=get(this.fig, 'CloseRequestFcn');
            set(this.fig, 'CloseRequestFcn', @close);
            
            function close(h,e)
                if isempty(this.fig)
                    return;
                end
                jw=Gui.JWindow(this.fig);
                this.fig=[];
                loc=jw.getLocation;
                this.watch.close;
                feval(priorClose, h,e);
                drawnow;
                jd=msg(struct(...
                    'javaWindow', 'none', 'msg', ...
                    ['<html><u>' String.Capitalize(priority) ...
                    '</u> priority job watch has <br>'...
                    '<b>ended</b> on the folder:'  ...
                    htmlFolder '<hr></html>']), ...
                    6, 'center', 'Note', 'eye.gif');
                jd.setLocation(loc.x+15, loc.y+10);
                %jd.setVisible(true);
                PopUp.TimedClose(jd, 6)
                if isdeployed
                    MatBasics.RunLater(...
                        @(h,e)askCloseAll(), .25);
                end
                
                function askCloseAll
                    if askYesOrNo(struct(...
                            'javaWindow', jd, 'msg', ...
                            ['<html><center>Do you wish to'...
                            ' now close <br><b>all other</b>'...
                            ' windows?</center><hr></html>']), ...
                            'Close all?', 'north++', true);
                        exit;
                    end
                end

            end
            
            function parseJobs(newFiles)
                N=length(newFiles);
                for i=1:N
                    file=fullfile(this.folder, newFiles{i});
                    job.file=file;
                    job.props=JavaProperties.Read(file, 'run');
                    job.varArgs=job.props.getNumOrLogical(...
                        this.expectedArgs, this.onlyArgs);
                    this.toDo{end+1}=job;
                end
                if ~isempty(callBack)
                    MatBasics.RunLater(@(h,e)dispatchJobs(this), .15);
                end
            end
        end
        
        function dispatchJobs(this)
            if ~this.dispatchingJobs
                this.dispatchingJobs=true;
                this.showPending;
                job=this.next();
                while ~isempty(job)
                    try
                        if ~this.watch.isAlive
                            return;
                        end
                        finalArgs=[];
                        jobFile=File.ExpandHomeSymbol(job.file);
                        badResultsFile=File.SwitchExtension(...
                            jobFile, 'suh.bad');
                        if exist(badResultsFile, 'file')
                            delete(badResultsFile);
                        end
                        resultsFile=File.SwitchExtension(...
                            jobFile, 'suh.results');
                        if exist(resultsFile, 'file')
                            delete(resultsFile);
                        end
                        run=job.props.get('run');
                        if isempty(run)
                            finalArgs=feval(this.callBack, this, job);
                        else
                            [command, args]=...
                                SuhJob.Parse(run);
                            I=StringArray.IndexOfIgnoreCase(...
                                this.supportedCommands, command);
                            if I<1
                                if this.runUnsupportedCommand
                                    try
                                        finalArgs.cmd=run;
                                        finalArgs.done=true;
                                        feval(command, args{:});
                                    catch
                                        finalArgs.done=false;
                                    end
                                end
                            else
                                job.command=command;
                                job.args=args;
                                finalArgs=feval(this.callBack, this, job);
                            end                            
                        end
                    catch ex
                        BasicMap.Global.reportProblem(ex);
                    end
                    if isempty(finalArgs)
                        txt=Args.ToStringWithNewLines(...
                            job.varArgs{:});
                        File.WriteTextFile(resultsFile, ...
                            [txt 'done=false' newline]);
                        % send EFFICIENT signal that job failed
                        % so job submitter need not open the
                        % RESULTS file if they know where
                        % the output_folder is
                        copyfile(resultsFile, badResultsFile);
                    else
                        txt=String.toString(finalArgs, ...
                            true, '=', false, newline);
                        File.WriteTextFile(...
                            resultsFile, txt);
                    end
                    delete(job.file);
                    this.showPending;
                    job=this.next();
                end
                this.dispatchingJobs=false;
            else
                disp([num2str(length(this.toDo)+1) ...
                    ' job(s) ALREADY being dispatched!!'])
            end
        end
        
        function job=next(this)
            if isempty(this.toDo)
                job=[];
            else
                job=this.toDo{1};
                this.toDo(1)=[];
            end
        end
        
        function showPending(this)
            if ~isempty(this.jPending)
                this.jPending.setText([...
                    num2str(length(this.toDo)) ...
                    ' job(s) pending...']);
            end
        end
        
    end
    
end
