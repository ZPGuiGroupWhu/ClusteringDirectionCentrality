function [ cluster ] = DirectionClusterKNN( k_num,edge_thre,X )
% This function is for clustering 2D data
% k_num:the K of KNN
% edge_thre: the threshold of DCM (direction centrality metric)
% X: the input data
a1 = X(:,1);
a2 = X(:,2);
[n,m] = size(a1);
dis = zeros(n,n);

    for i=1:n
        for j=i+1:n
            dis(i,j) = sqrt((a1(i)-a1(j))^2+(a2(i)-a2(j))^2);
            dis(j,i) = dis(i,j);
        end
    end                          %%% Compute the distance matrix

    temp_sort = zeros(n,1);
    get_knn = zeros(n,k_num);
 
    for i=1:n
        temp_sort = sort(dis(:,i));
        temp_topk = find(dis(:,i)<=temp_sort(k_num+1));
        temp_topk(temp_topk==i) = [];
        get_knn(i,:) = temp_topk(1:k_num);
    end                         %%% Search the KNN of each point
    
    angle = zeros(n,k_num);
    for i=1:n
        for j=1:k_num
            delta_x = a1(get_knn(i,j))-a1(i);
            delta_y = a2(get_knn(i,j))-a2(i);
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
    angle_var = angle_var/((k_num-1)*4*pi^2/k_num^2);           %%% Calculate the DCM of each point
 
    near_dis = zeros(n,1);
    for i=1:n
        if(angle_var(i)<=edge_thre)
            [temp_sort,idx] = sort(dis(:,i));
            for j=1:n
                if(angle_var(idx(j))>edge_thre)
                    near_dis(i) = temp_sort(j);
                    break;
                end
            end
        end
    end                                                         %%% Distinguish internal and boundary points
    
    cluster = zeros(n,1);
    mark = 1;
    for i=1:n
        if(angle_var(i)<=edge_thre&&cluster(i)==0)
            cluster(i) = mark;
            for j=1:n
               if(angle_var(j)<=edge_thre&&dis(i,j)<=near_dis(i)+near_dis(j))
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
    end                                                         %%% Connect the internal points
    
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
    end                                                       %%% Assign the cluster id
    
    for i=1:n
        if(cluster(i)==0)
           [temp_sort,idx] = sort(dis(:,i));
           for j=1:n
               if(angle_var(idx(j))<=edge_thre)
                   cluster(i)=cluster(idx(j));
                   break;
               end
           end
        end
    end                                                       %%% Assign thecluster id to the boundary points
end