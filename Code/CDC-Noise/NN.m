function [NNi] = NN(DataSet,k,i)
    %NN ÎÒ(i)µÄÅóÓÑÊÇË­£¿
    if(k > DataSet.nn)
        DataSet.increaseBuffer(k);
    end
    [kdist_obj,increaseKs] = kDistObj(DataSet,k);
    NNi = kdist_obj.id(i,1:increaseKs(i));
    %find(increaseKs ~= k)
end