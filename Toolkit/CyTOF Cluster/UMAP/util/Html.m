%   AUTHORSHIP
%   Primary Developer: Stephen Meehan <swmeehan@stanford.edu> 
%   Provided by the Herzenberg Lab at Stanford University 
%   License: BSD 3 clause
%

classdef Html
    properties(Constant)
        JET=jet;
        PROP_JET='Html.jet';
        JET_HSV=rgb2hsv(jet);
        SORT_REGEX='(?<=<Sort name=")([^"]+)" type="([^"]+)" value="([^"]+)">';
        SORT_REGEX_FMT='(?<=<Sort name=")%s" type="([^"]+)" value="([^"]+)">';
        YELLOW= '#FFFF00';
        YELLOW_LIGHT="#FDFDEC";
        RED=    '#FF0000'
        MAROON= '#8000000';
        BLACK=  '#000000';
        GRAY=   '#808080';
        OLIVE=  '#808000';
        GREEN=  '#00FF00';
        AVACODO='#008000';
        CYAN=   '#00FFFF';
        TEAL=   '#008080';
        BLUE=   '#0000FF';
        NAVY=   '#000080';
        MAGENTA='#FF00FF';
        PURPLE= '#800080';
        ORANGE= '#FFBF00';
        GOLD=   '#FF8000';
        COLORS={Html.NAVY, Html.BLACK, Html.BLUE, Html.ORANGE, Html.RED, ...
            Html.MAGENTA, Html.OLIVE, Html.GRAY, Html.MAROON, ...
            Html.YELLOW, Html.CYAN, Html.GREEN, Html.PURPLE, Html.AVACODO,...
            Html.TEAL, Html.GOLD};
        NCOLORS=length(Html.COLORS);
        SHAMROCK='<html><font size="5" color="green"><b>&#9752;</b></font></html>';
        HEART='<html><font size="5" color="#FFC0CB"><b>&hearts;</b></font></html>';
        SUN='<html><font size="5" color="#FFFF00"><b>&#9728;</b></font></html>';
        WARN='<html><font size="5" color="#AAAA00"><b>&#9888;</b></font></html>';
        RECYCLE='<html><font size="4" color="#111111"><b>&#9851;</b></font></html>';
        CLOUD='<html><font size="5" color="#444444"><b>&#9729;</b></font></html>';
        UMBRELLA='<html><font size="5" color="#2200AA"><b>&#9730;</b></font></html>';
        SMILE='<html><font size="5" color="#CCCC00"><b>&#9787;</b></font></html>';
        PHONE='<html><font size="5" color="#4400AA"><b>&#9742;</b></font></html>';
        FINGER='<html><font size="5" color="#BBBB22"><b>&#9757;</b></font></html>';
        SKULL='<html><font size="5" color="#FF0022"><b>&#9760;</b></font></html>';
        CHECK='<html><font size="5" color="green"><b>&#9745</b></font></html>';
        NOT_CHECKED='<html><font size="5" color="red"><b>&#9746</b></font></html>';
        CHECKED='<html><font size="5" color="00FF22"><b>&#10004</b></font></html>';
        NOT_CHECKED2='<html><font size="5" color="red"><b>&#10005</b></font></html>';
        CROSS='<html><font size="5" color="#0099FF"><b>&#10010</b></font></html>';
        STAR='<html><font size="5" color="11AADD"><b>&#10027</b></font></html>';
        PENCIL='<html><font size="5" color="22DD22"><b>&#9998</b></font></html>';
        SCISSORS='<html><font size="5" color="2255EE"><b>&#9986</b></font></html>';
    end
    
    methods(Static)
        function [values, types]=DecodeSortValues(str, name)
            fmt=sprintf(Html.SORT_REGEX_FMT, name);
            if isa(str, 'javax.swing.JPanel')
                try
                    str=char(str.getComponent(0).getText);
                catch
                    str='';
                end
            end
            tokens=regexp(str, fmt, 'tokens');
            N=length(tokens);
            types=cell(1,N);
            values=cell(1,N);
            for i=1:N
                values{i}=tokens{i}{2};
                types{i}=tokens{i}{1};
            end
        end
        
        function [keys, types, values]=DecodeSort(str)
            if isa(str, 'javax.swing.JPanel')
                try
                    str=char(str.getComponent(0).getText);
                catch
                    str='';
                end
            end
            tokens=regexp( str, Html.SORT_REGEX, 'tokens');
            N=length(tokens);
            keys=cell(1,N);
            types=cell(1,N);
            values=cell(1,N);
            for i=1:N
                keys{i}=tokens{i}{1};
                types{i}=tokens{i}{2};
                values{i}=tokens{i}{3};
            end
        end
        
        function str=EncodeSort(key, value, type)
            if nargin<3
            	if isnumeric(value)
                    type='N';
                else
                    type='C';
                end
            end
            if isnumeric(value)
                value=num2str(value);
            end
            str=['<Sort name="' key '" type="' type '" value="'...
                value '">'];
        end
        
        function html=RotatedStyle
            html=[...
                '<STYLE>'...
                'th.rotate {'...
                '  /* Something you can count on */'...
                ' height: 140px;'...
                ' white-space: nowrap;'...
                '}'...
                'th.rotate > div {'...
                '  transform: '...
                '    /* Magic Numbers */'...
                '    translate(0px, 51px)'...
                '    rotate(315deg);'...
                '  width: 30px;'...
                '}'...
                'th.rotate > div > span {'...
                '  border-bottom: 1px solid #ccc;'...
                '  padding: 5px 10px;'...
                '}</STYLE>'];
            
            
        end
        
        function html=Rotate(txts)
            html='';
            if iscell(txts)
            N=length(txts);
            for i=1:N
                html=[html '<th class="rotate"><div><span>'...
                    txts{i} '</span></div></th>'];
            end
            else
                html=['<th class="rotate"><div><span>'...
                    txts '</span></div></th>'];
            end
        end
        
        function html=TestRotate
            rows={{'Killarney', 'Black', '9'}, ...
                {'Fergus', 'Gold', '5'},...
                {'Pepper', 'Gold', '13'}};
            cols={'Doggie name', 'Color', '# of years'};
            html=['<html>' Html.RotatedStyle '<table>'];
            html=[html '<thead>' Html.Rotate(cols) '</thead>'];
            html=[html Html.TableBody(rows, false) '</table></html>'];
            
        end
        
        function html=TableBody(rows, headerDone)
            if nargin<2
                headerDone=true;
            end
            if headerDone
                html='<table>';
            else
                html='';
            end
            nRows=length(rows);
            for i=1:nRows
                row=rows{i};
                nCols=length(row);
                html=[html '<tr>'];
                for j=1:nCols
                    html=[html '<td>' row{j} '</td>'];
                end
                html=[html '</tr>'];
            end
            if headerDone
                html=[html '</table>'];
            end
        end
        function RotateTable(cols, rows)
            style=Html.RotatedStyle;
            hdr=Html.Rotations(cols);
        end
        
        function html=TableCell(obj)
            if isnumeric(obj)
                html=['<td align="right">' String.toString(obj) '</td>'];
            else
                html=['<td>' String.toString(obj) '</td>'];
            end

        end
        
        function html=Vertical(txt, pfx, sfx, limit)
            if nargin<4
                limit=9;
                if nargin<3
                    pfx='';
                    sfx='';
                end
            end
            txt=char(edu.stanford.facs.swing.Basics.RemoveXml(txt));
            N=length(txt);
            if N>limit
                txt=[txt(1:limit) '*'];
                N=limit+1;
            end
            html='<table cellspacing="0" cellpadding="0" border="0"><tr><td align="center">';
            for i=1:N
                html=[html pfx txt(i) sfx '<br>'];
            end
            html=[html '</td></tr></table>'];
        end
        
        function html=Verticals(txts, pfx, sfx)
            if nargin<2
                pfx='';
                sfx='';
            end
            N=length(txts);
            html='<table valign="bottom" cellpadding="0" cellspacing="0"><tr>';
            for i=1:N
                html=[html '<td>' Html.Vertical(txts{i}, pfx, sfx) '</td>'];
            end
            html=[html '</tr></table>'];
        end

        function str=H2(str, hrToo)
            app=BasicMap.Global;
            if nargin<2 || hrToo
                hr='<hr>';
            else
                hr='';
            end
            str=[app.h2Start str app.h2End hr];
        end
        
        function str=Small2(str)
            str=Html.Small(String.ToHtml(str));
        end
        
        function str=Small(str)
            app=BasicMap.Global;
            str=[app.smallStart str app.smallEnd];
        end
        
        function str=Wrap(str, pixelWidth, cellpadding)
            if nargin<2
                str=['<html>' str '</html>'];
            else
                if nargin<3
                    str=Html.WrapTable(str, 6, pixelWidth);
                else
                    str=Html.WrapTable(str, cellpadding, pixelWidth);
                end
            end
        end
        
        function str=WrapTable(str, cellpadding, width, border, ...
                align, widthUnit, app)
            %Example
            %msg(Html.WrapTable(['Hi folks ... well... I''m .... I''m going to sneeze'],2,3, '1', 'center', 'in'))
            %
                if nargin<5
                    align='left';
                    if nargin<4
                        border='0';
                    end
                end
            if nargin<2
                cellpadding=6;
            end
            if nargin<3
                str=sprintf(['<html><table '...
                    'cellpadding="%d"><tr><td>'...
                    '%s</td></tr></html>'],  cellpadding, str);
            else
                if nargin<7
                    app=BasicMap.Global;
                    if nargin<6
                        widthUnit='px';
                        if nargin<5
                            align='center';
                            if nargin<4
                                border='1';
                            end
                        end
                    end
                end
                if app.highDef
                    width=width*app.toolBarFactor;
                    cellpadding=cellpadding*app.toolBarFactor;
                end

                str=sprintf(['<html><table width="%d%s" border="%s" '...
                    'cellpadding="%d"><tr><td align="%s">%s</td>' ...
                    '</tr></html>'], width, widthUnit, border,...
                    cellpadding, align, str);
            end
        end
        
        function str=WrapC(str)
            str=['<html><center>' str '</center></html>'];
        end
        
        function str=WrapSmall(str)
            app=BasicMap.Global;
            str=['<html>' app.smallStart str app.smallEnd '</html>'];
        end
        
        function str=WrapColor(str, clr)
            str=['<font color="' clr '">' str '</font>'];
        end
        
        function str=WrapSmallTags(str)
            app=BasicMap.Global;
            if iscell(str)
                str=StringArray.toString(str);
            end
            str=[app.smallStart '<b>' str '</b>' app.smallEnd ];
        end

        function str=PreventTooWide(str, pixelsWide, centered, padding)
            if nargin<4
                padding=2;
                if nargin<3
                    centered=false;
                    if nargin<2
                        pixelsWide=400;
                    end
                end
            end
            if centered
                td='<td align="center">';
            else
                td='<td>';
            end
            app=BasicMap.Global;
            if app.highDef
                pixelsWide=pixelsWide*1.4;
            end
            if iscell(str)
                str=StringArray.toString(str);
            end
            str=['<table cellpadding="' num2str(padding) ...
                '" cellspacing="0" width="' ...
                num2str(pixelsWide) 'px"><tr>' td app.smallStart ...
                '<b>' str '</b>' app.smallEnd '</td></tr></table>'];
        end

        function str=WrapHr(str)
            str=['<html><table border="0"><tr><td></td><td align="center">' ...
                str '</td><td></td></tr></table><hr></html>'];
        end

        function str=Hr(str)
            str=['<html><center>' str '</center><hr></html>'];
        end

        function str=WrapClr(words, clr, otherFontAttributes)
            if nargin<3
                str=['<html><font ' Html.Color(clr) '>' ...
                    words '</font></html>'];
            else
                str=['<html><font ' Html.Color(clr) otherFontAttributes ...
                    ' >' words '</font></html>'];
            end
        end

        function str=WrapClr2(words, clr, otherFontAttributes)
            if nargin<3
                str=['<font ' Html.Color(clr) '>'  words '</font>'];
            else
                str=['<font ' Html.Color(clr) otherFontAttributes ...
                    ' >' words '</font>'];
            end
        end

        function str=WrapSm(str, app)
            if nargin<2
                app=BasicMap.Global;
            end
            str=['<html>' app.smallStart str app.smallEnd '</html>'];
        end

        function str=WrapSmallBold(str, app)
            if nargin<2
                app=BasicMap.Global;
            end
            str=['<html><b>' app.smallStart str app.smallEnd '</b></html>'];
        end

        function strs=WrapSmallBoldCell(strs, app)
            if nargin<2
                app=BasicMap.Global;
            end
            html1=['<html><b>' app.smallStart ];
            html2=[app.smallEnd '</b></html>'];
            N=length(strs);
            for i=1:N
                strs{i}=[html1 strs{i} html2];
            end
        end

        function strs=WrapBoldSmallCell(strs, app)
            if nargin<2
                app=BasicMap.Global;
            end
            html1=['<b>' app.smallStart ];
            html2=[app.smallEnd '</b>'];
            N=length(strs);
            for i=1:N
                strs{i}=[html1 strs{i} html2];
            end
        end

        function str=WrapBoldSmall(str, app)
            if nargin<2
                app=BasicMap.Global;
            end
            str=['<b>' app.smallStart str app.smallEnd '</b>'];
        end

        function colors=ColorIds(ids)
            u=unique(ids);
            N=length(ids);
            colors=cell(1, N);
            for i=1:N
                idx=find(u==ids(i));
                colors{i}=Html.Color(idx);
            end
        end
        
        function s=Color(ml)
            if length(ml)==1
                idx=mod(ml, Html.NCOLORS)+1;
                s=Html.COLORS{idx};
                return;
            end
            ml=floor(ml*255);
            try
                s=sprintf('color="#%s%s%s"', hex(ml(1)), ...
                    hex(ml(2)), hex(ml(3)));
            catch ex
                s='color="black"';
            end
            function c=hex(c)
                c=dec2hex(c);
                if length(c)==1
                    c=['0' c];
                end
            end
        end

        function Browse(html)
            web( File.SaveTempHtml(html), '-browser');
        end
        
        function html=TitleMatrix(m, decimals, prefix, num2strThreshold)
            [R,C]=size(m);
            html=prefix;
            for r=1:R
                for c=1:C
                    html=[html '&#009;' ...
                        String.encodeRounded(m(r,c), decimals, true, num2strThreshold)];
                end
                html=[html '&#013;&#010;'];
            end
        end
        
        function img=ImgFile(f)
            img=['<img src=''file:/' ...
                        edu.stanford.facs.swing.Basics.EncodeFileUrl(f)...
                        '''>'];
        end
        
        function html=MatrixColored(rowHdrs, colHdrs, data, colors, ...
                emphasizeColumn, encode)
            if nargin<6
                encode=@encode_;
                if nargin<5
                    emphasizeColumn=-1;
                    if nargin<4
                        colors={};
                    end
                end
            end            
            html='<table cellpadding="5"><tr><td></td>';
            nCols=length(colHdrs);
            nRows=length(rowHdrs);
            for col=1:nCols
                html=[html '<td bgcolor="#AABDFF" align="center">' ...
                    encodeHead(colHdrs{col}) '</td>'];
            end
            html=[html '</tr>'];
            for row=1:nRows
                html=[html '<tr><td bgcolor="#FFFFDD">' ...
                    encodeHead(rowHdrs{row}) '</td>'];
                if isempty(colors)
                    clr='black';
                else
                    clr=colors{row};
                end
                for col=1:nCols
                    if col==emphasizeColumn
                        pre='<i><b>';
                        suf='</b></i>';
                    else
                        pre='';
                        suf='';
                    end
                    str=feval(encode, row, col, data(row, col));
                    html=[html '<td align="right"><font color="'...
                        clr '">' pre String.Pad(str, 9) ...
                        suf '</font></td>'];
                end
                html=[html '</tr>'];
            end
            html=[html '</table>'];
            function num=encode_(row, col, num)
                num=String.encodeRounded(num, 2, true);
            end
            function value=encodeHead(value)
                if isnumeric(value)
                    if size(value,1)>1
                        value=num2str(value');
                    else
                        value=num2str(value);
                    end
                end
            end
                    
        end
        

        function html=Matrix(rowHdrs, colHdrs, data, encode)
            if nargin<4
                encode=@encode_;
            end
            [R, C]=size(data);
            if isempty(rowHdrs) 
                rowHdrs=StringArray.Num2Str(1:R);
            end
            if isempty(colHdrs)
                colHdrs=StringArray.Num2Str(1:C);
            end
            html='<table><tr><td></td>';
            nCols=length(colHdrs);
            nRows=length(rowHdrs);
            for col=1:nCols
                html=[html '<td bgcolor="#AABDFF" align="center">' ...
                    String.ToHtml(colHdrs{col}) '</td>'];
            end
            html=[html '</tr>'];
            for row=1:nRows
                html=[html '<tr><td bgcolor="#FFFFDD">' rowHdrs{row} '</td>'];
                for col=1:nCols
                    str=feval(encode, row, data(row, col));
                    html=[html '<td align="right">'...
                        String.Pad(str, 9) '</td>'];
                end
                html=[html '</tr>'];
            end
            html=[html '</table>'];
            function num=encode_(col, num)
                num=String.encodeRounded(num,2,true);
            end

        end
        
        function img=Samusik(scale, forBrowser)
            file=Gui.SamusikIconFile;
            folder=Gui.SamusikIconFolder;
            img=Html.Img(file, folder, scale, forBrowser);
        end

        function img=Organizer(scale, forBrowser, filePath)
            if nargin<2
                forBrowser=false;
                if nargin<1
                    scale=.12;
                end
            end
            %file='plottype-dendrogram.png';
            %folder=fullfile(matlabroot,'/toolbox/matlab/icons/');
            file='tree2.png';
            folder=BasicMap.Global.contentFolder;
            if nargin<3 || ~filePath
                img=Html.Img(file, folder, scale, forBrowser);
            else
                img=fullfile(folder,file);
                img=edu.stanford.facs.swing.Basics.GetResizedImg(...
                    java.io.File(img), scale, ...
                    java.io.File(BasicMap.Global.appFolder));
            end
        end

        function img=Microscope(scale, forBrowser)
            file='microScope.png';
            folder=BasicMap.Global.contentFolder;
            img=Html.Img(file, folder, scale, forBrowser);
        end

        function img=Img(file, folder, scale, forBrowser)
            if nargin<4
                forBrowser=false;
                if nargin<3
                    if ispc && BasicMap.Global.highDef
                        scale=.2;
                    else
                        scale=.11;
                    end
                    if nargin<2 
                        folder=BasicMap.Global.contentFolder;
                    end
                end
            end
            if isempty(folder)
                folder=BasicMap.Global.contentFolder;
            end
            if scale==1
                f=fullfile(folder,file);
                if forBrowser
                    img=Html.ImgForBrowser(f,'');
                else
                    img=['<img src=''file:/' ...
                        edu.stanford.facs.swing.Basics.EncodeFileUrl(f)...
                        '''>'];
                end
            else
                img=edu.stanford.facs.swing.Html.ImgSized3(...
                    file, folder, scale, forBrowser);
            end
        end
        
        function img=ImgXy(file, folder, scale, forBrowser, ...
                parentFolderOnly, appForHighDefAdjusting)
            if nargin<4
                forBrowser=false;
                if nargin<3
                    scale=1;
                    if nargin<2 
                        folder=BasicMap.Global.contentFolder;
                    end
                end
            end
            if scale==1
                if isempty(folder)
                    folder=BasicMap.Global.contentFolder;
                end
                f=fullfile(folder,file);
                if forBrowser
                    img=Html.ImgForBrowser(f,'');
                else
                    img=['<img src=''file:/' ...
                        edu.stanford.facs.swing.Basics.EncodeFileUrl(f)...
                        '''>'];
                end
            else
                if nargin>5
                    if appForHighDefAdjusting.highDef
                        scale=appForHighDefAdjusting.toolBarFactor*scale;

                    end
                    if isempty(folder)
                        folder=appForHighDefAdjusting.contentFolder;
                    end
                elseif isempty(folder)
                    folder=BasicMap.Global.contentFolder;

                end
                img=edu.stanford.facs.swing.Html.ImgSizedXy3(...
                    file, folder, scale, forBrowser);
            end
            if nargin>4 && parentFolderOnly
                idx=String.IndexOf(img, 'src=''file:');
                if idx>0
                    [~, f e]=fileparts(folder);
                    if ~forBrowser
                        slash='%2F';
                    else
                        slash=filesep;
                    end
                    img=[img(1:idx-1) 'src=''' [f e] slash file '''>'];
                end
            end
            
        end
        
        function s=HexColor(ml)
            s=Gui.HtmlHexColor(ml);
        end
        function img=ImgForBrowser(file, folder)
            if nargin<2
                folder=BasicMap.Global.contentFolder;
            end
            f=fullfile(folder, file);
            q='''';
            if String.Contains(f, '''')
                q='"';
            end
            f=regexprep(f, '#', '%23');
            img=['<img src=' q 'file:' f q '>'];
        end
        
        function html=To2Lists(strs1, strs2, type, hdr1, hdr2, ...
                highlightDifferences, limit)
            if nargin==7
                strs1=StringArray.Trim(strs1, limit);
                strs2=StringArray.Trim(strs2, limit);
            end
            if nargin>5 && highlightDifferences
                list1=Html.ToListDiff(strs1, strs2, type, false);
            else
                list1=Html.ToList(strs1, type, false);
            end
            if nargin>5 && highlightDifferences
                list2=Html.ToListDiff(strs2, strs1, type, false);
            else
                list2=Html.ToList(strs2, type, false);
            end
            html=['<tr><td valign="top">' list1 '</td><td valign="top">'...
                list2 '</td></tr>'];
            if nargin>3
                html=['<tr><td align="center" bgcolor="white"><b><u>'...
                    hdr1 '</u></b></td><td align="center" '...
                    'bgcolor="white"><b><u>' hdr2 '</u></b></td></tr>' html];
            end
            html=['<table bgcolor="white" >' html '</table>'];
        end
        
        function str=ToListDiff(strs, strs2, type, noListIf1, ...
                noListStart, noListEnd)
            if nargin<4
                if nargin<3
                    type='ul';
                    noListIf1=true;
                else
                    noListIf1=false;
                end
            end
            N=length(strs);
            if N==1 && noListIf1
                if nargin<6
                    noListStart='<b>';
                    noListEnd='</b>';
                end
                str=[noListStart String.ToHtml(strs{1}) noListEnd];
            else
                str=['<' type '>'];
                for i=1:N
                    if StringArray.Contains(strs2, strs{i})
                        str=[str '<li>' String.ToHtml(strs{i})];
                    else
                        str=[str '<li><font color="red"><b>' ...
                            String.ToHtml(strs{i}) '</b></font>'];
                    end
                end
                str=[str '</' type '>' ];
            end
        end
        
        function str=ToLimitedList(strs, limit, listType)
            if nargin<3
                listType='ol';
            end
            str=Html.ToList(strs, listType, true, '<b>', '</b>', limit);
        end
        
        function str=ToList(strs, listType, noListIf1, noListStart,...
                noListEnd, limit)
            if nargin<3
                if nargin<2
                    listType='ul';
                    noListIf1=true;
                else
                    noListIf1=false;
                end
            end
            N=length(strs);
            if N==1 && noListIf1
                if nargin<5 || isempty(noListStart)
                    noListStart='<b>';
                    noListEnd='</b>';
                end
                str=[noListStart String.ToHtml(strs{1}) noListEnd];
            else
                str=['<' listType '>'];
                if nargin>=6 && N>limit
                    for i=1:limit
                        str=[str '<li>' String.ToHtml(strs{i})];
                    end
                    str=[str '<li>' num2str(N-limit) ' more...'];
                else
                    for i=1:N
                        str=[str '<li>' String.ToHtml(strs{i})];
                    end
                end
                str=[str '</' listType '>' ];
                
            end
        end
        
        function str=ToListItemsAreHtml(items, listType, noListIf1, noListStart,...
                noListEnd, limit)
            if nargin<3
                if nargin<2
                    listType='ul';
                    noListIf1=true;
                else
                    noListIf1=false;
                end
            end
            N=length(items);
            if N==1 && noListIf1
                if nargin<5 || isempty(noListStart)
                    noListStart='<b>';
                    noListEnd='</b>';
                end
                str=[noListStart items{1} noListEnd];
            else
                str=['<' listType '>'];
                if nargin>=6 && N>limit
                    for i=1:limit
                        str=[str '<li>' String.ToHtml(items{i})];
                    end
                    str=[str '<li>' num2str(N-limit) ' more...'];
                else
                    for i=1:N
                        str=[str '<li>' items{i}];
                    end
                end
                str=[str '</' listType '>' ];
                
            end
        end
        
        function str=ToListWithHtml(strs, type, noListIf1, noListStart, noListEnd)
            if nargin<3
                if nargin<2
                    type='ul';
                    noListIf1=true;
                else
                    noListIf1=false;
                end
            end
            N=length(strs);
            if N==1 && noListIf1
                if nargin<5
                    noListStart='<b>';
                    noListEnd='</b>';
                end
                str=[noListStart strs{1} noListEnd];
            else
                str=['<' type '>'];
                for i=1:N
                    str=[str '<li>' strs{i}];
                end
                str=[str '</' type '>' ];
            end
        end
        
        function list=WrapList(list, prefix, suffix)
            if nargin<2
                prefix='<small>';
                suffix='</small>';
            end
            N=length(list);
            for i=1:N
                list{i}=[prefix list{i} suffix];
            end
        end
        
        function str=ToList2(strs, type, noListIf1, noListStart, noListEnd)
            if nargin<3
                if nargin<2
                    type='ul';
                    noListIf1=true;
                else
                    noListIf1=false;
                end
            end
            N=length(strs);
            if N==1 && noListIf1
                if nargin<5
                    noListStart='<b>';
                    noListEnd='</b>';
                end
                str=[noListStart strs{1} noListEnd];
            else
                str=['<' type '>'];
                for i=1:N
                    str=[str '<li>' strs{i}];
                end
                str=[str '</' type '>' ];
            end
        end

        
        function uri=ToFileUrl(s)
            if ispc
                uri=char(java.io.File(s).toURI);
            else
                file=java.io.File(s);
                if ~file.isAbsolute
                    fullpath=fullfile(pwd, s);
                    file=java.io.File(fullpath);
                end
                uri=char(file.toURI);
            end
        end
        
        function BrowseFile(fileName, convert)
            if nargin>1 && convert && ismac
                str=File.ReadTextFile(fileName);
                str=strrep(str, 'file:/%2F', 'file:/');
                str=strrep(str, '%2F', filesep);
                fileName=File.SaveTempHtml(str);
            end
            web(Html.ToFileUrl(fileName), '-browser');
        end
        
        function ok=BrowseString(lines)
            try
                file=[tempname '.html'];
                fid=fopen(file, 'wt');
                fprintf(fid, '%s\n', char(lines));
                fclose(fid);
                Html.BrowseFile(file);
                ok=true;
            catch ex
                disp(ex.message);
                ok=false;
            end
        end
        
        function out=StripHtmlWord(in)
            in=strtrim(in);
            if length(in)>13 && ...
                strcmpi(in(1:6), '<html>') && strcmpi(in(end-6:end), '</html>')
                    out=in(7:end-7);
            else
                out=in;
            end
        end
        
        function out=remove(in)
            if ~isempty(in)
                in=strtrim(in);
                if length(in)>13 && ...
                        strcmpi(in(1:6), '<html>') && strcmpi(in(end-6:end), '</html>')
                    out=in(7:end-7);
                else
                    out=in;
                end
            else
                out=in;
            end
        end
       
        function str=Symbol(clr, sz, wrapHtml)
            if nargin<3
                wrapHtml=true;
            end
            str=['<font  ' Gui.HtmlHexColor(clr)...
                '>&bull;</font>'];
            sz=((sz-7)/4)+2;
            if sz>10
                sz=10;
            end
            sz=String.encodeInteger(ceil(sz) );
            if wrapHtml
                str=['<html><font size="' sz '">' str '</font></html>'];
            else
                str=['<font size="' sz '">' str '</font>'];
            end
        end

        function img=TempImg(fig, forBrowser, scale)
            if nargin<3
                scale=.8;
                if nargin<2
                    forBrowser=true;
                end
            end
            file=[tempname '.png'];
            try
                saveas(fig, file);
            catch 
            end
            [fldr, fn, ext]=fileparts(file);
            img=Html.ImgXy([fn ext], fldr, scale, forBrowser);
        end
        
        function out=H2Small2(h2, small)
            out=Html.WrapC([Html.H2(h2) Html.Small2(small)]);
        end
        
        function rgb=ToRgb(hex)
            if hex(1)=='#'
                rgb=[hex2dec(hex(2:3))/255 hex2dec(hex(4:5))/255 hex2dec(hex(6:7))/255];
            else
                rgb=[hex2dec(hex(1:2))/255 hex2dec(hex(3:4))/255 hex2dec(hex(5:6))/255];
            end
            
        end
        
        function J=JET2(sz)
            if nargin<1
                j=jet;
            else
                j=jet(sz);
            end
            [R, C]=size(j);
            order=zeros(R,C);
            for i=1:R
                [~,order(i,:)]=sort(j(i, :));
            end
            J=[j*3 order];
        end
        
        function [str, clr01, clr255]=Scatter(color, size, sortCode)
            if nargin<3
                sortCode=3;%hsv
            end
            [hex, ~, clr255]=Gui.HtmlHexColor(color);
            clr01=clr255/255;
            if ispc
                str=['&middot;&#8286;&bull;&#9729;'];
            else
                str=['&middot;&#8286;&bull;'];
            end
            size=ceil(size);
            if size>8
                size=8;
            elseif size<2
                size=2;
            end
            
            if sortCode==1 % hsv
                order='';
                [~,I]=pdist2( Html.JET_HSV, rgb2hsv(clr01) , 'Euclidean', 'Smallest', 1);
                str=['<sort b="' dec2hex(I,2) '.' num2str(order) ...
                    '"><font ' hex ' size="' num2str(size) '">' str '</font>'];
            elseif sortCode==2 % rgb
                [~,order]=sort(clr01, 'descend');
                [~,I]=pdist2( Html.JET, clr01, 'Euclidean', 'Smallest', 1);
                str=['<sort b="' dec2hex(I,2) '.' num2str(order) ...
                    '"><font ' hex ' size="' num2str(size) '">' str '</font>'];
            elseif sortCode==3 % rgb
                c2=round(clr01*25);
                [c2, order]=sort(c2, 'descend');
                dif=c2(1)/5 -c2(2)/5 ;
                if dif<1
                    if c2(2)-c2(3)<=1
                        order=0; %no color
                    else
                        switch order(1)
                            case 1
                                if order(2)==2 %green
                                    order=2;
                                else %blue
                                    order=5; %magenta region
                                end
                            case 2
                                if order(2)==3
                                    order=4; %cyan region
                                else
                                    order=2;%yellow region
                                end
                            otherwise  %blue
                                if order(2)==2
                                    order=4; %cyan region
                                else
                                    order=5; %magenta region
                                end
                        end
                    end
                else
                    switch order(1)
                        case 2
                            order=3;
                        case 3
                            order=6;
                        otherwise
                            order=1;
                    end
                end
                str=['<sort b="' num2str(order) '.' dec2hex(int32(c2(1)-c2(2)), 2)...
                    '"><font ' hex ' size="' num2str(size) '">' str '</font>'];
            else
                str=['<font ' hex ' size="' num2str(size) '">' str '</font>'];
            end
            if ismac
                str=[str '<font ' hex ' size="5">&#9729;</font>'];
            end
        end
        
        function str=Bullet(color, size)
            str=['<font  ' Gui.HtmlHexColor(color)...
                '>&bull;</font>'];
            size=ceil(size);
            if size>8
                size=8;
            elseif size<2
                size=2;
            end
            str=['<font size="' num2str(size) '">' str '</font>'];
        end
        
        function str=BulletItem(color, size, suffix)
            size=String.encodeInteger(ceil(size) );
            if size>8
                size=8;
                suffixSize=4;
            elseif size<2
                size=2;
                suffixSize=2;
            else
                suffixSize=ceil(size/3);
            end
            suffix=['<font size="' num2str(suffixSize) '">&larr;' suffix '</font>'];
            clr=Gui.HtmlHexColor(color);
            str=['<font  ' clr '>&bull;' suffix '</font>'];
            str=['<font size="' num2str(size) '">' str '</font>'];
            
        end
        
        function str=FileTree(path, app, forBrowser, conserveSpace)
            if nargin<3
                forBrowser=true;
                if nargin<2
                    app=BasicMap.Global;
                    if nargin<1
                        path=app.contentFolder;
                    end
                end
            end
            if isempty(path)
                str='';
                return;
            end
            path=File.AbbreviateRoot(path, true);
            fldr=[Html.ImgXy('foldericon.png', [], .9, forBrowser) '&nbsp;'];
            leaf=[Html.ImgXy('rightArrow.png', [], .99, forBrowser) '&nbsp;'];
            l=split(path, filesep);
            N=length(l);
            sb=java.lang.StringBuilder(500);
            sb.append('<b>');
            pad='&nbsp;&nbsp;&nbsp;';
            sb.append(app.smallStart);
            started=false;
            for i=1:N
                item=l{i};
                if isempty(item)
                    continue;
                end
                if started
                    sb.append('<br>');
                else
                    if nargin<4 || ~conserveSpace
                        sb.append('<br>');
                    end
                    started=true;
                end
                for j=1:i
                    sb.append(pad);
                end
                if i==N
                    sb.append(app.smallEnd);
                    sb.append(leaf);
                    sb.append('<font color=''blue''><i>');
                    sb.append(java.lang.String((item)));
                    sb.append('</i></font></b>');
                    if exist(path, 'file')
                        if ~exist(path, 'dir')
                            sb.append('<br>');
                            for j=1:i
                                sb.append(pad);
                            end
                            sb.append('&nbsp;&nbsp;');
                            try
                                de=dir(path);
                                if ~isempty(de)
                                    sb.append(app.smallStart);
                                    sb.append('(<i>');
                                    sb.append( String.encodeGb(...
                                        de.bytes,[],2)  );
                                    sb.append(', ');
                                    sb.append(de.date);
                                    sb.append('</i>)');
                                    sb.append(app.smallEnd);
                                end
                            catch ex
                                ex.getReport
                            end
                        end
                    end
                    
                else
                    sb.append(fldr);
                    sb.append(java.lang.String((item)));
                end
            end
            str=char(sb.toString);
        end
        
        function rep=Exception(exception, app)
            if nargin <2
                app=BasicMap.Global;
            end
            smallStart=app.smallStart;
            smallEnd=app.smallEnd;
            rep=String.ToHtml(exception.getReport(...
                'extended', 'hyperlinks', 'off'));
            rep=regexprep(rep, 'Error in (.*?\(line \d+\))', 'Error in <b><u>$1</u></b>');
            rep=regexprep(rep,'\t', ...
                '&nbsp;&nbsp;&nbsp;');
            rep=strrep(rep, '  ', '&nbsp;');
            rep=strrep(rep, '<br><br>', '<br>');
            rep=Html.WrapTable(['<font color="red">'...
                smallStart rep smallEnd '</font>'],2,4,'0','left','in',app);
        end
    end
    
end
