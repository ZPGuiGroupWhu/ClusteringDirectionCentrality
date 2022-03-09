classdef ColorsByName <handle
%   AUTHORSHIP
%   Primary Developer: Stephen Meehan <swmeehan@stanford.edu> 
%   Math Lead & Secondary Developer:  Connor Meehan <connor.gw.meehan@gmail.com>
%   Bioinformatics Lead:  Wayne Moore <wmoore@stanford.edu>
%   Provided by the Herzenberg Lab at Stanford University 
%   License: BSD 3 clause
%
    
    properties(Constant)
        DEFAULT_COLOR=[.9 .9 .9];
        FILE='colorsByName.properties';
    end
    
    properties
        file;
        props;%key: name original case canonical; value: java String 0 to 255 unrounded
        spellFile;
        spellProps; % maintain correct spelling since props uses lower case
        synonyms; %key: java String color 0 to 255 unrounded; value original case name
        canon; %key: java String color 0 to 255 unrounded; value original case name
        map;%key: lower case name; value: numeric color 0 to 1
        backupFile;
    end
    
    properties(SetAccess=private)
        listeners;
    end
    
    methods
        function this=ColorsByName(file, spellFile)
            if nargin<2
                spellFile=[];
                if nargin<1
                    file=[];
                end
            end
            if isempty(file) || ~exist(file, 'file')
                file=ColorsByName.DefaultFile(file);
            end
            if isempty(spellFile)
                [p,f,e]=fileparts(file);
                spellFile=fullfile(p, [f '.spell' e]);
            end
            if ~exist(spellFile, 'file')
                spellFile=ColorsByName.DefaultFile(spellFile);
            end
            this.file=file;
            this.spellFile=spellFile;
            this.map=BasicMap;
            this.synonyms=TreeMapOfMany;
            this.canon=java.util.HashMap;
            this.setColors(file, spellFile);
        end
        
        function setColors(this, file, spellFile)
            this.props=ColorsByName.ReadProperties(file);
            this.spellProps=ColorsByName.ReadProperties(spellFile);
            this.map.clear;
            this.synonyms.clear;
            this.canon.clear;
            if isempty(this.props)
                this.props=java.util.Properties;
                return;
            end
            changed=0;
            it=java.util.ArrayList(this.props.keySet).iterator;
            while it.hasNext
                key=it.next;
                name=strtrim(key);
                try
                    isCanonicalName=startsWith(name, '*');
                    strColor=this.props.get(java.lang.String(name));
                    if isCanonicalName
                        name=name(2:end);
                    end
                    nameLower=lower(name);
                    jname=java.lang.String(nameLower);
                    if ~this.spellProps.containsKey(jname)
                        this.spellProps.put(jname, ...
                            java.lang.String(String.Capitalize(name)));
                        changed=changed+1;
                    end
                    if isempty(strColor)
                        warning(['Null color for "' key '": [' strColor ']']);
                        strColor=num2str(ColorsByName.DEFAULT_COLOR);
                    end
                    [~, color, was255, strColor]...
                        =ColorsByName.Get255(strColor, key, false);
                    this.props.remove(java.lang.String(key));
                    if this.map.containsKey(nameLower)
                        warning('Case insensitivity: "%s"=[%s] overridden by [%s]\n', ...
                            key, String.Num2Str(str2num(char(strColor)), ' '), ...
                            String.Num2Str(floor(this.map.get(nameLower)*255), ' ')); %#ok<*ST2NM> 
                        this.props.put(jname, strColor);
                        changed=changed+1;
                        continue;
                    elseif ~isequal(key, nameLower)
                        warning('Case sensitivity: "%s" is being stored as "%s"\n', ...
                            key, nameLower);
                        this.props.put(jname, strColor);
                        changed=changed+1;
                    else
                        this.props.put(jname, strColor);
                    end
                    this.map.set(nameLower, color);
                    this.synonyms.put(strColor, nameLower);
                    if isCanonicalName ...
                            || ~this.canon.containsKey(strColor)
                        this.canon.put(strColor, nameLower);
                    end
                    if this.synonyms.valueCount(strColor)>1
                        fprintf('%s has %d synonyms\n', key, ...
                            this.synonyms.valueCount(strColor));
                    end
                catch
                    fprintf('Name "%s" is null?\n', key);
                end
            end
            if changed>0
                this.save;
            end
        end
        
        function [synonyms, clr, canonicalName, name, nameLower]=...
                getSynonyms(this, externalKey, fnTranslate)
            if nargin<3
                name=externalKey;
            else
                translated=feval(fnTranslate, externalKey);
                if isempty(translated)
                    name=externalKey;
                else
                    name=translated;
                end
            end
            nameLower=lower(name);
            clr=num2str((255*this.map.get(nameLower)));
            if isempty(clr)
                synonyms=[];
                canonicalName=[];
            else
                synonyms=this.synonyms.getCell(clr);
                clr=java.lang.String(clr);
                if nargout>2
                    canonicalName=this.canon.get(clr);
                end
            end
        end
        
        function color=get(this, key, idx, nIdxs, fnTranslate)
            if isempty(this.props) || this.props.size==0
                color=[];
                return;
            end
            %map is guaranteed to have ONLY contains lower case keys
            color=this.map.get(lower(key));
            if isempty(color)
                if nargin>=5
                    name=feval(fnTranslate, key);
                else
                    name=key;
                end
                if ~isempty(name)
                    color=this.map.get(lower(name));
                    if ~isempty(color)
                        fprintf('map.set for ID=%s, name=%s\n', key, name);
                        this.map.set(key, color);
                    elseif nargin>2 && idx>-1
                        color=Gui.HslColor(idx, nIdxs);
                    end
                end
            end
        end
        
        function yes=isUsing(this, externalKey)
            yes=this.map.containsKey(externalKey);
        end
        
        function [cnt, synonyms_]=update(this, externalKey, color, fnTranslate)
            cnt=0;
            if isempty(this.props) || this.props.size==0 
                return;
            end
            if nargin<4
                [synonyms_, oldColor, ~, name, nameLower]=...
                    this.getSynonyms(externalKey);
            else
                [synonyms_, oldColor, ~, name, nameLower]=...
                    this.getSynonyms(externalKey, fnTranslate);
            end
            [~,color,~,newColor]=ColorsByName.Get255(color, externalKey, false);
            if newColor.equals(oldColor)
                return;
            end
            N=length(synonyms_);
            if N>0
                for i=1:N
                    synonym=synonyms_{i};
                    assert(strcmp(synonym, lower(synonym)))
                    this.map.set(synonym, color);
                    this.props.put(java.lang.String(synonym), newColor);
                    cnt=cnt+1;
                end
                this.synonyms.renameKey(oldColor, newColor);
                if this.canon.containsKey(oldColor)
                    v=this.canon.remove(oldColor);
                    this.canon.put(newColor, v);
                    this.props.put(['*' v], newColor);
                end
            else
                if this.synonyms.containsKey(newColor)
                    warning(['Color already in use for "' ...
                        name '" by "' ...
                        char(this.synonyms.get(newColor)) '"']);
                else
                    cnt=1;
                    this.map.set(nameLower, color);
                    jname=java.lang.String(nameLower);
                    this.synonyms.put(newColor, jname);
                    this.canon.put(newColor, jname);
                    this.props.put(jname, newColor);
                    if ~this.spellProps.containsKey(jname)
                        this.spellProps.put(jname, ...
                            java.lang.String(externalKey));
                    end
                end
            end
            this.save;
        end
        
        
        function color=getStrColor255(this, key, fnTranslate)
            % 4 efforts ensure that case sensitivity does not
            % defeat finding a color from the java.util.Properties
            
            color=this.map.get(lower(key));
            if nargin>2 && isempty(color)
                key=feval(fnTranslate, key);
                if ~isempty(key)
                    color=this.map.get(lower(key));
                    if isempty(color)
                        key=lower(key);
                        color=this.map.get(lower(key));
                    end
                end
            end
            color=num2str(color*255);
        end
        
        function [oldSynonyms, newSynonyms]=...
                update1(this, externalKey, color, fnTranslate)
            oldSynonyms={};
            newSynonyms={};
            if isempty(this.props) || this.props.size==0 
                return;
            end
            if nargin<4
                [synonyms_, oldColor, ~, name, nameLower]=...
                    this.getSynonyms(externalKey);
            else
                [synonyms_, oldColor, ~, name, nameLower]=...
                    this.getSynonyms(externalKey, fnTranslate);
            end
            [~,color0to1,~,str255]=ColorsByName.Get255(color, externalKey, false);
            if str255.equals(oldColor)
                return;
            end
            jname=java.lang.String(nameLower);
            N=length(synonyms_);
            if N>1
                if nargout>0
                    for i=1:N
                        if ~strcmp(synonyms_{i}, name)
                            oldSynonyms{end+1}=synonyms_{i};
                        end
                    end
                end
                this.synonyms.remove(oldColor, jname); 
            end
            if this.synonyms.containsKey(str255) % has new synonyms
                if nargout>1
                    newSynonyms=this.synonyms.get(str255);
                end
            else
                this.canon.put(str255, jname);
            end
            this.map.set(nameLower, color0to1);
            this.synonyms.put(str255, jname);
            this.props.put(jname, str255);
            if ~this.spellProps.containsKey(jname)
                this.spellProps.put(jname, ...
                    java.lang.String(externalKey));
            end
        end
        
        function save(this)
            File.SaveProperties2(this.file, this.props)
            File.SaveProperties2(this.spellFile, this.spellProps)
        end
        
        function backup(this)
            bak=[this.file '.1'];
            next=2;
            while exist(bak, 'file')
                if File.AreEqual(this.file, bak)
                    this.backupFile=bak;
                    return;
                end
                bak=[this.file '.' num2str(next)];
                next=next+1;
            end
            if next > 10 % only 10 backups
                allFiles=sortStructs(dir([this.file '.*']), 'datenum', 'descend');
                bak=fullfile(allFiles(1).folder, allFiles(1).name);
            end
            copyfile(this.file, bak);
            this.backupFile=bak;
            [~,~,e]=fileparts(bak);
            bak=[this.spellFile e];
            copyfile(this.spellFile, bak);            
        end
        
        function chosenFile=compareBackup(this, pick)
            if nargin>1 && pick
                chosenFile=File.Ask([this.file '.*'], true, '', 'Pick colors backup');
                if isempty(chosenFile)
                    return;
                end
                bak=fullfile(chosenFile.folder, chosenFile.name);
            else
                bak=this.backupFile;
            end
            visdiff(this.file, bak);
        end
        
        function [ok, names, colors]=restoreBackup(this, pick)
            names={};
            colors=[];
            ok=false;
            if nargin>1 && pick
                chosenFile=File.Ask([this.file '.*'], true, '', 'Pick colors backup');
                if isempty(chosenFile)
                    return;
                end
                bak=fullfile(chosenFile.folder, chosenFile.name);
            else
                bak=this.backupFile;
            end
            if isempty(bak)
                return;
            end
            temp=tempname;
            try
                movefile(this.file, temp);
                movefile(bak, this.file);
                movefile(temp, bak);
                [~,~,e]=fileparts(bak);
                bak=[this.spellFile e];
                if exist(bak)
                    movefile(this.spellFile, temp);
                    movefile(bak, this.spellFile);
                    movefile(temp, bak);
                end
                ok=true;
            catch ex
                ex.getReport
                return;
            end
            p=ColorsByName.ReadProperties(this.file);
            keys=java.util.HashSet(this.props.keySet);
            keys.addAll(p.keySet);
            it=keys.iterator;
            while it.hasNext
                name=it.next;
                oldColor=round(str2num(this.props.get(java.lang.String(name))));
                newColor=round(str2num(p.get(java.lang.String(name))));
                if ~isequal(oldColor, newColor)
                    names{end+1}=name;
                    if isempty(newColor)
                        newColor=ColorsByName.DEFAULT_COLOR;
                    end
                    colors(end+1,:)=newColor;
                end
            end    
            this.setColors(this.file, this.spellFile);
        end
        
        function [yes,synonyms,canonicalName,color,htmlSymb,strColor]=...
                isUsed(this, colorOrKey, fnTranslate)
            yes=false;
            synonyms=[];
            canonicalName=[];
            htmlSymb=[];
            strColor=[];
            if isempty(this.props) || isempty(colorOrKey)
                return;
            end
            if isnumeric(colorOrKey) && length(colorOrKey)==3
                color=colorOrKey;
            else
               if ~ischar(colorOrKey)
                   colorOrKey=char(colorOrKey);
               end
               if nargin<3
                   color=this.get(colorOrKey);
               else
                   color=this.get(colorOrKey, -1,-1,fnTranslate);
               end
               if length(color)~=3
                   return;
               end
            end            
            strColor=num2str(floor(255*color));
            yes=this.synonyms.containsKey(strColor);
            if nargout>1
                synonyms=this.synonyms.getCell(strColor);
                if nargout>2
                    canonicalName=this.canon.get(strColor);
                    if nargout>4
                        htmlSymb=Html.Symbol(color, 30, false);
                    end
                end
            end
        end
        
        function idx=indexOfListener(this, listener)
            idx=0;
            N_=length(this.listeners);
            for i=1:N_
                if this.listeners{i}==listener
                    idx=i;
                    return;
                end
            end
            
        end
        
        function addListener(this, listener)
            if isempty(this.listeners)
                idx=0;
                this.listeners={};
            else
                idx=this.indexOfListener(listener);
            end
            if idx==0
                this.listeners{end+1}=listener;
            end
        end
        
        function removeListener(this, listener)
            idx=this.indexOfListener(listener);
            if idx>0
                this.listeners(idx)=[];
            end
        end
        
        function notify(this, source, names, colors, ...
                isUpdatedOrExplanation, notifySelf)
            if nargin<6
                notifySelf=false;
                if nargin<5
                    isUpdatedOrExplanation=true;
                end
            end
            if ischar(names)
                names={names};
            end
            N_=length(this.listeners);
            N2=length(colors);
            if N2==1 && N_>1
                colors=repmat(N_,1);
            end
            if islogical(isUpdatedOrExplanation)
                if isUpdatedOrExplanation
                    event.type='changed';
                else
                    event.type='used';
                end
            else
                event.type=isUpdatedOrExplanation;
            end
            event.names=names;
            event.colors=colors;
            for i=1:N_
                if ~notifySelf && source==this.listeners{i}
                    disp('Not caling source of notification');
                else
                    this.listeners{i}.actionPerformed(source, event);
                end
            end
        end
    end
    
    methods(Static)
        function file=DefaultFile(propFile)
            if nargin<1 || isempty(propFile)
                propFile=ColorsByName.FILE;
            end
            [~,f,e]=fileparts(propFile);
            propFile=[f e];
            file=fullfile(UmapUtil.LocalSamplesFolder, propFile);
            homeAg=fullfile(File.Home, '.autoGate', propFile);
            if exist(file, 'file')
            elseif exist(homeAg, 'file')
                file=homeAg;
            else
                try
                    url=WebDownload.ResolveUrl(propFile);
                    WebDownload.Get({url}, {file}, false, false, 'south');
                catch
                    file=ColorsByName.Copy2Ag;
                end
            end
        end
        
        function destination=Copy2Ag
            destination=fullfile(File.Home, '.autoGate',ColorsByName.FILE);
            if ~exist(destination, 'file')
                p=fullfile(fileparts(fileparts(mfilename('fullpath'))), 'umap');
                source=fullfile(p, ColorsByName.FILE);
                File.mkDir(fileparts(destination));
                copyfile(source, destination);
            end
            
        end
        
        function props=ReadProperties(colorFile)
            if ~isempty(colorFile)
                fldr=fileparts(colorFile);
                if isempty(fldr)
                    colorFile=ColorsByName.DefaultFile(colorFile);
                end
                props=File.ReadProperties(colorFile, true);
            else
                props=java.util.Properties;
            end
        end
        
        
        function cnt=Override(lblMap, colorFile, beQuiet)
            cnt=0;
            if ~isempty(colorFile)
                if isequal(colorFile, ColorsByName.FILE)
                    cbn=BasicMap.Global.colorsByName.props;
                else
                    cbn=ColorsByName.ReadProperties(colorFile);
                end
                if ~isempty(cbn)
                    c=StringArray.Cell(cbn.keySet);
                    N=length(c);
                    for i=1:N
                        key=c{i};
                        try
                            clr=cbn.get(key);
                            if startsWith(key, '*') %canonical name
                                cbn.put(lower(key(2:end)), clr);
                            else
                                cbn.put(lower(key), clr);
                            end
                        catch 
                            if nargin<3 || ~beQuiet
                                fprintf('key #%d "%s" is null?\n', i, key);
                            end
                        end
                    end
                    it=java.util.ArrayList(lblMap.keySet).iterator;
                    while it.hasNext
                        key=char(it.next);
                        if ~endsWith(key, '.color')
                            name=lower(String.RemoveTex(lblMap.get(...
                                java.lang.String(key))));
                            if cbn.containsKey(name)
                                clr=cbn.get(name);
                                lblMap.put([key '.color'], clr);
                                cnt=cnt+1;
                            else
                                if nargin<3 || ~beQuiet
                                    fprintf('No override for %s=%s\n',...
                                        key, name);
                                end
                            end
                        end
                    end
                end
            end
        end
        
        function [color255, color0to1, was255, js255, str255]=...
                Get255(color0to1,  name, roundDown)
            if ischar(color0to1)
                color0to1=str2num(color0to1);
            end
            originalColor=color0to1;
            if all(color0to1<=1)
                if any(color0to1<0)
                    warned=true;
                    color0to1(color0to1<0)=0;
                    warning('RGB out of range "%s", converted [%s] to [%s]',...
                        name, String.Num2Str(originalColor, ' '), ...
                        String.Num2Str(color0to1, ' '));
                elseif all(color0to1==1)
                    warned=true;
                    warning(['Assuming [1 1 1] means white ' ...
                        'for "%s" (not black?)'], name);
                end
                color255=255*color0to1;
                was255=false;
            else
                if any((color0to1<1&color0to1>0)| color0to1<0)
                    warned=true;
                    color0to1(color0to1<1&color0to1>0)=...
                        color0to1(color0to1<1&color0to1>0)*255;
                    color0to1(color0to1<0)=0;
                    warning('RGB out of range "%s", converted [%s] to [%s]',...
                        name, String.Num2Str(originalColor, ' '), ...
                        String.Num2Str(color0to1, ' '));
                end
                color255=color0to1;
                color0to1=color255/255;
                was255=true;
            end
            if roundDown
                color255=floor(color255);
            end
            if length(color0to1)~=3
                color0to1=ColorsByName.DEFAULT_COLOR;
                s=sprintf('Bad RGB form for "%s", converted [%s] to [%s]\n',...
                    name, String.Num2Str(originalColor, ' '), ...
                    String.Num2Str(color0to1, ' '));
                if exist('warned', 'var')
                    fprintf(s)
                else
                    warning(s);
                end
            end
            if nargout==4
                js255=java.lang.String(num2str(color255));
            elseif nargout==5
                str255=num2str(color255);
                js255=java.lang.String(str255);                
            end
        end
    end
end
