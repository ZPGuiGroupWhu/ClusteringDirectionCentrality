classdef RoiUtil < handle
%   AUTHORSHIP
%   Primary Developer: Stephen Meehan <swmeehan@stanford.edu> 
%   Math Lead & Secondary Developer:  Connor Meehan <connor.gw.meehan@gmail.com>
%   Bioinformatics Lead:  Wayne Moore <wmoore@stanford.edu>
%   Provided by the Herzenberg Lab at Stanford University 
%   License: BSD 3 clause
%
    properties(Constant)
        V='9.6';
        POLYGON='impoly';
        RECTANGLE='imrect';
        ELLIPSE='imellipse';
        NEW_COLOR=[.1 .66 .9];
        EDIT_COLOR=[.71 .839 .06];
    end
    
    methods(Static)
        function ok=CanDoNew
            ok=~verLessThan('matlab',  RoiUtil.V);
        end
        
        function [roi, str]=NewForXy(ax, xy, tolerance, cbMoved)
            if nargin<4
                cbMoved=[];
                if nargin<3
                    tolerance=1;
                end
            end
            xy=xy(boundary(xy(:,1), xy(:,2), .1241), :);
            xy=double(edu.stanford.facs.swing.CurveSimplifier.ToArray(...
                xy, tolerance));
            [roi, str]=RoiUtil.NewPolygon(ax, xy, cbMoved);
        end
        
        function oldClr=SetColor(roi, clr)
            oldRoi=~RoiUtil.CanDoNew;
            if ~oldRoi
                oldClr=roi.Color;
                roi.Color=clr;
            else
                oldClr=roi.getColor;
                roi.setColor(clr);
            end
        end
        
        function oldLbl=SetLabel(roi, lbl)
            oldRoi=~RoiUtil.CanDoNew;
            try
                if ~oldRoi
                    oldLbl=roi.Label;
                    roi.Label=lbl;
                end
            catch
            end
        end
        
        function [roi, str]=NewPolygon(ax, xy, cbMoved)
            str=MatBasics.XyToString(xy);            
            oldRoi=~RoiUtil.CanDoNew;
            if ~oldRoi
                roi=drawpolygon(ax, ...
                    'Position', xy,...
                    'ContextMenu', [], 'SelectedColor', ...
                    RoiUtil.NEW_COLOR);
            else
                roi=impoly(ax, xy);
                roi.setColor(RoiUtil.NEW_COLOR);
            end
            if ~isempty(cbMoved)
                if oldRoi
                    roi.addNewPositionCallback(...
                        @(pos)RoiUtil.OldRoiMoved(cbMoved, roi));
                else
                    addlistener(roi, 'ROIMoved', ...
                        @(src,evt)RoiUtil.Moved(cbMoved, src));
                    
                end
                feval(cbMoved,roi);
            end
        end
        
        function roi=New(ax, type, cbMoved, cbMoving)
            oldRoi=~RoiUtil.CanDoNew;
            if strcmp(type, RoiUtil.RECTANGLE)
                if ~oldRoi
                    roi=drawrectangle(ax, 'ContextMenu', [],...
                        'Rotatable', true, 'SelectedColor', ...
                        RoiUtil.NEW_COLOR);
                else
                    roi=imrect(ax);
                end
            elseif strcmp(type, RoiUtil.ELLIPSE)
                if ~oldRoi
                    roi=drawellipse(ax, 'RotationAngle', 0, ...
                        'ContextMenu', [], 'SelectedColor', ...
                        RoiUtil.NEW_COLOR);
                else
                    roi=imellipse(ax);
                end
            else
                if ~oldRoi
                    roi=drawpolygon(ax, ...
                        'ContextMenu', [], 'SelectedColor', ...
                        RoiUtil.NEW_COLOR);
                else
                    roi=impoly(ax);
                end
            end
            if oldRoi
                roi.addNewPositionCallback(...
                    @(pos)RoiUtil.OldRoiMoved(cbMoved, roi));
            else
                if nargin>3
                    addlistener(roi, 'MovingROI', ...
                        @(src,evt)RoiUtil.Moving(cbMoving, src));
                end
                addlistener(roi, 'ROIMoved', ...
                    @(src,evt)RoiUtil.Moved(cbMoved, src));
                
            end
            feval(cbMoved,roi);
        end
        
        function OldRoiMoved(cb, roi)
            feval(cb, roi);
        end
        
        function Moving(cb, roi)
            feval(cb, roi);
        end

        function Moved(cb, roi)
            feval(cb, roi);
        end
        
        function ok=IsNewRoi(roi)
            ok=isa(roi, 'images.roi.Ellipse') ||...
                isa(roi, 'images.roi.Rectangle') ||...
                isa(roi, 'images.roi.Polygon');
        end
        
        function position=Position(roi)
            if ~RoiUtil.IsNewRoi(roi)
                position=roi.getPosition();
            else
                if isa(roi, 'images.roi.Ellipse')
                    c=get(roi, 'Center');
                    sa=get(roi, 'SemiAxes');
                    position=[c(1)-sa(1) c(2)-sa(2) sa(1)*2 sa(2)*2];
                    if roi.RotationAngle ~=0
                        position(end+1)=roi.RotationAngle;
                    end
                else
                    position=get(roi, 'Position');
                    if isa(roi, 'images.roi.Rectangle')
                        if roi.RotationAngle ~=0
                            position(end+1)=roi.RotationAngle;
                        end
                    end
                end
            end
        end
        
                
        function rows=GetRows(roi, data2D)
            if RoiUtil.IsNewRoi(roi)
                rows=roi.inROI(data2D(:,1), data2D(:,2));
                return;
            end
            pos=RoiUtil.Position(roi);
            typeT=class(roi);
            if strcmpi(typeT,RoiUtil.ELLIPSE)
                rows=RoiUtil.InEllipseUnrotated(data2D(:,1), data2D(:,2), pos);
            elseif strcmpi(typeT, RoiUtil.RECTANGLE)
                rows=RoiUtil.InRectUnrotated(data2D(:,1), data2D(:,2), pos);
            elseif strcmp(typeT, RoiUtil.POLYGON)
                rows=inpolygon(data2D(:,1), data2D(:,2),pos(:,1),pos(:,2));
            else
                rows=[];
            end
        end
        

        function inside=InEllipseUnrotated(X, Y, pos)
            xmin = pos(1);
            ymin = pos(2);
            width = pos(3);
            height = pos(4);
            a = width/2;
            b = height/2;
            center = [xmin+a, ymin + b];
            inside = (X - center(1)*ones(size(X))).^2./a^2 + ...
                (Y - center(2)*ones(size(Y))).^2./b^2 <= ones(size(X));
        end
        
        function inside=InRectUnrotated(X, Y, pos)
            xmin = pos(1);
            ymin = pos(2);
            width = pos(3);
            height = pos(4);
            a = width/2;
            b = height/2;
            center = [xmin+a, ymin + b];
            inside = abs(X - center(1)*ones(size(X))) <= a*ones(size(X))...
                & abs(Y - center(2)*ones(size(Y))) <= b*ones(size(Y));
        end
        

    end
end