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
        try
            dif_x = X(get_knn(i,:),:) - X(i,:);
            map_x = inv(diag(sqrt(diag(dif_x*dif_x'))))*dif_x;
            convex = convhulln(map_x);
            simplex_num = length(convex(:,1));
            simplex_vol = zeros(simplex_num,1);
            for j=1:simplex_num
                simplex_coord = map_x(convex(j,:),:);
                simplex_vol(j) = sqrt(max(0,det(simplex_coord*simplex_coord')))/gamma(d-1);
            end  
            DCM(i) = var(simplex_vol);
        catch exception 
            DCM(i) = 0;
        end
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
int_id = find(ind==1);
edg_id = find(ind==0);
ind_edg_D = pdist2(X(int_id,:),X(edg_id,:));
int_mark = 1;
edg_mark = 1;
for i=1:n
    if(ind(i)==1)
        near_dis(i) = min(ind_edg_D(int_mark,:));
        int_mark = int_mark + 1;
    else
        near_dis(i) = int_id(find(ind_edg_D(:,edg_mark)==min(ind_edg_D(:,edg_mark)),1));
        edg_mark = edg_mark + 1;
    end
end

%% Conduct internal connection
cluster = zeros(n,1);
mark = 1;
[int_dis,sort_id] = sort(near_dis(int_id),'descend');
int_id = int_id(sort_id);
int_D = pdist2(X(int_id,:),X(int_id,:));
for i=1:length(int_id)
    ti = int_id(i);
    if(cluster(ti)==0)
        cluster(ti) = mark;
        for j=1:length(int_id)
            tj = int_id(j);
            if(int_D(i,j)<=int_dis(i)+int_dis(j))
               if(cluster(tj)==0)
                   cluster(tj) = cluster(ti);
               else
                   temp_cluster = cluster(tj);
                   cluster(cluster==temp_cluster)=cluster(ti);
               end
            end
        end
        mark = mark + 1;
    end
end

%% Assign labels to boundary points
cluster(edg_id) = cluster(near_dis(edg_id));

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
