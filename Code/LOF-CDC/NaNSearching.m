function [r,max_nb] = NaNSearching(DataSet)
    %利用Natural Neighbor searching来找到
    %自适应的搜索半径r和最受欢迎的点的邻居数max_nb
    r = 1;
    %自适应寻找搜索范围
    while r <= DataSet.n
        %自适应搜索范围
        fprintf('r is now:%d\n',r);

        [Rnbi,numb] = DDOutlier.rnbs(DataSet,r);
        if r == 1
            %如实这是第一次循环，就初始化上一次搜索半径
            numb_upd = numb;
            r = r + 1;
        elseif numb_upd == numb
            break;
        else
            numb_upd = numb;
            r = r + 1;
        end

    end

    %最受欢迎点的欢迎度
    max_nb = max(Rnbi);
end