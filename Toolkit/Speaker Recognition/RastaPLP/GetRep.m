function [res] = GetRep (X,num)
[n,m] = size(X);
res = zeros(n,1);
for i=1:n
    count = zeros(num,1);
    group = cell(num,1);
    minX = min(X(i,:));
    maxX = max(X(i,:));
    gap = (maxX-minX)/num;
    for j=1:m
        id = ceil((X(i,j)-minX)/gap);
        if(id>num)
            id = num;
        elseif(id<1)
            id = 1;
        end
        count(id) = count(id)+1;
        group{id} = [group{id},j];
    end
    [~,index] = max(count);
    res(i) = mean(X(i,group{index}));
end