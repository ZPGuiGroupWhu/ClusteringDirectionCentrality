function class = DBSCAN(data,MinPts,Eps)
[m,n] = size(data);
class = zeros(m,1);
x = [(1:m)' data];
types = zeros(1,m);
dealed = zeros(m,1);
dis = calDistance(x(:,2:n+1));
number = 1;
for i = 1:m
    if dealed(i) == 0
        xTemp = x(i,:);
        D = dis(i,:);
        ind = find(D<=Eps);
        if length(ind) > 1 && length(ind) < MinPts+1
            types(i) = 0;
            class(i) = 0;
        end
        if length(ind) == 1
            types(i) = -1;
            class(i) = -1;
            dealed(i) = 1;
        end
        if length(ind) >= MinPts+1
            types(xTemp(1,1)) = 1;
            class(ind) = number;
            
            while ~isempty(ind)
                yTemp = x(ind(1),:);
                dealed(ind(1)) = 1;
                ind(1) = [];
                D = dis(yTemp(1,1),:);
                ind_1 = find(D<=Eps);                
                if length(ind_1)>1
                    class(ind_1) = number;
                    if length(ind_1) >= MinPts+1
                        types(yTemp(1,1)) = 1;
                    else
                        types(yTemp(1,1)) = 0;
                    end
                    
                    for j=1:length(ind_1)
                       if dealed(ind_1(j)) == 0
                          dealed(ind_1(j)) = 1;
                          ind=[ind ind_1(j)];   
                          class(ind_1(j))=number;
                       end                    
                   end
                end
            end
            number = number + 1;
        end
    end
end
ind_2 = class==-1;
class(ind_2) = 0;
end


