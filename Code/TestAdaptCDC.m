X = textread('Demo_Datasets/synthetic_test2.txt');
data = X(:,1:2);
ref = X(:,3);

%% Perform the adaptive CDC algorithm (Select one of the following functions to perform)
% cluster = DCCParaAdapt(input_data);
% cluster = DCCParaAdapt(input_data,class_num);
% cluster = DCCParaAdapt(input_data,class_num,k_num);
% ----Examples----
addpath CDC
cluster = CDCParaAdapt(data);
% cluster = CDCParaAdapt(data,7);
% cluster = CDCParaAdapt(data,7,20);

%% Plot and evaluatethe the clustering results with the six validity indexes
addpath ClusterPlot
plotcluster(length(data),data,cluster);   
addpath ClusterEvaluation
[ Accuracy, NMI, ARI, Fscore, JI, RI] = ClustEval(ref, cluster);
