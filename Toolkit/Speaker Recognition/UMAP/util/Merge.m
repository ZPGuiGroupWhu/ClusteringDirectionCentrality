%   AUTHORSHIP
%   Primary Developer: Stephen Meehan <swmeehan@stanford.edu> 
%   Math Lead & Secondary Developer:  Connor Meehan <connor.gw.meehan@gmail.com>
%   Bioinformatics Lead:  Wayne Moore <wmoore@stanford.edu>
%   Provided by the Herzenberg Lab at Stanford University 
%   License: BSD 3 clause
classdef Merge < handle
    methods(Static)
        
        function peaks=Peaks(ptrs)
            peaks=find(ptrs < -1); %indices of gridpoints with pointers to dummy states representing clusters
        end

        function changes=ForNonConstant(dns, peaks)
            changes={};
            debug=DensityBiased.DEBUG;
            nPeaks=length(peaks);  %number1 of dummy states
            distanceThreshold=dns.M*DensityBiased.DFLT_MAX_TWIN_PEAK_DIST;
            for i = 1:nPeaks
                peak=peaks(i);
                [x,y]=ind2sub([dns.M dns.M], peak);
                fPeak=dns.fmatVector(peak);
                nnPeak=dns.nnVec(peak);
                clue=dns.pointers(peak);
                test1=fPeak * (1+sqrt(2/nnPeak));
                others=find(dns.pointers<-1 & dns.pointers~=clue);
                [X, Y]=ind2sub([dns.M dns.M], others);
                if isempty(X) 
                    continue;
                end
                [pd, I]=pdist2([X;Y]', [x y], 'Euclidean', 'Smallest', 25);
                if pd(1)<distanceThreshold
                    [u, uI, II]=unique(pd);
                    top=find(II==1);
                    top=I(top);
                    top=others(top);
                    [maxDns, I]=max(dns.fmatVector(top));
                    mergeTo=top(I);
                    nnMerge=dns.nnVec(mergeTo);
                    test2=dns.fmatVector(mergeTo)*(1-sqrt(2/nnMerge));
                    if test1>=test2
                        if debug
                            [x2,y2]=ind2sub([dns.M dns.M], mergeTo);
                            fprintf(['Merge idx=%d (dns=%d x=%d y=%d)'...
                                ' to idx=%d (dns=%d x=%d y=%d)\n'], ...
                                peak, ceil(fPeak), x, y, mergeTo, ...
                                ceil(dns.fmatVector(mergeTo)), x2, y2);
                        end
                        changes{end+1}=[peak mergeTo maxDns];
                    end
                elseif debug
                    fprintf(['No merge for idx=%d (dns=%d x=%d y=%d)'...
                        'closest dist=%s\n'], ...
                        peak, ceil(fPeak), x, y, ...
                        String.encodeRounded(pd(1), 2));
                end
            end
        end
        
        
        function ForConstantDensity(dns, javaDbm, Pointers, stdErr)
            outerLoop=0;
            MM=dns.M^2;
            neighborhood=cell(1, MM);
            possibleClusterTears=[];
            pu=[];
            changes=1;
            f=reshape(dns.fmat, [1 MM]);
            while outerLoop==0 || changes>0 %PUBREF=STEP 5 handle necessary repetitions
                outerLoop=outerLoop+1;
                %PUBREF=STEP 4
                %pu=reportClusterMerging(outerLoop, changes, peaks, pu, startTime);
                newPointers=Pointers;
                peaks= find(Pointers < -1); %indices of gridpoints with pointers to dummy states representing clusters
                fDummies = f(peaks);  %densities at gridpoints that have pointers to dummy states
                numDummies = length(peaks);  %number1 of dummy states
                
                [~,ix]=sort(fDummies,'descend');
                newDummies=peaks(ix);  %indices of gridpoints with pointers to dummy states in order of decreasing density
                innerLoop=0;
                for i = 1:numDummies
                    innerLoop=innerLoop+1;
                    %make A
                    A = newDummies(i);
                    test=(f(newDummies(i)) - stdErr(newDummies(i)));
                    if Pointers(A)>0
                        % Rachel originally commented:
                        %I can't remember why this is here because
                        %everything in newDummies should have pointers
                        %to dummy states, but I am too lazy to
                        %remove it, assuming I put it here for a%
                        %reason initially.
                        
                        % Answer to Rachel's comment is that the new
                        % merging she did on 6_22_10 WILL cause this when
                        % if ~isempty(starts) && any(f_starts>maxQ)
                        
                        continue
                    end
                    sizeOfA = 0;
                    for k=1:MM
                        newSizeOfA=length(A);
                        if newSizeOfA > sizeOfA  %if not all of A has had its neighbors checked yet
                            if k==newSizeOfA %if checking the neighbors of the current last member of A, update sizeofA
                                sizeOfA=k;
                            end
                            neighbors=neighborhood{A(k)};
                            if isempty(neighbors)
                                neighbors=dns.getNeighborIdxs(A(k));
                                neighborhood{A(k)}=neighbors;
                            end
                            A=[A neighbors(Pointers(neighbors)==0 & f(neighbors)+stdErr(neighbors)>test)];
                            [~, whereInA]=unique(A, 'first');  %list of indices of unique values in AA
                            A=A(sort(whereInA));  %unique values of A in order in which they originally appeared, so we don't check the same things twice
                        else
                            break  %if all of A was checked and nothing got added to AA during the last iteration, move on
                        end
                    end
                    
                    %make B
                    neighborsOfAandA=unique([cell2mat(neighborhood(A)) A]);
                    B=neighborsOfAandA(Pointers(neighborsOfAandA)<-1);
                    if length(B)>1
                        disp('huh');
                    end
                    [fQ,yQ] = max(f(B));
                    newPeak=Pointers(B(yQ));
                    tearAble=Pointers(A(Pointers(A)<-1));
                    useOldMerging=true;
                    neighborsOfMaxB=neighborhood{B(yQ)};
                    starts=Pointers(neighborsOfMaxB)>0;
                    if ~isempty(starts)
                        C=neighborsOfMaxB(starts);
                        f_starts=f(C);
                        if any(f_starts>fQ)
                            [~,maxf]=max(f_starts);
                            newPeak=Pointers(C(maxf));
                            useOldMerging=false;
                        end
                    end
                    
                    Pointers(A)=newPeak; %create pointers from all points in AA to q: changed to Pointers(q) from q
                    Pointers(B)=newPeak; %create pointers from all points in B to q:  changed to Pointers(q) from q
                    
                    if any(tearAble ~= newPeak)
                        possibleClusterTears=[possibleClusterTears tearAble];
                    end
                end
                
                changes=sum(Pointers~=newPointers);
            end
            possibleClusterTears=unique(possibleClusterTears);
            try
                if isempty(javaDbm.possibleClusterTears)
                elseif any(possibleClusterTears~=javaDbm.possibleClusterTears')
                    msgBox('New Java merging POINTER problem');
                end
                if any(Pointers~=javaDbm.pointers')
                    msgBox('New Java merging POINTER problem');
                end
            catch
            end
            %% put in final clusters
            javaDbm.fixClusterTear;
            if ~isempty(possibleClusterTears)
                possibleClusterTears=unique(possibleClusterTears);
                if Density.IsDebugging
                    fprintf('*Possible* cluster tears ---> %s\n', ...
                        MatBasics.toString(possibleClusterTears));
                end
                [Pointers, actualClusterTears]=fixClusterTear(...
                    dns.M, Pointers,  neighborhood, possibleClusterTears);
                if isempty(actualClusterTears)
                    disp('No actual cluster tears');
                else
                    nTears=sum(actualClusterTears(:,2));
                    fprintf('*ACTUAL* cluster tears --> %d\n',nTears);
                end
                if any(javaDbm.tears ~= actualClusterTears)
                    disp('New Java merging cluster tear problem');
                end
                if any(Pointers~=javaDbm.pointers')
                    disp('New Java merging POINTER problem after knitting torn clusters');
                end

            end
            dns.pointers=Pointers; %this is to save Pointers for making vector plot later
%            dns.rawPointers=Pointers;
            fprintf('MATLAB merging completed\n\n');
            
        end
        
        
    end
end