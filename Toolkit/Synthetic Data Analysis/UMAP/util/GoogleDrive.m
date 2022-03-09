%   AUTHORSHIP
%   Primary Developer: Stephen Meehan <swmeehan@stanford.edu> 
%   Provided by the Herzenberg Lab at Stanford University 
%   License: BSD 3 clause
%
classdef GoogleDrive < handle
    properties(Constant)
        URL_FILE_PREFIX="https://drive.google.com/file/d";
        URL_FOLDER_PREFIX="https://drive.google.com/drive/folders";
    end
    
    properties
        localFolder='';
        pathKey='';
        dirProps;
        originalFileName;
        fileName;
        linkMap;
        drive;
    end
    
    methods
        function this=GoogleDrive(folderOnGoogleDrive, dirProperties)
            this.drive=File.GoogleDrive;
            if ~exist(this.drive, 'dir')
                error('Folder does not exist: %s', this.drive);
            end
            if nargin<2
                dirProperties='dir.properties';
            end
            this.setFolder(folderOnGoogleDrive);
            this.linkMap=TreeMapOfMany;
            this.dirProps=JavaProperties(fullfile(...
                this.drive, dirProperties));
            this.originalFileName=this.dirProps.fileName;
            this.fileName=this.originalFileName;
            this.buildLinkMap;
        end
        
        function [fileList, dirSize, actualSize]...
                =getFileAndSizes(this, link)
            if nargin<2
                link=clipboard('paste');
                if ~startsWith(link, ...
                        GoogleDrive.URL_FILE_PREFIX)...
                        && ~startsWith(link,...
                        GoogleDrive.URL_FOLDER_PREFIX)
                    warning('clipboard does not contain link');
                    fileList=[];
                    dirSize=[]; 
                    actualSize=[];
                    msgError('Clipboard does not contain drive link', 'modal');
                    return;
                end
            end
            [files, fileList]=this.linkMap.get(link);
            if ~isempty(files)
                if fileList.size>1
                    warning(...
                        'This link associates with %d files: %s',...
                        fileList.size, char(files));
                end
                file1=char(fileList.get(0));
                [link2, dirSize, actualSize]=...
                    this.getLinkAndSizes(file1);
                if ~isequal(link, link2)
                    warning(['Conflict ... dirProps link '...
                        'for %s is INSTEAD:  %s'],...
                        link, link2);
                end
            else
                dirSize=[];
                actualSize=[];
                disp(['No directory entry uses ' link]);
            end
        end
        
        function [link, dirSize, localSize]...
                =getLinkAndSizes(this, key)
            link=[]; dirSize=[];localSize=[];
            if this.dirProps.containsKey(key)
                [link, dirSize]=GoogleDrive.Parse(this.dirProps.get(key));
            	if isempty(link)
                    warning('Directory stores %s without correctly formatted link',key);
                end
            end
            d=dir( fullfile(File.GoogleDrive, key));
            if ~isempty(d)
                localSize=d.bytes;
                if ~isempty(dirSize) && localSize~=dirSize
                    warning(['Updated size of %s from '...
                        '%s to %s'], key,...
                        String.encodeInteger(dirSize), ...
                        String.encodeInteger(localSize));
                    this.dirProps.put(key, ...
                        [num2str(localSize) ' ' link]);
                end
            end
        end
        
        function buildLinkMap(this)
            if isempty(this.dirProps)
                msgError('No directory properties yet!!', ...
                    'modal');
                return;
            end
            this.linkMap.clear;
            startingCount=this.dirProps.updateCount;
            keys=this.dirProps.keys;
            N=length(keys);
            bad=BasicMap;
            for i=1:N
                key=keys{i};
                link=this.getLinkAndSizes(key);
                if isempty(link)
                    bad.set(key, link);
                    continue;
                end
                [prior, priorList]=this.linkMap.get(link);
                if ~isempty(prior)
                    bad.set(key, link);
                    warning(['Duplicate! Same link used by '...
                        '%s AND %d more (%s):'...
                        '\n\tlink=%s'], key, priorList.size, ...
                        char(prior), link);
                end
                this.linkMap.put(link, key);
            end
            if this.dirProps.updateCount > startingCount
                this.dirProps.save(this.fileName, true);
            end
        end
            
        function saveToOriginalFile(this)
            if isempty(this.dirProps)
                msgError('No directory properties yet!!', ...
                    'modal');
                return;
            end
            this.dirProps.save(this.originalFileName, true);
        end
        
        function useBackupProperties(this)
            if isempty(this.dirProps)
                msgError('No directory properties yet!!', ...
                    'modal');
                return;
            end
            this.fileName=[this.dirProps.fileName '.bak'];
        end
        
        function setFolder(this, folderOnGoogleDrive)
            lf=fullfile(this.drive, folderOnGoogleDrive);
            if ~exist(lf, 'dir')
                choice=File.Ask([lf '*'], true, ...
                    [], ['Can''t find "' lf '"'], [],[], true);
                if isempty(choice)
                    msgError(['<html>Folder does not (yet) exist?' ...
                        Html.FileTree(this.localFolder) ...
                        '<br><br><center>???</center>'...
                        '<hr></html>'], 7');
                    return;
                end
                p=fileparts(folderOnGoogleDrive);
                folderOnGoogleDrive=fullfile(p, choice.name);
                lf=fullfile(this.drive, folderOnGoogleDrive);
                if ~exist(lf, 'dir')
                    msg(['Not a folder "' lf '"']);
                    return;
                end
            end
            this.localFolder=lf;
            this.pathKey=folderOnGoogleDrive;
            fprintf('Working in folder %s\n',...
                folderOnGoogleDrive)
        end
        
        function line=addFile(this, file)
            driveFile=fullfile(this.localFolder, file);
            if ~exist(driveFile, 'file')
                [choice, cancelled]=...
                    File.Ask([driveFile '*'], true, ...
                    [],  ['Can''t find "' file '"'], [], ...
                    [], false, 'name', 'ascend');
                if isempty(choice)
                    if ~cancelled
                        msgError(['<html>File does not (yet) exist?' ...
                            Html.FileTree(driveFile) ...
                            '<hr></html>'],7);
                    end
                    disp('No change made!')
                    sz=0;
                    return;
                else
                    file=choice.name;
                    driveFile=fullfile(this.localFolder, file);
                    sz=choice.bytes;
                end
            else
                e=dir(driveFile);
                sz=e.bytes;
            end
            fileNoSpace=String.URLEncode(file, true);
            key=fullfile(this.pathKey, fileNoSpace);
            if ispc %sigh
                key=strrep(key, '\', '/');
            end
            line=[key '=' num2str(sz) ' '];
            googleLink=clipboard('paste');
            if startsWith(googleLink, ...
                    GoogleDrive.URL_FOLDER_PREFIX)
                line=[line googleLink];
            elseif startsWith(googleLink, ...
                    GoogleDrive.URL_FILE_PREFIX)
            	line=[line googleLink];
            else
                msgError(Html.WrapHr(['The clipboard'...
                    ' has no suitable Google Drive ' ...
                    'sharing link<br><br>"' ...
                    Html.WrapBoldSmall(...
                    googleLink) '"']), 'modal');
                return;
            end
            if ~isempty(this.dirProps)
                [priorKey, priorList]=...
                    this.linkMap.get(googleLink);
                if priorList.size>0 &&...
                        ~priorList.contains(...
                        java.lang.String(key))
                    if ~askYesOrNo( Html.WrapHr(['The '...
                            'Google Drive link found on the'...
                            'clipboard is already used for'...
                            '<br><b>' strrep(char(priorKey), ...
                            '%20', ' ')...
                            '</b><br><br>CONTINUE???']))
                        return;
                    end
                elseif priorList.size>1
                    suffix=Html.WrapBoldSmall([...
                            '<i>'...
                            Html.ToList(StringArray.Cell(priorList), ...
                            'ol', true) '</i><br>']);
                    msg(['<html>Multiple files in directory '...
                        'share the same link<br>' ...
                        suffix '</html>']);
                end
                [priorLink, priorSz]=this.getLinkAndSizes(key);
                if ~isempty(priorLink)
                    if ~isequal(priorLink, googleLink)
                        [~, priorList]=this.linkMap.get(priorLink);
                        if priorList.size>1
                            l=java.util.ArrayList(priorList);
                            l.remove(key);
                            suffix=Html.WrapBoldSmall([...
                                '<br>(Also used by:<i>'...
                                Html.ToList(StringArray.Cell(l), ...
                                'ol', true) '</i><br>']);
                        else
                            suffix='';
                        end
                        app=BasicMap.Global;
            
                        if ~askYesOrNo(Html.WrapHr([...
                                app.h2Start...
                            'Overwrite prior link?'...
                            app.h2End...
                            '<table border="1">'...
                            '<thead><tr><th>Entry</th>'...
                            '<th>Size</th><th>Google '...
                            'Drive sharing link</th></tr>'...
                            '</thead><tr><td>' ...
                            '<font color="blue">Prior</font>'...
                            '</td><td align="right">' ...
                            String.encodeInteger(priorSz) '</td>'...
                            '<td>' priorLink '</td></tr>'...
                            '<tr><td><font color="blue">'...
                            'New</font></td>'...
                            '<td align="right">' ...
                            String.encodeInteger(sz) '</td>'...
                            '<td>' googleLink ...
                            '</td></tr></table>'...
                            suffix '<br>???'] ))
                            return;
                        end
                        this.linkMap.remove(priorLink, key);
                    elseif sz ~= priorSz
                        msg(Html.WrapHr([...
                            'Size updated from ' ...
                            String.encodeInteger(priorSz) ...
                            ' to ' String.encodeInteger(sz) ...
                            '!']));
                    else
                        warning('Nothing changed ...same as prior directory entry');
                        return;
                    end
                end
                this.dirProps.put(key, ...
                    [num2str(sz) ' ' googleLink]);
                this.linkMap.put(googleLink, key);
                this.dirProps.save(this.fileName, true);
                fprintf(['SUCCESS....saved new '...
                    'directory entry for\n   "%s"!!\n'], file);
            elseif nargout==0
                clipboard('copy', line);
            end
        end
    end
    
    methods(Static)
        function HandleTooBig(dwl, modal)
            N=dwl.tooBigFiles.size;
            try
                if ishandle(get(0, 'CurrentFigure'))
                    jw=Gui.JWindow(gcf);
                    jw.setAlwaysOnTop(false);
                end
            catch
            end
            warned=false;
            hasOpenedBrowser=false;
            openedTarget=false;
            openedDownloads=false;
            if N<1
                return;
            end
            if nargin<2
                modal=true;
            end
            app=BasicMap.Global;
            firstDeleteBtn=[];
            fldrByFile=dwl.tooBigLocalFolderByRemoteFile;
            fldrByFldr=dwl.tooBigLocalFolderByRemoteFolder;
            nFldrs=dwl.tooBigLocalFolderByRemoteFile.size;
            pnl1=Gui.GridPanel([],nFldrs,1);
            firstFldr='';
            moveBtnMap=SuhAnyMap;
            fileMap=SuhAnyMap;
            fldrMap=SuhAnyMap;
            priorInDownloads={};
            priorSizes=[];
            askedAboutPrior=false;
            it=fldrByFile.keySet.iterator;
            while it.hasNext
                pnl1.add(BorderPnl(it.next));
            end
            ttl1='Google Drive issues..,.';
            if modal
                moveAll(msgBox(Gui.Scroll(pnl1, 500, 550, app), ttl1));
            else
                msg(Gui.Scroll(pnl1, 500, 550, app), 10, 'center', ttl1 );
            end
            
            function bp=BorderPnl(fldr)
                if isempty(firstFldr)
                    firstFldr=fldr;
                end
                list=fldrByFile.get(fldr);
                bp=Gui.BorderPanel([],0,9);
                ttl=[num2str(list.size) ' file(s) APPEAR too big for '...
                    'automatic download ...'];
                Gui.SetTitledBorder(ttl, bp, 'bold', java.awt.Color.RED);
                p2=Gui.BorderPanel([],0,0);
                pnlOpenFldrs=Gui.SetTitledBorder('See a folder', p2);
                p2.add(Gui.NewBtn(Html.WrapSmallBold('Target'),...
                    @(h,e)local(h, fldr, true)), 'Center');
                p2.add(Gui.NewBtn(Html.WrapSmallBold('<u>Downloads</u>'),...
                    @(h,e)local(h, File.Downloads, false)), 'North');
                list2=fldrByFldr.get(fldr);
                if ~isempty(list2)
                    N2=list2.size;
                    if N2>1
                        word=['Remote (' num2str(N2) ')'];
                    else
                        word='Remote';
                    end
                    p2.add(Gui.NewBtn(Html.WrapSmallBold(word),...
                        @(h,e)openBrowser(h, list2, true)), 'South');
                end
                pnlTarget=Gui.SetTitledBorder('Target folder', ...
                    Gui.FlowLeftPanel(0,0,[ ...
                    '<html>' Html.FileTree(fldr, app, false, true) ...
                    '</html>']));
                pnlTarget=Gui.FlowPanel([], 0,4, pnlTarget);
                bp.add(Gui.BorderPanel([], 4,0, 'West', ...
                    pnlTarget, 'East',...
                    Gui.Panel(pnlOpenFldrs)), 'North');
                it=list.iterator;
                foci={...
                    '<html><b>File name</b></html>',...
                    '<html><b>Size</b></html>',...
                    Html.WrapSmallBold(...
                    'Download<br>by browser?'),Html.WrapSmallBold(...
                    'Exists in<br><u>Downloads</u>?')};
                while it.hasNext
                    con=it.next; %instance of edu.stanford.facs.Swing.WebDownload.Con
                    url=char(con.sharingUrl);
                    fldrMap.set(url, fldr);
                    [~, f, ext]=fileparts(char(con.driveKey));
                    file=String.URLDecode([f ext]);
                    foci{end+1}=file;
                    delete(fullfile(fldr, file)); % bad file
                    file=fullfile(File.Downloads, file);
                    fileMap.set(url,file);
                    isPrior=exist(file, 'file'); 
                    if isPrior % clear prior downloads
                        word='<font color="red"><i>Move?</i></font>';
                        priorInDownloads{end+1}=url;
                        priorSizes(end+1)=con.size;
                    else
                        word='Move';
                    end
                    foci{end+1}=String.encodeMb(con.size);
                    foci{end+1}=Gui.NewBtn(Html.WrapSmallBold(...
                        'Download'), @(h,e)openBrowser(h, url, false),...
                        'Open browser to download file');
                    btn=Gui.NewBtn(Html.WrapSmallBold(...
                        word), @(h,e)moveOrDelete(h, url),...
                        'Move from downloads folder');
                    btn.setEnabled(isPrior);
                    moveBtnMap.set(url, btn);
                    if isPrior
                        if isempty(firstDeleteBtn)
                            firstDeleteBtn=btn;
                        end
                    end
                    foci{end+1}=btn;
                end
                gbc=javaObjectEDT('java.awt.GridBagConstraints');
                anchors=[gbc.WEST gbc.EAST gbc.CENTER gbc.CENTER];
                center=Gui.GridBagPanel(0, 4, anchors, foci{:});
                bp.add(center, 'Center');
            end
            
            function enableMoveBtn(url)
                if ~StringArray.Contains(priorInDownloads, url)
                    btn=moveBtnMap.get(url);
                    btn.setEnabled(true);
                end
            end
            
            function moveOrDelete(btn, url)
                jd=Gui.WindowAncestor(btn);
                file=fileMap.get(url);
                idx=StringArray.IndexOf(...
                    priorInDownloads, url);
                if idx>0
                    d=dir(file);
                    strSize=String.encodeInteger(...
                            d.bytes);
                    if d.bytes ~= priorSizes(idx)
                        htmlSize=Html.WrapBoldSmall(...
                            ['<br><br>(Expected size is ' ...
                            '<u>' String.encodeInteger(...
                            priorSizes(idx)) '</u> bytes... ' ...
                            '<br> but <i>this file''s size'...
                            '</i> is <font color="red">'...
                            strSize '</font> )' ]);
                    else
                        htmlSize= Html.WrapBoldSmall(...
                            ['<br><br>(Expected size ' ...
                            'and <i>this file''s size</i><br>'...
                            ' are BOTH  <u>' strSize ...
                            '</u> bytes)' ]);
                    end
                    [a,~,cancelled]=questDlg(struct(...
                        'where', 'north',...
                        'javaWindow', jd,...
                        'msg', Html.WrapHr(['So this file '...
                            'was already in <br>your '...
                            '<u>Downloads</u> folder...'...
                            htmlSize ])),...
                            'Different file same name?',...
                            'Move', 'Delete', 'Cancel', 'Delete');
                    if cancelled
                        return;
                    end
                    idx=StringArray.IndexOf(priorInDownloads, url);
                    priorInDownloads(idx)=[];
                    
                    if strcmp(a, 'Delete')
                        if exist(file, 'file')
                            delete(file);
                        end
                        btn=moveBtnMap.get(url);
                        btn.setText(Html.WrapSmallBold(...
                            '<font color="#777799">Move</font>'));
                        btn.setEnabled(false);
                        return;
                    end
                    
                end
                [~, f, ext]=fileparts(file);
                if ~exist(file, 'file')
                    msg(struct('msg', Html.WrapHr(['Hmmm ... "<b>' f ...
                        ext '</b>"<br>is not found in your<br>'...
                        '<u>Downloads</u> folder...<br>'...
                        'try downloading again!']), ...
                        'javaWindow', jd), 7, 'south+',...
                        'First download it!');
                    return;
                end
                fldr=fldrMap.get(url);
                dst=fullfile(fldr, [f ext]);
                if ~exist(dst, 'file') ||  askYesOrNo(struct('msg', [...
                        '<html>Exists ...<font color="red"><b><i>'...
                        'overwrite</i></b></font>?</html>'], ...
                        'javaWindow', jd), 'Ooops...', 'south+')
                    movefile(file,dst,'f');
                    btn=moveBtnMap.get(url);
                    btn.setText(Html.WrapSmallBold(...
                        '<font color="#777799">Moved</font>'));
                end
            end
            
            function moveAll(jd)
                nToMove=0;
                N2=fileMap.size;
                for i=1:N2
                    [file, url]=fileMap.item(i);
                    if exist(file, 'file') && ~StringArray.Contains(...
                            priorInDownloads, url)
                        nToMove=nToMove+1;
                    end
                end
                if nToMove>0
                    fldrs=java.util.HashSet; % for counting targets`
                    for i=1:N2
                        [file, url]=fileMap.item(i);
                        fldr=fldrMap.get(url);
                        if exist(file, 'file') && ~StringArray.Contains(...
                                priorInDownloads, url)
                            movefile(file, fldr, 'f');
                        end
                        fldrs.add(fldr);
                    end
                    [~,f, ext]=fileparts(fldr);
                    if fldrs.size>1
                        words=['"<b>' f ext '</b>" and 2 ' fileMap.size 'more'];
                    else
                        words=['"<b>' fldr '<]/b>"'];
                    end
                    if isempty(priorInDownloads)
                        conflict='';
                    else
                        nConflicts=length(priorInDownloads);
                        conflict=Html.WrapBoldSmall(['<br><br>'...
                            '(Did NOT move the' ...
                            String.Pluralize2('file', nConflicts)...
                            ' found previously in <u>Downloads</u>)']);
                    end
                    msg(struct('javaWindow', jd, 'msg', ...
                        ['<html><center>' num2str(nToMove) ...
                        ' downloaded file(s) moved from <br>'...
                        'your <u>Downloads</u> folder to <br>"' ...
                        words '"' conflict '<hr></center></html>']),...
                        8, 'north+');
                end
            end
            
            function handleConflict(jd)
                N2=length(priorInDownloads);
                if ~askedAboutPrior && N2>0
                    if N2>1
                        words1=[' are ' num2str(N2) ' files '];
                        words2='conflicting names';
                    else
                        words1=' is 1 file ';
                        words2='a confliciing name';
                    end
                    edu.stanford.facs.swing.Basics.Shake(firstDeleteBtn,5);
                    if askYesOrNo(struct('msg', ...
                            Html.WrapHr(['There' words1 ...
                            '<i>previously</i> in your <u>'...
                            'Downloads</u><br>folder with ' words2 ...
                            ' ... <br><br><b>Remove?</b>']),...
                            'javaWindow', jd), 'Oooops....',...
                            'north+')
                        for i=1:N2
                            url2=priorInDownloads{i};
                            file=fileMap.get(url2);
                            if exist(file, 'file')
                                delete(file);
                            end
                            btn=moveBtnMap.get(url2);
                            btn.setText(Html.WrapSmallBold('Move'));
                        end
                        priorInDownloads={};
                    else
                        if N2>1
                            words1='these files';
                        else
                            words1='this file';
                        end
                        msg(struct('javaWindow', jd, 'msg',...
                            Html.WrapHr(['Okay ...you will have to move ' ...
                            words1 '<br>manually from <u>Downloads</u>'...
                            ' to the target folder.'])), 8, 'north++');
                    end
                    askedAboutPrior=true;
                end
            end
            
            function handleBrowserOpen
                if hasOpenedBrowser
                    if nargin>1
                        enableMoveBtn(url);
                    else
                        N2=moveBtnMap.size;
                        for i=1:N2
                            btn=moveBtnMap.item(i);
                            btn.setEnabled(true);
                        end
                    end
                end
            end
            
            function checkDownloadsFolder(jd, url)
                handleConflict(jd);
                handleBrowserOpen;
            end
            
            function openBrowser(btn, url, isList)
                jd=Gui.WindowAncestor(btn);
                hasOpenedBrowser=true;
                if ~isList
                    checkDownloadsFolder(jd, url)
                    web(url, '-browser');
                else
                    checkDownloadsFolder(jd);
                    it=url.iterator;
                    while it.hasNext
                        web(char(it.next), '-browser');
                    end
                end
                if ~warned
                    setAlwaysOnTopTimer(jd, 2, true, false);
                    MatBasics.RunLater(@(h,e)lazyOpen(jd), 3);
                end
            end
            
            function lazyOpen(jd)
                jd.requestFocus;
                
                warned=true;
                if ~openedTarget
                    local(jd, firstFldr, true);
                end
                if ~openedDownloads
                    local(jd, File.Downloads, false);
                end
                MatBasics.RunLater(@(h,e)instruct(jd), 1);
            end
            function instruct(jd)
                [~,f,ext]=fileparts(firstFldr);
                advice=msg(struct('msg', Html.WrapHr(...
                    ['Once you have downloaded '...
                    '<br>file(s) click their "Move" button<br>'...
                    '<br>... or drag and drop them<br>'...
                    'to the folder window titled<br>"<i>'...
                    f ext '</i>"']), 'javaWindow', jd),...
                    12, 'east++');
                setAlwaysOnTopTimer(advice, 2, true, false);
            end
            
            function local(h, fldr, isTarget)
                if isa(h, 'javax.swing.JDialog')
                    jd=h;
                else
                    jd=Gui.WindowAncestor(h);
                end
                handleConflict(jd);
                if isTarget
                    openedTarget=true;
                else
                    openedDownloads=true;
                end
                File.OpenFolderWindow(fullfile(fldr, '.'), '', false);
            end
        end
        
        function [link, sz]=Parse(value)
            link=[]; sz=[];
            if ~isempty(value)                
                idx=String.IndexOf(value, ' ');
                if idx>0
                    sz=str2double(value(1:idx-1));
                    link=strtrim(value(idx:end));
                else
                    link='';
                end
            end
        end
        
        
        function UpdateDirectory(fileSpecOnGoogleDrive, dirFileName)
            folder=File.GoogleDrive;
            spec=qualify(fileSpecOnGoogleDrive, 'file spec');
            if nargout<2
                dirFileName=fullfile(folder, 'dir.properties');
            end
            dirFileName=qualify(dirFileName, 'directory property file');
            m=File.ReadProperties(dirFileName);
            subFldr=fileparts(spec(length(folder)+2:end));
            fs=dir(spec);
            gd='^(?<size>\d+)\s+(?<url>https://drive.google.com/.*)';
            gd2='^(?<size>\d+)\s+';
            N=length(fs);
            if N==0
                whine=Html.Wrap(['File does not exist<br>'...
                    Html.WrapBoldSmall(String.ToHtml(spec))]);
                msg(whine);
                warning(whine);
                return;
            end
            WebDownload.StateSharingRequirements
            
            changes=0;
            for i=1:N
                f=fs(i);
                if ~startsWith(f.name, '.') && f.bytes>0
                    key=fullfile(subFldr, f.name);
                    if ispc
                        key=strrep(key, filesep, '/');
                    end
                    value=num2str(f.bytes);
                    if ~m.containsKey(key)
                        disp(['      Adding to Google dir "' key '"=' value]);
                        m.put(key, [value ' ']);
                        changes=changes+1;
                    else
                        old=m.get(key);
                        flds=regexp(old, gd, 'names');
                        if isempty(flds)
                            flds=regexp(old, gd2, 'names');
                            if ~isempty(flds)
                                flds.url='';
                            end
                        end
                        if isempty(flds)
                            warning(['Bad/incomplete format ' key '=' old ]);
                            disp(['      Correcting Google dir "' key '"=' value]);
                            m.put(key, [value ' ']);
                            changes=changes+1;
                        else
                            if ~strcmp(flds.size, value)
                                disp([' .     Changing Google dir size from ' ...
                                    flds.size ' to ' value ' for "' key '"']);
                                m.put(key, [value ' ' flds.url]);
                                changes=changes+1;
                            else
                                disp(['       Google dir unchanged for "'...
                                    key '"="' old '"']);
                            end
                        end
                    end
                end
            end
            if changes>0
                File.SaveProperties(m, dirFileName, true);
            end
            function qualified=qualify(fileThing, word)
                jf=java.io.File(fileThing);
                
                if ~jf.isAbsolute
                    qualified=fullfile(folder, fileThing);
                else
                    qualified=fileThing;
                end
                assert(startsWith(qualified, folder), ...
                    ['The Google ' word ...
                    ' must be on your Google Drive!']);
            end
        end
        
        
        function J=Test
            [~, ~, J]=WebDownload.Many({'omip044Labeled.csv',...
                'omip69Labeled.csv'});
        end
        
        function J=TestOMIP40Color
            was=WebDownload.GoogleDriveOnly(true);
            disp('Expecting download window')
            [~, ~, J]=WebDownload.Many({'MC%203015036.fcs',...
                'MC%20303444.fcs'}, [], 'Samples/OMIP40Color');
            WebDownload.GoogleDriveOnly(was);
        end
        
        
        function J=TestOmip44
            was=WebDownload.GoogleDriveOnly(true);
            [~, ~, J]=WebDownload.Many({...
                'Compensation%20Controls_V780%20Stained%20Control_017.fcs',...
                'samples_AllCells%20A5807%20part1_030.fcs',...
                'Compensation%20Controls_U730%20Stained%20Control_023.fcs'},...
                [], 'Samples/omip44');
            WebDownload.GoogleDriveOnly(was);
        end
        
        function J=TestNikolay
            was=WebDownload.GoogleDriveOnly(true);
            disp('Expecting download window')
            [~, ~, J]=WebDownload.Many({...
                'BM2_cct_normalized_10_non-Neutrophils.fcs',...
                'BM2_cct_normalized_01_non-Neutrophils.fcs'}, ...
                [], 'Samples/Nikolay');
            WebDownload.GoogleDriveOnly(was);
        end
    end
end