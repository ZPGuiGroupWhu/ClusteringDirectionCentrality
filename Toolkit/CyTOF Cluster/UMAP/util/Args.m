%   AUTHORSHIP
%   Primary Developer: Stephen Meehan <swmeehan@stanford.edu> 
%   Provided by the Herzenberg Lab at Stanford University 
%   License: BSD 3 clause
%
classdef Args < handle
    properties 
        app=BasicMap.Global;
        parentIsFig=false;
        commandPreamble=''; %e.g. suh_pipelines
        commandVarArgIn='';
        javaWindow;
    end
    
    properties(SetAccess=private)
        p;
        fields;
        argued;  % explicitly
        map; %map of meta info about each
        commentFiles={}; % m files to gather help from
        commented=false; %tips parsed out of commentFiles
        argFile;
        fncTypify;
        isMetaSet=false;
        argGroups;
        argGroupLabels;
        props;
        property_prefix;
        csv_args={};
        csv_label_column_args={};
        csv_label_file_args={};
        fileFoci;
        fncRun;
        positionalArgs;
        jtfCommand;
    end
    
    methods
        
        function setArgGroup(this, group, label)
            N=length(group);
            assert(N>1);
            missing=0;
            for i=1:N
                meta=this.map.get([group{i} '.meta']);
                if isempty(meta)
                    missing=missing+1;
                    warning('No defined argument named "%s"', group{1});
                end
            end
            if missing<N
                this.argGroups{end+1}=group;
                if nargin<3
                    this.argGroupLabels{end+1}=[group{1} ...
                        sprintf(' & %d related setting(s)', N-1)];
                else
                    this.argGroupLabels{end+1}=label;
                end
            end            
        end
        
        function setMetaInfo(this, arg, varargin)
            metaP=Args.DefineArgs;
            parse(metaP, varargin{:})
            meta=metaP.Results;
            meta.name=arg;
            if isempty(this.map)
                this.initMap;
            end
            assert(meta.outsider || isfield(this.fields, arg));
            priorMeta=this.map.get([arg '.meta']);
            if ~isempty(priorMeta) %NOT outsider
                if isempty(meta.text_columns)
                    meta.text_columns=priorMeta.text_columns;
                end
                if StringArray.Contains(metaP.UsingDefaults, 'type')
                    meta.type=priorMeta.type;
                end
                if isempty(meta.label)
                    meta.label=priorMeta.label;
                end
            end
            this.map.set([arg '.meta'], meta);
            if ~isempty(meta.default_if_empty)
                if ~isfield(this.fields, arg)
                    prior=[];
                else
                    prior=getfield(this.fields, arg);
                end
                if isempty(prior)
                    this.fields=setfield(this.fields, arg, ...
                        meta.default_if_empty);
                end
            end
        end
        
        function pnl=getArgumentClinicPanel(this, description)
            if nargin<2
                description='';
            end
            app_=this.app;
            normalFont=javax.swing.UIManager.getFont('Label.font');
            pnlCenter=Gui.BorderPanel([], 11, 4);
            font=java.awt.Font(normalFont.getName, ...
                normalFont.ITALIC, normalFont.getSize+3);
            Gui.SetTitledBorder(['The argument clinic ' description ...
                '...'], pnlCenter, font);
            pnlClinic=Gui.BorderPanel;
            btnCloseClinic=Gui.ImageButton('close.gif', ...
                'Hide Monty Python', @(h,e)closeClinic());
            pnlClinicNorth=Gui.BorderPanel([],2,0,'West', ...
            	javax.swing.JLabel(['<html>Come for an argument?' ...
                '</html>']), 'East', btnCloseClinic);
            pnlClinic.add(pnlClinicNorth, 'North');
            if app_.highDef
                pngSize=1.295;
            else
                pngSize=.6;
            end
            [~, imgClinic]=Gui.ImageLabel(['<html><hr>' Html.ImgXy(...
                'argumentClinic.png',[], pngSize) '</html>'], [], ...
                'Click for history of this', @(h,e)web(...
                'https://en.wikipedia.org/wiki/Argument_Clinic',...
                '-browser'));
            pnlClinic.add(imgClinic, 'Center');
            pnlCenter.add(pnlClinic, 'West');
            flds=this.fields;
            fieldNames=fieldnames(flds);
            ss=SortedStringSet(true, false, ...
                fieldNames{:});
            fieldNames=ss.strings;
            nNames=length(fieldNames);
            nGroups=length(this.argGroups);
            choices=cell(1,nNames+nGroups);
            for i=1:nGroups
                arg1=this.argGroups{i}{1};
                idx=StringArray.IndexOf(fieldNames, arg1);
                if idx>0
                    choices{i}=this.argGroupLabels{i};
                end
            end
            for i=1:nNames
                choices{i+nGroups}=fieldNames{i};
            end
            [pnlList, jList]=Gui.NewListSearch(choices,...
                'Find 1+ args', [], ...
                'Arguments to run with', @(h,e)listClick(e));
            pnlCenter.add(Gui.BorderPanel([], 3, 2, 'North', ...
                '<html>OK... pick one (or more)...<hr></html>',...
                'Center', pnlList), 'Center');
            east=Gui.BorderPanel;
            btnRefine=Gui.NewBtn(...
                '<html><i>Refine</i> the<br>argument</html>',...
                @(H,e)refine(), 'Change selected argument(s)',...
                'match16.png');
            east.add(btnRefine, 'South');
            pnlCenter.add(east, 'East');
            btnRun=Gui.NewBtn('<html>Run with<br>arguments</html>',...
                    @(h,e)run(), '', 'smallGenie.png');
            setRunTipAndCmd(false);
            south=Gui.BorderPanel([],5, 1);
            southEast=Gui.BorderPanel([],5, 1);
            southEast.add(btnRun, 'South');
            south.add(southEast, 'East');
            setFileFociIfNeeded;
            pnlCenter.add(south, 'South');
            this.jtfCommand=Gui.NewTextField('', 35,...
                'Copy & paste to command line');
            pnlSouth=Gui.FlowLeftPanel(12);
            pnlSouth.add(Gui.NewBtn(...
                Html.WrapSmallBold('Copy command...'),...
                @(h,e)copyCmd(), ...
                'Copy command to clipboard', ...
                'Copy.png'));
            pnlSouth.add(this.jtfCommand);
            pnl=Gui.BorderPanel([],2,15, 'Center', ...
                pnlCenter, 'South', pnlSouth);
            
            function copyCmd
                s=strtrim(char(this.jtfCommand.getText));
                if ~isempty(s)
                    clipboard('copy',s);
                end
            end
            
            function closeClinic
                pnlClinic.setVisible(false);
                if ~this.parentIsFig
                    w=Gui.WindowAncestor(pnlClinic);
                    w.pack;
                end
            end
            
            function setFileFociIfNeeded
                if ~isempty(this.fileFoci)
                    nFoci=length(this.fileFoci);
                    foci={};
                    for i=1:nFoci
                        focus=this.fileFoci{i};
                        focus.jLbl=Gui.Label('');
                        pnlFocusNorth=Gui.Panel(...
                            ['<html><b>' focus.ttl '</b><hr></html>']);
                        southSouth=Gui.BorderPanel([],4,4, 'West', focus.jLbl);
                        pnlFocus=Gui.BorderPanel([],0,1,'North',...
                            pnlFocusNorth,...
                            'South', southSouth);
                        if iscell(focus.args) && length(focus.args)>1
                            focus.combo=Gui.Combo(focus.choices,1, ...
                                [],[], @(h,e)setCurFileFocus(focus, h));
                            pnlFocusNorth.add(focus.combo);
                        else
                            focus.combo=[];
                        end
                        pnlSelectCsv=Gui.Panel(...
                            Gui.NewBtn(Html.WrapSmall(...
                            ['Select<br>' focus.ext ' file']), ...
                            @(h,e)changeFileFocus(focus), ...
                            'Click to select different csv file as data source',...
                            'file_open.png'));
                        southSouth.add(pnlSelectCsv, 'Center');
                        setCurFileFocus(focus, focus.combo);
                        foci{end+1}=pnlFocus;
                    end
                    south.add(Gui.GridBagPanel(0,3, [],foci{:}), 'West');
                end
            end
            function run
                [varArgIn, html, cmd]=this.getVarArgIn;
                this.jtfCommand.setText(cmd);
                lbl=Gui.Label(Html.Wrap(html), 200, 200);
                jp=Gui.BorderPanel([], 5, 12, 'North', Html.WrapHr(...
                    [app_.h3Start 'Run with these arguments?' app_.h3End]), ...
                    'Center', lbl);
                if askYesOrNo(struct('msg', jp, 'javaWindow',...
                        Gui.WindowAncestor(btnRefine), 'icon', ...
                        'genieSearch.png'), 'Ready to run?', 'north+',...
                        true, [], 'Args.Run')
                    try
                        feval(this.fncRun, varArgIn{:});
                    catch ex
                        Gui.MsgException(ex);
                    end
                end
            end
            
            function changeFileFocus(focus)
                if ischar(focus.args)
                    arg=focus.args;
                else
                    arg=focus.args{focus.combo.getSelectedIndex+1};
                end
                editorCmp=this.getEditorComponent(arg);
                    
                Gui.FireActionListener(editorCmp);
                setCurFileFocus(focus, focus.combo);
                setRunTipAndCmd(true);
            end
            
            function setRunTipAndCmd(show)
                [~,html, functionCallSyntax]=this.getVarArgIn(8);
                btnRun.setToolTipText(['<html>Click to run with '...
                    'these<br>explicit (non default) arguments'...
                    html '</html>']);
                if show
                    edu.stanford.facs.swing.Basics.Shake(btnRun,5);
                    app_.showToolTip(btnRun);
                end
                if ~isempty(this.jtfCommand)
                    
                    [~,~, commandLineSyntax, isGood]...
                        =Args.CommandLineSyntax(...
                        functionCallSyntax);
                    if isGood
                        if isdeployed
                            [~,v]=MatBasics.VersionAbbreviation;
                            if ismac
                                commandLineSyntax=strrep(...
                                    commandLineSyntax, ...
                                    'suh_pipelines', [...
                                    'run_suh_pipelines' v '.sh']);
                            elseif ispc
                                commandLineSyntax=strrep(...
                                    commandLineSyntax, ...
                                    'suh_pipelines', [...
                                    'suh_pipelines ' v ]);
                            end
                        end
                        commandLineSyntax=...
                            strrep(commandLineSyntax, [...
                            WebDownload.DefaultFolder filesep], ...
                            '');
                        this.jtfCommand.setText(...
                            commandLineSyntax);
                    else
                        this.jtfCommand.setText(...
                            functionCallSyntax);
                    end
                end
            end
            
            function setCurFileFocus(focus, combo)
                if ischar(focus.args)
                    arg=focus.args;
                else
                    arg=focus.args{combo.getSelectedIndex+1};
                end
                jLbl=focus.jLbl;
                cur=getfield(this.fields, arg);
                if ischar(cur)
                    jLbl.setText(['<html>' Html.FileTree(cur) '</html>']);
                elseif isempty(cur)
                    jLbl.setText('None selected');
                elseif isnumeric(cur)
                    [R,C]=size(cur);
                    jLbl.setText(sprintf('%d x %d data points', R, C));
                else
                    jLbl.setText([class(cur) ' object']);
                end
                if ~this.parentIsFig
                    try
                        Gui.WindowAncestor(jLbl).pack;
                    catch
                    end
                end
            end
            
            function setRefineBtn
                args=gatherArgs(false);
                N=length(args);
                if N>1
                    btnRefine.setText(sprintf(...
                        '<html><i>Refine</i> %d<br>arguments</html>', N));
                else
                    btnRefine.setText(...
                        '<html><i>Refine</i> the<br>arguments</html>');
                end
            
            end
            
            function listClick(e)
                % Determine the click type
                % (can similarly test for CTRL/ALT/SHIFT-click)
                if ~isempty(e) && e.getClickCount==2
                    Gui.FireActionListener(btnRefine);
                    edu.stanford.facs.swing.Basics.Shake(btnRun,5);
                    Gui.SetDefaultButton(btnRun);
                else
                    edu.stanford.facs.swing.Basics.Shake(btnRefine,5);
                    Gui.SetDefaultButton(btnRefine);
                end
                setRefineBtn;
            end

            function args=gatherArgs(complain)
                args={};
                idxs=jList.getSelectedIndices;
                if isempty(idxs) && (nargin==0 || complain)
                    msgError('First pick an argument', 4,'south east');
                    return;
                end
                idxs=idxs+1;
                for argIdx=idxs'
                    if argIdx<=nGroups
                        args=[args this.argGroups{argIdx}];
                    else
                        args=[args choices{argIdx}];
                    end
                end
                args=StringArray.RemoveDuplicates(args, java.util.LinkedHashSet);
            end
            
            function refine
                args=gatherArgs;
                cancelled=this.editArgs(args, Gui.WindowAncestor(btnRefine));
                if ~cancelled
                    setRunTipAndCmd(true);
                end
            end
        
            
        end
        
        function ok=isFile(this, arg, suffix)
            ok=false;
            prop=[arg '.meta'];
            meta=this.map.get(prop);
            if ~isempty(meta)
                f=meta.type;
                if isempty(suffix)
                    ok=startsWith(f, 'csv_') || startsWith(f, 'file_');
                else 
                    ok=isequal(f, ['csv_' suffix]) ...
                        || isequal(f, ['file_' suffix]);
                end
            end
        end
        

        function setFileFocus(this, ttl, args, ext)
            if nargin<4
                ext='csv';
            end
            f.args=args;
            f.choices=args;
            f.ext=ext;
            if 2==length(args) 
                if this.isFile(args{1}, 'readable') 
                    if this.isFile(args{2}, 'writable')
                        f.choices={'Read from', 'Save to'};
                    end
                end
            end
            f.ttl=ttl;
            this.fileFoci{end+1}=f;
        end
        
        function setCsv(this, arg, readOnly, label_column_arg, label_file_arg)
            if nargin<4
                label_file_arg='';
                if nargin<3
                    label_column_arg='';
                    if nargin<2
                        readOnly=true;
                    end
                end
            end
            prop=[arg '.meta'];
            meta=this.map.get(prop);
            if isempty(meta)
                metaP=Args.DefineArgs;
                parse(metaP)
                meta=metaP.Results;
                meta=setfield(meta, arg, '');
                meta.name=arg;
            end
            if readOnly
                meta.type='csv_readable';
            else
                meta.type='csv_writable';
            end
            this.map.set(prop, meta);
            this.csv_args{end+1}=arg;
            this.csv_label_column_args{end+1}=label_column_arg;
            this.csv_label_file_args{end+1}=label_file_arg;
            meta=this.map.get([label_file_arg '.meta']);
            if isempty(meta.file_ext)
                meta.file_ext='properties';
                this.map.set([label_file_arg '.meta'], meta);
            end
        end
        
        function cancelled=refineArgs(this, varargin)
            N=length(varargin);
            args={};
            for i=1:N
                if isnumeric(varargin{i})
                    args=[args this.argGroups{varargin{i}}];
                else
                    args{end+1}=varargin{i};
                end
            end
            cancelled=this.editArgs(args);
        end
        
        function cancelled=editArgs(this, args, javaWindow)
            if nargin<3
                javaWindow=[];
            end
            args=StringArray.RemoveDuplicates(args, java.util.LinkedHashSet);
            nArgs=length(args);
            mainPanel=Gui.GridBagPanel;
            gbc=javaObjectEDT('java.awt.GridBagConstraints');
            gbc.anchor=gbc.WEST;
            gbc.fill=0;
            cmps=cell(1,nArgs);
            for j=1:nArgs
                arg_=args{j};
                [cmp, meta]=this.getEditorComponent(arg_);
                gbc.gridy=j-1;
                gbc.gridx=0;
                gbc.anchor=gbc.EAST;
                if ~isempty(meta.low)&&~isempty(meta.high)
                    if meta.high==intmax
                        sHigh='max';
                    else
                        sHigh=num2str(meta.high);
                    end
                    
                    jl=Gui.Label(sprintf('%s (%s-%s)', meta.label,...
                        num2str(meta.low), sHigh));
                else
                    jl=Gui.Label(meta.label);
                end
                jl.setHorizontalAlignment(javax.swing.JLabel.RIGHT);
                mainPanel.add(jl, gbc);
                gbc.gridx=1;
                gbc.anchor=gbc.WEST;
                mainPanel.add(Gui.ImageButton('help2.png', 'Find help', ...
                    @(h,e)help(h, arg_)), gbc);
                gbc.gridx=2;
                mainPanel.add(cmp, gbc);
                cmps{j}=cmp;
            end
            try
                cmps{1}.requestFocus;
            catch
            end
                    
            [~,~, cancelled]=questDlg(struct(...
                'msg', Gui.Scroll(mainPanel, 400, 300, this.app), ...
                'javaWindow',  javaWindow, 'where', 'north', ...
                'icon', 'genieSearch.png'), ...
                'Argument Clinic...', 'Save', 'Cancel', 'Save');
            if ~cancelled
                for j=1:nArgs
                    this.updateWithEditorValue( args{j}, cmps{j});
                end
            end
            function help(h, arg)
                this.getHelp(arg, true, Gui.WindowAncestor(h));
            end
        end
        
        function p=getProp(this, arg)
            p=[this.property_prefix '.' arg];
        end
        
        function [value, property, meta]=syncProp(this, arg)
            value=getfield(this.fields, arg);
            property=this.getProp(arg);
            meta=this.map.get([arg  '.meta']);
            if ~isempty(value)
                if islogical(value)'
                    if value
                        this.props.set(property, 'true');
                    else
                        this.props.set(property, 'false');
                    end
                elseif isnumeric(value)
                    this.props.set(property, num2str(value));
                elseif ischar(value)
                    if strcmpi(meta.type, 'file_readable') ...
                        || strcmpi(meta.type, 'csv_readable') ...
                        || strcmpi(meta.type, 'file_writable')...
                        || strcmpi(meta.type, 'csv_writable') ...
                        || strcmpi(meta.type, 'folder')
                        fldr=fileparts(value);
                        if ~isempty(fldr)
                            this.props.set(property,fldr);
                        end
                    else
                        this.props.set(property,value);
                    end
                end
            end
        end
        
        function value=updateWithEditorValue(this, arg, cmp)
            if isequal(cmp.getForeground, Gui.ERROR_COLOR) ...
                    || isa(cmp, 'javax.swing.JLabel')
                value=[];
                return;
            end
            bad=0;
            if isequal(cmp.getForeground, Gui.ERROR_COLOR)
                bad=1;
            end
            meta=this.map.get([arg  '.meta']);
            if ~isempty(meta.valid_values)
                value=cmp.getSelectedItem;
            elseif strcmpi(meta.type, 'double')
                [values, bad]=Gui.GetTextFieldNums(cmp, true);
                nNums=length(values);
                value=[];
                for i=1:nNums
                    if ~isnan(values(i))
                        value(end+1)=values(i);
                    end
                end
            elseif strcmpi(meta.type, 'logical')
                value=cmp.isSelected;
            elseif strcmpi(meta.type, 'char')
                values=Gui.GetTextFieldStrs(cmp);
                nNums=length(values);
                if nNums==1
                    value=values{1};
                else
                    value={};
                    for i=1:nNums
                        if ~isempty(values{i})
                            value{end+1}=values{i};
                        end
                    end
                end
            else
                return;
            end
            if bad==0
                cur=getfield(this.fields, arg);
                %even if EQUAL we need to update 
                % because default values are not
                % auto-shown 
                %if ~isequal(cur, value)
                    this.update(arg, value);
                %end
            end
        end
        
        function [cmp, meta]=getEditorComponent(this, arg)
            [value, prop, meta]=this.syncProp(arg);
            cmp=[];
            if ~meta.command_only
                if ~isempty(meta.valid_values)
                    cmp=Gui.Combo(meta.valid_values, value, ...
                        prop, this.props,meta.callback,meta.tip, ...
                        'this is big enough');
                elseif strcmpi(meta.type, 'double') && isnumeric(value)
                    nValues=length(value);
                    if meta.is_integer
                        fncFmt='int';
                    else
                        fncFmt=[];
                    end
                    cols=meta.editor_columns;
                    if nValues<=1 && cols<2
                        cmp=Gui.AddNumberField(meta.label, meta.text_columns, ...
                            value, this.props, prop,...
                            [], meta.tip, meta.low, meta.high,...
                            false, fncFmt);
                    else
                        rows=ceil(nValues/cols);
                        if rows<meta.editor_rows
                            rows=meta.editor_rows;
                        end
                        cmp=Gui.GridPanel([], rows, meta.editor_columns);
                        if nValues<1
                            i=1;
                        else
                            for i=1:nValues
                                cmp.add(Gui.AddNumberField(...
                                    meta.label, meta.text_columns, ...
                                    value(i), this.props, prop,...
                                    [], meta.tip, meta.low, meta.high,...
                                    false, fncFmt));
                            end
                        end
                        if nValues<meta.editor_columns*rows
                            while i<=meta.editor_columns*rows
                                cmp.add(Gui.AddNumberField(...
                                    meta.label, meta.text_columns, ...
                                    [], this.props, prop,...
                                    [], meta.tip, meta.low, meta.high,...
                                    false, fncFmt));
                                i=i+1;
                            end
                        end
                    end
                elseif strcmpi(meta.type, 'logical')
                    cmp=Gui.CheckBox('', value, this.props, prop);
                elseif strcmpi(meta.type, 'char')
                    if iscell(value)
                        nValues=length(value);
                    else
                        nValues=1;
                    end
                    cols=meta.editor_columns;
                    if nValues<=1 && cols<2
                        cmp=Gui.NewTextField(value, meta.text_columns, ...
                            meta.tip, this.props, prop, meta.callback);
                    else
                        rows=ceil(nValues/cols);
                        if rows<meta.editor_rows
                            rows=meta.editor_rows;
                        end
                        cmp=Gui.GridPanel([], rows, meta.editor_columns);
                        if nValues<1
                            i=1;
                        else
                            for i=1:nValues
                                cmp.add(Gui.NewTextField(value{i}, ...
                                    meta.text_columns, meta.tip, ...
                                    this.props, prop, meta.callback));
                            end
                        end
                        if nValues<meta.editor_columns*rows
                            while i<=meta.editor_columns*rows
                                cmp.add(Gui.NewTextField('', ...
                                    meta.text_columns, meta.tip, ...
                                    this.props, prop, meta.callback));
                                i=i+1;
                            end
                        end
                    end

                elseif strcmpi(meta.type, 'file_readable') ...
                        ||strcmpi(meta.type, 'csv_readable')
                    cmp=this.getFileButton(arg, @getFileRead);
                elseif strcmpi(meta.type, 'file_writable')...
                        ||strcmpi(meta.type, 'csv_writable')
                    cmp=this.getFileButton(arg, @getFileWrite);
                elseif strcmpi(meta.type, 'folder')
                    cmp=this.getFileButton(arg, @getFolder);
                end
            end
            if isempty(cmp)
                %assert(strcmpi(meta.type, 'unknown'));
                s=Html.WrapSmall(['Only set with<br>Script/command']);
                cmp=Gui.Label(s);
                cmp.setToolTipText( ['<html>No GUI element has '...
                    'been <br>developed for this ' class(value) ' argument.'])
            end
        end
        
        function btn=getFileButton(this, arg, callback)
            cur=this.syncProp(arg);
            txt='';
            tip='';
            if isempty(cur)
                txt='Pick';
                tip='Pick from file system';
            else
                txtTip;
            end
            btn=Gui.NewBtn(txt, @(h,e)cb(h), tip,'file_open.png');
            
            function txtTip
                [~,f,e]=fileparts(cur);
                txt=[f e];
                tip=['<html>' Html.FileTree(cur) '</html>'];
            end
            
            function cb(h)
                cur=feval(callback, this, arg);
                if ~isempty(cur)
                    idx=StringArray.IndexOf(this.csv_args, arg);
                    if idx>0
                        if ~isempty(this.csv_label_column_args{idx})
                            [~, label_column]=File.ReadCsvHeader(...
                                cur, Gui.WindowAncestor(h));
                            larg=...
                                this.csv_label_column_args{idx};
                            if label_column>0
                                this.update(larg, label_column);
                                if ~isempty(this.csv_label_file_args{idx})
                                    this.getFileRead(...
                                        this.csv_label_file_args{idx});
                                end
                            else
                                this.remove(larg);
                            end
                        end
                    end
                    txtTip;
                    h.setText(txt);
                    h.setToolTipText(tip);
                end
            end
        end
    end
    
    methods(Access=private)
        function initMap(this)
            metaP=Args.DefineArgs;
            parse(metaP);
            prototype=metaP.Results;
            
            this.map=Map;
            names=fieldnames(this.fields);
            N=length(names);
            for i=1:N
                arg=names{i};
                meta=prototype;
                meta.name=arg;
                meta.label=arg;
                fieldValue=getfield(this.fields, arg);
                if islogical(fieldValue)
                    meta.type='logical';
                    meta.text_columns=1;
                elseif isnumeric(fieldValue) 
                    if isempty(fieldValue)
                        if Args.WARN_TYPE==2
                            warning('"%s" is empty ... assuming double', arg);
                        end
                        meta.type='unknown';
                    else
                        meta.type='double';
                    end
                    meta.text_columns=5;
                elseif ischar(fieldValue)
                    meta.type='char';
                    meta.text_columns=12;
                else
                    fprintf('"%s" has unsupported type %s\n', arg, class(fieldValue));
                end
                this.map.set([arg '.meta'], meta);
            end
        end
    end
       
    methods
        function setRange(this, arg, low, high)
            prop=[arg '.meta'];
            meta=this.map.get(prop);
            assert( ~isempty(meta));
            assert(strcmpi(meta.type, 'double'));
            meta.low=low;
            meta.high=high;
            this.map.set(prop, meta);
        end
        
        function setSources(this, fncRun, commentFiles, argFile, ...
                props, property_prefix, fncTypify)
            if nargin<7
                fncTypify=[];
                if nargin<6
                    property_prefix=[];
                    if nargin<5
                        props=[];
                        if nargin<4
                            argFile=[];
                        end
                    end
                end
            end
            if ischar(commentFiles)
                commentFiles={commentFiles};
            end
            if isempty(argFile)
                argFile=commentFiles{1};
            end
            this.fncRun=fncRun;
            this.commentFiles=commentFiles;
            this.argFile=argFile;
            [~,f]=fileparts(argFile);
            if isempty(property_prefix)
                this.property_prefix=f;
            end
            if isempty(props)
                props=BasicMap.Global;
            end
            this.props=props;
            if isempty(fncTypify)
                this.fncTypify=[f '.SetArgsMetaInfo'];
            else
                this.fncTypify=fncTypify;
            end
        end
        
        function file=saveFile(this)
            file=[];
            if ~isempty(this.commentFiles) ... %derive from 1st comment file name
                    && exist(this.commentFiles{1}, 'file')
                [path,f]=fileparts(this.commentFiles{1});
                file=fullfile(path, [f '.mat']);
            end
        end 
       
        function gotLoaded=load(this)
            gotLoaded=false;
            saveFile=this.saveFile;
            if isempty(saveFile)
                this.setAllMetaInfo;
                return;
            end
            saveFileInfo=dir(saveFile);
            lackMetaInfo=isempty(saveFileInfo);
            if ~isdeployed %check uncompiled source code file
                newerFiles=false;
                for i=1:length(this.commentFiles)
                    commentFileInfo=dir(this.commentFiles{i});
                    thisFileInfo=dir([mfilename('fullpath') '.m']);
                    if lackMetaInfo ...%saved is OLDER
                            || saveFileInfo.datenum < commentFileInfo.datenum ...
                            || saveFileInfo.datenum < thisFileInfo.datenum
                        newerFiles=true;
                        break;
                    end
                end
                if newerFiles
                    this.setAllMetaInfo;
                   this.save;
                elseif ~isempty(this.argFile)
                    if ~strcmp(this.argFile, this.commentFiles{1})
                        argFileInfo=dir(this.argFile);
                        if ~isempty(argFileInfo)
                            if saveFileInfo.datenum<argFileInfo.datenum
                                newerFiles=true;
                                this.setAllMetaInfo;
                                this.save;
                            end
                        end
                    end
                end
            else
                newerFiles=false; %must read mat if deployed
            end
            if ~newerFiles
                this.commented=true;
                this.setAllMetaInfo;
                try
                    load(saveFile, 'theMap');
                    this.map=theMap;
                    gotLoaded=true;
                catch 
                end
            end
        end
        
        function setAllMetaInfo(this)
            if ~this.isMetaSet && ~isempty(this.fncTypify)
                this.initMap;
                try
                    feval(this.fncTypify, this);
                    if Args.WARN_TYPE
                        this.warnUnknowns;
                    end
                catch ex
                    ex.getReport
                end
                this.isMetaSet=true;
                this.expandHomeSymbols;
            end
        end
        
        function expandHomeSymbols(this)
            keys=this.map.keys;
            N=length(keys);
            for i=1:N
                key=keys{i};
                if endsWith(key, '.meta')
                    meta=this.map.get(key);
                    if Args.IsFileSystemType(meta.type)
                        value=getfield(this.fields, meta.name);
                        if ischar(value) && startsWith(value, '~')
                            this.fields=setfield(this.fields, meta.name,...
                                File.ExpandHomeSymbol(value));
                        end
                    end
                end
            end
        end
        
        function unknowns=warnUnknowns(this)
            sb=java.lang.StringBuilder;
            unknowns=0;
            keys=this.map.keys;
            N=length(keys);
            for i=1:N
                key=keys{i};
                if endsWith(key, '.meta')
                    meta=this.map.get(key);
                    if strcmpi(meta.type, 'unknown')
                        unknowns=unknowns+1;
                        
                        sb.append(keys{i});
                        sb.append(',');
                    end
                end
            end
            if unknowns>0
                fprintf('%d unknown args:  %s\n', unknowns, char(sb.toString));
                warning('%d arguments of unknown type', unknowns);
            end
        end

        function ok=save(this)
            ok=false;
            saveFile=this.saveFile;
            if isempty(saveFile)
                return;
            end
            this.readComments;
            ok=true;
            theMap=this.map;
            save(saveFile, 'theMap');
        end
        
        function readComments(this)
            if ~this.commented
                for i=1:length(this.commentFiles)
                    Args.ReadComments(this.commentFiles{i}, this.map);
                end
                this.commented=true;
            end
        end
        
        function help=getHelp(this, arg, popUp, javaWindow)
            if nargin<4
                javaWindow=[];
                if nargin<3
                    popUp=true;
                end
            end
            this.readComments;
            meta=this.map.get([arg '.meta']);
            if isempty(meta.help_arg)
                help_arg=arg;
            else
                help_arg=meta.help_arg;
            end
            help=this.map.get([help_arg '.help']);
            if popUp
                if isempty(help)
                    msg(struct('msg', ['No help for "' arg '"'],...
                        'javaWindow', javaWindow), 9, 'east+', ...
                        [arg ' help...']);
                else
                    jtp=javax.swing.JTextPane;
                    jtp.setContentType("text/html");
                    jtp.setEditable(false);
                    jtp.setText(Html.Wrap(help));
                    jp=Gui.Panel;
                    jp.add(Gui.Scroll(jtp, 340, 250, this.app));
                    links=this.map.get([help_arg '.links']);
                    if ~isempty(links)
                        hjEditbox = handle(jtp,'CallbackProperties');
                        set(hjEditbox,'HyperlinkUpdateCallback',@(s,e)hyper(e));                        
                        cmb=Gui.Combo( links, 0,'','',@(h,e)link());
                        cmb.setPrototypeDisplayValue('not too wide a value')
                        pnl=Gui.SetTitledBorder([num2str(length(links)) ...
                            ' link(s) to lookup...']);
                        pnl.add(cmb);
                        
                        msg(struct('msg', jp, 'javaWindow', javaWindow), ...
                            9, 'east+', [arg ' help...'],...
                            'facs.gif', [], false, pnl);
                    else
                        msg(struct('msg', jp, 'javaWindow', javaWindow), ...
                            9, 'east+', [arg ' help...']);
                    end
                end
            end
            function link
                web(cmb.getSelectedItem, '-browser');
            end
            
            function hyper(eventData)
                description = char(eventData.getDescription); % URL stri
                et=char(eventData.getEventType);
                switch char(et)
                    case char(eventData.getEventType.ENTERED)
                        disp('link hover enter');
                    case char(eventData.getEventType.EXITED)
                        disp('link hover exit');
                    case char(eventData.getEventType.ACTIVATED)
                        web(description, '-browser');
                end
            end
        end
        
        function askUser(this, arg)
        end
        
        
        function this=Args(p, varargin)
            this.p=p;
            parse(p,varargin{:});
            this.fields=p.Results;
            this.argued=SortedStringSet.New(p);
        end
        
        function setPositionalArgs(this, varargin)
            this.positionalArgs=varargin;
        end
        
        function [varArgIn, html, cmd]=getVarArgIn(this, htmlLimit)
            N1=length(this.positionalArgs);
            varArgIn={};
            for i=1:N1
                varArgIn{end+1}=getfield(this.fields, this.positionalArgs{i});
            end
            N2=this.argued.size;
            strings=this.argued.strings;
            for i=1:N2
                arg=strings{i};
                if ~StringArray.Contains(this.positionalArgs, arg)
                    varArgIn{end+1}=arg;
                    varArgIn{end+1}=getfield(this.fields, arg);
                end                
            end
            if nargout>1
                if N1==0
                    html='<center><i>All default arguments...</i></center>';
                    sb=java.lang.StringBuilder;
                else
                    if nargin<2
                        htmlLimit=intmax;
                    end
                    sb=java.lang.StringBuilder('<table border="1">');
                    for i=1:N1
                        sb.append('<tr><td colspan="2">');
                        sb.append(String.toString(varArgIn{i}));
                        sb.append('</td></tr>');
                    end
                    N2=length(varArgIn);
                    nArgs=N1+1;
                    for i=N1+1:2:N2
                        sb.append('<tr><td>');
                        sb.append(varArgIn{i});
                        sb.append('</td><td>');
                        sb.append(String.toString(varArgIn{i+1}));
                        sb.append('</td></tr>');
                        if nArgs==htmlLimit
                            sb.append('<tr><td colspan="2"><b><i>');
                            sb.append(num2str(htmlLimit-N2));
                            sb.append(' more </i></b></td></tr>');
                            break;
                        end
                        nArgs=nArgs+1;
                    end
                    sb.append('</table>');
                    html=char(sb.toString);
                end
                if nargout>2
                    sb.setLength(0);
                    sb.append(this.commandPreamble);
                    sb.append('(');
                    for i=1:N1
                        sb.append(String.toString(varArgIn{i},false,',',true));
                        sb.append(',');
                    end
                    sb.append(this.commandVarArgIn);
                    
                    N2=length(varArgIn);
                    nArgs=N1+1;
                    for i=N1+1:2:N2
                        sb.append('''');
                        sb.append(varArgIn{i});
                        sb.append(''',');
                        sb.append(String.toString(varArgIn{i+1}, ...
                            false,',', true));
                        if i<N2-1
                            sb.append(',');
                        end
                        nArgs=nArgs+1;
                    end
                    sb.append(')');
                    cmd=char(sb.toString);
                end
            end
        end
        
        function varArgIn=parseStr2NumOrLogical(this, varArgIn)
            varArgIn=Args.Str2NumOrLogical(this.fields, varArgIn);
        end
        
        function varArgIn=extractFromThat(this, thatArgFields, onlyArgued)
            if nargin<3||~onlyArgued
                varArgIn=Args.ExtractFromThat(this.fields, thatArgFields);
            else
                varArgIn=Args.ExtractFromThat(this.fields, thatArgFields, ...
                    this.argued.strings);
            end
        end

        function varArgIn=extractFromThis(this, thatArgFields, onlyArgued)
            if nargin<3||~onlyArgued
                varArgIn=Args.ExtractFromThis(this.fields, thatArgFields);
            else
                varArgIn=Args.ExtractFromThis(this.fields, thatArgFields, ...
                    this.argued.strings);
            end
        end

        function update(this, arg, value)
            this.fields=setfield(this.fields, arg, value);
            this.argued.add(arg);
        end
        
        function remove(this, arg)
            this.fields=setfield(this.fields, arg, []);
            this.argued.remove(arg);
        end
        
        function fldr=getFolder(this, arg)
            cur=getfield(this.fields, arg);
            if isempty(cur)
                cur=File.Documents;
            end
            fldr=File.GetDir(cur,  [this.property_prefix '.' arg],...
                cur, ['Select ' arg ' folder'], ...
                this.props);
            if ~isempty(fldr)
                this.update(arg, fldr);
            end
        end
        
        
        function file=getFileRead(this, arg, ext)
            meta=this.map.get([arg '.meta']);
            cur=getfield(this.fields, arg);
            if nargin<3
                if strcmpi('csv_readable', meta.type)
                    ext='.csv';
                elseif isempty(cur)
                    if isempty(meta.file_ext)
                        ext='*';
                    else
                        ext=['.' meta.file_ext];
                    end
                else
                    [~,~,ext]=fileparts(cur);
                end
            end
            if ~startsWith(ext, '.')
                ext=['.' ext];
            end
            if isempty(cur)
                fldr='';
            else
                fldr=fileparts(cur);
            end
            file=uiGetFile(['*' ext], fldr, ['Open ' arg ' file'], ...
                this.props, [this.property_prefix '.' arg]);
            if isempty(file)
                prior=getfield(this.fields, arg);
                if ~isempty(prior)
                    [~, prior]=fileparts(prior);
                end
                if ~isempty(prior) && ...
                        askYesOrNo(struct('msg', ...
                        'Remove file?', 'javaWindow',...
                        this.javaWindow), 'No file?', ...
                        'south east+')
                    this.remove(arg);
                end
            else
                this.update(arg, file);
            end
        end

        function file=getFileWrite(this, arg)
            meta=this.map.get([arg  '.meta']);
            cur=getfield(this.fields, arg);
            if ~isempty(cur)
                [fldr, f, ext]=fileparts(cur);
                if isempty(f)
                    f='newFile';
                end
                if isempty(ext)
                    ext=['.' meta.file_ext];
                end
                file=[f ext];
            else
                fldr=[];
                if strcmpi('csv_writable', meta.type)
                    file=[arg '.csv'];
                elseif ~isempty(meta.file_ext)
                    file=['someFile.' meta.file_ext];
                else
                    file='';
                end
            end
            file=uiPutFile(fldr, file, this.props, ...
                [this.property_prefix, arg], ['Create/overwrite ' arg ' file']);
            if isempty(file)
                prior=getfield(this.fields, arg);
                if ~isempty(prior)
                    [~, prior]=fileparts(prior);
                end
                if ~isempty(prior) && ...
                        askYesOrNo(struct('msg', ...
                        'Remove file?', 'javaWindow',...
                        this.javaWindow), 'No file?', ...
                        'south east+')
                    this.remove(arg);
                end
            else
                this.update( arg, file);
            end
        end

        function varArgs=getUnmatchedVarArgs(this)
            varArgs=SuhStruct.ToNamedValueCell(this.p.Unmatched);
        end
        
        function this=merge(this, inParsers, varargin)
            N=length(inParsers);
            for i=1:N
                inParsers{i}.KeepUnmatched=true;
                that=Args(inParsers{i}, varargin{:});
                this.fields=SuhStruct.AddNewValues(...
                    this.fields, that.fields);
                this.argued.addAll(that.argued);
            end
        end
    end
    
    methods(Static)
        function [args, argued, unmatchedArgs, this]...
                =NewKeepUnmatched(p, varargin)
            p.KeepUnmatched=true;
            this=Args(p, varargin{:});
            args=this.p.Results;
            argued=this.argued;
            unmatchedArgs=this.p.Unmatched;
            if isempty(fieldnames(unmatchedArgs))
                unmatchedArgs=[];
            end
        end

        function [args, argued, this]=New(p, varargin)
            this=Args(p, varargin{:});
            args=this.p.Results;
            argued=this.argued;
        end
        
        function argsObj=NewMerger(inputParsers, varargin)
            N=length(inputParsers);
            if N==0 || ~iscell(inputParsers) ...
                    || ~isa(inputParsers{1}, 'inputParser')
                error('First arg must be cell with inputParsers');
            end
            [~, ~, ~, argsObj]=Args.NewKeepUnmatched(...
                inputParsers{1}, varargin{:});
            
            if N>1
                argsObj.merge(inputParsers(2:end), varargin{:});
            end
        end

        function argument=Get(name, varargin)
            argument=[];
            N=length(varargin);
            for i=1:2:N
                if strcmpi(name, varargin{i})
                    argument=varargin{i+1};
                    break;
                end
            end
        end
                

        function argument=GetStartsWith(name, defaultIfNotFound, varArgIn)
            N=length(varArgIn);
            name=lower(name);
            for i=1:2:N
                if startsWith(name, lower(varArgIn{i}))
                    argument=varArgIn{i+1};
                    return;
                end
            end
            argument=defaultIfNotFound;
        end
        
        function argument=GetIfNotPairs(name, varargin)
            argument=[];
            N=length(varargin);
            name=lower(name);
            for i=1:N
                if ischar(varargin{i}) ...
                        && startsWith(name, lower(varargin{i}))
                    argument=varargin{i+1};
                    break;
                end
            end
        end
        
        function [argument, name]...
                =StartsWith(name, varargin)
            N=length(varargin);
            name=lower(name);
            for i=1:2:N
                if startsWith(name, lower(varargin{i}))
                    name=varargin{i};
                    argument=varargin{i+1};
                    return;
                end
            end
            argument=[];
        end
        
        function ok=Contains(name, varargin)
            value=Args.StartsWith(name, varargin{:});
            ok=~isempty(value);
        end
        
        function varargin=Set(name, value, varargin)
            N=length(varargin);
            for i=1:2:N
                if strcmpi(name, varargin{i})
                    varargin{i+1}=value;
                    return;
                end
            end
            varargin{end+1}=name;
            varargin{end+1}=value;
        end

        function varArgIn=SetDefaults(varArgIn, varargin)
            N1=length(varargin);
            N2=length(varArgIn);
            done=false(1,N1);
            for i=1:2:N1
                a=lower(varargin{i});
                for j=1:2:N2
                    if startsWith(a, lower(varArgIn{j}))
                        done(i)=true;
                        break;
                    end
                end
            end
            for i=1:2:N1
                if ~done(i)
                    varArgIn{end+1}=varargin{i};
                    varArgIn{end+1}=varargin{i+1};
                end
            end
        end
        
        function ok=IsInteger(num, name, low, high)
            ok=false;
            if ~isnumeric(num)
                disp(num);
                warning('%s must be an integer ...', name);
                return;
            end
            if floor(num)~=num
                warning('%s=%d is not an integer ', name, num)
                return;
            end
            if nargin>2 && num<low
                warning('%s=%d is less than %d', name, num, low);
                return;
            end
            if nargin>3 && num>high
                warning('%s=%d is greater than %d', name, num, high);
                return;
            end
            ok=true;
        end
        
        function ok=IsColumnRanges(num, name)
            if nargin<2
                name='column_ranges';
            end
            ok=false;
            if ~isnumeric(num)
                disp(num);
                warning('%s must be a number ...', name);
                return;
            end
            N=length(num);
            if mod(N,3)~=0
                warning('%s must be triplets of # max min', name);
                return;
            end
            ok=true;
            C=N/3;
            for i=0:C-1
                idx=i*3+1;
                if num(idx)<1
                    warning('%s triplet # %d has # < 1', name, i, num(idx));
                    ok=false;
                end
            end
        end
        
        function ok=IsNumber(num, name, low, high)
            ok=false;
            if ~isnumeric(num)
                disp(num);
                warning('%s must be a number ...', name);
                return;
            end

            if nargin>2 && num<low
                warning('%s=%d is less than %d', name, num, low);
                return;
            end
            if nargin>3 && num>high
                warning('%s=%d is greater than %d', name, num, high);
                return;
            end
            ok=true;
        end
        
        function ok=IsStrings(x)
            ok=false;
            if iscell(x)
                N=length(x);
                if N>0
                    for i=1:N
                        if ~ischar(x{i})
                            ok=false;
                            return;
                        end
                    end
                    ok=true;
                end
            end
        end
    
        function varArgOut=Str2NumOrLogical(args, ...
                varArgIn, ignoreIfNotConvertible)
            sa=StringArray(fieldnames(args));
            N=length(varArgIn);
            varArgOut=cell(1, N);
            for i=1:2:N
                name=varArgIn{i};
                arg=varArgIn{i+1};
                varArgOut{i}=name;
                varArgOut{i+1}=arg;
                if ischar(arg)
                    [ai, argName]=...
                        sa.findArgumentName(name);
                    if ai==0
                        continue;
                    end
                    fieldValue=getfield(args, argName);
                    
                    if islogical(fieldValue)
                        seemsLogical=strcmpi(arg, 'true') ...
                                    || strcmpi(arg, 'yes')...
                                    || strcmpi(arg, 'false')...
                                    || strcmpi(arg, 'no');
                        if seemsLogical
                            if nargin>2 && ...
                                    StringArray.IndexOfIgnoreCase(...
                                    ignoreIfNotConvertible, name)>0
                                varArgOut{i+1}=...
                                    strcmpi(arg, 'true')...
                                    || strcmpi(arg, 'yes');
                            else
                                varArgOut{i+1}=...
                                    strcmpi(arg, 'true')...
                                    || strcmpi(arg, 'yes');
                            end
                        end
                    elseif isnumeric(fieldValue) && ~isempty(fieldValue)
                        num=str2double(arg);
                        if ~isnan(num)
                            varArgOut{i+1}=num;
                        else
                            if nargin>2 && ...
                                    StringArray.IndexOfIgnoreCase(...
                                    ignoreIfNotConvertible, name)>0
                                continue;
                            end
                            varArgOut{i+1}=arg;
                            if ~(strcmpi('end', arg)...%special case
                                    && strcmpi('label_column', name))
                                warning(['Arg "%s" value of "%s" '...
                                    'left alone\n...it is not number '...
                                    '(as expected)...'], name, arg)
                            end
                        end
                    end                    
                end
            end
        end
        
        function varOut=ExtractFromThis(thisArgFields, thatArgFields, argued)
            varOut={};
            if ~isempty(thatArgFields)
                if isa(thatArgFields, 'inputParser')
                    if isempty(fieldnames(thatArgFields.Results))
                        parse(thatArgFields);
                    end
                    thatArgFields=thatArgFields.Results;
                    
                end
                names=fieldnames(thatArgFields);
                N=length(names);
                for i=1:N
                    name=names{i};
                    if isfield(thisArgFields, name)
                        if nargin>2
                            if ~StringArray.Contains(argued, name)
                                continue;
                            end
                        end
                        varOut{end+1}=name;
                        varOut{end+1}=getfield(thisArgFields, name);
                    end
                end
            end
        end
        
        function varOut=ExtractFromThat(thisArgFields, thatArgFields, argued)
            varOut={};
            if ~isempty(thatArgFields)
                if isa(thatArgFields, 'inputParser')
                    if isempty(fieldnames(thatArgFields.Results))
                        parse(thatArgFields);
                    end
                    thatArgFields=thatArgFields.Results;
                    
                end
                names=fieldnames(thatArgFields);
                N=length(names);
                for i=1:N
                    name=names{i};
                    if isfield(thisArgFields, name)
                        if nargin>2
                            if ~StringArray.Contains(argued, name)
                                continue;
                            end
                        end
                        varOut{end+1}=name;
                        varOut{end+1}=getfield(thatArgFields, name);
                    end
                end
            end
        end
        
        function ok=IsVerbose(x)
            ok=any(validatestring(x, Args.VERBOSE_VALUES));
        end
        
        function ok=IsFolderOk(x)
            if ~ischar(x)
                ok=isempty(x);%ok to clear file
            else
                [ok, errMsg]=File.mkDir(File.ExpandHomeSymbol(x));
                if ~ok
                    msgError(Html.Wrap(errMsg, 200), 20, ...
                        'south east+', 'Folder problem...');
                end
            end
        end
        
        function ok=IsJobFolderOk(x)
            if ~ischar(x)
                ok=isempty(x);%ok to clear file
            else
                [~, x]=File.ParseWatchFolder(x);
                [ok, errMsg]=File.mkDir(x);
                if ~ok
                    msgError(Html.Wrap(errMsg, 200), 20, ...
                        'south east+', 'Folder problem...');
                end
            end
        end
        
        function ok=IsLabelColumn(x)
            ok=strcmpi(x, 'end') || (isnumeric(x) && (x(1)>0||length(x)>1));
        end
        
        function ok=IsDataOk(x)
            ok=false;
            if isnumeric(x)
                ok=true;
                return;
            elseif ischar(x)
                ok=Args.IsFileOk(x);
                return;
            end
            
        end
        
        function ok=IsFileOk(x, mustExist)
            if ~ischar(x)
                ok=isempty(x);%ok to clear file
            else
                x=File.ExpandHomeSymbol(x);
                if exist(x, 'dir')
                    ok=false;
                    msgError(['<html>This file is a folder' ...
                        Html.FileTree(x) '</html>'], 20, ...
                        'south east+', 'Folder problem...');
                else
                    ok=Args.IsFolderOk(fileparts(x));
                    if ok && nargin>1 && mustExist
                        if ~exist(x, 'file')
                            msgError(['<html>Can''t find the file ' ...
                                Html.FileTree(x) '</html>'], 20, ...
                                'south east+', 'File problem...');
                        end
                    end
                end
            end
        end
        
        function ok=IsLocateFig(x, name)
            if isempty(x)
                ok=true;
                return;
            end
            ok=false;
            if iscell(x)
                if length(x)>=2
                    if length(x)==2 || islogical(x{3}) % default is true
                        if ischar(x{2})
                            ok=Gui.IsFigure( x{1} );
                            if ~ok
                                if isa(x{1}, 'java.awt.Window')
                                    ok=true;
                                end
                            end
                        end
                    end
                end
            end
            if ~ok
                warning('%s be be 2 part cell ... like {myFigure, ''west''}', name)
            end
        end
        
        function [varArgIn, value]=RemoveArg(varArgIn, arg)
            N=length(varArgIn);
            arg=lower(arg);
            for i=1:2:N
                a=lower(varArgIn{i});
                if startsWith(arg, a)
                    value=varArgIn{i+1};
                    varArgIn(i+1)=[];
                    varArgIn(i)=[];
                    return;
                end
            end
            value=[];
        end
        
        function [command, args, statement, isGood]=...
                CommandLineSyntax(statement)
            if contains(statement, '"')
                error(['Use only single quotes in '...
                    ' statement and not double quotes\n\t'...
                    '%s'], statement)
            end
            codeExp='(\w+?)\( *(''[^'']+'')|([^,\)]+)';
            a=regexp(statement, codeExp, 'tokens');   
            isGood=true;
            if length(a)>1
                args=[a{1}{2} a{2:end}];
                N=length(args);
                for i=1:N
                    arg=strtrim(args{i});
                    if startsWith(arg, '''')
                        arg=arg(2:end-1);
                    end
                    args{i}=arg;
                    if ~isempty(regexp(arg, '[\), ''"\(]', 'once'))
                        isGood=false;
                    end
                end
            else
                if ~isempty(regexp(statement, '[\),''"\(]', 'once'))
                    error(['Sorry ..cannot parse this ', ...
                        'statement\n   %s'], statement);
                end
                cmdLineExp=' *([^ ;]+)';
                a=regexp(statement, cmdLineExp, 'tokens');
                args=[a{2:end}];
            end
            if strcmp(args{end}, ';')
                args(end)=[];
            end
            command=a{1}{1};
            if nargout>2
                sb=java.lang.StringBuilder(command);
                sb.append(' ');
                N=length(args);
                for i=1:N
                    sb.append(args{i});
                    sb.append(' ');
                end
                statement=char(sb.toString);
            end
        end
    end
    
    properties(Constant)
        WARN_TYPE=1;
        REGEX_COMMENT1='% *''([^'']*)'' *(.*)';
        REGEX_COMMENT2='% *(.*)';
        VERBOSE_VALUES={'graphic','text','none'};
        FILE_TYPES={'folder', 'file_readable', 'file_writable', 'csv_readable',...
                'csv_writable'};
        TYPES=['char', 'double', 'int', 'logical',  Args.FILE_TYPES];
            
    end
    
    methods(Static)
        function map=ReadComments(file, map)
            if isdeployed %deployed m files are not text parseable I think?
                return;
            end
            if nargin<2
                map=BasicMap;
            end
            fid=[];
            app=BasicMap.Global;
            try
                fid=fopen(file);
                if fid<0
                    msgError(['<html><b>Can''t open file</b><br>'...
                        Html.FileTree(file) '<hr></html>']);
                    return;
                end
                line = fgetl(fid);
                sb=java.lang.StringBuilder;
                empties=java.lang.StringBuilder;
                arg='';
                nameValueAnnounced=false;
                done=0;
                links={};
                margin=0;
                while ~isempty(line)
                    if isnumeric(line)
                        break;
                    end
                    toks=regexp(line, Args.REGEX_COMMENT1, 'tokens');
                    if isempty(toks)
                        toks=regexp(line, Args.REGEX_COMMENT2, 'tokens');
                        if isempty(toks)
                            if done>0
                                break;
                            end
                            line = fgetl(fid);
                            continue;
                        end
                    end
                    toks=toks{1};
                    
                    if length(toks)>1 && margin>0
                        li=String.IndexOf(line, '''');
                        if li-margin>2
                            toks={[toks{1} toks{2}]};
                        end
                    end
                    if length(toks)>1
                        if nameValueAnnounced
                            addArg;
                            sb.append(strtrim(toks{2}));
                            arg=toks{1};
                            empties.setLength(0);
                            if margin==0
                                margin=String.IndexOf(line, '''');
                            end
                        end
                    elseif ~isempty(arg)
                        ss=strtrim(toks{1});
                        if strcmpi(ss, 'authorship') ...
                                || strcmpi(ss, 'examples') ...
                                || strcmpi(ss, 'algorithm') ...
                                || strcmpi(ss, 'algorithms')
                            break;
                        end
                        lss=lower(ss);
                        if startsWith(lss, 'default')
                            ss=['<font color="#44AAFF"><b>' ss '</></font>'];
                        end
                        if ~isempty(ss)
                            sb.append(empties.toString);
                            sb.append('<br>');
                            if startsWith(ss, 'https://') ...
                                    || startsWith(ss, 'http://')
                                links{end+1}=ss;
                                sb.append('<a href="');
                                sb.append(ss);
                                sb.append('">');
                                sb.append(app.smallStart);
                                if length(ss)>58
                                    ss=[ss(1:58) '...'];
                                end
                                sb.append(ss);
                                sb.append(app.smallEnd);
                                sb.append(' (link ');
                                sb.append(int32(length(links)));
                                sb.append(')</a>');
                            else
                                sb.append(ss);
                            end
                            
                            empties.setLength(0);
                        else
                            empties.append('<br>');
                        end
                    elseif ~nameValueAnnounced
                        nameValueAnnounced=~isempty(regexpi(toks{1}, '^name *value$'));
                        if nameValueAnnounced
                            disp('ok');
                        end
                    end
                    line = fgetl(fid);
                end
                addArg;
                fclose(fid);
                if isempty(arg)
                    msgError(['<html><b>ZERO arguments found in</b><br>'...
                        Html.FileTree(file) '<hr>Expecting '...
                        'an argument name to be on <br>a commented line'...
                        'with single quotes like<br><b>% ''name'''...
                        '&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;'...
                        '</b><i>description of argument<br><br></html>']);
                end
            catch ex
                if ~isempty(fid)
                    try
                        fclose(fid);
                    catch ex2
                        ex2.getReport
                    end
                    ex.getReport;
                    rethrow(ex);
                end
            end
            
            function addArg
                if ~isempty(arg)
                    if ~map.containsKey([arg '.meta'])
                        warning('Unrecognized argument %s', arg);
                    else
                        map.set([arg '.help'], char(sb.toString));
                        if ~isempty(links)
                            map.set([arg '.links'], links);
                        end
                        done=done+1;
                    end
                    sb.setLength(0);
                    links={};
                end
            end
        end
        function ok=IsFileSystemType(type)
            ok=StringArray.Contains(Args.FILE_TYPES, type);
        end
         
        function txt=ToStringWithNewLines(varargin)
            N=length(varargin);
            sb=java.lang.StringBuilder(N*15);
            for i=1:2:N
                sb.append(varargin{i});
                sb.append('=');
                value=varargin{i+1};
                if ischar(value)
                sb.append(value);
                elseif islogical(value)
                    if value
                        sb.append('true');
                    else
                        sb.append('false');
                    end
                elseif isnumeric(value)
                    if floor(value)==value
                        sb.append(int64(value));
                    else
                        sb.append(value);
                    end
                else
                    sb.append(String.ToString(value, ...
                        true, '=', false, '|'));
                end
                sb.append(newline);
            end
            txt=char(sb.toString);
        end
    end
    
    methods(Static, Access=private)
        function p=DefineArgs()
            p = inputParser;
            addParameter(p,'type', 'double',  ...
                @(x)any(validatestring(x,Args.TYPES)));
            addParameter(p,'tip', ...
                'Provide a value, click ? for more details',  @ischar);
            addParameter(p, 'callback', [], @(x)isa(x, 'function_handle'));
            addParameter(p, 'valid_values', {}, @iscell);
            addParameter(p, 'high', [], @isnumeric);
            addParameter(p, 'low', [], @isnumeric);
            addParameter(p, 'label', [], @ischar);
            addParameter(p, 'text_columns', 5, @isnumeric);
            addParameter(p, 'editor_columns', 1, ...
                @(x)isnumeric(x) && x>0&&x<5);
            addParameter(p, 'editor_rows', 1, ...
                @(x)isnumeric(x) && x>0&&x<5);
            addParameter(p, 'file_ext', [], @ischar);
            addParameter(p, 'help_arg', [], @ischar);
            addParameter(p, 'default_if_empty', []);
            addParameter(p, 'command_only', false, @islogical);
            addParameter(p, 'outsider', false, @islogical);            
            addParameter(p, 'is_integer', false, @islogical);
        end
    end
    
end