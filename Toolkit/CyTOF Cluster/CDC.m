function [ clus ] = CDC(data,k_num,ratio)
% k_num: k for KNN
% ratio: threshold of DCM (range in [0,1])

%% Remove the repeated elements
[N,d] = size(data);
[X, idx, idy] = unique(data,'rows','stable');

%% Search the KNNs
get_knn = knnsearch(X,X,'k',k_num+1);
get_knn(:,1) = [];

%% Calculate the DCMs
[n,~] = size(X);
DCM = zeros(n,1);
if (d==2)
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
    for i=1:n
        angle_order = sort(angle(i,:));
        for j=1:k_num-1
            point_angle = angle_order(j+1)-angle_order(j);
            DCM(i) = DCM(i) + (point_angle-2*pi/k_num).^2;
        end
        point_angle = angle_order(1)-angle_order(k_num)+2*pi;
        DCM(i) = DCM(i) + (point_angle-2*pi/k_num).^2;
        DCM(i) = DCM(i)/k_num;
    end   
    DCM = DCM/((k_num-1)*4*pi^2/k_num^2);    
else
    for i=1:n
        dif_x = X(get_knn(i,:),:) - X(i,:);
        map_x = inv(diag(sqrt(diag(dif_x*dif_x'))))*dif_x;
        convex = convhulln(map_x);
        simplex_num = length(convex(:,1));
        simplex_vol = zeros(simplex_num,1);
        for j=1:simplex_num
            simplex_coord = map_x(convex(j,:),:);
            simplex_vol(j) = sqrt(det(simplex_coord*simplex_coord'))/gamma(d);
        end  
        DCM(i) = var(simplex_vol);
    end
end
     

%% Divide all points into internal and boundary points
ind = zeros(n,1);
sort_DCM = sort(DCM);
edge_thre = sort_DCM(ceil(n*ratio));
for i=1:n
    if(DCM(i)<edge_thre)
        ind(i) = 1;
    end
end

%% Calculate the reachable distance 
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

%% Conduct internal connection
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

%% Assign labels to boundary points
for i=1:n
    if(ind(i)==0)
        cluster(i) = cluster(near_dis(i));
    end
end

%% Adjust the cluster id to continuous positive integer
mark_temp = 1;
storage = zeros(n,1);
for i=1:n
    if (ismember(cluster(i),storage)==0)
        storage(i) = cluster(i);
        cluster(i) = mark_temp;
        mark_temp = mark_temp+1;
    else
        cluster(i) = cluster(find(storage==cluster(i),1));
    end
end

clus = zeros(length(data(:,1)),1);
clus(idx) = cluster;
rep_id = setdiff(1:N,idx);
clus(rep_id) = cluster(idy(rep_id));
end
