function [ cluster ] = ProjCDC( k_num,edge_thre,X )
% This function is for clustering high-dimensional data
% k_num:the k of KNN
% edge_thre: the threshold of DCM(direction centrality metric)
% X: the input data
[n,m] = size(X);
get_knn = knnsearch(X,X,'k',k_num);
DC = zeros(n,m*(m-1)/2);
for i=1:m-1
    for j=i+1:m
        data = [X(:,i),X(:,j)];
        DC(:,(2*m-i)*(i-1)/2+j-i) = DCCalculation(get_knn,data);
    end
end
angle = zeros(n,1);
for i=1:n
    angle(i) = max(DC(i,:));
end
[near_dis,dis] = GetNearEdge(X,angle,edge_thre);
cluster = zeros(n,1);
mark = 1;
for i=1:n
    if(angle(i)<=edge_thre&&cluster(i)==0)
        cluster(i) = mark;
        for j=1:n
           if(angle(j)<=edge_thre&&dis(i,j)<=near_dis(i)+near_dis(j))
               if(cluster(j)==0)
                   cluster(j) = cluster(i);
               else
                   temp_cluster = cluster(j);
                   for k=1:n
                       if(cluster(k)==temp_cluster)
                           cluster(k)=cluster(i);
                       end
                   end
               end
           end
        end
        mark = mark + 1;
    end
end
for i=1:n
    if(cluster(i)==0)
        cluster(i) = cluster(near_dis(i));
    end
end

mark_temp = 1;
storage = zeros(n,1);
for i=1:n
    storage(i) = -1;
end
for i=1:n
    if(cluster(i)>0)
        if (ismember(cluster(i),storage)==0)
            storage(i) = cluster(i);
            cluster(i) = mark_temp;
            mark_temp = mark_temp+1;
        else
            index = find(storage==cluster(i));
            cluster(i) = cluster(index);
        end
    end
end 
end
