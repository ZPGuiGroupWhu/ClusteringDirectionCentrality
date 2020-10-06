function [cluster] = DCCParaAdapt(k_num,class,X)
% This function is for CDC combined with adaptive method to determine the TDCM
% k_num:the K of KNN
% class: the number of clusters
% X: the input data
X = unique(X,'rows');
n = length(X);
dis = zeros(n,n);
ave_dis = zeros(n,1);
k_dis=zeros(n,1);
    for i=1:n
        for j=i+1:n
            dis(i,j) = sqrt((a1(i)-a1(j))^2+(a2(i)-a2(j))^2);
            dis(j,i) = dis(i,j);
        end
    end                          %%% Compute the distance matrix

    temp_sort = zeros(n,1);
    get_knn = zeros(n,k_num);
    rnn_num = zeros(n,1);
    for i=1:n
        temp_sort = sort(dis(:,i));
        temp_topk = find(dis(:,i)<=temp_sort(k_num+1));
        temp_topk(temp_topk==i) = [];
        get_knn(i,:) = temp_topk(1:k_num);
        k_dis(i) = temp_sort(k_num+1);
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
            ave_dis(i) = ave_dis(i) + dis(get_knn(i,j),i);
        end
        ave_dis(i) = ave_dis(i)/k_num;
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
    angle_var = angle_var/((k_num-1)*4*pi^2/k_num^2); %%% Calculate the DCM of each point
    
    angle_var = sort(angle_var,'descend');       
    dis_t = mean(ave_dis);
    dt=delaunayTriangulation(X(:,1),X(:,2));
    triplot(dt,'r');hold on;
    [s,t] =size(dt);
    edge_num=s;
    for i=1:s
     mark = ismember(dt(i,1),get_knn(dt(i,2),:))+ismember(dt(i,2),get_knn(dt(i,1),:))+ismember(dt(i,1),get_knn(dt(i,3),:))+ismember(dt(i,3),get_knn(dt(i,1),:))+ismember(dt(i,2),get_knn(dt(i,3),:))+ismember(dt(i,3),get_knn(dt(i,2),:));
     if(mark<3)
        edge_num = edge_num-1;
        plot([a1(dt(i,1)),a1(dt(i,2)),a1(dt(i,3)),a1(dt(i,1))],[a2(dt(i,1)),a2(dt(i,2)),a2(dt(i,3)),a2(dt(i,1))],'b');hold on;
     end
    end
    vex_num = 2*n-edge_num-2*class;   %%% Compute the number of boundary points
    ave_thre = angle_var(vex_num);
    cluster = DirectionClusterKNN(k_num,ave_thre,X);    %%% Perform CDC
end
  
  
  