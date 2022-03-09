%   AUTHORSHIP
%   Primary Developer: Stephen Meehan <swmeehan@stanford.edu> 
%   Math Lead & Secondary Developer:  Connor Meehan <connor.gw.meehan@gmail.com>
%   Bioinformatics Lead:  Wayne Moore <wmoore@stanford.edu>
%   Provided by the Herzenberg Lab at Stanford University 
%   License: BSD 3 clause
classdef Binning<handle
    methods(Static)
        function G=Points(mins, maxs, M)
            G=zeros(M^2, 2);
            ye=zeros(2,M);
            for ii=1:2
                ye(ii,:) = linspace(mins(ii),maxs(ii),M);
                
            end
            k=1;
            for i=1:M
                for j=1:M
                    G(k, :)=[ye(1, i) ye(2, j)];
                    k=k+1;
                end
            end
        end
        
        function normalized=Weights(xyData, M)
            stopIfNot2dDatafrom0to1(xyData);
            N=size(xyData, 1);
            mins=[0 0];
            maxs=[1 1];
            deltas = 1/(M-1)*(maxs-mins);  %vector of distances between neighbor grid points in each dimension
            ye=zeros(2,M);
            pointLL=zeros(N,2);  %this will be the "lower left" gridpoint to each data point
            for ii = 1:2
                ye(ii,:) = linspace(mins(ii),maxs(ii),M);
                pointLL(:,ii)=floor((xyData(:,ii)-mins(ii))./deltas(ii)) + 1;
            end
            %% compute w
            Deltmat=repmat(deltas,N,1);
            shape=M*ones(1,2);
            wmat=zeros(M,M);
            for ii=0:1  %number of neighboring gridpoints in 2 dimensions
                for j=0:1
                    pointm=pointLL+repmat([j ii],N,1);  %indices of ith neighboring gridpoints
                    pointy=zeros(N,2);
                    for k=1:2
                        pointy(:,k)=ye(k,pointm(:,k));  %y-values of ith neighboring gridpoints
                    end
                    W=prod(1-(abs(xyData-pointy)./Deltmat),2);  %contribution to w from ith neighboring gridpoint from each datapoint
                    wmat=wmat+accumarray(pointm,W,shape);  %sums contributions for ith gridpoint over data points and adds to wmat
                end
            end
            wmat=reshape(wmat, [1, M^2]);
            normalized=wmat/sum(wmat);
        end

        
        function [counts, edges, means, binIdxs]=Counts(bivariateData, numBinsOrEdges)
            M=16;
            stopIfNot2dDatafrom0to1(bivariateData);
            univariateData=Binning.MakeUnivariate(bivariateData, [0 0], [1 1], M);
            if nargin>1
                [counts, edges, binIdxs]=histcounts(univariateData, numBinsOrEdges);
            else
                [counts, edges, binIdxs]=histcounts(univariateData);
            end
            counts=counts/size(bivariateData,1);
            if nargout>2
                uniqueBinIdxs=unique(binIdxs);
                means=zeros(length(counts), 2);
                N=length(uniqueBinIdxs);
                for i=1:N
                    b=uniqueBinIdxs(i);
                    means(b,:)=mean(bivariateData(binIdxs==b, :), 1);
                end
            end
        end
        
        function [X, Y]=ToDataScale(gridXy, mins, maxs, M)
            deltas=1/(M-1)*(maxs-mins);
            X=mins(1)+((gridXy(:,1)-1)*deltas(1));
            Y=mins(2)+((gridXy(:,2)-1)*deltas(2));
        end

        function [gridXy, onScale]=ToGridXy(xy, M, mins, maxs)
            if nargin<4
                maxs=max(xy);
                if nargin<3
                    mins=min(xy);
                    if nargin<2
                        M=128;
                    end
                end
            end
            d=size(xy,2);
            ye=zeros(d,M);
            for i = 1:d
                ye(i,:) = linspace(mins(i),maxs(i),M);                
            end
            [xGrid, yGrid]=meshgrid(ye(1,:),ye(2,:));
            gridPoints=interp2(xGrid, yGrid, reshape(1:M^2,M,M)',...
                xy(:,1),xy(:,2),'nearest'); 
            onScale=~isnan(gridPoints);
            [xx, yy]=ind2sub(M, gridPoints(onScale));
            gridXy=[xx yy];
        end

        function [gridPoints, onScale]=MakeUnivariate(xy, mins, maxs, M)
            d=size(xy,2);
            ye=zeros(d,M);
            for i = 1:d
                if mins(i) == maxs(i)
                    maxs(i)=1.0001*mins(i);
                end
                
                ye(i,:) = linspace(mins(i),maxs(i),M);                
            end
            MM = M^2; %number of total gridpoints
            z=reshape(1:MM,M,M);
            %% assign each data point to its closest grid point
            [xGrid, yGrid]=meshgrid(ye(1,:),ye(2,:));
            gridPoints=interp2(xGrid, yGrid, z', xy(:,1),xy(:,2),'nearest'); 
            onScale=~isnan(gridPoints);
        end
        
        function [counts, means, edges, bivariateData]=...
                DistCounts(bivariateData, numBinsOrEdges)            
            univariateData=pdist2(bivariateData, [1 1]); 
            if nargin==1
                [counts, edges, binIdxs]=histcounts(univariateData);
            else
                [counts, edges, binIdxs]=histcounts(univariateData, numBinsOrEdges);                    
            end
            counts=counts/size(bivariateData,1);
            uniqueBinIdxs=unique(binIdxs);
            means=zeros(length(counts), 2);
            N=length(uniqueBinIdxs);
            for i=1:N
                b=uniqueBinIdxs(i);
                if b>0
                    l=binIdxs==b;
                    if any(l)
                        means(b,:)=mean(bivariateData(l, :));
                    else
                        disp('empty bin');
                    end
                end
            end
        end
        
        function means=ComputeMeans(referenceMeans, otherMeans, ...
                M, spatialLogic)
            if strcmp(spatialLogic, 'grid edge')
                if M<2
                    means=referenceMeans;
                else
                    [X, Y]=ind2sub([M M], 1:M^2);
                    means=[X;Y]';
                end
            elseif strcmp(spatialLogic, 'mean of means')
                means=Binning.MergeMeans(referenceMeans, otherMeans);
            elseif strcmp(spatialLogic, 'reference means')
                means=referenceMeans;
            else
                ME = MException('QuadraticForm:StaticCounts', ...
                    'spatial logic "%s" not recognized', spatialLogic);
                throw(ME)
            end
        end
        
        function result=MergeMeans(m1, m2, test)
            
            r=size(m1,1);
            mm=[reshape(m1, 1, r*2);reshape(m2,1,r*2)];
            result=reshape(mean(mm), r,2);
            if nargin>2 && test
                out=zeros(r,2);
                for i=1:r
                    out(i,:)=mean([m1(i,:);m2(i,:)]);
                end
            end
        end

    end
end