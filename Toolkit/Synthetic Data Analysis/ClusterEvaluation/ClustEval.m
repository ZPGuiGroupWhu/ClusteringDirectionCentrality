function [ Accuracy, NMI, ARI, Fscore, JI, RI] = ClustEval(ref, res)
n = length(res);
SS = 0; % same class same clusters
SD = 0; % same class different clusters
DS = 0; % different class same clusters
DD = 0; % different class different clusters
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

ARI = 2*(SS*DD-DS*SD)/((2*(SS*DD-DS*SD))+(DS+SD)*(SS+SD+DS+DD));
precision = SS/(SS+DS);
recall = SS/(SS+SD);
RI = (SS+DD)/(SS+SD+DS+DD);
Fscore = 2*precision*recall/(precision+recall);
JI = SS/(SS+SD+DS);

p = unique(ref');
c = unique(res');
P_size = length(p);
C_size = length(c);
Pid = double(ones(P_size,1)*ref' == p'*ones(1,n) );
Cid = double(ones(C_size,1)*res' == c'*ones(1,n) );
CP = Cid*Pid';
[~,cost] = munkres(-CP);
Accuracy = -cost/n;

NMI = GetNMI(ref, res);
end