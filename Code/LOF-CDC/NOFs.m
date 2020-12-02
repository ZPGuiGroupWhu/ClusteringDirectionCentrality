function [nofs] = NOFs(DataSet,k)
    %计算数据集基于搜索范围k的local Outlier factor
    lrds = zeros(DataSet.n,1);
    for p = 1:1:DataSet.n
        neighbors = DDOutlier.NN(DataSet,k,p);
        [lrd] = DDOutlier.LRD(DataSet,p,k,neighbors);
        lrds(p) = lrd;
    end
    nofs = zeros(DataSet.n,1);
    for p = 1:1:DataSet.n
        neighbors = DDOutlier.NIS(DataSet,k,p);
        
        numNeighbors = numel(neighbors);
        lrdos = lrds(neighbors);
        lrdp = lrds(p);
        nofs(p) = sum(lrdos)/lrdp/numNeighbors;
        %temp = 0;
    end
end