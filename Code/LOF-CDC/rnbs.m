function [Rnbi,numb] = rnbs(DataSet,k)
    %rnbs 为每一个点找到把自己当邻居的其他点的个数。
    %Rnbi 就是每一个点的欢迎度
    %numb 是不受欢迎个体的个数
    
    if k > DataSet.nn
        DataSet.increaseBuffer(k + 10);
    end
    [kdist_obj,~] = DDOutlier.kDistObj(DataSet,k);
    
    
    edges = [0.5:1:(DataSet.n + 0.5)];
    [Rnbi,~] = histcounts(kdist_obj.id,edges);
    Rnbi = Rnbi';
    
    numb = sum(Rnbi == 0);
end