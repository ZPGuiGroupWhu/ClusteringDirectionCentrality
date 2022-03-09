classdef GatingMl
    methods(Static)
        function fullFile=GetFile(epp)
            argued=epp.args.gating_ml_file;
            [gatingMlFolder, f, ext]=fileparts(argued);
            if isempty(gatingMlFolder)
                fullFile=fullfile(epp.folder, [f ext]);
            else
                gatingMlFolder=File.ExpandHomeSymbol(gatingMlFolder);
                [ok,errMsg]=File.mkDir(gatingMlFolder);
                if ~ok
                    msg(['<html>Problems accessing folder ' ...
                        Html.FileTree(gatingMlFolder) '<br>'...
                        '<br>Your file system complaint is:<br>'...
                        '&nbsp;&nbsp;"<table width=300px><tr><td>'...
                        '<font color="red">' errMsg '</font>"</td>'...
                        '</td></table><br>THUS no gating ml XML has been '...
                        'deposited into your file<br><center>'...
                        '"<i>' [f ext] '</i>" !!</center><hr></html>'],12);
                    fullFile=[];
                else
                    fullFile=fullfile(gatingMlFolder, [f ext]);
                end
            end
        end
        
        function ok=Run(epp)
            fullFile=GatingMl.GetFile(epp);
            if isempty(fullFile)
                ok=false;
                return;
            end
            try
                javaMethodEDT('createGatingML','edu.stanford.facs.swing.EppProps',...
                    epp.properties_file, fullFile, epp.dataSet.columnPrefixes);
                msg(['<html>The Gating-ML for EPP is in'...
                    Html.FileTree(fullFile) '<br><br><center>NOTE: '...
                    Html.WrapBoldSmall(['You likely need'...
                    ' to add further XML to describe the data setup'...
                    '<br>(scaling, transformations etc.) done before'...
                    ' you passed the data to EPP.)']) ...
                    '</center><hr></html>'], 8, 'south west+', 'Gating-ML');
                ok=true;
            catch ex
                ex.getReport
                msgError(Html.WrapHr(['<table width="300px"><tr><tc>'...
                    ex.message '</td></tr></table>']), 8, 'center', ...
                    'Gating-ML error...');
                return;
            end
            
        end
        
    end
end