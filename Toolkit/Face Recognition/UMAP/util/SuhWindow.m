classdef SuhWindow < handle
    properties(Constant)
        TESTING=false;
    end
    properties(SetAccess=private)
        handlingMoved=false;
        movedByBtnClick=false;
        followed;
        where;
        followers; %key is window, value is struct of follower dlg + where info
        figMap;
        always;
    end
    
    methods
        function this=SuhWindow()
            this.followers=TreeMapOfMany(java.util.HashMap);
            this.followed=java.util.HashMap;
            this.figMap=SuhAnyMap;
            this.where=java.util.HashMap;
            this.always=java.util.HashSet;
        end
        
        
        function follower=follow(this, follower, followed, where, locate)
            assert(~isempty(follower) && ~isempty(followed));
            assert(isjava(follower) && isjava(followed));
            if this.followed.containsKey(follower)
                prior=this.followed.get(follower);
                if prior ~= followed
                    error(['Follower-to-followed is N-to-1 '...
                        '\n..thus "%s" can''t follow both '...
                        '"%s" AND "%s"!!'], ...
                        follower.getTitle, prior.getTitle, ...
                        followed.getTitle); 
                end
            end
            followed=Gui.JWindow(followed);
            follower=Gui.JWindow(follower);
            if isequal(follower.getParent, followed)
                try
                follower.setParent([]);
                catch ex
                    warning('Parent window is LOCKED! in');
                end
            end
            if nargin<5 || locate
                Gui.LocateJava(follower, followed, where);
            end
            drawnow;
            this.followers.put(followed,follower);
            this.followed.put(follower, followed);
            this.where.put(follower, where);
        end
        
        function resetHandling(this)
            this.handlingMoved=false;
        end
        
        function moved(this, followed)
            if Gui.IsFigure(followed)
                if ~Gui.IsVisible(followed)
                    error('Figure "%s" must be visible', followed.Name);
                end
                this.forgetVisibleFigures(followed);
            end
            if this.handlingMoved
                disp('Already moving');
                return;
            end
            if ~isjava(followed)
                followed=Gui.JWindow(followed);
            end
            disp(['Moved=' char(followed.getTitle)]);
            this.handlingMoved=true;
            this.move(followed);
            drawnow;
            MatBasics.RunLater(@(h,e)focus,.35)
            
            function focus
                drawnow;
                followed.toFront;
                this.handlingMoved=false;
            end
        end
        
        function move(this, followed)
            it=this.followers.getIterator(followed);
            while it.hasNext
                follower=it.next;
                where_=this.where.get(follower);
                Gui.LocateJava(follower, followed, where_);
                this.move(follower);
                follower.toFront;
            end
        end
        
        function remove(this, jw)
            if isempty(jw)
                return;
            end
            followed_=this.followed.remove(jw);
            if ~isempty(followed_)
                this.where.remove(jw);
                this.followers.remove(followed_, jw);
            end
            this.followers.remove(jw);
            this.always.remove(jw);
        end
        
        function clear(this)
            this.where.clear;
            this.followed.clear;
            this.followers.clear;
            this.resetHandling;
            this.figMap.clear;
            this.always.clear;
        end
        
        function followerJw=rememberInvisibleFigure(this, ...
                followerFig, followedFig, where)
            
            followerJw=Gui.JWindow(followerFig);
            if ~isempty(followerJw) || Gui.IsVisible(followerFig)
                return;
            end
            v=this.figMap.get(followedFig);
            if isempty(v)
                v={};
            end
            v{end+1}=struct('fig', followerFig, ...
                'where', where);
            this.figMap.set(followedFig,v);
        end
        
        
        function [followedJw, invisible]=...
                forgetVisibleFigures(this, followedFig)
            if ~(isjava(followedFig) || Gui.IsVisible(followedFig));
                followedJw=[];
                invisible=[];
                return;
            end
            invisible=this.figMap.get(followedFig);
            followedJw=Gui.JWindow(followedFig);
            if ~isempty(invisible)
                N=length(invisible);
                forgotten=0;
                for i=N:-1:1
                    o=invisible{i};
                    if Gui.IsVisible(o.fig)
                        invisible(i)=[];
                        followerJw=Gui.JWindow(o.fig);
                        this.follow(followerJw, ...
                            followedJw, o.where, isjava(followedFig));
                        forgotten=forgotten+1;
                        if this.figMap.containsKey(o.fig)
                            set(followerJw, 'ComponentMovedCallback',...
                                @(h,e)SuhWindow.Moved(followerJw, o.fig));
                        end
                    end
                end
                if forgotten>0
                    if isempty(invisible)
                        this.figMap.remove(followedFig);
                    else
                        this.figMap.set(followedFig,invisible);
                    end
                    if SuhWindow.TESTING
                        fprintf('%d followers for %s becamse visible!\n',...
                            forgotten, followedFig.Name);
                    end
                end
            end
        end
        
        function startFollowingIfWasInvisible(this, followerFig)
            %if follwerFIg is in figMap and the followedFig is visible then
            % followerFig was invisible and is ready to start following
            followedFig=[];
            N=length(this.figMap.values);
            for i=1:N
                values=this.figMap.values{i};
                N2=length(values);
                for j=1:N2
                    if isequal(followerFig, values{j}.fig)
                        followedFig=this.figMap.keys{i};
                        if isjava(followedFig)
                            if followedFig.isVisible
                                this.forgetVisibleFigures(followedFig);
                            end
                        elseif Gui.IsVisible(followedFig)
                            this.forgetVisibleFigures(followedFig);
                        end
                        return;
                    end
                end
                
            end
        end
        
        function alwaysMove=showTipAndMoveIfAlways(this, jw)
            alwaysMove=this.always.contains(jw);
            if SuhWindow.TESTING
                fprintf('window="%s", handlingMove=%d\n',jw.getTitle, this.handlingMoved);
            end
            if alwaysMove
                this.showTipIfAsked(jw);
            else
                this.showTipRightNow(jw);
            end
        end
        
        function showTipIfAsked(this, jw)
            jw=Gui.JWindow(jw);
            app=BasicMap.Global;
            quest=Html.WrapSmallBold(...
                '<center>Keep moving associated windows?</center>', app);
            north=Gui.FlowPanelCenter(0,0, quest);
            btnAlways=Gui.NewBtn(Html.WrapSmallBold('Yes, always', app), ...
                @(h,e)alwaysMove());
            btnWhenAsked=Gui.NewBtn(Html.WrapSmallBold(...
                'Only if <font color="red">asked</font>', app), @(h,e)ifAsked);
            south=Gui.FlowLeftPanel(0,0, btnAlways, btnWhenAsked);
            pnl=Gui.BorderPanel([], 0, 0, 'North', north, 'South', south);
            [midRight, d]=Gui.GetCenterRightLocation(jw, pnl);
            BasicMap.Global.showToolTip(jw.getContentPane, pnl, ...
                midRight, -(d.height*2), 5)
            function alwaysMove
                this.always.add(jw);
                app.closeToolTip
            end
            
            function ifAsked
                this.always.remove(jw);
                app.closeToolTip
            end
        end
        
        function showTipRightNow(this, jw)
            jw=Gui.JWindow(jw);
            app=BasicMap.Global;
            
            quest=Html.WrapSmallBold(...
                '<center>Move associated windows?</center>', app);
            north=Gui.FlowPanelCenter(0,0, quest);
            btnAlways=Gui.NewBtn(Html.WrapSmallBold('Always', app),...
                @(h,e)alwaysMove());
            btnWhenAsked=Gui.NewBtn(Html.WrapSmallBold(...
                'Right <font color="red">now</font>!', app), @(h,e)rightNow);
            south=Gui.FlowLeftPanel(0,0, btnAlways, btnWhenAsked);
            pnl=Gui.BorderPanel([], 0, 0, 'North', north, 'South', south);
            [midRight, d]=Gui.GetCenterRightLocation(jw, pnl);
            BasicMap.Global.showToolTip(jw.getContentPane, pnl, ...
                midRight, -(d.height*2), 5)
            
            function alwaysMove
                this.always.add(jw);
                rightNow
            end
            
            function rightNow
                this.moved(jw);
                app.closeToolTip;
            end
        end
    end
    
    methods(Static)
        function [f1, f2, f3]=TestFigs(visible1st, visible2nd)
            cnt=1;
            f1=new1;
            f2=new1;
            if nargin<1 || visible1st
                f2.Visible='off';
            end
            f3=new1;
            if nargin<1 || visible1st
                f3.Visible='off';
            end

            f4=new1;
            if nargin<1 || visible1st
                f4.Visible='off';
            end
            BasicMap.Global.sw.clear;
            
            SuhWindow.Follow(f2, f1, 'east++');
            SuhWindow.Follow(f3, f2, 'south++');
            SuhWindow.Follow(f4, f2, 'north east++');
            if nargin<2 || visible2nd
                %f2.Visible='on';
                SuhWindow.SetFigVisible(f2);
                %f3.Visible='on';
                SuhWindow.SetFigVisible(f3);
                %f4.Visible='on';
                SuhWindow.SetFigVisible(f4);
            end
            function f=new1()
                f=Gui.NewFigure;
                set(f, 'Name', ['Fig #' num2str(cnt)]);
                cnt=cnt+1;
                p=get(f, 'OuterPosition');
                p(3)=p(3)*.33;
                p(4)=p(4)*.33;
                set(f, 'OuterPosition', p);
            end
        end
        function [j1, j2, j3]=TestJava
            cnt=1;
            j1=new1;
            j2=new1;
            j2.setVisible(false);
            j3=new1;
            j3.setVisible(false);
            BasicMap.Global.sw.clear;
            
            SuhWindow.Follow(j2, j1, 'east++');
            SuhWindow.Follow(j3, j2, 'south++');
            
            j2.setVisible(true);
            j3.setVisible(true);
            
            function J=new1()
                [fig, ~, J]=Gui.NewFigure;
                set(fig, 'Name', ['Fig #' num2str(cnt)]);
                cnt=cnt+1;
                p=get(fig, 'OuterPosition');
                p(3)=p(3)*.33;
                p(4)=p(4)*.33;
                set(fig, 'OuterPosition', p);
            end
        end
        
        function SetFigVisible(fig)
            if Gui.IsFigure(fig)
                Gui.FitFigToScreen(fig);
                set(fig, 'visible', 'on');
                drawnow;
                sw=BasicMap.Global.sw;
                sw.forgetVisibleFigures(fig);
                sw.startFollowingIfWasInvisible(fig);
            end
        end
        
        function Moved(jw, fig)
            if jw.isVisible
                spot=jw.getLocationOnScreen;
                MatBasics.RunLater(@(h,e)SuhWindow.MoveFollowers(...
                    spot, jw,fig), .25);
            end
        end
        
        function MoveFollowers(spot, jw, fig)
            spotNow=jw.getLocationOnScreen;
            if isequal(spotNow, spot) 
                this=BasicMap.Global.sw;
                if ~this.handlingMoved
                    if this.showTipAndMoveIfAlways(jw)
                        this.moved(fig);
                    end
                end
            elseif SuhWindow.TESTING
                fprintf('%s is moving\n',jw.getTitle);
            end
        end
        
        function  ttl=GetTitle(jw, fig)
            if ~isempty(jw)
                ttl=jw.getTitle;
            else
                ttl=fig.Name;
            end
        end
        function Follow(follower, followed, where, closeToo)
            if nargin<4
                closeToo=true;
                if nargin<3
                    where='east+';
                end
            end
            if iscell(followed)
                if length(followed)>2
                    closeToo=followed{3};
                end
                where=followed{2};
                followed=followed{1};
            end
            if isempty(followed) || isempty(follower) ...
                    || ~ishandle(followed) || ~ishandle(follower)
                return;
            end
            drawnow;
            jwFollowed=Gui.JWindow(followed);
            sw=BasicMap.Global.sw;
            jwFollower=sw.rememberInvisibleFigure(...
                follower, followed, where);
            if SuhWindow.TESTING
                fprintf('"%s" is following "%s"\n', ...
                    SuhWindow.GetTitle(jwFollower, follower),...
                    SuhWindow.GetTitle(jwFollowed, followed));
            end
            if isempty(jwFollower) || isempty(jwFollowed) %followed invisible
                if Gui.IsFigure(followed)
                    %invisible figures can be located
                    Gui.Locate(follower, followed, where);
                end
            else
                sw.follow(jwFollower, jwFollowed, where);
            end
            set(jwFollowed, 'ComponentMovedCallback',...
                @(h,e)SuhWindow.Moved(jwFollowed, followed));
            if closeToo && Gui.IsFigure(followed)
                priorCloseFcn=get(followed, 'CloseRequestFcn');
                set(followed, 'CloseRequestFcn', @hushFollowed);
            end
            if Gui.IsFigure(follower)
                priorCloseFollower=get(follower, 'CloseRequestFcn');
                set(follower, 'CloseRequestFcn', @hushFollower);
            end
            
            function hushFollower(h,e)
                try
                    jw2=Gui.JWindow(follower);
                    if SuhWindow.TESTING
                        if ~isempty(jw2)
                            fprintf('Am closing follower "%s"\n', jw2.getTitle);
                        end
                    end
                    if isa(priorCloseFollower, 'function_handle')
                        feval(priorCloseFollower, h,e);
                    elseif ischar(priorCloseFollower)
                        feval(priorCloseFollower);
                    end
                    sw.remove(jw2);
                catch ex
                    ex.getReport
                end
            end

            function hushFollowed(h,e)
                jwFollowed=Gui.JWindow(followed);
                if SuhWindow.TESTING
                    fprintf('Am closing followed "%s"\n', ...
                        jwFollowed.getTitle);
                end
                if Gui.IsFigure(follower)
                    close(follower);
                elseif ~isempty(jwFollower) && jwFollower.isVisible
                    try
                        jwFollower.dispose;
                    catch 
                        fprintf('jFollower==null?')
                    end
                end
                try
                    if isa(priorCloseFcn, 'function_handle')
                        feval(priorCloseFcn, h,e);
                    elseif ischar(priorCloseFcn)
                        feval(priorCloseFcn);
                    end
                catch ex
                    ex.getReport
                end
                sw.remove(jwFollowed);
                try
                    jwFollowed.dispose;
                catch 
                    %fprintf('jwFollowed==null?\n')
                end
            end
        end

    end
end