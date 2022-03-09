%   AUTHORSHIP Primary Developer: Stephen Meehan <swmeehan@stanford.edu>
%   Math Lead & Secondary Developer:  Connor Meehan <connor.gw.meehan@gmail.com>
%   Provided by the Herzenberg Lab at Stanford
%   University License: BSD 3 clause
%
%TODO ... convert to live script mlx SuhFile.mlx
%https://www.mathworks.com/help/matlab/matlab_prog/create-live-scripts.html
%https://www.mathworks.com/help/matlab/matlab_prog/marking-up-matlab-comments-for-publishing.html
%
classdef File
    properties(SetAccess=private)
        file='';
        absolute='';
        firstFolder='';
    end
    
    properties(Constant)
        DEBUG=0;
        EXPORT_TYPES={'*.txt', 'tab-delimited file';...
            '*.csv', 'comma separated values';...
            '*.xls', 'Excel workbook'};
        PROP_EXPORT='exportType2';
        PROP_XLS_IMG='xlsGateImg';
        PROP_XLS_ADD='lastXls';
        PROP_XLS_OPEN='isOpenSlidesWorkbook';
    end
    
    methods        
        function [this]= File(file)
            this.file=file;
            this.absolute=File.canonicalPath(file);
            if ~isfolder(this.absolute)
                [this.firstFolder, ~, ~]=fileparts(this.absolute);
            else
                this.firstFolder=this.absolute;
            end
        end
        
        function [levels]=countAncestors(this, ancestorFolder)
            ancestorFolder=File.canonicalPath(ancestorFolder);
            N=length(ancestorFolder);
            folder=this.firstFolder;
            levels=-1;
            while strncmp(ancestorFolder, folder, N)
                levels=levels+1;
                [folder, ~, ~]=fileparts(folder);
            end
        end
    end
    
    methods(Static)
        function [size, map]=Tally(folder, spec, parent, map, cur)
            if nargin<3
                parent=[];
            end
            if nargin<4
                map=java.util.TreeMap;
            end
            size=0;
            fsp=fullfile(folder,spec);
            xxx=dir(fsp);
            N=length(xxx);
            if nargin<5
                cur=now;
            end
            if isempty(parent)
                scan=true;
            else
                idx=String.LastIndexOf(folder, filesep);
                if idx>0
                    lastPath=String.SubString(folder, idx+1);
                    scan=strcmp(lastPath, parent);
                else
                    scan=false;
                end
            end
            if scan
                for i=1:N
                    fl=xxx(i);
                    fname=fl.name;
                    if ~fl.isdir
                        subSize=fl.bytes;
                        elapsed=cur-fl.datenum;
                        path=fullfile(folder, fname);
                        map.put(elapsed, path);
                        size=size+subSize;
                    end
                end
            end
            if ~isempty(parent)
                path=fullfile(folder, parent);
                if exist(path, 'dir')
                    subSize=File.Tally(path, spec, parent, map, cur);
                    size=size+subSize;
                end
            end
            fsp=folder;
            xxx=dir(fsp);
            N=length(xxx);
            for i=1:N
                fl=xxx(i);
                fname=fl.name;
                if fl.isdir
                    if ~strcmp('.', fname) && ~strcmp('..', fname)
                        if isempty(parent) || ~strcmp(fname, parent)
                            path=fullfile(folder, fname);
                            subSize=File.Tally(path, spec, parent, map, cur);
                            size=size+subSize;
                        end
                    end
                end
            end
        end
        
        function [sz, str]=Size2(to, matches)
            sz=0;
            existType=exist(to);
            if existType>0
                files=dir(to);
                if existType==2 %file
                    sz=files(1).bytes;
                elseif existType==7 %directory
                    N=length(files);
                    for i=1:N
                        if files(i).isdir
                            n=files(i).name;
                            if ~isequal(n, '.') && ~isequal(n, '..')
                                sz=sz+File.Size2(fullfile(to, ...
                                    files(i).name), matches);
                            end
                        else
                            sz=sz+files(i).bytes;
                        end
                    end
                end
                File.SizeMatches(to, matches);
            end
            if nargout>1
                str='';%['<td align="right">' String.encodeBytes(sz) '</td>'];
                it=matches.keySet.iterator;
                while it.hasNext
                    sz2=matches.get(it.next);
                    str=[str '<td align="right">' ...
                        String.encodeBytes(sz2) '</td>'];
                end
            end
        end
        
        function SizeMatches(dirName, matches)
            it=matches.keySet.iterator;
            while it.hasNext
                match=char(it.next);
                sp=fullfile(dirName, match);
                dd=dir(sp);
                N=length(dd);
                sz=0;
                for i=1:N
                    sz=sz+dd(i).bytes;
                end
                matches.put(match, matches.get(match)+sz);
            end
        end
        
        function [sz, str]=Size(to)
            sz=0;
            existType=exist(to);
            if existType>0
                files=dir(to);
                if existType==2 %file
                    sz=files(1).bytes;
                elseif existType==7 %directory
                    N=length(files);
                    for i=1:N
                        if files(i).isdir
                            n=files(i).name;
                            if ~isequal(n, '.') && ~isequal(n, '..')
                                sz=sz+File.Size(fullfile(to,files(i).name));
                            end
                        else
                            sz=sz+files(i).bytes;
                        end
                    end
                end
            end
            if nargout>1
                str=String.encodeBytes(sz);
            end
        end
        
        function CopyBySpec(from, someSpec, to)
            spec=fullfile(from, someSpec);
            File.mkDir(to);
            copyfile(spec, to);
        end
        
        function ok=Copy(from, to, retrying)
            ok=true;
            try
                copyfile(from, to);
            catch ex
                ok=false;
                if ~exist(fileparts(to), 'dir')
                    File.mkDir(fileparts(to))
                    ok=File.Copy(from, to, true);
                    return;
                end
                if nargin>2 && retrying
                    rethrow(ex);
                else
                    ok=File.Copy1by1(from, to);
                end
            end
        end
        function ok=Copy1by1(from, to)
            ok=true;
            a=dir(from);
            N=length(a);
            for i=1:N
                n=a(i).name;
                if isequal(n, '.') || isequal(n, '..')
                else
                    ff=fullfile(a(i).folder, a(i).name);
                    if ~File.Copy(ff, to, true)
                        ok=false;
                        return;
                    end
                end
            end
        end

        function ok=isFile(input)
            ok=false;
            if exist(input, 'file')
                ok=~isdir(input);
            end
        end
        
        function file=AppendSuffix(file, suffix)
            [fldr, ff, ext]=fileparts(file);
            file=fullfile(fldr, [ff suffix ext]);
        end
        
        function fullFile=SwitchExtension(fullFile, type2)
            lSepIdx1=String.LastIndexOf(type2, filesep);
            lSepIdx2=String.LastIndexOf(fullFile, filesep);
            lExtIdx1=String.LastIndexOf(type2, '.');
            lExtIdx2=String.LastIndexOf(fullFile, '.');
            if lExtIdx1>0 && lExtIdx1 > lSepIdx1 && lExtIdx2>0 ...
                    && lExtIdx2>lSepIdx2
                ext1=String.SubString(type2, lExtIdx1);
                ext2=String.SubString(fullFile, lExtIdx2);
                if ~strcmp(ext1,ext2)
                    fullFile=[fullFile(1:lExtIdx2-1) ext1];
                end
            end
        end
        
        function fullFile=SwitchExtension2(fullFile, newExt)
            if endsWith(fullFile, newExt)
                return;
            end
            sepIdx=String.LastIndexOf(fullFile, filesep);
            idx=String.LastIndexOf(fullFile, '.');
            if idx>0 && idx>sepIdx
                fullFile=[fullFile(1:idx-1) newExt];
            end
        end
        
        function floats=ReadFloat32(fileName)
            f=[];
            floats=[];
            try
                f = fopen(fileName,'r');
                sz=fread(f, [1 2], 'int32', 'b');
                floats=fread(f, sz, 'float32', 'b');
                fclose(f);
            catch ex
                ex.getReport
                if ~isempty(f)
                    fclose(f);
                end
            end
        end
        
        function WriteFloat32(fileName, floats)
            f=[];
            try
                f = fopen(fileName,'w');
                if f==-1
                    fileattrib(fileName, '+w');
                    f = fopen(fileName,'w');
                    if f<0
                        return;
                    end
                end
                fwrite(f, size(floats), 'int32', 'b');
                fwrite(f, floats, 'float32', 'b');
                fclose(f);
            catch ex
                ex.getReport
                if ~isempty(f)
                    fclose(f);
                end
            end
        end
        
        function fn=SaveTempHtml(html)
            fn=File.SaveTempTextFile(html, '.html');
        end
        
        function fn=SaveTempTextFile(text, fileExt)
            if nargin<2
                fileExt='.txt';
            end
            fn=File.TempName('', fileExt);
            File.SaveTextFile(fn, text);
        end
        
        function name=TempName(prefix, fileExt)
            if nargin<2
                fileExt='';
                if nargin<1
                    prefix='';
                end
            end
            name=fullfile(tempdir, File.Time(prefix, fileExt));
        end
        
        function ok=SaveMatrix(fileName, matrix, useLabels)
            if nargin<3
                useLabels=true;
            end
            if issparse(matrix)
                [row, col, V]=find(matrix);
                matrix=[row col V];
            end
            ok=false;
            try
                fileName=File.ExpandHomeSymbol(fileName);
                if useLabels
                    f = fopen(fileName,'w');
                    if f==-1
                        fileattrib(fileName, '+w');
                        f = fopen(fileName,'w');
                        if f<0
                            return;
                        end
                    end
                    [~,C]=size(matrix);
                    for c=1:C
                        if c>1
                            fprintf(f, ', ');
                        end
                        fprintf(f, 'column%d', c);
                    end
                    fprintf(f, '\n');
                    fclose(f);
                    if isinteger(matrix)
                        dlmwrite(fileName, matrix, '-append',  'precision', '%13d');
                    else
                        dlmwrite(fileName, matrix, '-append', 'precision', 13);
                    end
                else
                    csvwrite(fileName, matrix);
                end
                ok=true;
            catch ex
                ok=false;
                ex.getReport
            end
        end

        function [matrix, ok]=ReadMatrix(fileName)
            try
                fileName=File.ExpandHomeSymbol(fileName);
                matrix=csvread(fileName, 1);
                ok=true;
            catch ex
                matrix=[];
                ok=false;
                ex.getReport
            end
        end

        function fileName=ExpandHomeSymbol(fileName)
            if startsWith(fileName, '~')
                fileName=strrep(fileName, '~', File.Home);
            end
        end
        
        function props=ReadProperties(fileName, getEmpty)
            fileName=File.ExpandHomeSymbol(fileName);
            props=java.util.Properties;
            try
                fis=java.io.FileInputStream(strrep(fileName, '~', File.Home));
                props.load(fis);
                fis.close;
            catch ex
                fldr=fileparts(fileName);
                if isempty(fldr)
                    onMatLabPath=which(fileName);
                    if ~isempty(onMatLabPath)
                        warning(['Found properties on MatLab path?:  "' onMatLabPath '"']);
                        props=File.ReadProperties(onMatLabPath);
                        return;
                    end
                end
                if nargin<2 || ~getEmpty
                    ex.getReport
                    props=[];
                end
            end    
        end
        
        function props=GetProperties(fileName)
            props=File.ReadProperties(fileName, true);
        end
        
        function ok=SaveProperties2(fileName, props, headerString, sorted)
            ok=false;
            fid=[];
            try
                if nargin<3
                    headerString='';
                end
                fileName=File.ExpandHomeSymbol(fileName);
                if nargin<4 || ~sorted
                    fos=java.io.FileOutputStream(fileName);
                    props.save(fos, headerString);
                    fos.close;
                else
                    fid=fopen(fileName, 'wt');
                    ts=java.util.TreeSet(...
                        java.lang.String.CASE_INSENSITIVE_ORDER);
                    ts.addAll(props.keySet);
                    fprintf(fid, '#\n#%s\n', char(datetime));
                    it=ts.iterator;
                    while it.hasNext
                        next=char(it.next);
                        fprintf(fid, '%s=%s\n', next, ...
                            char(props.getProperty(next)));
                    end
                    fclose(fid);
                    fid=[];
                end
                ok=true;
            catch ex
                ex.getReport
                if ~isempty(fid)
                    fclose(fid);
                end
            end
        end
        
        function Log(info, severity, module)
            if nargin<3
                module='';
                if nargin<2
                    severity=0;
                end
            end
            log=sprintf('%s %s severity=%d info=%s\n', module, ...
                datestr(now),  severity, info, module);
            File.AppendTextFile(fullfile(File.Home, 'suh.log'), log);
        end
        
        
        function AppendTextFile(fileName, text)
            f=[];
            fileName=File.ExpandHomeSymbol(fileName);
            try
                f = fopen(fileName,'a');
                if f<0
                    return;
                end
                fwrite(f, text);
                fclose(f);
            catch ex
                ex.getReport
                if ~isempty(f)
                    fclose(f);
                end
            end
        end
        
        function SaveTextFile(fileName, text)
            f=[];
            fileName=File.ExpandHomeSymbol(fileName);
            try
                f = fopen(fileName,'w');
                if f==-1
                    fileattrib(fileName, '+w');
                    f = fopen(fileName,'w');
                    if f<0
                        return;
                    end
                end
                fwrite(f, text);
                fclose(f);
            catch ex
                ex.getReport
                if ~isempty(f)
                    fclose(f);
                end
            end
        end
        
        function fid=Save(nameOrFileHandle, joStyle, ci, ci2, labels,...
                matrix, close)
            if ischar(nameOrFileHandle)
                fid=fopen(nameOrFileHandle, 'w');
            else
                fid=nameOrFileHandle;
            end
            if joStyle
                eol='\r';
            else
                eol='\n';
            end
            N2=length(ci);
            if ~joStyle
                fprintf(fid, '\t');
            end
            for i = 1:N2
                fprintf(fid, '%s', labels{ci(i)});
                if i<N2
                    fprintf(fid, '\t');
                end
            end
            fprintf(fid, eol);
            for i = 1:N2
                if ~joStyle
                    fprintf(fid, '%s\t', labels{ci(i)});
                end
                for j = 1:N2
                    fprintf(fid, '%1.8f', matrix(ci2(i), ci2(j)));
                    if j<N2
                        fprintf(fid, '\t');
                    end
                end
                fprintf(fid, eol); 
            end
            fprintf(fid, eol);
            if nargin>6 && close
                fclose(fid);
            end
        end
        
        function ConfirmParentFolderExists(file)
            [folder, ~]=fileparts(file);
            File.mkDir(folder);
        end
        
        function [ok,errMsg, errId]=moveFile(from, to, force)
            ok=true;
            errMsg='';
            errId=0;            
            try
                removeFrom=false;
                if ispc
                    if ~contains(from, '*') &&...
                            ~contains(to, '*')
                        if exist(from, 'dir')
                            if ~exist(to, 'dir') && ~exist(to, 'file')
                                fromDir=from;
                                from=fullfile(from, '*.*');
                                File.mkDir(to);
                                removeFrom=true;
                                pause(.25);
                                exist(to)
                                disp('Avoiding windows Copy question yes/skip/cancel');
                            end
                        end
                    end
                end
                if nargin>2 && force
                    [ok,errMsg, errId]=movefile(from, to, 'f');                    
                else
                    [ok,errMsg, errId]=movefile(from, to);
                end
                if removeFrom
                    if exist(to, 'dir')
                        File.rmDir(fromDir);
                    end
                end
                if ~ok
                    disp(errMsg);
                end
            catch ex
                disp(ex);
            end
        end
        
        function [ok,errMsg, errId]=rmDir(to, killIfFile)
            ok=true;
            errMsg='';
            errId=0;
            if exist(to, 'dir')
                try
                    [ok,errMsg, errId]=rmdir(to, 's');
                catch ex
                    if exist([to sprintf('/Icon\r')], 'file')
                        delete([to sprintf('/Icon\r')]);
                        rmdir(to, 's');
                    end
                end
            elseif nargin>1 && killIfFile && exist(to, 'file')
                delete(to);
            elseif exist(to, 'file')
                [ok,errMsg, errId]=rmdir(to, 's');
            end
            if ~ok
                disp(errMsg);
            end
        end

        function [ok,errMsg, errId]=emptyDir(to, killIfFile)
            if nargin<2
                killIfFile=false;
            end
            File.rmDir(to, killIfFile);
            [ok,errMsg, errId]=File.mkDir(to);
        end


        function [ok,errMsg, errId]=mkDir(folder)
            errMsg='';
            errId=0;
            if isempty(folder)
                ok=true;
                return;
            end
            folder=File.ExpandHomeSymbol(folder);
            if exist(folder, 'dir')
                ok=true;
            else
                [ok, errMsg,errId]=mkdir(folder);
                if ~ok
                    disp(errMsg);
                end
            end
        end
    
        function path=TrimHome(path)
            if ~isempty(path)
                ur=File.Home;
                if startsWith(path, ur)
                    N=length(ur);
                    path=path(N+2:end);
                elseif startsWith(path, '~/')
                    path=path(3:end);
                end
            end
        end
        
        function path=TrimUserRoot(path)
            ur=File.Home;
            if ~isempty(path) && String.StartsWith(path, ur)
                N=length(ur);
                path=['HOME' String.SubString2(path, N+1, length(path)+1)];
            end
        end
                    
        function ok=isSameOrAncestor(ancestor, descendant)
            file_=File(descendant);
            ok=file_.countAncestors(ancestor)>=0;
        end
        
        function ok=endsWith( path, name )
            path=String.PruneSuffix(path, filesep);
            name=String.PruneSuffix(name, filesep);
            [p, f, ~]=fileparts(path);
            ok=strcmp(f,name);
        end
        
        function folder=parent(path)
            [folder,~,~]=fileparts(File.canonicalPath( path ) );
        end
        
        function  path=canonicalPath( path )
            path=File.absolutePath( path, false);
        end       
        
        function yes=isEmpty(filespec)
            files=dir(filespec);
            yes=false;
            if isempty(files)
                yes=true;
            else
                if length(files)==2
                    if isdir(filespec) || String.EndsWith(filespec,'*.*')
                        if strcmp(files(1).name,'.')
                            if strcmp(files(2).name, '..')
                                yes=true;
                            end
                        end
                    end
                end
            end                 
        end
        
        function ok=IsAbsolute(path)            
            f = java.io.File(path);
            ok=f.isAbsolute;
        end
        
        function [relativePath, parentFolderCount]=...
                GetSubPath(descendent, ancestor)
            relativePath=descendent;
            d=java.io.File(descendent);
            if d.isAbsolute
                p={};
                a=java.io.File(ancestor);
                while ~isempty(d)
                    if d.equals(a)
                        parentFolderCount=length(p);
                        if parentFolderCount==0
                            relativePath='';
                        else
                            for i=parentFolderCount:-1:1
                                if i==parentFolderCount
                                    relativePath=p{i};
                                else
                                    relativePath=[relativePath ...
                                        filesep p{i}];
                                end
                            end
                        end
                        return;
                    end
                    p{end+1}=char(d.getName);
                    d=d.getParentFile;
                end
            end
            parentFolderCount=-1;
        end
        
        function [path, added]=AddParentPath(fromPath, toPath)
            added=~File.IsAbsolute(fromPath);
            if ~added
                path=fromPath;
            else
                path=fullfile(toPath, fromPath);
            end
        end
        
        
        function abs_path=absolutePath( path,  throwErrorIfFileNotExist )            
            % 2nd parameter is optional:
            if nargin < 2
                throwErrorIfFileNotExist = false;
            end
            
            %build absolute path
            file = java.io.File(path);
            if ~file.isAbsolute()
                file=java.io.File(cd, path);
            end
            abs_path = char(file.getCanonicalPath());
            
            %check that file exists
            if throwErrorIfFileNotExist && ~exist(abs_path, 'file')
                throw(MException('absolutePath:fileNotExist', 'The file %s doesn''t exist', abs_path));
            end
        end
    
        function path=addSeparatorIfNecessary(path)
            if ~String.EndsWith(path, filesep)
                path=strcat(path,filesep);
            end
        end
        
        function [ok, parentFolder]=IsLastFolder(...
                path, lastFolder)
            ok=false;            
            f=java.io.File(path);
            parentFolder=char(f.getParent().toString());
            if f.isDirectory()
                if strcmp(f.getName(), lastFolder)
                    ok=true;
                end
            end
        end
        
        function name=Name(path)
            [~, name, ext]=fileparts(path);
            name=[name ext];
        end
        
        function folder=GetRoot(files, homePrefix)
            if nargin==1
                homePrefix=false;
            end
            N=length(files);
            if iscell(files) && N>0
                folder=File.getFolder(files{1});
                for i=2:N
                    if ~isempty(files{i})
                        folder=File.getCommon(folder, files{i});
                    end
                end
            else
                folder=File.getFolder(files);
            end
            folder=File.addSeparatorIfNecessary(folder);
            if homePrefix
                folder=File.TrimUserRoot(folder);
            end
        end
        
        function [folder]=getCommon(f1,f2)
            folder='/';
            while 1
                folder1=File.getFolder(f1);
                folder2=File.getFolder(f2);
                N1=length(folder1);
                N2=length(folder2);
                if N1<=N2
                    if strncmp(folder1, folder2, N1)
                        folder=folder1;
                        break;
                    end
                else
                    if strncmp(folder2, folder1, N2)
                        folder=folder2;
                        break;
                    end
                end
                [f1, ~, ~]=fileparts(folder1);
                [f2, ~, ~]=fileparts(folder2);
            end
        end
        
        function [folder]=getFolder(f)
            if isdir(f)
                folder=f;
            else
                [folder,~,~]=fileparts(f);
            end
            folder=File.canonicalPath(folder);
        end
        
        function [commonParentFolder, list]=Abbreviate(files)
            list={};
            if ~isempty(files)
                commonParentFolder=File.GetRoot(files);
                prefix=length(commonParentFolder)-1;
                N=length(files);
                for i=1:N
                    file=File.canonicalPath(files{i});
                    if ~isempty(file)
                        [path, name, ext]=fileparts(file);
                        N2=length(path);
                        if N2 < prefix
                            list{i}='.';
                        elseif N2 > prefix
                            subPath=path(1, [prefix+2:N2]);
                            list{i}=[name ext ' (in ' subPath ')'];
                        else
                            list{i}=[name ext];
                        end
                    end
                end
            else
                commonParentFolder='';
            end
        end
        
        
        function ok=ExistsOrOk(file, type)
            if ~isempty(file)
                if nargin == 1
                    type='This file';
                end
                file=File.ExpandHomeSymbol(file);
                if ~exist(file)
                    no='<html>Are you kidding?<br> .. no, no, NO!</html>';
                    yes='Sure .. (why not?)';
                    [folder,fileName, ext]=File.Parts(file);
                    ok=askYesOrNo(['<html>"'...
                        fileName ext ...
                        '" does not exist in <br>' ...
                        Html.FileTree(folder) '"'...
                        '<br><br><b><i>Do you '...
                        'wish to continue?</i></b><hr>'...
                        '</html>'], 'center',...
                        [type ' is not found '],false);
                else
                    ok=true;
                end
            else
                ok=false;
            end
        end
        
         function [ newPath, name, ext ] = Parts( path )
             %UNTITLED Summary of this function goes here
             %   Detailed explanation goes here
             [newPath, name, ext]=fileparts(path);
             if isempty(newPath)
                 newPath = ['.' filesep];
             else
                 newPath = strcat(newPath, filesep);
             end
         end
         
         function [list1, list2] = AddToLists(folder, file, list1, list2)
             item=[folder file ];
             idx=getnameidx(list1, item);
             if (idx==0)
                 list1{end+1}=item;
                 list2{end+1}=[file ' (' folder ')' ];
             end
         end
         
         function [set] = AddToSet(folder, file, set)
             item=[folder file ];
             idx=getnameidx(set, item);
             if (idx==0)
                 set{end+1}=item;
             end
         end
         function files=ToList(pathString, canonical)
             if strcmp('cell', class(pathString))
                 files=pathString;
                 return;
             end
             l=dir(pathString);
             if nargin==1
                 canonical=false;
             end
             if canonical
                 pathString=File.canonicalPath(pathString);
             end
             [p, ~, ~]=File.Parts(pathString);
             n=length(l);
             files=cell(1, n);
             for i=1:n
                 f=[p l(i).name];
                 files{i}=f;
             end
         end

         
         function home=Home(varargin)
             home=char( java.lang.System.getProperty('user.home') );
             if ~isempty(varargin)
                 home=fullfile(home,  varargin{:});
             end
         end
         
         function desktop=DeskTop(varargin)
             desktop=fullfile(File.Home, 'Desktop',...
                 varargin{:});
         end
         
         function drive=GoogleDrive(varargin)
             root=fullfile(File.Home, 'Google Drive');
             if exist(root, 'dir')
                 drive=fullfile(root, varargin{:});
             elseif ispc
                 root='G:\My Drive';
                 if exist(root, 'dir')
                    drive=fullfile(root, varargin{:});
                 else
                     error(['Cannot find Google Drive either at G:\My Drive\ or at ' ...
                         File.Home('GoogleDrive') '\ !!']);
                 end
             else
                 error(['Cannot find Google Drive at ' File.Home('GoogleDrive') ...
                     '\  !!']);
             end
         end

         function documents=Documents(varargin)
             documents=fullfile(File.Home, 'Documents',...
                 varargin{:});
         end
         
         function downloads=Downloads(varargin)
             downloads=fullfile(File.Home, 'Downloads',...
                 varargin{:});
         end
         
         function [ok, file]=SwitchRoot(file, sub)
            str=fullfile(File.Home, sub, filesep);
            if startsWith(file, str )
                idx=length(str);
                if isempty(sub)
                    [~,f,e]=fileparts(File.Home);
                    sub=[f e];
                end
                file=fullfile(sub, file(idx+1:end));
                ok=true;
            else
                ok=false;                
            end
        end
        
        function [abbreviation, ok]=AbbreviateRoot(file, forHtml)
            home=File.Home;
            if ~startsWith(file, home)
                abbreviation=file;
                ok=false;
                return;
            end
            if nargin<2
                forHtml=false;
            end
            [ok, abbreviation]=clip(file, 'Desktop');
            if ~ok
                [ok, abbreviation]=clip(file, 'Documents');
                if ~ok
                    [ok, abbreviation]=clip(file, 'Downloads');
                    if ~ok
                        [ok, abbreviation]=clip(file, 'Google Drive');
                        if ~ok
                            [ok, abbreviation]=clip(file, '');
                            if ~ok
                                abbreviation=file;
                            end
                        end
                    end
                end
            end
            function [ok, file]=clip(file, sub)
                str=fullfile(home, sub, filesep);
                if startsWith(file, str )
                    idx=length(str);
                    if isempty(sub)
                        [~,f,e]=fileparts(home);
                        sub=[f e];
                    end
                    if ~forHtml
                        file=fullfile(sub, file(idx+1:end));
                    else
                        file=['&lt;' sub '&gt;'  file(idx:end)];
                    end
                    ok=true;
                else
                    ok=false;
                end
            end
            
        end
        
        function description=Describe(file)
            [folder,name,ext]=fileparts(file);
            [folder, parentName, parentExt]=fileparts(folder);
            folder=File.AbbreviateRoot(folder);
            description=[parentName parentExt filesep name ext ' (in ' folder ')'];
        end
        
        function files=FindAll(path, fileSpec)
            l=dir(path);
            N=length(l);
            files={};
            for i=1:N
                d=l(i);
                if d.isdir && ~String.StartsWith(d.name, '.')
                    subFiles=File.FindAll(fullfile(path, d.name), fileSpec);
                    if ~isempty(subFiles)
                        if isempty(files)
                            files=subFiles;
                        else
                            files=[files(1,:) subFiles(1,:)];
                        end
                    end
                end
            end
            l=dir(fullfile(path,fileSpec));
            N=length(l);
            subPath=fileparts(fileSpec);
            for i=1:N
                f=fullfile(path, subPath, l(i).name);
                if ~l(i).isdir
                    files{end+1}=f;
                end
            end
        end
        function txt=ReadTextFile(file)
            txt=char(edu.stanford.facs.swing.CpuInfo.readTextFile(file));
        end
        function yes=AreEqual(fileName1, fileName2)
            file_1 = javaObject('java.io.File', fileName1);
            file_2 = javaObject('java.io.File', fileName2);
            yes=javaMethod('contentEquals','org.apache.commons.io.FileUtils',...
                file_1, file_2);
        end
        function yes=TextFilesAreEqual(file1, file2)
            yes=false;
            fid1 = fopen(file1, 'r');
            fid2 = fopen(file2, 'r');
            if fid1 ~= -1 && fid2 ~= -1
                lines1 = textscan(fid1,'%s','delimiter','\n');
                lines2 = textscan(fid2,'%s','delimiter','\n');
                lines1 = lines1{1};
                lines2=lines2{1};
                yes = isequal(lines1,lines2);
            end
            
            if fid1~=-1
                fclose(fid1);
            end
            if fid2~= -1
                fclose(fid2);
            end
        end
        
        function ok=WriteTextFile(fileName, textOrLinesOfText)
            if isnumeric(textOrLinesOfText)
                textOrLinesOfText=MatBasics.ToStrs(textOrLinesOfText);
            end
            try
                fileName=File.ExpandHomeSymbol(fileName);
                fid=fopen(fileName, 'wt');
                N=length(textOrLinesOfText);
                if isa(textOrLinesOfText, 'java.lang.Object[]')
                    for i=1:N
                        fprintf(fid, '%s\n', textOrLinesOfText(i));
                    end
                elseif iscell(textOrLinesOfText) 
                    for i=1:N
                        fprintf(fid, '%s\n', textOrLinesOfText{i});
                    end
                else
                    fprintf(fid, '%s\n', char(textOrLinesOfText));
                end
                fclose(fid);
                ok=true;
            catch ex
                disp(ex.message);
                ok=false;
            end
        end
        
        function file=FindFirst(path, fileSpec)
            file=[];
            l=dir(fullfile(path,fileSpec));
            N=length(l);
            for i=1:N
                f=fullfile(path, fileparts(fileSpec), l(i).name);
                if ~l(i).isdir
                    file=f;
                    return;
                end
            end
            l=dir(path);
            isub = [l(:).isdir]; %# returns logical vector
            nameFolds = {l(isub).name}';
            N=length(nameFolds);
            for i=1:N
                d=nameFolds{i};
                if d(1) ~= '.'
                    subFile=File.FindFirst(fullfile(path, d), fileSpec);
                    if ~isempty(subFile)
                        file=subFile;
                        return;
                    end
                end
            end
        end
        
        function SaveProperties(p,f, sortKeys)
            l={};
            if sortKeys
                ts=java.util.TreeSet(...
                    java.lang.String.CASE_INSENSITIVE_ORDER);
                ts.addAll(p.keySet);
                ks=ts.iterator;
            else
                ks=p.keySet.iterator;
            end
            while ks.hasNext
                k=char(ks.next);
                v=char(p.get(k));
                l{end+1}=[k '=' v];
            end
            File.WriteTextFile(f, l);
        end
        
        function out=Html(path)
            out='';
            if isempty(path)
                return;
            end
            cnt=0;
            home=File.Home;
            prefix='';
            originalPath=path;
            while true
                priorPath=path;
            
                [path, name, ext]=fileparts(path);
                cnt=cnt+1;
                if cnt==1
                    out=[name ext out];
                elseif cnt==2
                    out=[name ext filesep out];
                end
                if isempty(path) || length(path)<=3
                    break;
                elseif isequal([home filesep 'Documents'], path)
                    prefix=['<b>~' filesep 'Documents</b>'];
                    break;
                elseif isequal([home filesep 'Desktop'], path)
                    prefix=['<b>~' filesep 'Desktop</b>'];
                    break;
                elseif isequal(home, path)
                    prefix=['<b>~</b>'];
                    break;
                elseif isequal(priorPath, path)
                    warning('Infinite loop parsing "%s"', originalPath);
                    break;
                end
            end
            if cnt-2>0
                out=[prefix filesep '<i><font color=''blue''>' ...
                    String.Pluralize2('folder', ...
                    cnt-2) '</font></i>' filesep out ];
            else
                out=[prefix filesep out];
            end
        end
        
        function [bytes, map]=DirRecursive(folder, spec, parent, map, cur, pu)
            if nargin<6
                pu=[];
                if nargin<5
                    cur=[];
                    if nargin<4
                        %map=java.util.TreeMap;
                        map=[];
                        if nargin<3
                            parent=[];
                        end
                    end
                end
            end
            if isempty(map)
                %map=java.util.TreeMap;
                map=TreeMapOfMany;
            end
            bytes=0;
            fsp=fullfile(folder,spec);
            diskItems=dir(fsp);
            N=length(diskItems);
            if isempty(cur)
                cur=now;
            end
            if isempty(parent)
                scan=true;
            else
                idx=String.LastIndexOf(folder, filesep);
                if idx>0
                    lastPath=String.SubString(folder, idx+1);
                    scan=strcmp(lastPath, parent);
                else
                    scan=false;
                end
            end
            if scan
                if ~isempty(pu)
                    pu.setText2([String.Pluralize2('file', N) ...
                        ' in ' File.Html(folder) ]);
                    if File.DEBUG>0
                        disp([String.Pluralize2('file', N) ...
                        ' in ' File.Html(folder) ])
                    end
                end
                for i=1:N
                    fl=diskItems(i);
                    fname=fl.name;
                    if ~fl.isdir
                        elapsed=cur-fl.datenum;
                        path=fullfile(folder, fname);
                        if File.DEBUG>1 && map.containsKey(elapsed)
                            fprintf(['%s size=%s, elapsed=%s, '...
                                'prior=%s\n'], fname, ...
                                String.encodeInteger(fl.bytes), ...
                                String.encodeRounded(elapsed, 3), ...
                                map.get(elapsed));
                        end
                        map.put(elapsed, path);
                        bytes=bytes+fl.bytes;                        
                    end
                end
                if ~isempty(pu) && pu.cancelled
                    return;
                end
            end
            if ~isempty(parent)
                path=fullfile(folder, parent);
                if exist(path, 'dir')
                    bytes=bytes+...
                        File.DirRecursive(path, spec, parent, map, cur, pu);
                end
            end
            fsp=folder;
            diskItems=dir(fsp);
            N=length(diskItems);
            for i=1:N
                fl=diskItems(i);
                fname=fl.name;
                if fl.isdir
                    if ~strcmp('.', fname) && ~strcmp('..', fname)
                        if isempty(parent) || ~strcmp(fname, parent)
                            path=fullfile(folder, fname);
                            bytes_=File.DirRecursive(path, spec, parent, map, cur, pu);
                            bytes=bytes+bytes_;
                        end
                    end
                    if ~isempty(pu) && pu.cancelled
                        return;
                    end
                end
            end            
        end
        
        function [bytes, items]=DiskUsage(folder, spec, olderThanDays, pu, cur)
            if nargin<5
                cur=now;
                if nargin<4
                    pu=[];
                    if nargin<3
                        olderThanDays=0;
                    end
                end
            end
            bytes=0;
            items=0;
            fsp=fullfile(folder,spec);
            diskItems=dir(fsp);
            N=length(diskItems);
            if ~isempty(pu)
                pu.setText2([String.Pluralize2('file', N) ...
                    ' in ' File.Html(folder) ]);
                if File.DEBUG>0
                    disp([String.Pluralize2('file', N) ...
                        ' in ' File.Html(folder) ])
                end
            end
            for i=1:N
                fl=diskItems(i);
                if ~fl.isdir
                    if olderThanDays==0
                        bytes=bytes+fl.bytes;
                        items=items+1;
                    else
                        if cur-fl.datenum>olderThanDays
                            bytes=bytes+fl.bytes;
                            items=items+1;
                        end
                    end
                end
            end
            if ~isempty(pu) && pu.cancelled
                return;
            end            
            fsp=folder;
            diskItems=dir(fsp);
            N=length(diskItems);
            for i=1:N
                fl=diskItems(i);
                fname=fl.name;
                if fl.isdir
                    if ~strcmp('.', fname) && ~strcmp('..', fname)
                        path=fullfile(folder, fname);
                        [bytes_, items_]=File.DiskUsage(...
                            path, spec, olderThanDays, pu, cur);
                        bytes=bytes+bytes_;
                        items=items+items_;
                    end
                    if ~isempty(pu) && pu.cancelled
                        return;
                    end
                end
            end            
        end
        
        function subFolders=ParseLsStdOut(std)
            subFolders={};
            xxx=regexp(std, '([^ \t\n\r]*)', 'tokens');
            N=length(xxx);
            for i=1:N
                fn=xxx{i}{1};
                if ~String.EndsWith(fn, './')
                    subFolders{end+1}=fn;
                end
            end
        end
        
        function subFolders=GetSubFolders(folder)
            subFolders={};
            if ismac
                [~, std1]=system(['ls -a -d ' folder '/*/']);
                [~, std2]=system(['ls -a -d ' folder '/.*/']);
                subFolders=[ File.ParseLsStdOut(std1) ...
                    File.ParseLsStdOut(std2)];
            end
        end
        
        function Touch(fn)
            java.io.File(fn).setLastModified(java.lang.System.currentTimeMillis);
        end
        
        function [status, stdout]=Spawn(scriptLines, scriptFile, ...
                terminalName, runInBackground, showSpawnWindow)
            if nargin<5
                showSpawnWindow=false;
                if nargin<4
                    runInBackground=true;
                end
            end
            wnd=get(0, 'currentFig');
            [~, scriptF, scriptExt]=fileparts(scriptFile);
            doneFile=fullfile(File.Home, [scriptF scriptExt '.done']);
            if exist(doneFile, 'file')
                delete(doneFile);
            end
            makeDone=['echo > ' String.ToSystem(doneFile)];
            if ismac         
                setTerminalName=['echo -n -e "\033]0;' terminalName '\007"'];
                closeTerminal=['osascript -e ''tell application '...
                    '"Terminal" to close (every window whose name '...
                    'contains "' terminalName '")'' &'];
                if iscell(scriptLines)
                    strs=[setTerminalName, scriptLines, makeDone, ...
                        closeTerminal, 'exit'];
                else
                    strs={setTerminalName, scriptLines, makeDone, ...
                        closeTerminal, 'exit'};
                end
                File.WriteTextFile(scriptFile, strs);
                scriptCmd=String.ToSystem(scriptFile);
                system(['chmod 777 ' scriptCmd]);
                if showSpawnWindow || runInBackground
                    cmd=['open -b com.apple.terminal ' scriptCmd];
                else
                    cmd=scriptCmd;
                end
            else
                if iscell(scriptLines)
                    N=length(scriptLines);
                    strs=cell(1,N+2);
                    for i=1:N
                        strs{i}=[scriptLines{i} ' < nul'];
                    end
                    strs{end-1}=makeDone;
                    strs{end}='exit';
                else
                    strs={[scriptLines ' < nul'], makeDone, 'exit'};
                end
                File.WriteTextFile(scriptFile, strs);
                scriptCmd=String.ToSystem(scriptFile);
                if showSpawnWindow || runInBackground
                    cmd=[scriptCmd ' &'];
                else
                    cmd=scriptCmd;
                end
            end
            if ~runInBackground && ~isempty(terminalName)
                disp(terminalName);
            end
            [status, stdout]=system(cmd);
            if ~runInBackground
                if showSpawnWindow
                    File.Wait(doneFile, wnd, [], terminalName);
                end
            end            
        end
        
        function Wait(outFile, fig, btn, txt)
            if isempty(fig)
                fig=0;
            end
            setappdata(fig, 'canceling', 0);
            pu=PopUp(txt, 'west',...
                'Stand by, patience ....', false, ...
                @(h,e)cancel);
            set(pu.dlg, 'WindowClosingCallback', @(h,e)closeWnd());
            
            set(btn, 'visible', 'off');
            drawnow;
            done=false;
            was=pause('query');
            pause('on');
            canceled=0;
            closed=false;
            while ~done
                if ~ishandle(fig)
                    return;
                end
                try
                    if exist(outFile, 'file')
                        done=true;
                    elseif getappdata(fig, 'canceling')
                        canceled=canceled+1;
                        break;
                    elseif canceled>3 % hung?
                        break;
                    end
                    if closed
                        pu.dlg.dispose;
                        break;
                    end
                catch ex
                    ex.getReport
                    pu.close;
                    return;
                end
                pause(2);
            end
            pause(was);
            setappdata(fig, 'canceling', 0);
            set(btn, 'visible', 'on');
            pu.close;
            
            function cancel
                if canceled==0
                    pu.setText('Cancelling this process');
                end
                setappdata(fig, 'canceling', 1);
            end
            function closeWnd
                if canceled==0
                    cancel;
                else
                    closed=true;
                end
            end
        end
        

        function DeleteOld(folder, spec, olderThanDays, pu, fileCnt)
            txt1=sprintf('&gt; %s days old', String.encodeInteger(olderThanDays));
            txt2=sprintf('<html>Finding %s files %s in %s</html>', spec, txt1, File.Html(folder));
            if nargin<4
                pu=PopUp(txt2, 'center', 'Deleting ...', true, true);
            end
            if File.DEBUG>0
                disp(txt2)
            end
            [bytes, tm]=File.DirRecursive(folder, spec);
            if nargin<5
                fileCnt=tm.size;
            end
            if File.DEBUG>0
                fprintf('%d files occupying %s in subfolders below %s\n',...
                    fileCnt, String.encodeBytes(bytes), folder);
            end
            File.DeleteByAge(tm, 0, bytes, olderThanDays, pu, fileCnt);
            if nargin<4
                pu.close;
            end
        end
        
        function [fileCnt, bytes]=DeleteByAge(tm, byteLimit, ...
                totalBytes, olderThanDays, pu, totalFiles)
            it=tm.map.descendingKeySet.iterator;
            fileCnt=0;
            txtByteLimit=String.encodeBytes(byteLimit);
            if nargin>4
                if nargin==5
                    totalFiles=tm.size;
                end
                pu.initProgress(totalFiles);
                reportAt=ceil(totalFiles/25);
            end
            while it.hasNext
                days=it.next;
                if olderThanDays>0 && days<=olderThanDays
                    return;
                end
                fileIt=tm.getIterator(days);
                while fileIt.hasNext
                    if byteLimit >0 && totalBytes<byteLimit
                        return;
                    end
                    path=fileIt.next;
                    diskItem=dir(path);
                    bytes=diskItem(1).bytes;
                    totalBytes=totalBytes-bytes;
                    fileCnt=fileCnt+1;
                    if File.DEBUG>0
                        fprintf(['#%s %s days old, %s bytes leaving ' ...
                            '%s/%s\n\t\t--> ..%s\n'], ...
                            String.encodeInteger(fileCnt), ...
                            String.encodeRounded(days),...
                            String.encodeBytes(bytes),...
                            String.encodeBytes(totalBytes),...
                            txtByteLimit,...
                            String.RemoveXml(File.Html(path)));
                    end
                    if nargin>4
                        if mod(fileCnt, reportAt)==0
                            pu.incrementProgress(reportAt);
                        end
                    end
                    delete(path);
                end
            end
        end
        
        function ExportToolBar(tb, gt, labels, data, filterCols, ...
                file, subFolder, property, jtable)
            if nargin<6
                jtable=[];
            end
            ToolBarMethods.addButton(tb, ...
                'save16.gif', 'Export to excel and other file formats', ...
                @(h,e)export(h));
            
            function export(h)
                
                if ~isempty(jtable)
                    filterRows=SortTable.ModelRows(jtable);
                    filterCols2=SortTable.ModelCols(jtable);
                    if ~isempty(filterCols)
                        l=ismember(filterCols2, filterCols);
                        filterCols2=filterCols2(l);
                    end
                    labels2=labels(filterCols2);
                    data2=data(filterRows, filterCols2);
                elseif ~isempty(filterCols)
                    labels2=labels(filterCols);
                    data2=data(:,filterCols);
                else
                    labels2=labels;
                    data2=data;
                end
                File.Export([labels2;data2], gt, file, subFolder, property);
            end
        end
        
        function file=Export(tabLines, gtOrRootFldr, suggestedFile, ...
                subFolder, property, hasImgs, colSplit, rowSplit, cmp)
            if nargin<9
                cmp=[];
                if nargin<8
                    rowSplit=1;
                    if nargin<7
                        colSplit=1;
                        if nargin<6
                            hasImgs=false;
                            if nargin<5
                                property='statsFolder';
                                if nargin<4
                                    subFolder='exports';
                                    if nargin<3
                                        suggestedFile='exported';
                                        if nargin<2
                                            gtOrRootFldr=[];
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            if ~isa(gtOrRootFldr, 'GatingTree')
                rootFolder=gtOrRootFldr;
                app=CytoGate.Get;
                props=app;
            else
                gt=gtOrRootFldr;
                rootFolder=gt.app.stripIfUnderUrlFolder(gt.rootFolder, ...
                    CytoGate.Folder);
                props=gt.multiProps;
                app=gt.app;
            end
            if iscell(tabLines)
                tabLines=CellBasics.ToTabLines(tabLines);
            end
            app.currentJavaWindow=cmp;
            CytoGate.setHelp('AG_Export');
            exportType=props.getNumeric(File.PROP_EXPORT, 1);
            types=File.EXPORT_TYPES;
            N=size(types, 1);
            types2={};            
            types2(end+1,:)=types(exportType,:);
            for i=1:N
                if i~=exportType
                    types2(end+1,:)=types(i,:);
                end
            end
            if isempty(rootFolder)
                rootFolder=File.Home;
            end
            File.mkDir(fullfile(rootFolder, subFolder));
            file=File.GetOutputFile(rootFolder, subFolder, suggestedFile,...
                props, property, types2, 'Export to ...');
            if ~isempty(file)
                if String.EndsWithI(file, '.csv')
                    stObj=javaObjectEDT('edu.stanford.facs.swing.Basics');
                    data=StringArray.Cell(stObj.tabToCsv(tabLines));
                    props.set(File.PROP_EXPORT, '2');
                else
                    data=StringArray.Cell(tabLines);
                    props.set(File.PROP_EXPORT, '1');
                end
                if String.EndsWithI(file, '.xls')
                    props.set(File.PROP_EXPORT, '3');
                    if hasImgs
                        embedGateImg=props.is(File.PROP_XLS_IMG, false);
                        [embedGateImg, cancelled]=askYesOrNo(...
                            'Embed images into the worksheet?',...
                            'Confirm...', 'North', embedGateImg, ...
                            [File.PROP_XLS_IMG 'Rid']);
                        if cancelled
                            app.currentJavaWindow=[];
                            return;
                        end                         
                        props.setBoolean(File.PROP_XLS_IMG, embedGateImg);
                        if embedGateImg
                            gateImgFolder=fullfile(rootFolder, CytoGate.Folder);
                        else
                            gateImgFolder=[];
                        end
                    else
                        gateImgFolder=[];
                    end
                    file2=[file '.txt'];
                    File.WriteTextFile(file2, data);
                    if exist(file, 'file')
                        dflt=props.getNumeric(File.PROP_XLS_ADD, 1);
                        choices={'Add a new worksheet to the workbook', ...
                            'Overwrite (erase & recreate) the workbook'};
                        [answ,  cancelled]=mnuMultiDlg(...
                            'This workbook file exists ...', 'Caution...', ...
                            choices, dflt, true, true);
                        if cancelled
                            return;
                        end
                        if answ==2
                            delete(file);
                        end
                        props.set(File.PROP_XLS_ADD, num2str(answ));
                    end
                    makeXlsExternal(file2, file, colSplit, rowSplit, gateImgFolder);
                    %delete(file2);
                    openXlsNow=props.is(File.PROP_XLS_OPEN, false);
                    app.currentJavaWindow=[];
                    if openXlsNow
                        if ismac
                            system(['open ' String.ToSystem(file)]);
                        else
                            system(String.ToSystem(file));
                        end
                    end
                    delete([file '.txt']);
                else
                    File.WriteTextFile(file, data);
                end
                File.OpenFolderWindow(file);
            end
            app.currentJavaWindow=[];     
        end

        function OpenFolderWindow(file, rememberId, ask)
            if ~isempty(file)
                app=BasicMap.Global;
                if nargin<3
                    ask=true;
                    if nargin<2
                        rememberId='openFolder';
                    end
                end
                if ~ask || askYesOrNo(Html.WrapHr(['Open folder window now?'...
                        '<br><br>' Html.FileTree(file) ...
                        ')']), 'Confirm...', 'center', true, rememberId)
                    fldr=fileparts(file);
                    fldr=String.ToSystem(fldr);
                    if ispc
                        system(['explorer ' fldr]);
                    else
                        system(['open ' fldr]);
                    end
                end
            end
        end
        
        function [file, folder, fileName]=...
                GetOutputFile(rootFolder, suggestedSubFolder, fileName, ...
                properties, property, types, tip)
            if nargin==0
                rootFolder=File.Home;
                suggestedSubFolder='outputs';
                fileName='output';
                properties=[];
                types={'*.txt', 'MATLAB storage file'};
                tip='MATLAB storage';
            end
            app=BasicMap.Global;
            try
                parentFolder=app.stripIfUnderUrlFolder(rootFolder, '.autoGate');
            catch ex
                parentFolder=rootFolder;
            end
            if ~isempty(suggestedSubFolder)
                suggestedSubFolder=fullfile(parentFolder, suggestedSubFolder);
            else
                suggestedSubFolder=parentFolder;
            end
            if ~isempty(properties)
                fullFolder=properties.get(property, suggestedSubFolder);
            else
                fullFolder=suggestedSubFolder;
            end
            fullFile=fullfile(fullFolder, fileName);
            fullFile=File.SwitchExtension(fullFile, types{1,1});
            File.mkDir(suggestedSubFolder);
            [fileName, folder]=uiputfile(types, tip, fullFile);
            file=fullfile(folder,fileName);
            if ~isnumeric(folder) && ~isempty(properties)
                properties.set(property, folder);
            else
                file=[];
                folder=[];
                fileName=[];
            end
        end
        
        function names=CsvNames(t)
            names={};
            try
                names=t.Properties.VariableNames;
                N=length(names);
                vd=t.Properties.VariableDescriptions;
                if length(vd)==N
                    prefix='Original column heading: ''';
                    idx=length(prefix)+1;
                    for i=1:N
                        dsc=vd{i};
                        if String.StartsWith(dsc, prefix)
                            str=dsc(idx:end-1);
                            N2=length(str);
                            for j=1:N2
                                firstChar=double(str(j));
                                if firstChar>=30 && firstChar<=128
                                    break;
                                end
                            end
                            if j>1 && j<=N2
                                str=str(j:end);
                            end
                            names{i}=str;
                        elseif ~isempty(dsc)
                            names{i}=dsc;
                        end
                    end
                end
            catch ex
                ex.getReport
            end
        end
        
        function ok=WriteCsvFile(csvFile, numbers, cHeader, precision)
            if nargin<4
                precision=[];
                if nargin<3
                    [R,C]=size(numbers);
                    cHeader=cell(1,C);
                    for i=1:C
                        cHeader{i} = ['col ' num2str(i+1)];
                    end
                end
            end
            commaHeader = [cHeader;repmat({','},1,numel(cHeader))]; %insert commaas
            commaHeader = commaHeader(:)';
            textHeader = cell2mat(commaHeader); %cHeader in text with commas
            %write header to file
            
            fid = fopen(csvFile,'w');
            if textHeader(end)==','
                fprintf(fid,'%s\n',textHeader(1:end-1));
            else
                fprintf(fid,'%s\n',textHeader);
            end
            fclose(fid);
            if ~isempty(numbers)
                %write data to end of file
                if isempty(precision)
                    dlmwrite(csvFile, numbers,'-append');
                else
                    dlmwrite(csvFile, numbers,'-append', 'precision', precision);
                end
            end
        end
        
        function ok=WriteTabFile(tabFile, numbers, cHeader, precision)
            C=size(numbers, 2 );   
            if nargin<4
                precision=[];
                if nargin<3
                    cHeader=cell(1,C);
                    for i=1:C
                        cHeader{i} = ['col ' num2str(i+1)];
                    end
                end
            end
            %write header to file
            
            fid = fopen(tabFile,'w');
            for i=1:C
                if i==C
                    fprintf(fid,'%s\n',cHeader{i});
                else
                    fprintf(fid,'%s\t',cHeader{i});
                end
            end
            fclose(fid);
            %write data to end of file
            if isempty(precision)
                dlmwrite(tabFile, numbers,'-append', 'delimiter', '\t')
            else
                dlmwrite(tabFile, numbers,'-append', 'delimiter', '\t', 'precision', precision);
            end
        end
        
        function [columnNames, label_column_index]=ReadCsvHeader(csvFile, javaWindow)
            columnNames={};
            label_column_index=0;
            try
                fid = fopen(csvFile, 'r');
                found=false; row=1; rows=5;% find in first 5 rows hopefully
                while ~found && row<rows
                    line = fgetl(fid);
                    if ~isempty(line)
                        columnNames=split(line, ',');
                        if ~isempty(columnNames)
                            columnNames=columnNames';
                            if ~isempty(columnNames)&& ...
                                    isempty(columnNames{end})
                                columnNames(end)=[];
                            end
                            break;
                        end
                    end
                    row=row+1;
                end
                fclose(fid);
                if nargout>1
                    if nargin<2
                        javaWindow=[];
                    end
                    [pnlList, J]=Gui.NewListSearch([...
                        ['<None>'], columnNames], 'Find label', ...
                        [], 'Pick the column that contains labels',...
                        @(h,e)listSelect(e));
                    Gui.SetSingleSelection(J)
                    J.setVisibleRowCount(10);
                    pnl=Gui.BorderPanel;
                    pnl.add(javax.swing.JLabel('Choose a "label column"'), 'North');
                    pnl.add(pnlList, 'Center');
                    [~, ~, cancelled]=questDlg(struct('msg', pnl, ...
                        'javaWindow', javaWindow), 'Make choice...', ...
                        'Save', 'Cancel', 'Save');
                    if ~cancelled
                        label_column_index=StringArray.IndexOf(...
                            columnNames, char(J.getSelectedValue));
                    else
                        label_column_index=-1;
                    end
                end
            catch ex
                ex.getReport
            end
            
            function listSelect(e)
                if ~isempty(e) 
                    if e.getClickCount==2
                        w=Gui.WindowAncestor(J);
                        btn=w.getRootPane.getDefaultButton;
                        btn.doClick;
                    end
                end
            end
        end
        
        function [inData, columnNames, table]=ReadCsv(csvFile, mustBeNumbers)
            if nargin<2
                mustBeNumbers=true;
            end
            warning('OFF', 'MATLAB:table:ModifiedAndSavedVarnames');
            table=[];
            try
                csvFile=WebDownload.GetExampleIfMissing(csvFile);
                table=readtable(File.ExpandHomeSymbol(csvFile),...
                    'ReadVariableNames', true);
            catch ex
                inData=[];
                columnNames=[];
                ex.getReport
                return;
            end
            last1Bad=false;
            try
                inData=table2array(table);
                if verLessThan('matlab', '9.6')
                    if all(isnan(inData(:,end)))
                        C=size(inData,2);
                        if isequal(['Var' num2str(C)], ...
                                table.Properties.VariableNames{end}) ...
                                && isequal('', ...
                                table.Properties.VariableDescriptions{end})
                            last1Bad=true;
                            inData(:,end)=[];
                        end
                    end
                end
            catch ex
                if verLessThan('matlab', '9.6')
                    inData=[];
                    columnNames=[];
                    ex.getReport
                    return;
                end
                last1Bad=false;
                table=removevars(table, table.Properties.VariableNames{end});
                inData=table2array(table);
            end
            if nargout>1
                columnNames=File.CsvNames(table);
                if last1Bad
                    columnNames(end)=[];
                end
            end
            if iscell(inData) && mustBeNumbers
                inData=[];
                columnNames=[];
                warning('comma separated file does NOT contain numbers');
            end
        end
        
        
        function [table, columnNames]=ReadTable(csvFile)
            warning('OFF', 'MATLAB:table:ModifiedAndSavedVarnames');
            table=[];
            try
                table=readtable(File.ExpandHomeSymbol(csvFile), ...
                    'ReadVariableNames', true);
            catch ex
                table=[];
                columnNames=[];
                ex.getReport
                return;
            end
            if nargout>1
                columnNames=File.CsvNames(table);
                
            end
        end
        
        function out=Time(prefix, ext)
            if nargin<2
                ext='';
                if nargin<1
                    prefix='';
                end
            elseif ~startsWith(ext, '.')
                ext=['.' ext];
            end
            if ~isempty(prefix)
                prefix=[prefix '_'];
            end
            out=String.ToFile([prefix char(datetime( ...
                'now','Format','d-MMM-y HH_mm_ss')) ...
                ext]);
        end
        
        function yes=WantsDefaultFolder(dfltFolder, question)
            if nargin<2
                question='Look in default folder?';
            end
            [~,yes]=questDlg(['<html>' question '<br>'...
             Html.FileTree(dfltFolder) ...
             '<center><br><hr>Yes ???</center><hr></html>']);
        end
        
        function [folder, file]=PutFile(dfltFolder, dfltFile, props, ...
                property, ttl, longTtl, ext)
            if nargin<7
                ext=[];
                if nargin<6
                    longTtl='Save to which folder & file?';
                    if nargin<5
                        ttl='Save file...';
                        if nargin<4
                            property=[];
                            if nargin<3
                                props=[];
                            end
                        end
                    end
                end
            end
            privFldr=fileparts(tempname);
            [lastFolder, fn, fe]=fileparts(dfltFile);
            if isempty(ext)
                ext=fe;
            end
            File.mkDir(dfltFolder);
            if isempty(lastFolder) || isequal(privFldr, lastFolder)
                fn=File.Time;
                if ~isempty(props) && ~isempty(property)
                    lastFolder=props.get(property, dfltFolder);
                else
                    lastFolder=dfltFolder;
                end
            end
            lIdx=String.LastIndexOf(lastFolder, File.Home);
            if lIdx>2
                lastFolder=lastFolder(lIdx:end);
            end
            if endsWith(lastFolder, '.autoGate')
                lastFolder=fileparts(lastFolder);
            end
            done=false;
            if ismac
                jd=Gui.MsgAtTopScreen(longTtl, 25);
            else
                jd=[];
            end
            while ~done
                done=true;
                [file, folder]=uiputfile(['*' ext], ttl, ...
                    fullfile(lastFolder, [fn ext]));
                if ~isempty(jd)
                    jd.dispose;
                end
                if isempty(folder) || isnumeric(folder)
                    folder=[];
                    file=[];
                    if isequal(dfltFolder, lastFolder)
                        return;
                    end
                    if isequal([dfltFolder filesep], lastFolder)
                        return;
                    end
                    if isequal(dfltFolder, [lastFolder filesep])
                        return;
                    end
                    app=BasicMap.Global;
                    checkDflt=true;
                    if ~isempty(props) && ~isempty(property)
                        propFldr=props.get(property, dfltFolder);
                        if ~isequal(propFldr, dfltFolder)
                            choices{1}=dfltFolder;
                            choices{end+1}=propFldr;
                            answer=Gui.Ask('Check other locations?', choices, ...
                                [property '.other'], 'Confirm...');
                            if isempty(answer)
                                folder=[];
                                file=[];
                                return;
                            end
                            checkDflt=false;
                            dfltFolder=choices{answer};
                        end
                    end
                    if checkDflt
                        if ~File.WantsDefaultFolder(dfltFolder)
                            return;
                        end
                    end
                    [file, folder]=uiputfile(['*' ext], ...
                        'Save to which folder & file?', ...
                        fullfile(dfltFolder, [fn ext]));
                    if isempty(folder)|| isnumeric(folder)
                        folder=[];
                        file=[];
                        return;
                    end
                end
            end
            if ~isempty(props) && ~isempty(property)
                props.set(property, folder);
            end
            file=File.SwitchExtension2(file, ext);
        end
        
        function [chosenFile, cancelled]...
                =Ask(fileSpec, singleOnly, property, ...
                ttl, dflt, southWestButtons, folderOnly, ...
                sortBy, sortDirection)
            if nargin<9
                sortDirection='descend';
                if nargin<8
                    sortBy='datenum';
                    if nargin<7
                        folderOnly=false;
                        if nargin<6
                            southWestButtons=[];
                            if nargin<5
                                dflt=[];
                                if nargin<4
                                    ttl=[];
                                    if nargin<3
                                        property=[];
                                        if nargin<2
                                            singleOnly=true;
                                            if nargin<1
                                                fileSpec='*.m';
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            chosenFile=[]; cancelled=false;
            allFiles=dir(fileSpec);
            allFiles=sortStructs(allFiles, sortBy, sortDirection);
            N=length(allFiles);
            if N<1
                warning('No files found with "%s"', fileSpec);
                return;
            end
            dscs={};
            for i=1:N
                fl=allFiles(i);
                n=fl.name;
                d=datestr(datetime(fl.date), 'yyyy-mm-dd HH:MM:SS');
                if fl.isdir
                    dscs{end+1}=[...
                        '<html><font color="blue"><b>' ...
                        Html.EncodeSort('name', n) n ...
                        '</font> | ' ...
                        Html.EncodeSort('modified', d) d ' | ' ...
                        Html.EncodeSort('size', fl.bytes) ...
                        '</b></html>'];
                elseif ~folderOnly
                    dscs{end+1}=['<html>' Html.EncodeSort('name', n) n ' | ' ...
                        Html.EncodeSort('modified', d) d ' | ' ...
                        Html.EncodeSort('size', fl.bytes) ...
                        String.encodeBytes(fl.bytes) '</html>'];
                end
            end
            if isempty(ttl)
                ttl=sprintf('%d file(s) in "%s"', N, fileSpec);
            end
            if isempty(property)
                property='File.Ask';
            end
            if isempty(dflt)
                if singleOnly
                    dflt=1;
                else
                    dflt=1:N;
                end
            end
            if folderOnly
                word='folder';
            else
                word='file';
            end
            app=BasicMap.Global;
            [choice,cancelled]=Gui.Ask(struct('sortProps', app,...
                'sortGuiAlways', true, ...
                'sortProp',property,...
                'msg', ['<html><b><u><font '  ...
                'color="blue">Select a ' word ...
                ' from</font></u></b>'...
                Html.FileTree(allFiles(end).folder) ...
                '</html>']), dscs,[], ttl, dflt, ...
                southWestButtons, singleOnly);
            if ~isempty(choice)                
                chosenFile=allFiles(choice);
            end
        end
        
        function [yes, out]=Diff(file1, file2)
            if ispc
                cmd='FC';
            else
                cmd='diff';
            end
            if exist(file1, 'file')==2 && exist(file2, 'file')==2
                [rc,out]=system([cmd ' ' String.ToSystem(file1) ' ' ...
                    String.ToSystem(file2) ]);
                yes=rc==0;
            else
                yes=false;
            end
        end
        
        function ok=ExistsFile(file)
            file=File.ExpandHomeSymbol(file);
            if exist(file, 'dir')
                ok=false;
            else
                ok=exist(file, 'file');
            end
        end

        function [yes, exists]=IsEmpty(file)
            f=dir(file);
            if ~isempty(f)
                yes=f(1).bytes==0;
                exists=true;
            else
                exists=false;
                yes=true;
            end
        end
        
        function f=GetDir(dflt, prop, explanation, props)
            if nargin<4
                props=BasicMap.Global;
            end
            actual=props.get(prop, dflt);
            MatBasics.RunLater(@(h,e)explain(explanation),2);
            f=uigetdir(actual, explanation);
            if ischar(f)
                props.set(prop, f);
            else
                f=[];
            end
            function explain(txt)
                jd=msg(['Specify ' txt], 8, 'north west++');
                jd.setAlwaysOnTop(true)
            end
        end
        
        function fw=WatchFolder(folder, callBack, ...
                created, log2Console, modified, deleted)
            if nargin<6
                deleted=false;
                if nargin<5
                    modified=false;
                    if nargin<4
                        log2Console=true;
                        if nargin<3
                            created=true;
                            if nargin<2
                                callBack=[];
                            end
                        end
                    end
                end
            end
            [priority, fldr]=File.ParseWatchFolder(folder);
            btn=Gui.NewBtn('', @(h,e)parse(h,e));
            fw=edu.stanford.facs.swing.FolderWatch(...
                fldr, created, modified, deleted, ...
                btn, log2Console, priority);
            
            function parse(h, e)
                txt=char(h.getActionCommand);
                if startsWith(txt, 'Created: ')
                    event='created';
                    file=txt(10:end);
                elseif startsWith(txt, 'Deleted: ')
                    event='deleted';
                    file=txt(10:end);
                else
                    event='modified';
                    file=txt(11:end);
                end
                if isempty(callBack)
                    fprintf('operation=%s, file="%s"\n',...
                        event, file);
                else
                    feval(callBack, event, file);
                end
            end
        end
        
        function fw=WatchForNewFiles(callBack,...
                folder, askIfPrior, catchDeletes)
            if nargin<5
                catchDeletes=true;
                if nargin<4
                    askIfPrior=true;
                    if nargin<3
                        ignorePrior=false;
                        if nargin<2
                            folder='~/Downloads';
                            if nargin<1
                                callBack=[];
                            end
                        end
                    end
                end
            end
            
            [priority, fldr, fileSpec]...
                =File.ParseWatchFolder(folder);
            fullFileSpec=fullfile(fldr,fileSpec);
            dirData = dir(fullFileSpec);
            filenames = {dirData.name};
            curFiles = filenames;
            if ~ignorePrior
                N=length(curFiles);
                if N>0
                    firstFile=curFiles{1};
                    curFiles={};
                    if ~askIfPrior || ...
                            askYesOrNo(sprintf(['<html>'...
                            'Do the %d pre-existing '...
                            priority ' priority job(s)'...
                            '<br>found in<br>%s'], N,...
                            Html.FileTree(folder)))
                        notify('created', firstFile)
                    end
                end
            end
            fw=File.WatchFolder(folder, ...
                @(event, file)notify(event, file), ...
                true, true, false, catchDeletes);
            
            function notify(event, file)
                dirData = dir(fullFileSpec);
                filenames = {dirData.name};
                newFiles = setdiff(filenames,curFiles);
                curFiles = filenames;
                if strcmpi(event, 'deleted')
                    fprintf('Saw deletion of "%s"\n', file);
                elseif ~isempty(newFiles)
                    % deal with the new files
                    if ~isempty(callBack)
                        feval(callBack, newFiles);
                    else
                        fprintf('New files: \n\t%s\n', ...
                            StringArray.toString(newFiles));
                    end
                else
                    fprintf('No new files!\n')
                end
            end   
        end
        
        function [totalBad, missing, notNeeded, newTxt]=...
                SyncPrjImages(prjPath, filePath, ...
                issueWarning, forPc)
            if nargin<4
                forPc=false;
                if nargin<3
                    issueWarning=true;
                    if nargin<2
                        filePath='';
                    end
                end
            end
            if exist(prjPath, 'dir')
                error('Not expecting a folder:  %s!!', prjPath);
            end
            if ~exist(prjPath, 'file')
                    prjPath2=fullfile(...
                        fileparts(mfilename('fullpath'), ...
                        prjPath));
                    if ~exist(prjPath2, 'file') || exist(prjPath2, 'dir')
                        error('Can''t find the file %s', prjPath);
                    else
                        prjPath=prjPath2;
                    end
            end
            txt=File.ReadTextFile(prjPath);
            newTxt='';
            missing={};
            notNeeded={};
            gather('png');
            gather('gif');
            gather('jpg');
            gather('jpeg');
            
            totalBad=length(missing)+length(notNeeded);
            if nargin<3 || issueWarning
                if ~isempty(missing)>0
                    warning(['%d image file(s) missing '...
                        ' in %s:\n\t%s'], length(missing), ...
                        prjPath, StringArray.toString(missing));
                end
                if ~isempty(notNeeded)>0
                    warning(['%d image file(s) missing '...
                        ' in %s:\n\t%s'], length(notNeeded), ...
                        prjPath, StringArray.toString(notNeeded));
                end
            end
            
            function gather(ext)
                found=dir(fullfile(filePath, ['*.' ext]));
                N=length(found);
                if forPc
                    toks=StringArray(regexpi(txt, [...
                        '\${PROJECT_ROOT}\\([\w ]+.' ext ')'], ...
                        'tokens'), true);
                else
                    toks=StringArray(regexpi(txt, [...
                    '\${PROJECT_ROOT}/([\w ]+\.' ext ')'], ...
                    'tokens'), true);
                end
                
                for i=1:N
                    name=found(i).name;
                    if toks.indexOf(name)<1
                        tryPath=[filePath '/' name];
                        if toks.indexOfI(tryPath)<1
                            missing{end+1}=name;
                        end
                    end
                end
                files=StringArray({found.name});
                for i=1:toks.N
                    name=toks.strings{i}{1};
                    if files.indexOfI(name)<1
                        [~, tryNoPath]=fileparts(name);
                        if files.indexOf([tryNoPath ext])<1
                            notNeeded{end+1}=name;
                        end
                    end
                end
            end
        end
        
        
        function [priority, folder, fileSpec]...
            =ParseWatchFolder(folder)
            fldr=lower(folder);
            idx=String.IndexOf(fldr, ':');
            if idx>0
                priority=folder(1:idx-1);
                folder=folder(idx+1:end);
            else
                priority='high';
            end
            if startsWith('medium', priority)
                priority='medium';
            elseif startsWith('high', priority)
                priority='high';
            elseif startsWith('low', priority)
                priority='low';
            else
                if ~ispc || length(priority)>1
                    warning(['Priority="%s" found in %s'...
                        '\n    Expected priority values '...
                        'are:  high, medium or low!\n'...
                        '    (defaulting to medium)'],...
                        priority, folder);
                end
                priority='medium';
            end
            [folder, f, e]=fileparts(folder);
            if ~contains(f, '*')
                folder=fullfile(folder, [f e]);
                fileSpec='*.job';
            else
                fileSpec=[f e];
            end
            folder=File.ExpandHomeSymbol(folder);
        end
    end
    
end
