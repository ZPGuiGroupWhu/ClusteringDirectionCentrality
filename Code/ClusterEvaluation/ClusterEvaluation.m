function [  precision, recall, Fscore,rand_index,ad_rand_index, jaccard] = ClusterEvaluation( res,ref )
n = length(res);
SS = 0; % same calss same clusters
SD = 0; % same calss different clusters
DS = 0; % different calss same clusters
DD = 0; % different calss different clusters
for i=1:n
    for j=i+1:n
        if(res(i)==res(j)&&ref(i)==ref(j))
           SS = SS + 1;
        elseif(res(i)~=res(j)&&ref(i)~=ref(j))
           DD = DD + 1;
        elseif(res(i)~=res(j)&&ref(i)==ref(j))
           SD = SD + 1; 
        elseif(res(i)==res(j)&&ref(i)~=ref(j))
           DS = DS + 1;            
        end
    end
end
 
C=Contingency(res,ref);   %form contingency matrix
n=sum(sum(C));
nis=sum(sum(C,2).^2);       %sum of squares of sums of rows
njs=sum(sum(C,1).^2);       %sum of squares of sums of columns
 
t1=nchoosek(n,2);       %total number of pairs of entities
t2=sum(sum(C.^2));  %sum over rows & columnns of nij^2
t3=.5*(nis+njs);
 
%Expected index (for adjustment)
nc=(n*(n^2+1)-(n+1)*nis-(n+1)*njs+2*(nis*njs)/n)/(2*(n-1));
 
A=t1+t2-t3;     %no. agreements
D=-t2+t3;     %no. disagreements
 
if t1==nc
   ad_rand_index=0;            %avoid division by zero; if k=1, define Rand = 0
else
   ad_rand_index=(A-nc)/(t1-nc);       %adjusted Rand - Hubert & Arabie 1985
end

precision = SS/(SS+DS);
recall = SS/(SS+SD);
rand_index = (SS+DD)/(SS+SD+DS+DD);
Fscore = 2*precision*recall/(precision+recall);
jaccard = SS/(SS+SD+DS);
end