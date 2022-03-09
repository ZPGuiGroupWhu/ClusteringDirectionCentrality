function noise = IDM (X, k_num, T)
[n,~] = size(X);
[get_knn, knn_dis] = knnsearch(X,X,'k',k_num+1);
get_knn(:,1) = [];
knn_dis(:,1) = [];
idm = zeros(n,1);
for i=1:n
    idm(i) = 1/sum(knn_dis(i,:));
end
noise = [];
for i=1:n
    if(idm(i) < T)
        noise = [noise;i];
    end
end
end