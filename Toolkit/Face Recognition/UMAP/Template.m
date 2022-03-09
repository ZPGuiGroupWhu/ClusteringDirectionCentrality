%
%   AUTHORSHIP
%   Primary Developer: Stephen Meehan <swmeehan@stanford.edu>
%   Math Lead & Secondary Developer:  Connor Meehan <connor.gw.meehan@gmail.com>
%   Bioinformatics Lead:  Wayne Moore <wmoore@stanford.edu>
%   Provided by the Herzenberg Lab at Stanford University 
%   License: BSD 3 clause
%

classdef Template < handle

    methods(Static)
        function [umap, badCnt, canLoad, reOrgData, reducedParams]=...
                Get(inData, d1, umapFile, maxSdu) 
            canLoad=true;
            if nargin<4
                maxSdu=1;
                if nargin<3
                    umapFile=[];
                end
            end
            reOrgData=[];
            reducedParams=[];
            umap=[];
            badCnt=0;
            dimNow=size(inData, 2);
            while true
                umap=[];
                if isempty(umapFile)
                    umapFile=getUmapFile;
                end
                if ~isempty(umapFile)
                    sdus=[];
                    dimUmap=0;
                    try
                        try
                            warning('off', 'MATLAB:load:classNotFound');
                            warning('off', 'MATLAB:Java:ConvertToOpaque');
                            load(umapFile, 'umap');
                            warning('on', 'MATLAB:load:classNotFound');
                            warning('on', 'MATLAB:Java:ConvertToOpaque');
                        catch
                            canLoad=false;
                            break;
                        end
                        try
                            if ~isempty(umap.supervisors)
                                umap.supervisors.prepareForTemplate;
                                if ~isempty(umap.supervisors)
                                    Template.EnsureMlpLocation(umapFile, umap);
                                end
                            end                            
                            umapFile=[];
                            d2=umap.dimNames;
                            if ~isempty(d2) && isempty(d1)
                                html=Html.To2Lists(d2,d1,'ol', ...
                                        'Template', 'Current', true, 25);
                                answ=ask(['<html><b>'...
                                    'No parameter names were supplied, but the template has parameter names.</b><hr>'...
                                    html '<br><br><center>Is it OK to proceed anyway?'...
                                    '</center></html>'], 'Problem...');
                                if answ==1
                                    d1 = d2;
                                elseif answ==0
                                    badCnt=badCnt+1;
                                    continue;
                                else
                                    umap = [];
                                    return;
                                end
                            end
                            if ~isempty(d2) && ...
                                    ~StringArray.AreSameOrEmpty(d2, d1)
                                [reOrgData, reducedParams]=MatBasics.ReOrg(...
                                    inData, d1, d2, true, false);
                                isOk=~isempty(reOrgData);
                                if isOk && ~isempty(reducedParams)
                                    html=Html.To2Lists(d2,d1,'ol', ...
                                        'Template', 'Current', true, 25);
                                    if length(reducedParams)~=size(inData,2)
                                        app=BasicMap.Global;
                                        answ=askYesOrNo(['<html><b>'...
                                            'Parameters are a subset of each other</b><hr>'...
                                            html '<br><br><center>'...
                                            app.h2Start ...
                                            'Accept  reduced parameters?'...
                                            app.h2End ...
                                            '</center></html>'], 'Problem...',...
                                            'error');
                                        if answ==-1
                                            umap=[];
                                            return;
                                        elseif answ==0
                                            continue;
                                        end
                                    end
                                end
                                if ~isOk
                                    html=Html.To2Lists(d2,d1,'ol', ...
                                        'Template', 'Current', true, 25);
                                    showMsg(['<html><font color="red"><b>'...
                                        'Parameters differ</b><hr>'...
                                        html '</html>'], 'Problem...', 'error');
                                    badCnt=badCnt+1;
                                    continue;
                                else
                                    inData=reOrgData;
                                end
                            end
                        catch ex
                            disp(ex);
                        end
                        if isprop(umap, 'rawMeans') && ~isempty(umap.rawMeans)
                            sdus=MatBasics.SduDist2(inData, umap.rawMeans, umap.rawStds);
                        else
                            sdus=MatBasics.SduDist(inData, umap.raw_data);
                        end
                        dimUmap=size(umap.raw_data, 2);
                    catch ex
                        ex.getReport
                    end
                    if isempty(sdus)
                        s=sprintf(['Chosen template has <b>%d '...
                            'data dimensions</b>...<br>BUT current #'...
                            ' of data dimensions <b><font color="red">'...
                            'is %d!!</font></b>'], ...
                            dimUmap, dimNow);
                        msgBox(struct('icon', 'error.png', 'msg', ...
                            Html.WrapHr(s)), 'Incompatible...');
                    elseif any(sdus>maxSdu)
                        badCnt=badCnt+1;
                        
