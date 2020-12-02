X = textread('Demo_Datasets/synthetic_test_3d_1.txt');
data = X(:,1:3);
ref = X(:,4);

%% Perform CDC algorithm for 3D data using projection method
% cluster = ProjCDC(k_num,T_DCM,data); 
% synthetic_test_3d_1: [20,0.26]
% synthetic_test_3d_2: [20,0.15]
% synthetic_test_3d_3: [12,0.28]
% ----Examples----
addpath CDC
cluster = ProjCDC(20,0.26,data);   


%% Plot and evaluatethe the clustering results with the six validity indexes
addpath ClusterPlot
plotcluster3D(length(data),data,cluster);   
addpath ClusterEvaluation
[precision, recall, F1score, rand_index, ad_rand_index, jaccard] = ClusterEvaluation(cluster,ref); 
