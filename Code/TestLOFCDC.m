X = textread('Demo_Datasets/synthetic_test_noise_1.txt');
data = X(:,1:2);
ref = X(:,3);

%% Perform CDC algorithm equipped with LOF
% cluster = LOF(data,k_num,T_DCM,lof);
% synthetic_test_noise_1: [20,0.19,0.06];
% synthetic_test_noise_2: [30,0.11,0.078];
% synthetic_test_noise_3: [40,0.19,0.1];
% ----Examples----
addpath LOF-CDC
cluster = LOF(data,20,0.19,0.06);

%% Plot and evaluatethe the clustering results with the six validity indexes
addpath ClusterPlot
plotcluster(length(data),data,cluster);   
addpath ClusterEvaluation
[precision, recall, F1score, rand_index, ad_rand_index, jaccard] = ClusterEvaluation(cluster,ref); 
