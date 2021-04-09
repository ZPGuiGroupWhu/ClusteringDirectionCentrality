function [  precision, recall, accuracy, Fscore,rand_index,ad_rand_index, jaccard] = ClusterEvaluation( ref, res )
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

ad_rand_index = 2*(SS*DD-DS*SD)/((2*(SS*DD-DS*SD))+(DS+SD)*(SS+SD+DS+DD));
precision = SS/(SS+DS);
recall = SS/(SS+SD);
rand_index = (SS+DD)/(SS+SD+DS+DD);
Fscore = 2*precision*recall/(precision+recall);
jaccard = SS/(SS+SD+DS);

p = unique(ref');
c = unique(res');
P_size = length(p);
C_size = length(c);
Pid = double(ones(P_size,1)*ref' == p'*ones(1,n) );
Cid = double(ones(C_size,1)*res' == c'*ones(1,n) );
CP = Cid*Pid';
[~,cost] = munkres(-CP);
accuracy = -cost/n;
end