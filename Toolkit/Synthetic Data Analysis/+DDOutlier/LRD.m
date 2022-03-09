function [lrd] = LRD(DataSet,p,k,neighbors)
    %根据neighbors范围内的点计算i点的LRD值
    numNeighbors = numel(neighbors);
    add = 0;
    for i = 1:1:numNeighbors
        o = neighbors(i);
        %disp(reach_distance(DataSet,p,o,k))
        add = add + DDOutlier.reach_distance(DataSet,p,o,k);
    end
    lrd = add / numNeighbors;
    lrd = 1/lrd;
end