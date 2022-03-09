function [dist] = k_distance(DataSet,i,k)
    %k_distance 计算个体i的k邻居距离
    if k > DataSet.nn
        DataSet.increaseBuffer(k);
    end
%     k = k + 1;
%     [~,aDist] = knnsearch(DataSet.data,DataSet.data(i,:),'K',k,...
%             'Distance',DataSet.disMetric,'IncludeTies',true);
%     dist = aDist{1}(end);
    
    dist = DataSet.dist_obj.dist(i,k);
end