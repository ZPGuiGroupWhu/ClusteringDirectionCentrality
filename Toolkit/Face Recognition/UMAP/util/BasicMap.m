%   AUTHORSHIP
%   Primary Developer: Stephen Meehan <swmeehan@stanford.edu> 
%   Math Lead & Secondary Developer:  Connor Meehan <connor.gw.meehan@gmail.com>
%   Provided by the Herzenberg Lab at Stanford University 
%   License: BSD 3 clause
%

% this wrapper around MATLAB internal map is meant for 
% polymorphic function signature compatability with other
% classdef and Java class in CytoGenie AutoGate
classdef BasicMap < Map
    properties
        pu;
        parentCmpForPopup;
        needToAskForUmap=true;
        noDbscan=false;
        urlMap;
        cbn;
        sw=SuhWindow;
        currentJavaWindow=[];
        python=struct();
    end
    
    properties
        appVersion;
        appName;
        exeFile;
        versionFile;
        remoteFolder;
        remoteSourceCode;
    end
    
    properties(SetAccess=private)
        appFolder;
        contentFolder;
        toolBarSize=0;
        toolBarFactor=0;
        highDef=false;
        supStart='<sup>';
        supEnd='</sup>';
        subStart='<sub>';
        subEnd='</sub>';
        smallStart='<small>';
        smallEnd='</small>';
        h3Start='<h3>';
        h3End='</h3>';
        h2Start='<h2>';
        h2End='</h2>';
        h1Start='<h1>';
        h1End='</h1>';
        whereMsgOrQuestion='center';
        ttod;
        physicalCores;
        logicalCores;
        assignedCores;
        emptySet;
        emptyList;
        countUpdateCheck=0;
    end
    
    methods(Static)
        function this=Global(closeIfTrueOrMap)
            persistent singleton;
            if nargin>0 && islogical(closeIfTrueOrMap) && closeIfTrueOrMap
                clear singleton;
                singleton=[];
                disp('Resetting global BasicMap');
                this=[];
            else
                if nargin==1
                    try
                        priorMap=closeIfTrueOrMap;
                        %test method compatibility
                        %priorMap.size
                        prop='IsBasicMap';
                        if ~priorMap.has(prop)
                            priorMap.set(prop, 'false');
                            priorMap.get(prop, 'true');
                            priorMap.remove(prop);
                        else
                            priorMap.get(prop, 'true')
                        end
                        singleton=priorMap;
                        this=singleton;
                        return;
                    catch ex
                        ex.getReport
                    end
                end
                if isempty(singleton) 
                    singleton=BasicMap;
                    singleton.highDef=Gui.hasPcHighDefinitionAProblem(2000, 2500, false);
                    BasicMap.SetHighDef(singleton, singleton.highDef);
                end     
                this=singleton;
            end
        end
        
        function path=Path
            path=BasicMap.Global.contentFolder;
        end
        
        function obj=SetHighDef(obj, hasHighDef)
            factor=0;
            NORMAL_FONT_SIZE=12;
            SMALL_FONT_SIZE=2;
            H3_FONT_SIZE=3;
            H2_FONT_SIZE=3.5;
            H1_FONT_SIZE=4;
            if hasHighDef
                obj.highDef=true;
                factor=javax.swing.UIManager.getFont('Label.font').getSize...
                    /NORMAL_FONT_SIZE;
            else
                if ismac
                    %factor=1.6;
                end
            end
            if factor>0
                obj.toolBarFactor=factor;
                obj.toolBarSize=floor(16*factor);
                smallSize=floor(SMALL_FONT_SIZE*factor);
                if ispc
                    smallSize=smallSize+1;
                end
                obj.smallStart=['<font size="' num2str(smallSize) '">'];
                obj.smallEnd='</font>';
                obj.subStart=obj.smallStart;
                obj.supStart=obj.smallStart;
                obj.subEnd=obj.smallEnd;
                obj.supEnd=obj.smallEnd;
                h1Size=floor(H1_FONT_SIZE *factor);
                if ispc
                    h1Size=h1Size+1;
                end
                obj.h1Start=['<center><font size="' num2str(h1Size) ...
                    '" color="blue"><b>'];
                obj.h1End='</b></font></center><br>';

                h2Size=floor(H2_FONT_SIZE *factor);
                if ispc
                    h2Size=h2Size+1;
                end
                obj.h2Start=['<center><font size="' num2str(h2Size) ...
                    '" color="blue"><b>'];
                obj.h2End='</b></font></center><br>';

                h3Size=floor(H3_FONT_SIZE *factor);
                if ispc
                    h3Size=h3Size+1;
                end
                obj.h3Start='<h1>';
                obj.h3End='</h1>';
            else
                obj.toolBarSize=0;
                obj.toolBarFactor=0;
                obj.highDef=false;
        
                obj.smallStart='<small>';
                obj.smallEnd='</small>';
                obj.h3Start='<h3>';
                obj.h3End='</h3>';
                obj.h2Start='<h2>';
                obj.h2End='</h2>';
                obj.h1Start='<h1>';
                obj.h1End='</h1>';

            end
        end
        
        function nums=GetNumbers(props, name, defaultNumbers)
            if nargin<3
                defaultNumbers=[];
            elseif ~isempty(defaultNumbers) && isnumeric(defaultNumbers)
                defaultNumbers=num2str(defaultNumbers);
            end
            nums=props.get(name, defaultNumbers);
            if ~isempty(nums)
                nums=str2num(nums);
            else
                nums=[];
            end
        end
        
    end
    
    methods
        function this=BasicMap(keysOrFileName, values)
            if nargin<2
                values={};
                if nargin<1
                    keysOrFileName=[];
                end
            end
            this=this@Map(keysOrFileName, values);
            this.contentFolder=fileparts(mfilename('fullpath'));
            this.appFolder=fullfile(File.Home, '.run_umap');
            File.mkDir(this.appFolder);
            this.urlMap=Map;
            [this.physicalCores, this.logicalCores, this.assignedCores]...
                =MatBasics.DetectCpuCores;
            this.emptySet=java.util.Collections.unmodifiableSet(...
                java.util.HashSet);
            this.emptyList=java.util.Collections.unmodifiableList(...
                java.util.ArrayList);
            
            %'https://1drv.ms/u/s!AkbNI8Wap-7_jNJYg4RNDTKR4mkYOg?e=pfwWfO'
        end
        
        %function signature compatible with CytoGate.reportProblem
        function retry=reportProblem(~, exception, ~)
            retry=false;
            Gui.MsgException(exception);
        end
        
        function [name, found]=getMatchName(this, name, showEppImg, b1, b2)
            if nargin<4
                if this.highDef
                    b1='<b>';
                    b2='</b>';
                else
                    b1='<sup>';
                    b2='</sup>';
                end
                if nargin<3
                    if nargin<2
                        showEppImg=true;
                    end
                end
            end
            idx=strfind(name, ',\bf');
            if ~isempty(idx)
                sIdx=4;
                idx=idx(1);
            else
                idx=strfind(name, '\bf');
                sIdx=3;
            end
            if ~isempty(idx)
                matchName=strtrim(name(idx(1)+sIdx:end));
                eppName=name(1:idx(1)-1);
                if showEppImg
                    eppName =[ eppName ' ' this.eppImg];
                end
                if idx==1
                    name=[matchName eppName];
                else
                    name=[matchName ' ' b1 eppName b2];
                end
                found=true;
            else
                found=false;
            end
        end
        
        function cbn=colorsByName(this)
            if isempty(this.cbn)
                this.cbn=ColorsByName;
            end
            cbn=this.cbn;
        end
        
        function showToolTip(this, cmp, txt, xOffset, yOffset, ...
                dismissSecs, bottomCmp, hideCancelButton, startShowingSecs)
            if nargin<9
                startShowingSecs=0;
                if nargin<8
                    hideCancelButton=true;
                    if nargin<7
                        bottomCmp=[];
                        if nargin<6
                            dismissSecs=0;
                        end
                    end
                end
            end
            if isempty(cmp)
                return;
            end
            if isempty(this.ttod)
                this.ttod=edu.stanford.facs.swing.ToolTipOnDemand.getSingleton;
                pp=this.contentFolder;
                this.ttod.setCancel(fullfile(pp, 'close.gif'));
            end
            if dismissSecs>0
                old=javaMethodEDT('getDismissDelay', this.ttod);
                javaMethodEDT('setDismissDelay', this.ttod, dismissSecs*1000);
                tmr=timer;
                tmr.StartDelay=dismissSecs+1;
                tmr.TimerFcn=@(h,e)javaMethodEDT('setDismissDelay', this.ttod, old);
                start(tmr);
            end
            numArgs=nargin;
            if startShowingSecs==0
                show(numArgs);
            else
                tmr=timer;
                tmr.StartDelay=startShowingSecs;
                tmr.TimerFcn=@(h,e)show(numArgs);
                start(tmr);
            end
            function show(nArgs)
                javaMethodEDT('close', this.ttod);
                if nArgs>2 && isjava(txt)
                    bottomCmp=txt;
                    txt='';
                    if isempty(cmp.getToolTipText)
                        cmp.setToolTipText('');
                    end
                end
                if nArgs>3
                    if strcmpi(xOffset, 'center')
                        xOffset=cmp.getWidth/2;
                        if isjava(bottomCmp)
                            d=bottomCmp.getPreferredSize;
                            xOffset=xOffset-(d.width/2);
                        end
                    end
                else
                    xOffset=0;
                end
                if nArgs>=5
                    if strcmpi(yOffset, 'center')
                        yOffset=cmp.getHeight/2;
                        if isjava(bottomCmp)
                            d=bottomCmp.getPreferredSize;
                            yOffset=yOffset-(d.height/2);
                        end
                    end
                    if ~isempty(txt)
                        javaMethodEDT('showLater', this.ttod, cmp, false, ...
                            bottomCmp, xOffset, yOffset, hideCancelButton, txt);
                    else
                        javaMethodEDT('showLater', this.ttod, cmp, false,...
                            bottomCmp, xOffset, yOffset);
                    end
                elseif nArgs>=3
                    if isempty(txt) && isjava(bottomCmp)
                        javaMethodEDT('showLater', this.ttod, cmp, ...
                            false, bottomCmp, xOffset, 0);
                    else
                        javaMethodEDT('showLater', this.ttod, cmp, txt);
                    end
                else
                    javaMethodEDT('showLater', this.ttod, cmp);
                end
            end
        end
        
        function closeToolTip(this)
            if ~isempty(this.ttod)
                javaMethodEDT('close', this.ttod);
            end
        end
        
        function v=getMatLabVersion(this)
            [~, v]=MatBasics.VersionAbbreviation;
        end
        
        function v=VERSION(this) %upper case for CytoGate compatibility
            v=this.getVersion;
        end
        
        function rememberUpdateCheck(this)
            this.countUpdateCheck=this.countUpdateCheck+1;
        end
        
        function setAppVersion(this, autoGateV, umapV, eppV)
            matLabVersion=this.getMatLabVersion;
            if ~isempty(autoGateV)
                %AutoGate code is present
                this.appVersion=str2num(autoGateV);
                this.appName='AutoGate';
                [~, this.exeFile, this.versionFile]=CgSysAdmin.AppName;
                this.remoteFolder='GetDown2/domains/FACS';
            else
                this.remoteFolder='GetDown2/domains/SUH';
                this.remoteSourceCode='run_umap/umapAndEpp.zip';
                if ~isempty(eppV) && ~isempty(umapV)
                    this.appVersion=str2num(ArgumentClinic.VERSION);
                    this.appName='suh_pipelines';
                elseif isempty(eppV)
                    this.appVersion=str2num(umapV);
                    this.appName='run_umap';
                else
                    this.appName='run_epp';
                    this.appVersion=str2num(eppV);
                end
                ext='.tar';
                if ismac
                    computer='mac';
                elseif isunix
                    computer='unix';
                else
                    computer='pc';
                    ext='.exe';
                end
                this.exeFile=[this.appName matLabVersion ext];
                this.versionFile=[this.appName matLabVersion ...
                    '_' computer '.txt'];
            end
        end
        
        function detectAppVersion(this)
            %logic to determine the application containing
            %util/BasicMap.,m
            autoGateV=[];umapV=[];eppV=[];
            try
                autoGateV=CytoGate.VERSION;
            catch % will fail if AutoGate app not present
            end
            try
                umapV=UMAP.VERSION;
            catch % will fail if run_umap not present
            end
            try
                eppV=SuhEpp.VERSION;
            catch % will fail if run_umap not present
            end
            this.setAppVersion(autoGateV, umapV, eppV);
        end
        
        function [matLabVersion, appVersion, name, exeFile, ...
                versionFile, remoteFolder, remoteSourceCode]...
                =getAppDetails(this)
            if isempty(this.appVersion)
                this.detectAppVersion;
            end
            matLabVersion=this.getMatLabVersion;
            appVersion=this.appVersion;
            name=this.appName;
            exeFile=this.exeFile;
            versionFile=this.versionFile;
            remoteFolder=this.remoteFolder;
            remoteSourceCode=this.remoteSourceCode;
        end
        
        function setHelp(this, cue)
            if ~isequal(this, BasicMap.Global)
                try
                    BasicMap.Global.setHelp(cue);
                catch
                end
            else
                warning('App has no help system implementation yet...');
            end
        end
    end
end