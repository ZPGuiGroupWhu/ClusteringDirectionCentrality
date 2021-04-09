function [cluster] = RKNN(k_num, noise, T, X)
% k_num: the k of KNN
% noise: the threshold of IDM
% T: the threshold of DCM
% X: the two-dimensional data
% cluster: the cluster labels

[n,~] = size(X);
get_knn = knnsearch(X,X,'k',k_num+1);
get_knn(:,1) = [];

rnn_num = zeros(n,1);
for i=1:n
    for j=1:k_num
        id = get_knn(i,j);
        rnn_num(id) = rnn_num(id) + 1;
    end
end

rnn_num = (rnn_num-min(rnn_num))/(max(rnn_num)-min(rnn_num));
cluster = ones(n,1);
for i=1:n
    if(rnn_num(i)<noise)
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