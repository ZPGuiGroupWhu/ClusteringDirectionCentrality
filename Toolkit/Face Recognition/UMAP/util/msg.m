%   AUTHORSHIP
%   Primary Developer: Stephen Meehan <swmeehan@stanford.edu> 
%   Provided by the Herzenberg Lab at Stanford University 
%   License: BSD 3 clause
%
function [jd, pane]=msg(mainTxtOrObj, pauseSecs, ...
    where, title, icon, checkFnc, suppressParent, ...
    southWest)
if nargin<8
    southWest=[];
    if nargin<7
        suppressParent=false;
        if nargin<6
            checkFnc=[];
            if nargin<5
                icon='facs.gif';
                if nargin<4
                    title='Note...';
                    if nargin<3
                        where='center';
                        if nargin<2
                            pauseSecs=15;
                        end
                    end
                end
            end
        end
    end
end
if isstruct(mainTxtOrObj)
    st=mainTxtOrObj;
    if ~isfield(st, 'pauseSecs')
        st=setfield(st, 'pauseSecs', pauseSecs);
    end
    if ~isfield(st, 'modal')
        st=setfield(st, 'modal', false);
    end
    if ~isfield(st, 'suppressParent')
        st=setfield(st, 'suppressParent', suppressParent);
    end
    if ~isfield(st, 'where')
        st=setfield(st, 'where', where);
    end
    if ~isfield(st, 'icon')
        st=setfield(st, 'icon', icon);
    end
    if ~isfield(st, 'checkFnc')
        st=setfield(st, 'checkFnc', checkFnc);
    end
    [jd, pane]=msgBox(st, title);
    return;
end

if nargin<5
    [jd, pane]=msgBox(struct('msg', mainTxtOrObj, 'modal', false, ...
        'pauseSecs', pauseSecs, 'where', where, 'component',southWest,...
        'suppressParent', suppressParent), title);
else
    if ~isempty(icon)
        [jd, pane]=msgBox(struct('msg', mainTxtOrObj, 'modal', false, ...
            'pauseSecs', pauseSecs, 'where', where, 'icon', icon, ...
            'checkFnc', checkFnc,'suppressParent', suppressParent,...
            'component', southWest), title);
    else
        [jd, pane]=msgBox(struct('msg', mainTxtOrObj, 'modal', false, ...
            'pauseSecs', pauseSecs, 'where', where, 'icon', icon, ...
            'checkFnc', checkFnc, 'component', southWest,...
            'suppressParent', suppressParent), title, 'plain');
    end
end
end
