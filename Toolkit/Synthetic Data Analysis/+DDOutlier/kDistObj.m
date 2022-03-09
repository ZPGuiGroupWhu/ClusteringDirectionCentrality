function [kdist_obj,increaseKs] = kDistObj(DataSet,k)
    % kDistObj 生成一个矩阵，这个矩阵囊括了刚好等于k距离的那些邻居点。
    % 由于不同的节点k邻居不同，所以会导致长短不一。为了仍然能否存储在一个矩阵里。
    % 用无效的元素补全长短不齐的元素。
    % 用于补齐的距离的无效元素是inf
    % 用于补齐的ID的无效元素是-1
    
    persistent k_buff;
    persistent kdist_obj_buff;
    persistent increaseKs_buff;
    
    if isempty(k_buff) || (k_buff ~= k)
        
        increaseKs = ones(1,DataSet.n) * k;
        for i = 1:1:DataSet.n
            while DDOutlier.k_distance(DataSet,i,increaseKs(i)+1) <= ...
                    DDOutlier.k_distance(DataSet,i,increaseKs(i))
                increaseKs(i) = increaseKs(i) + 1;
                %warning("发现距离相等的元素。");
            end
            %fprintf("行%d扩展到：%d\n",i,increaseKs(i));
        end
        increaseKsMAX = max(increaseKs);
        kdist_obj = struct();
        kdist_obj.dist = zeros(DataSet.n,increaseKsMAX);
        kdist_obj.id = zeros(DataSet.n,increaseKsMAX);
        buffdist = kdist_obj.dist;
        buffid = kdist_obj.id;
        parfor i = 1:DataSet.n
            buffdist(i,:) = ...
                [DataSet.dist_obj.dist(i,1:increaseKs(i)) ...
                ones(1,increaseKsMAX-increaseKs(i))*inf];
            buffid(i,:) = ...
                [DataSet.dist_obj.id(i,1:increaseKs(i)) ...
                ones(1,increaseKsMAX-increaseKs(i))*(-1)];
        end
        kdist_obj.dist = buffdist;
        kdist_obj.id = buffid;
        
        %缓冲不对，重建缓冲
        k_buff = k;
        kdist_obj_buff = kdist_obj;
        increaseKs_buff = increaseKs;
    else
        kdist_obj = kdist_obj_buff;
        increaseKs = increaseKs_buff;
    end
end
