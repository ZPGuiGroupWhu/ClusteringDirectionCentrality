function [id,dist] = matlabKNN(data,k,disMetric)
%matlabKNN 是R包DBSCAN的KNN函数的MATLAB简要实现
%   
    %定义距离函数来源
    if strcmp(disMetric,'euclidean')
        disMetric = 'euclidean';
    else
        error('未知的距离参数');
    end
    
    %matlab运行需要的k要多加一个
    k = k + 1;
    
    [n,~] = size(data);
    id = zeros(n,k);
    dist = zeros(n,k);
    parfor i = 1:1:n
        datum = data(i,:);
        %[aID,aDist] = knnsearch(data,datum,'K',k,'Distance',disMetric,...
        %'NSMethod','kdtree');
        [aID,aDist] = knnsearch(data,datum,'K',k,...
            'Distance',disMetric,'IncludeTies',true);
        aID = aID{1}(1:(k));
        aDist = aDist{1}(1:(k));
        id(i,:) = aID;
        dist(i,:) = aDist;
    end
    
    %裁剪结果以匹配输出
    id1 = id(:,1);
    dist1 = dist(:,1);
    
    id = id(:,2:end);
    dist = dist(:,2:end);
    
    %检查结果防止出现自己(有的时候，自己不是被排在第一个，所以一刀减下去不是特别对)
    for i = 1:1:n
        mySelf = find(id(i,:) == i);
        if(~isempty(mySelf))
            %fprintf("元素%d在%d列被错误编入！\n",i,mySelf);
            id(i,mySelf) = id1(i);
            dist(i,mySelf) = dist1(i);
        end
    end
end

