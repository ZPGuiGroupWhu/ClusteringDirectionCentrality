function [dist] = reach_distance(DataSet,p,o,k)
    %p的可达距离
    %p是主节点，o认为是p的邻居，搜索范围为k
    k_dist = k_distance(DataSet,o,k);
    %k_dist
    dist = distance(DataSet,p,o,k);
    %dist
    dist = max(k_dist,dist);
    %disp(dist)
end