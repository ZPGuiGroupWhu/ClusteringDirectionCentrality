function [ near_dis, dis ] = GetNearEdge( X, angle, edge_thre )
[n,m] = size(X);
near_dis=zeros(n,1);
dis=zeros(n,n);
for i=1:n  
    for j=1:n
       dis(i,j)=sqrt((X(i,:)-X(j,:))* (X(i,:)-X(j,:))');
    end
    [temp_sort,idx] = sort(dis(i,:));
    if(angle(i)<=edge_thre)
        for j=1:n
            if(angle(idx(j))>edge_thre)
                near_dis(i) = temp_sort(j);
                break;
            end
        end
    else
        for j=1:n
            if(angle(idx(j))<=edge_thre)
                near_dis(i) = idx(j);
                break;
            end
        end
    end
end
end