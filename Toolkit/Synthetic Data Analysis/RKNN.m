function noise = RKNN (X, k_num, T)
[n,~] = size(X);
get_knn = knnsearch(X,X,'k',k_num+1);
get_knn(:,1) = [];
rnn = zeros(n,1);
for i=1:n
    rnn(i) = length(find(get_knn==i));
end
rnn = (rnn - min(rnn))/(max(rnn)-min(rnn));
noise = [];
for i=1:n
    if(rnn(i) < T)
        noise = [noise;i];
    end
end
end