function [ cluster ] = DirectionClusterKNN( k_num,edge_thre,X )
% k_num: the k of KNN
% edge_thre: the threshold of DCM
% X: the two-dimensional data
% cluster: the cluster labels

%% Get the length of data X
[n,~] = size(X);

%% Search the KNNs of each point
get_knn = knnsearch(X,X,'k',k_num+1);
get_knn(:,1) = [];

%% Calculate the formed angles by KNNs of each point
angle = zeros(n,k_num);
for i=1:n
    for j=1:k_num
        delta_x = X(get_knn(i,j),1)-X(i,1);
        delta_y = X(get_knn(i,j),2)-X(i,2);
        if(delta_x==0)
            if(delta_y==0)
                angle(i,j)=0;
            elseif(delta_y>0)
                angle(i,j)=pi/2;
            else
                angle(i,j)=3*pi/2; 
            end
        elseif(delta_x>0)
            if(atan(delta_y/delta_x)>=0)
                angle(i,j)=atan(delta_y/delta_x);
            else
                angle(i,j)=2*pi+atan(delta_y/delta_x);
            end
        else
            angle(i,j)=pi+atan(delta_y/delta_x);
        end
    end
end                             

%% Calculate DCM of each point
angle_var = zeros(n,1);
for i=1:n
    angle_order = sort(angle(i,:));
    for j=1:k_num
        if(j~=k_num)
            point_angle = angle_order(j+1)-angle_order(j);
            angle_var(i) = angle_var(i) + (point_angle-2*pi/k_num).^2;
        else
            point_angle = angle_order(1)-angle_order(k_num)+2*pi;
            angle_var(i) = angle_var(i) + (point_angle-2*pi/k_num).^2;
        end
    end
    angle_var(i) = angle_var(i)/k_num;
end   
angle_var = angle_var/((k_num-1)*4*pi^2/k_num^2);          

%% Divide the points into boundary and internal points based on DCM
ind = zeros(n,1);
for i=1:n
    if(angle_var(i)<edge_thre)
        ind(i) = 1;
    end
end

%% Calculate the reachable distance of each internal point,and find the nearest internal point of each boundary point
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

%% Conduct the internal connection
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

%% Assign the label of the nearest internal point to the boundary point
for i=1:n
    if(ind(i)==0)
        cluster(i) = cluster(near_dis(i));
    end
end

%% Adjust the cluster labels to the consecutive positive integersstart from one
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