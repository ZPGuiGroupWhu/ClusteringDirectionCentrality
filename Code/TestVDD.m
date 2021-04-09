X = textread('Demo_Datasets/synthetic_test_3d_1.txt');
data = X(:,1:3);
ref = X(:,4);

%% Perform CDC algorithm for 3D data using projection method
% synthetic_test_3d_1: 
% VDD: [6, 0.29]
% SDC: [9, 0.60]
% OPP: [20,0.26]
% synthetic_test_3d_2: 
% VDD: [25,0.09]
% SDC: [10,0.50]
% OPP: [20,0.15]
% synthetic_test_3d_3: 
% VDD: [15,0.11]
% SDC: [10,0.60]
% OPP: [12,0.28]
% ----Examples----
addpath CDC
cluster = VDD(6,0.29,data);
% cluster = SDC(9,0.60,data);
% cluster = OPP(20,0.26,data);

%% Plot and evaluatethe the clustering results with the six validity indexes
addpath ClusterPlot
plotcluster3D(length(data),data,cluster);   
addpath ClusterEvaluation
[ Accuracy, NMI, ARI, Fscore, JI, RI] = ClustEval(ref, cluster);
