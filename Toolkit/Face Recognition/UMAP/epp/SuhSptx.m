classdef SuhSptx < handle
    properties(Constant)
        BAD_KLD_FREQ=.0075; 
        LOG=false;
    end
    
    methods(Static)
        

        function B=EventsPerBin(density)
            java;
            M=density.M;
            D=MatBasics.HistCounts(density.eventBinIdxs);
            U=unique(density.eventBinIdxs);
            B=zeros(1,M*M);
            B(U)=D;
        end
        
        function [allClues,clueNoisyCnts, clueNoisyCnts2]...
                =AssignClustersToNoise(density)
            N=density.numClusters;
            M=density.M;
            pointers=density.pointers;
            ptrsToCluEdge=pointers;
            for i=1:N
                ind=gridEdgeInd(i, M, density.mins, density.deltas, pointers);
                % mark which grid points are cluster edge point
                ptrsToCluEdge(ind)=0-i;
            end
            edgeInd=find(ptrsToCluEdge<0)';
            noiseInd=find(pointers==0)';
            [edgeX, edgeY]=ind2sub([M M], edgeInd);
            [noiseX, noiseY]=ind2sub([M M], noiseInd);
            [~, idxs]=pdist2( [edgeX edgeY], [noiseX noiseY], 'euclidean',...
                'SMALLEST', 1);
            % mark background grid points as belonging to closest cluster
            allClues=pointers;
            allClues(noiseInd)=pointers(edgeInd(idxs));
            if nargout>1
                clueNoisyCnts=MatBasics.HistCounts(allClues(density.eventBinIdxs));
                if nargout>2
                    u=unique(allClues);
                    clueNoisyCnts2=zeros(1,max(u));
                    eventsPerBin=SuhSptx.EventsPerBin(density);
                    for i=1:length(u)
                        clue=u(i);
                        clueNoisyCnts2(clue)=sum(eventsPerBin(allClues==clue));
                    end
                end
            end
        end
        
        function [score, this]=New(density, balanced, balancedNoisy, ...
                trimLeaves, minLeafSize)
            if density.numClusters>5
                threads=BasicMap.Global.physicalCores;
            else
                threads=0;
            end
            this=SuhSptx(density, balancedNoisy, trimLeaves);
            J=this.getJava(balanced, minLeafSize);
            J.verboseFlags=0;%1;%15;
            if threads>0
                J.computeInParallel(threads)
            else
                J.compute;
            end
            score=J.getBestScore;
            if isnan(score)
                score=1;
            end
        end
        
        function edge=Edge(clusterId, M, pointers)
            cluInd=find(pointers==clusterId);
            edge=edu.stanford.facs.swing.GridClusterEdge.Get(M, cluInd);
        end
        
        function [percentDensity, borders, ptrsToSeparatrix]=...
                Split(dns, ptrsTo2Sides)
            borders=false(1,4);
            M=dns.M;
            ptrsToSeparatrix=zeros(M^2,1);
            ind=gridEdgeInd(1, M, dns.mins, dns.deltas, ptrsTo2Sides);
            ptrsToSeparatrix(ind)=1;
            side=ones(1, M);
            ptrsToSeparatrix(sub2ind([M M], 1:M, side))=0;
            ptrsToSeparatrix(sub2ind([M M], side, 1:M))=0;
            side(:)=M;
            ptrsToSeparatrix(sub2ind([M M], 1:M, side))=0;
            ptrsToSeparatrix(sub2ind([M M], side, 1:M))=0;
            newEdgeBins=find(ptrsToSeparatrix);
            [X, Y]=ind2sub([M M], newEdgeBins);
            borders(1)=any(X<=2);
            borders(2)=any(X>=255);
            borders(3)=any(Y<=2);
            borders(4)=any(Y>=255);
            percentDensity=sum(dns.fmatVector(ptrsToSeparatrix>0))/sum(dns.fmatVector);
        end
        
        function ShowPolygons(this, ax)
            [A, B]=this.getPolygons();
            SuhSptx.Show(ax, A);
            SuhSptx.Show(ax, B);
        end
        
        function [H, x, y]=TestPolygon(this, xy, ax, isPart1, useBoundary)
            p=this.getPolygon(isPart1, useBoundary);
            H=impoly(ax, p);
            ip=inpolygon(xy(:,1),xy(:,2), p(:,1), p(:,2));
            [A, B]=this.getPolygons;
            fprintf('cells=%d, is A?=%d, is B?=%d?\n', ...
                sum(ip), isequal(A, p), isequal(B, p));
            delete(H);
        end
        
        function H=Show(ax, xy)
            H=plot(ax, xy(:,1), xy(:,2), ...
                'LineWidth',2,...
                'Color', 'black',...
                'Marker', 'd', ...
                'MarkerSize',4,...
                'MarkerEdgeColor','red',...
                'MarkerFaceColor',[0.5,0.5,0.5]);
        end
        
       
        function [edgeInd, gce]=GridEdgeInd(clusterId, M, mins, deltas, pointers)
            cluInd=find(pointers==clusterId);
            gce=edu.stanford.facs.swing.GridClusterEdge(M);
            gce.computeAll(cluInd, mins, deltas)
            edgeInd=gce.edgeBins;
        end
        function edges=NoiseLessEdges(density)
            M=density.M;
            N=density.numClusters;
            pointers=density.pointers;
            if N<=1
                edges={};
                return;
            end
            ptrsToCluEdge=pointers;
            for i=1:N
                ind=SuhSptx.GridEdgeInd(i, M, density.mins, density.deltas, pointers);
                % mark which grid points are cluster edge point
                ptrsToCluEdge(ind)=0-i;
            end
            edgeInd=find(ptrsToCluEdge<0)';
            noiseInd=find(pointers==0)';
            [edgeX, edgeY]=ind2sub([M M], edgeInd);
            [noiseX, noiseY]=ind2sub([M M], noiseInd);
            [~, idxs]=pdist2( [edgeX edgeY], [noiseX noiseY], 'euclidean',...
                'SMALLEST', 1);
            % mark background grid points as belonging to closest cluster
            ptrsToNewClusters=pointers;
            ptrsToNewClusters(noiseInd)=pointers(edgeInd(idxs));
            edges=cell(1, N);
            for i=1:N
                if i==2 && N==2
                    continue;
                end
                edges{i}=gridEdgeInd(i, M, density.mins, density.deltas, ptrsToNewClusters);
            end
        end 
    end
        
    properties
        gexys=[];
        noiseXys;
        density=[];
        alreadyDone;
        clueDists;
        allClues;
        clueNoisyCnts;
        clueCnts4Balanced;
        clueCnts4MinSplit;
        edgy;%Edgy and dull and cut a six inch valley
        hasTooLow=false;
        java;
    end
    
    methods
        function this=SuhSptx(density, balancedNoisy, trimLeaves)
            this.density=density;
            this.alreadyDone=java.util.TreeSet;
            N=density.numClusters;
            this.gexys=cell(1, N);
            M=density.M;
            this.gexys=cell(1, N);
            if N>1
                nle=SuhSptx.NoiseLessEdges(density);
                for i=1:N
                    [x, y]=ind2sub([M M], nle{i});
                    this.gexys{i}=[x y];
                end
            else
                fprintf('\nCannot do a separatrix with %d cluster(s)!!\n', N);
            end
            this.computeClueDists;
            
            [this.allClues, clueNoisyCnts]=SuhSptx.AssignClustersToNoise(density);
            this.clueNoisyCnts=clueNoisyCnts;
            clueCnts=density.getClusterCounts;
            if balancedNoisy
                this.clueCnts4Balanced=clueNoisyCnts;
            else
                this.clueCnts4Balanced=clueCnts;
            end
            if trimLeaves
                this.clueCnts4MinSplit=clueCnts;
            else
                this.clueCnts4MinSplit=clueNoisyCnts;
            end
        end
        

        function J=getJava(this, balanced, minLeafSize)
            if nargin<5
                minLeafSize=0;
            end
            dns=this.density;
            normal=[];
            tooLow=[];
            kld=40;%ignore kld test done before now
            kldThreshold=0; 
            kldFreqThreshold=.0075; % not used any more
            J=edu.stanford.facs.swing.Separatrix(...
                this.clueCnts4Balanced, this.clueDists, tooLow, ...
                dns.M, this.allClues, dns.fmatVector, kld, normal, ...
                kldThreshold, kldFreqThreshold, minLeafSize, ...
                length(dns.onScale), this.clueCnts4MinSplit);
            J.setBalanced(balanced);
            this.java=J;
        end
        
        function [A, B]=getPolygons(this, useBoundary, tolerance) 
            if nargin<3
                tolerance=1;
                if nargin<2
                    useBoundary=false;
                end
            end
            A=this.getPolygon(true,useBoundary, tolerance);
            B=this.getPolygon(false, useBoundary, tolerance);
        end
        
        function xy=getPolygon(this, isPart1, useBoundary, tolerance)
            if nargin<4
                tolerance=1;
            end
            try
                J=this.java;
                if  ~useBoundary
                    poly=J.getPolygon(tolerance);
                    p=double(poly.getPoints(isPart1));
                else
                    if isPart1
                        poly=J.getPolygon;
                    else
                        poly=J.getPolygon(J.getOtherClusters(J.getBestClusterGroup));
                    end
                    p=double(poly.part1Xy);
                    p=double(poly.simplify(p(boundary(p), :), tolerance));
                end
            catch ex
                ex.getReport
                xy=[];
                return;
            end
            if isempty(p) 
                if ~useBoundary
                    xy=this.getPolygon(isPart1, true, tolerance);
                else
                    xy=[];
                end
                return; % boundary needed
            end
            [x,y]=this.density.toData(p(:,1), p(:,2));
            xy=[x y];
        end
    end
    
    methods(Access=private)
        
        function ok=good(this, thisPartClues)
            N1=length(thisPartClues);
            if N1==1
                ok=true;
                return;
            end
            fromClue=thisPartClues(1);
            done=this.alreadyDone;
            for i=2:N1
                done.clear;
                toClue=thisPartClues(i);
                done.add(toClue);
                ok=this.contiguous(thisPartClues, N1, ...
                    fromClue, toClue, done);
                if ~ok
                    return;
                end
            end
            ok=true;
        end
        
        function ok=contiguous(this, clues, N1, fromClue, toClue, done)
            ok=this.clueDists(fromClue,toClue)<=1;
            if ok
                return;
            end
            done.add(fromClue);
            if N1-done.size<1
                return;
            end
            %Search for INdirect contiguity
            for ii=1:N1
                clue=clues(ii);
                if this.clueDists(fromClue, clue)<=1
                    if ~done.contains(clue)
                        okInDirectly=...
                            this.contiguous(clues, N1, clue, toClue, ...
                            done);
                        if okInDirectly
                            ok=true;
                            return;
                        end
                    end
                end
            end
        end
        
        function dists_=computeClueDists(this)
            c=this.density.getClusterMat;
            N_=this.density.numClusters;
            dists_=zeros(N_, N_);
            for i=1:N_
                here=this.gexys{i};
                for j=i+1:N_
                    if ~isempty(here) && ~isempty(this.gexys{j})
                        dists_(i,j)=min(pdist2(here, this.gexys{j},'euclidean', ...
                            'smallest', 1));
                        dists_(j,i)=dists_(i,j);
                    end
                end
            end
            this.clueDists=dists_;
        end
    end
end