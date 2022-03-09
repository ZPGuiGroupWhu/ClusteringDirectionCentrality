function [lofs] = LOFs(DataSet,k)
    %计算数据集基于搜索范围k的local Outlier factor
    lrds = zeros(DataSet.n,1);
    for p = 1:1:DataSet.n
        neighbors = DDOutlier.NN(DataSet,k,p);
        [lrd] = DDOutlier.LRD(DataSet,p,k,neighbors);
        lrds(p) = lrd;
    end
    lofs = zeros(DataSet.n,1);
    for p = 1:1:DataSet.n
        neighbors = DDOutlier.NN(DataSet,k,p);
        numNeighbors = numel(neighbors);
        lrdos = lrds(neighbors);
        lrdp = lrds(p);
        lofs(p) = sum(lrdos)/lrdp/numNeighbors;
        %temp = 0;
    end
end