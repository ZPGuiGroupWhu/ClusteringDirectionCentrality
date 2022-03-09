function [dist] = distance(DataSet,i,j,k)
    %找个体i到邻居j的距离。搜索范围是k
    %如果在k范围内，j不是i的邻居就会出错。
    [kdist_obj,~] = DDOutlier.kDistObj(DataSet,k);
    
    [~,neighborLevel_j] = find(kdist_obj.id(i,:) == j);
    if ~isempty(neighborLevel_j)
        dist = kdist_obj.dist(i,neighborLevel_j); 
    else
        disp('i的k邻居里面没有j!');
        [~,neighborLevel_i] = find(kdist_obj.id(j,:) == i);
        if ~isempty(neighborLevel_i)
            dist = kdist_obj.dist(j,neighborLevel_i); 
        else
            error('i和j不在各自的k邻居范围内！');
        end
    end
    
end