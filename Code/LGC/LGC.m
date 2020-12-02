function [Xlabel,sortClusterIdx,time ] = LGC( dataset, IM, k, cFactor)
% LGC is short for local gravitation cluserting
% dataset: a matrix of real values;
% IM: the initial momentum, a real number, default value as 10
% k: the number of neighbors
% cFactor: the threshold value of  CE
% --------------------------------------------
% Example:
%     X = [randn(1000,2)+ones(1000,2); randn(100,2)-ones(100,2)];
%     idx=LGC(X);
% you can also preset parameters IM, k and cFactor, like:
%     idx=LGC(X,50,10,0.5);
% citation: Z. Wang et al., "Clustering by Local Gravitation," in IEEE Transactions on Cybernetics, vol. 48, no. 5, pp. 1383-1396, May 2018.
% 
%% initial the parameters
[rowNums,colNums]=size(dataset);
% if the IM is not preset, assign default value as 10.
if nargin<2
    borderDegree=10;
else
    borderDegree=IM;
end
% disp(['The points in corer areas has initial momentum ',num2str(borderDegree),' to connect its border-neighbors']);
% if the number of neighbors is not preset, assign default value.
if nargin<3
    if rowNums>1000
        neighborNums=ceil(rowNums*0.005);
        neighborNums=min(30,neighborNums);
    else
        neighborNums=min(15,floor(rowNums*0.015));
        neighborNums=max(5,neighborNums);
    end
%     disp(['Neighbor nums is not guided, the program set k = ',num2str(neighborNums)]);
else
    neighborNums=k;
%     disp(['Neighborsize=',num2str(neighborNums)]);
end
% if the CE is not preset, assign default value.
if nargin<4
    coreFactor=-99;
else
    coreFactor=cFactor;
%     disp(['data points with a CE<',num2str(coreFactor),' will be labeled as points in border areas']);
end
%% perform the clustering task with the initialized parameters.
[Xlabel,cNums,time]= LGC_CLUSTERING(dataset,coreFactor,neighborNums,borderDegree);
%% display the clustering results
cla;
% fprintf('%d clusters find: \n', cNums);
clusterNums=zeros(cNums,1);
% plotcluster(rowNums,dataset,Xlabel);
% if size(dataset,2)==2
%     cla
% %     subplot(1,2,1);
% %     hold on
%     for k=1:cNums
%         plot(dataset(Xlabel==k,1),dataset(Xlabel==k,2),'.','color',[rand(),rand(),rand()]);
%         clusterNums(k)=sum(Xlabel==k);
%         disp(['Cluster ',num2str(k), ': ', num2str(clusterNums(k)),' data points.']);
%     end
%     plot(dataset(Xlabel==0,1),dataset(Xlabel==0,2),'kx');
%     nulCluster=sum(Xlabel==0);
%     disp(['Noise points: ', num2str(nulCluster),' data points.']);
% %     subplot(1,2,2);
% %     bar(clusterNums);
% %     xlabel('Cluster id');
% %     ylabel('The number of points');
% else
%     for k=1:cNums
%         clusterNums(k)=sum(Xlabel==k);
%         disp(['Cluster ',num2str(k), ': ', num2str(clusterNums(k)),' data points.']);
%     end
%     nulCluster=sum(Xlabel==0);
%     disp(['Noise points: ', num2str(nulCluster),' data points.']);
%     bar(clusterNums);
% end
[a,sortClusterIdx]=sort(clusterNums,'descend');
end
%%
function [ Xlabel, cNums, time ] = LGC_CLUSTERING( X,CE,neighborNums,borderDegree)
%   X is the input dataset, borderDegree is the parameter IM
[rowNums,colNums]=size(X);
%%   if the threshold value  is not predetermined, search a proper one.
coreFactor=CE;
autoDect=false;
properCE=false;
if coreFactor==-99
    autoDect=true;
    coreFactor=0.2;
    if colNums<3
        coreFactor=0.1;
    else
        if colNums<10
            coreFactor=0.2;
        else
            coreFactor=0.3;
        end
    end
