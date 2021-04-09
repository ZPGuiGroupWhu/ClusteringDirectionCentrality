function [ Accuracy, NMI, ARI, Fscore, JI, RI] = ClustEval(ref, clus)
[~,~, Accuracy, Fscore, RI, ARI, JI]=ClusterEvaluation(ref, clus);
NMI = GetNMI(ref, clus);
end