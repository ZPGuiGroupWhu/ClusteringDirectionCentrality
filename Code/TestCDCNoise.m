X = textread('Demo_Datasets/synthetic_test_noise_3.txt');
data = X(:,1:2);
ref = X(:,3);
% plotcluster(length(data),data,ref);
%% Perform CDC algorithm equipped with LOF
% cluster = LOF(data,k_num,T_DCM,lof);
% synthetic_test_noise_1: 
% IDM: [20,0.4,0.2];
% RKNN: [20,0.38,0.2];
% LOF: [20,0.19,0.06];
% synthetic_test_noise_2: 
% IDM: [30,0.5,0.13];
% RKNN: [30,0.45,0.2];
% LOF: [30,0.11,0.078];
% synthetic_test_noise_3: 
% IDM: [40,0.08,0.2];
% RKNN: [40,0.08,0.2]
% LOF: [40,0.27,0.2];
% ----Examples----
addpath CDC-Noise

% cluster = IDM(40,0.08,0.2,data);
% cluster = RKNN(40,0.27,0.2,data);
% cluster = LOF(data,20,0.19,0.06);

%% Plot and evaluatethe the clustering results with the six validity indexes
addpath ClusterPlot
plotcluster(length(data),data,cluster);   
addpath ClusterEvaluation
[ Accuracy, NMI, ARI, Fscore, JI, RI] = ClustEval(ref, cluster);
