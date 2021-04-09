function [ cluster ] = OPP( k_num,T,X )
[n,m] = size(X);
get_knn = knnsearch(X,X,'k',k_num);
DC = zeros(n,m*(m-1)/2);
for i=1:m-1
    for j=i+1:m
        data = [X(:,i),X(:,j)];
        DC(:,(2*m-i)*(i-1)/2+j-i) = DCCalculation(get_knn,data);
    end
end
DCM = zeros(n,1);
for i=1:n
    DCM(i) = max(DC(i,:));
end

ind = zeros(n,1);
for i=1:n
    if(DCM(i)<T)
        ind(i) = 1;
    end
end
near_dis = zeros(n,1);
for i=1:n
    if(ind(i)==1)
        knn_id = ind(get_knn(i,:));
        if(isempty(find(knn_id==0,1))==0)
            edge_id = get_knn(i,find(knn_id==0,1));
            near_dis(i) = sqrt((X(i,:)-X(edge_id,:))* (X(i,:)-X(edge_id,:))');
        else
            near_dis(i) = inf;
            for j=1:n
                if(ind(j)==0)
                    temp_dis = sqrt((X(i,:)-X(j,:))* (X(i,:)-X(j,:))');
                    if(temp_dis < near_dis(i))
                        near_dis(i) = temp_dis;
                    end
                end
            end
        end      
    else
        knn_id = ind(get_knn(i,:));
        if(isempty(find(knn_id==1,1))==0)
            near_dis(i) = get_knn(i,find(knn_id==1,1));
        else
            mark_dis = inf;
            for j=1:n
                if(ind(j)==1)
                    temp_dis = sqrt((X(i,:)-X(j,:))* (X(i,:)-X(j,:))');
                    if(temp_dis < mark_dis)
                        mark_dis = temp_dis;
                        near_dis(i) = j;
                    end
                end
            end
        end 
    end
end

cluster = zeros(n,1);
mark = 1;
for i=1:n
    if(ind(i)==1&&cluster(i)==0)
        cluster(i) = mark;
        for j=1:n
           if(ind(j)==1&&sqrt((X(i,:)-X(j,:))* (X(i,:)-X(j,:))')<=near_dis(i)+near_dis(j))
               if(cluster(j)==0)
                   cluster(j) = cluster(i);
               else
                   temp_cluster = cluster(j);
                   cluster(cluster==temp_cluster)=cluster(i);
               end
           end
        end
        mark = mark + 1;
    end
end

for i=1:n
    if(ind(i)==0)
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
            cluster(i) = cluster(find(storage==cluster(i),1));
        end
    end
end
end