% DG changed
%                         showMsg(Html.WrapHr([num2str(sum(sdus>maxSdu))...
%                             ' standard deviation unit(s) ' ...
%                             '<br>are greater than ' num2str(maxSdu) ...
%                             ...'<br><b>' MatBasics.toRoundedTable(sdus, 2, ...
%                             ...find(sdus>maxSdu)) '</b>'...
%                             ]), ...
%                             'Incompatible...', 'error');
                        answ=ask(['<html>'...
                            num2str(sum(sdus>maxSdu))...
                             ' standard deviation unit(s) ' ...
                             '<br>are greater than ' num2str(maxSdu) ...
                             '<br><br><center>'...
                            'Accept anyway?'...
                            '</center></html>'], 'Problem...',...
                            'error');
                        if answ==-1 % Cancel
                            umap=[];
                            return;
                        elseif answ==0 % No
                            continue;
                        else % Yes
                            break;
                        end
                        % DG changed
                    else
                        if isempty(d2)
                            warning(['This template has no dimension names'...
                                ' to aid data compatibility checking!!']);
                            msg(Html.WrapHr(...
                                ['This template has no '...
                                'dimension names<br>to aid data '...
                                'compatibility checking!!<br><br>'...
                                'Good luck....']), 8, 'north east+', ...
                                'Template is vague');
                        end
                        break;
                    end
                else
                    break;
                end
            end
            
            function umapFile=getUmapFile()
                umapFile=FileBasics.UiGet('*.umap.mat', pwd, ...
                    'Select prior compatible UMAP template');
            end
            
        end
        
        function ok=Save(umap, inputFile)
            umapFile=getNewUmapFile(inputFile);
            ok=~isempty(umapFile);
            if ok
                umap.progress_callback=[];
                umap.graph=[];
                pu=PopUp('Saving template');
                save(umapFile, 'umap');
                pu.close;
            end
            
            
            function umapFile=getNewUmapFile(file)
                [fldr, fl, ~]=fileparts(file);
                [fldr, file]=FileBasics.UiPut(fldr, [fl '.umap.mat'], ...
                    'Save UMAP as guiding template');
                if isempty(fldr)
                    umapFile=[];
                else
                    if ~String.EndsWith(file, '.umap.mat')
                        file=[file(1:end-4) '.umap.mat'];
                        if exist(fullfile(fldr,file), 'file')
                            answer=questdlg(['Template "' ...
                                file '" already '...
                                'exists ... Replace?']);
                            if isempty(answer) || isequal('Cancel', answer)
                                umapFile=[];
                                return;
                            elseif ~yes
                                umapFile=this.getNewUmapFile;
                                return;
                            end
                        end
                    end
                    umapFile=fullfile(fldr, file);
                end
            end
        end
        
        function [percNewSubsets, newSubsetIdxs, newSubsetCnt]=...
                CheckForUntrainedFalsePositives(template, inData, ...
                sduLimit, parameterLimit)
            if isempty(template.supervisors)
                percNewSubsets=0;
                newSubsetIdxs=[];
                newSubsetCnt=0;
                return;
            end
            if nargin<3
                sduLimit=3.66;
                parameterLimit=2;
            end
            [newSubsetCnt, newSubsetIdxs]=detectUnsupervised(template, inData, ...
                sduLimit, parameterLimit);
            R=size(inData,1);
            percNewSubsets=newSubsetCnt/R*100;
        end
        
        function [choice, cancelled]=Ask(perc)
            html=Html.WrapHr([String.encodeRounded(perc, 1) '% of the '...
                'rows/events appear NEW <br> or unseen in the data '...
                'that trained<br> this supervised template<br>']);
            choices={'Use anyway (it''s okay)', ...
                'Re-supervise via SDU distance'};
            [choice, cancelled]=Gui.Ask(html, choices, ...
                'umapNew2Template', 'New subsets?', 1);
        end
       
        function [resave, hopeForDownload, umap]...
                =EnsureMlpLocation(ust, umap)
            if nargin<2
                umap=[];
            end
            resave=false;
            hopeForDownload=false;
            if isempty(umap)
                try
                    load(ust, 'umap');
                catch ex
                    warning('Not a umap template %s', ust);
                    return;
                end
            end
            if ~isa(umap, 'UMAP')
                warning('Not a UMAP template %s', ust);
                umap=[];
                return;
            end
            mf=umap.mlp_model;
            if isempty(mf)
                return;
            end
            mf=[mf Mlp.Ext(umap.mlp_use_python)];
            if ~exist(mf, 'file')
                %maybe mlp moved to same folder?
                [~, mf, mext]=fileparts(mf);
                ustFldr=fileparts(ust);
                mf=fullfile(ustFldr, [mf mext]);
                if ~exist(mf, 'file')
                    %assume mlp model shall be downloaded 
                    warning('MLP not found in folder:  %s\n\tassuming it will be downloaded?', mf);
                    hopeForDownload=true;
                else
                    %assume co-location of mlp model
                    warning('MLP assumed to be co-located with template and not in %s', mf);
                end
                resave=true;
                [~,of]=fileparts(umap.mlp_model);
                umap.mlp_model=fullfile(ustFldr, of);
                umap.supervisors.mlp_model=umap.mlp_model;
            end
            if ~hopeForDownload
                crc=edu.stanford.facs.swing.CpuInfo.getCrc32(mf);
                if ~isempty(umap.mlp_crc)
                    if crc ~= umap.mlp_crc
                        warning('MLP crc mismatch %s', mf);
                        hopeForDownload=true;
                        return;
                    end
                else
                    resave=true;
                    umap.mlp_crc=crc;
                end
                if resave
                    save(ust, 'umap');
                end
            end
        end

    end
end