end
tic
%% compute the resultant force
% Y is the local resultant force
distMatrix=squareform(pdist(X));
Y=zeros(rowNums,colNums);
Xlabel=zeros(rowNums,1);
cNums=0;
mass=zeros(rowNums,1);
massUnba=zeros(rowNums,1);
Ynorm=zeros(rowNums,1);
D = zeros(rowNums,1);
for m=1:rowNums
    for j=1:rowNums
        D(j) = sqrt((X(m,:)-X(j,:))* (X(m,:)-X(j,:))');
    end
    [a,idx]=sort(D);
%     [a,idx]=sort(distMatrix(m,:));
    NormY=zeros(neighborNums,1);
    possibleY=zeros(neighborNums,colNums);
    for k=2:neighborNums
        deltaDist=X(idx(k),:)-X(m,:);
        if norm(deltaDist)~=0
            Y(m,:)=Y(m,:)+(deltaDist/norm(deltaDist));
        end
    end
    deltaDist=X(idx(neighborNums+1),:)-X(m,:);
    if norm(deltaDist)~=0
        possibleY(1,:)=Y(m,:)+(deltaDist/norm(deltaDist));
    end
    NormY(1)=norm(possibleY(1,:));
    for k=2:neighborNums
        deltaDist=X(idx(neighborNums+k),:)-X(m,:);
        if norm(deltaDist)~=0
            possibleY(k,:)=possibleY(k-1,:)+(deltaDist/norm(deltaDist));
        end
        NormY(k)=norm(possibleY(k,:));
    end
    [minNorm,idx]=min(NormY);
    if minNorm<norm(Y(m,:))
        mass(m)=sum(a(2:neighborNums+idx(1)));
        Y(m,:)=possibleY(idx(1),:);
    else
        mass(m)=sum(a(2:neighborNums));
    end
    massUnba(m)=sum(a(2:neighborNums));
    Y(m,:)=Y(m,:)*mass(m);
    Ynorm(m)=norm(Y(m,:));
end
time1=toc;
sortYnorm=sort(Ynorm);
sortMass=sort(mass);
% data points with extre-small mass&&Norm are the seed for core
smallYnorm=sortYnorm(ceil(rowNums*0.05));
smallMass=sortMass(ceil(rowNums*0.05));
coreThdMass=sortMass(ceil(rowNums*0.7));
% data points with extre-large mass&&Norm are the seed for border
upYnorm=sortYnorm(ceil(rowNums*0.8))*neighborNums;
upMass=sortMass(ceil(rowNums*0.995));
nTmass=0;
%%  assign the types of each pattern
% CEscore is the centrality value
while (~properCE)
    tic;
    cType=zeros(rowNums,1);
    coreNums=0;
    boderNums=0;
    CEscore=zeros(rowNums,1);
    for m=1:rowNums
        resultantY=Y(m,:);
        coreScore=0;
% %         for j=1:rowNums
% %             D(j) = sqrt((X(m,:)-X(j,:))* (X(m,:)-X(j,:))');
% %         end
% %         [a,idx]=sort(D);
        [~,idx]=sort(distMatrix(m,:));
        clear a;
        currentNorm=Ynorm(m);
        k=1;
        interNums=0;
        if currentNorm<=smallYnorm && mass(m)<=smallMass
            cType(m)=2;
            coreNums=coreNums+1;
            CEscore(m)=1;
            continue;
        end
        if currentNorm>=upYnorm
            boderNums=boderNums+1;
            cType(m)=1;
            CEscore(m)=-1;
            continue;
        end
        if mass(m)>upMass
            boderNums=boderNums+1;
            cType(m)=1;
            CEscore(m)=-1;
            continue;
        end
        iterNum=0;
        for k=2:neighborNums
            currentNorm=currentNorm+Ynorm(idx(k));
            resultantY=resultantY+Y(idx(k),:);
            deltaDist=X(m,:)-X(idx(k),:);
            if norm(deltaDist)~=0 && Ynorm(idx(k),:)~=0
                iterNum=iterNum+1;
                coreScore=coreScore+dot(deltaDist,Y(idx(k),:))/(norm(deltaDist)*Ynorm(idx(k),:));
            end
        end
        coreScore=coreScore/iterNum;
        coreScoreMax=coreScore;
        while currentNorm<upYnorm
            k=k+1;
            currentNorm=currentNorm+Ynorm(idx(k));
            resultantY=resultantY+Y(idx(k),:);
            deltaDist=X(m,:)-X(idx(k),:);
            if norm(deltaDist)~=0 && Ynorm(idx(k),:)~=0
                coreScore=coreScore*(iterNum)+dot(deltaDist,Y(idx(k),:))/(norm(deltaDist)*Ynorm(idx(k),:));
                iterNum=iterNum+1;
                coreScore=coreScore/iterNum;
            end
            if coreScoreMax<coreScore
                coreScoreMax=coreScore;
            end
        end
        if coreScore<coreFactor && dot(resultantY,Y(m,:))>0
            boderNums=boderNums+1;
            cType(m)=1;
        else
            if  coreScore>=-0.5 && mass(m)<=coreThdMass
                coreNums=coreNums+1;
                cType(m)=2;
            end
        end
        CEscore(m)=coreScore;
    end
    time2=toc;
    
    borderPercent=boderNums/rowNums;
    if autoDect==false
        disp([num2str(boderNums) ,' of data points in border areas,  ',num2str(sum(cType==2)) ,' of core points,  ',num2str(sum(cType==0)) ,' of unlabeled data points.']);
        disp([num2str(boderNums/rowNums*100), '% data points are labeled as borders.']);
        if borderPercent<0.05
            warning('The borders deteted with current params  is lower than 5% of the data set, to continue running please press any key, to abbort please press CTRL + C');
            pause;
        end
        properCE=true;
    else
        if borderPercent>=0.6 || borderPercent<0.4 && coreFactor<1
            disp(['Current CE is ',num2str(coreFactor),' start a new search for a proper CE so that border percent in 50%~60%']);
            disp([num2str(boderNums/rowNums*100), '% data points are labeled as borders.']);
            if borderPercent>0.6
                coreFactor=coreFactor-0.02;
            else
                coreFactor=coreFactor+0.02;
            end
        else
            disp(['Current CE is ',num2str(coreFactor)]);
            disp([num2str(boderNums) ,' of data points in border areas,  ',num2str(sum(cType==2)) ,' of core points,  ',num2str(sum(cType==0)) ,' of unlabeled data points.']);
            disp([num2str(boderNums/rowNums*100), '% data points are labeled as borders.']);
            properCE=true;
        end
    end
end
%%
%% connect core ares
tic;
threadNorm=sortYnorm(ceil(rowNums*0.8))*borderDegree*borderPercent;
threadMass=sortMass(ceil(rowNums*0.99))*borderDegree;
coreIdx=0;
isAllCored=false;
for k=1:rowNums
    if cType(k)==2 && Xlabel(k)==0
        cNums=cNums+1;
        coreIdx=k;
        Xlabel(coreIdx)=cNums;
        corePattern=dlnode(0);
        pHead=corePattern;
        pCurrent=pHead;
        break;
    end
end
while ~isAllCored && coreIdx>0
%     for j=1:rowNums
%         D(j) = sqrt((X(coreIdx,:)-X(j,:))* (X(coreIdx,:)-X(j,:))');
%     end
%     [sortDist,idx]=sort(D);
    [~,idx]=sort(distMatrix(coreIdx,:));
    clear sortDist;
    bSumNorm=0;
    bSumMass=0;
    for k=2:rowNums
        if cType(idx(k))==1 && massUnba(idx(k))>=nTmass
            bSumNorm=bSumNorm+Ynorm(idx(k));
            bSumMass=bSumMass+mass(idx(k));
            if bSumNorm>threadNorm || bSumMass>threadMass
                break;
            end
        end
        if  cType(idx(k))==2 && Xlabel(idx(k))==0
            Xlabel(idx(k))=cNums;
            q=dlnode(idx(k));
            q.insertAfter(pCurrent);
            pCurrent=q;
        else
            if cType(idx(k))==0 && Xlabel(idx(k))==0
                Xlabel(idx(k))=cNums;
            end
        end
    end
    while pCurrent ~= pHead
        pHead=pHead.Next;
        pHead.Prev.delete;
        coreIdx=pHead.Data;
%         for j=1:rowNums
%             D(j) = sqrt((X(coreIdx,:)-X(j,:))* (X(coreIdx,:)-X(j,:))');
%         end
%         [sortDist,idx]=sort(D);
        [~,idx]=sort(distMatrix(coreIdx,:));
        clear sortDist;
        bSumNorm=0;
        bSumMass=0;
        for k=2:rowNums
            if cType(idx(k))==1 && massUnba(idx(k))>=nTmass
                bSumNorm=bSumNorm+Ynorm(idx(k));
                bSumMass=bSumMass+mass(idx(k));
                if bSumNorm>threadNorm ||bSumMass>threadMass
                    break;
                end
            end
            if  cType(idx(k))==2 && Xlabel(idx(k))==0
                Xlabel(idx(k))=cNums;
                q=dlnode(idx(k));
                q.insertAfter(pCurrent);
                pCurrent=q;
            else
                if cType(idx(k))==0 && Xlabel(idx(k))==0
                    Xlabel(idx(k))=cNums;
                end
            end
        end
    end
    
    for k=1:rowNums
        if cType(k)==2 && Xlabel(k)==0
            cNums=cNums+1;
            coreIdx=k;
            Xlabel(coreIdx)=cNums;
            corePattern=dlnode(0);
            pHead=corePattern;
            pCurrent=pHead;
            break;
        end
    end
    if k==rowNums && ~(cType(k)==2 && Xlabel(k)==0)
        isAllCored=true;
    end
    
end
%%
%% assign borders and isolaters to cores
for m=1:rowNums
    if Xlabel(m)==0
%         for j=1:rowNums
%             D(j) = sqrt((X(m,:)-X(j,:))* (X(m,:)-X(j,:))');
%         end
%         [sortDist,idx]=sort(D);
        [~,idx]=sort(distMatrix(m,:));
        clear sortDist;
        for k=2:2*neighborNums
            if Xlabel(idx(k))>0 && cType(idx(k))==2 && mass(m)>mass(idx(k))
                if cType(m)==0
                    deltaDist=X(idx(k),:)-X(m,:);
                    if dot(deltaDist,Y(idx(k),:))>0
                        Xlabel(m)=Xlabel(idx(k));
                        break;
                    end
                else
                    if cType(m)==1
                        deltaDist=X(idx(k),:)-X(m,:);
                        if dot(deltaDist,Y(m,:))>0
                            Xlabel(m)=Xlabel(idx(k));
                            break;
                        end
                    end
                end
            end
        end
    end
end
%%
if rowNums>5000
    for k=1:cNums
        if sum(Xlabel==k)<0.005*rowNums
            cType(Xlabel==k)=0;
            Xlabel(Xlabel==k)=0;
        end
    end
else
    for k=1:cNums
        if sum(Xlabel==k)<0.01*rowNums
            cType(Xlabel==k)=0;
            Xlabel(Xlabel==k)=0;
        end
    end
end
for m=1:rowNums
    if Xlabel(m)==0
%         for j=1:rowNums
%             D(j) = sqrt((X(m,:)-X(j,:))* (X(m,:)-X(j,:))');
%         end
%         [sortDist,idx]=sort(D);
        [~,idx]=sort(distMatrix(m,:));
        clear sortDist;
        for k=2:3*neighborNums
            if Xlabel(idx(k))>0 && cType(idx(k))==2
                if cType(m)==0
                    deltaDist=X(idx(k),:)-X(m,:);
                    if dot(deltaDist,Y(idx(k),:))>0
                        Xlabel(m)=Xlabel(idx(k));
                        break;
                    end
                else
                    if cType(m)==1
                        deltaDist=X(idx(k),:)-X(m,:);
                        if dot(deltaDist,Y(m,:))>0
                            Xlabel(m)=Xlabel(idx(k));
                            break;
                        end
                    end
                end
            end
        end
    end
end
%%
rNums=sum(Xlabel==0);
rNumsTemp=0;
XlabelTemp=Xlabel;
while  rNums~=rNumsTemp
    rNumsTemp=rNums;
    for m=1:rowNums
        if Xlabel(m)==0
%             for j=1:rowNums
%                 D(j) = sqrt((X(m,:)-X(j,:))* (X(m,:)-X(j,:))');
%             end
%             [sortDist,idx]=sort(D);
            [~,idx]=sort(distMatrix(m,:));
            clear sortDist;
            neighborNumsCounter=zeros(cNums,1);
            neighborDist=zeros(cNums,1);
            for k=2:5*neighborNums
                if Xlabel(idx(k))>0
                    neighborNumsCounter( Xlabel(idx(k)))=neighborNumsCounter( Xlabel(idx(k)))+1;
                    neighborDist( Xlabel(idx(k)))=neighborDist( Xlabel(idx(k)))+distMatrix(idx(k),m);
%                     neighborDist( Xlabel(idx(k)))=neighborDist( Xlabel(idx(k)))+D(idx(k));
                end
            end
            [maxNums,idx]=max(neighborNumsCounter./neighborDist);
            if maxNums>0
                XlabelTemp(m)=idx;
            end
        end
    end
    Xlabel=XlabelTemp;
    rNums=sum(Xlabel==0);
end
time3=toc;
%% resort cluster labels
lblCounter=zeros(cNums,1);
for k=1:cNums
    lblCounter(k)=sum(Xlabel==k);
end
[a,idx]=sort(lblCounter,'descend');
cNums2=cNums;
for k=1:cNums
    if a(k)<1
        cNums2=k-1;
        break;
    end
    XlabelTemp(Xlabel==idx(k))=k;
end
cNums=cNums2;
Xlabel=XlabelTemp;
time=time1+time2+time3;
end
