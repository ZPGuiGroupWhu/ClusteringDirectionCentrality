function [cluster] = CDCParaAdapt(data,class,k_num)
% This function is for CDC combined with adaptive method to determine the TDCM
% data: the input data
% class: the number of clusters
% k_num:the k of KNN

X = unique(data,'rows');
n = length(X);

if n < 1000
    temp_k = 0.5*(ceil(n/20)+ceil(n/50));
else
    temp_k = 3*ceil(log2(n))+5;
end

if nargin == 1
    class = 1;
    k_num = temp_k;
elseif nargin == 2
    k_num = temp_k;
end

get_knn = knnsearch(X,X,'k',k_num);
angle_var = DCCalculation(get_knn,X); %%% Calculate the DCM of each point
    
angle_var = sort(angle_var,'descend');       
dt=delaunayTriangulation(X(:,1),X(:,2));  %%% Generate the TIN
%     triplot(dt,'r');hold on;
[s,~] =size(dt);
edge_num=s;
for i=1:s
    mark = ismember(dt(i,1),get_knn(dt(i,2),:))+ismember(dt(i,2),get_knn(dt(i,1),:))+ismember(dt(i,1),get_knn(dt(i,3),:))+ismember(dt(i,3),get_knn(dt(i,1),:))+ismember(dt(i,2),get_knn(dt(i,3),:))+ismember(dt(i,3),get_knn(dt(i,2),:));
    if(mark<3)
        edge_num = edge_num-1;
    end
end
vex_num = 2*n-edge_num-2*class;   %%% Compute the number of boundary points
ave_thre = angle_var(vex_num);
cluster = CDC(k_num,ave_thre,data);    %%% Perform CDC
end
  
  
  