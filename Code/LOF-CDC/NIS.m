function [NISi] = NIS(DataSet,k,i)
    %Natural Influence Space
    rNNi = DDOutlier.rNN(DataSet,k,i);
    NNi = DDOutlier.NN(DataSet,k,i);
    NISi = union(rNNi,NNi,'sorted');
end