function [rNNi] = rNN(DataSet,k,i)
    %rNNs Ë­ÊÇÎÒ(i)µÄÅóÓÑ?
    if(k > DataSet.nn)
        DataSet.increaseBuffer(k);
    end
    [kdist_obj,~] = DDOutlier.kDistObj(DataSet,k);
    
    [rNNi,~] = find(kdist_obj.id == i);
end