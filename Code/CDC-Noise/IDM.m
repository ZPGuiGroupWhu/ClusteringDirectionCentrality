function [cluster] = IDM(k_num, noise, T, X)
% k_num: the k of KNN
% noise: the threshold of IDM
% T: the threshold of DCM
% X: the two-dimensional data
% cluster: the cluster labels

[n,~] = size(X);
dis = pdist2(X,X);
get_knn = knnsearch(X,X,'k',k_num+1);
get_knn(:,1) = [];

idm = zeros(n,1);
for i=1:n
    idm(i) = 1/sum(dis(i,get_knn(i,:)));
end

cluster = ones(n,1);
for i=1:n
    if(idm(i)<noise)
        cluster(i) = 0;
    end
end
X(cluster==0,:)=[];

temp = OptCDC(k_num,T,X);
mark = 1;
for i=1:n
    if(cluster(i)==1)
        cluster(i) = temp(mark);
        mark = mark + 1;
    end
end