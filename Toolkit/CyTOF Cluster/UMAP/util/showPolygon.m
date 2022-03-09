%   AUTHORSHIP
%   Primary Developer: Stephen Meehan <swmeehan@stanford.edu> 
%   Provided by the Herzenberg Lab at Stanford University 
%   License: BSD 3 clause
%
function selectedRows=showPolygon(data, X, Y,...
    polygon, curAxes, columnNames, ttl, zeroTo1, ...
    xTicks, yTicks)
if nargin<10
    yTicks='compute';
    if nargin<9
        xTicks='compute';
        if nargin<8
            zeroTo1=true;
            if nargin<7
                ttl=[];
                if nargin<6
                    columnNames='';
                    if nargin<5
                        curAxes=gca;
                        if nargin<4
                            polygon=[];
                        end
                    end
                end
            end
        end
    end
end
if X<=0 || Y<=0
    selectedRows=[];
    if X<=0
        warning('X must be >  0');
    else
        warning('Y must be >  0');
    end
    return;
end
if strcmp(curAxes, 'new')
    f=Gui.Figure;
    f.Visible='on';
    curAxes=Gui.Axes(f);
end
wasHeld=ishold(curAxes);
[R,C]=size(data);
xy=[data(:,X) data(:,Y)];

DISPLAY_LIMIT=75000;
if R>DISPLAY_LIMIT
    limitRows=randi(R, 1,DISPLAY_LIMIT);
    ProbabilityDensity2.Draw(curAxes, xy(limitRows, :), ...
        true, true, true, .05, 10);
else
    ProbabilityDensity2.Draw(curAxes, xy, ...
        true, true, true, .05, 10);
end
hold(curAxes, 'on');
axis(curAxes, 'square');
setLim(true);
setLim(false)
grid(curAxes, 'on')
if ~isempty(columnNames)
    N=length(columnNames);
    if X<=N
        xlabel(curAxes, ['#' num2str(X) ': ' columnNames{X}]);
    end
    if Y<=N
        ylabel(curAxes, ['#' num2str(Y) ': ' columnNames{Y}]);
    end
end
if ~isempty(ttl)
    title(curAxes, ttl);
end
if ~isempty(polygon)
    clr=[1  0 1];
    plot(curAxes, polygon(:,1), polygon(:,2), ...
        'LineWidth',2,...
        'Color', clr,...
        'Marker', 'd', ...
        'MarkerSize',2,...
        'MarkerEdgeColor', clr,...
        'MarkerFaceColor',[0.5,0.0,0.5]);
    selectedRows=inpolygon(xy(:,1), xy(:,2), ...
        polygon(:,1), polygon(:,2));
    fprintf('%d rows selected by polygon for part 1 of split\n', sum(selectedRows));
    fprintf('%d rows selected by polygon for part 2 of split\n', sum(~selectedRows));
    fprintf('\n');
else
    selectedRows=[];
end
handleTicks(true);
handleTicks(false);
if ~wasHeld
    hold(curAxes, 'off');
end
drawnow;

    function handleTicks(isX)
        clearLabels=false;
        if isX
            ticks=xTicks;
            fnc1=@xticks;
            fnc2=@xticklabels;
        else
            ticks=yTicks;
            fnc1=@yticks;
            fnc2=@yticklabels;
        end
        if isequal(ticks, 'none')
            return;
        end
        if isequal(ticks, 'compute')
            if zeroTo1
                clearLabels=true;
                ticks=[ 0 .25 .5 .75 100];
            else
                ticks=[];
            end
        end
        if ~isempty(ticks)
            feval(fnc1, curAxes, ticks);
        end
        if clearLabels
            feval(fnc2, curAxes, {});
        end
    end

    function setLim(isX)
        if zeroTo1
            if isX
                l=xlim(curAxes);
            else
                l=ylim(curAxes);
            end
            if l(1)>0 || l(2)<1
                if l(1)>0
                    l(1)=0;
                end
                if l(2)<1
                    l(2)=1;
                end
                if isX
                    xlim(curAxes,l);
                else
                    ylim(curAxes,l);
                end
            end
        end
    end
end
        