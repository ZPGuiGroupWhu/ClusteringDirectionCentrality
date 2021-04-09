X = textread('Demo_Datasets/UCI_iris.txt');
init_data = X(:,1:4);
ref = X(:,5);

%% Perform PCA to reduce the dimensions
[coeff,score,latent,tsquare] = pca(init_data);
X0 = bsxfun(@minus,init_data,mean(init_data,1));
data = X0*coeff(:,1:2);

%% Perform t-SNE to reduce the dimensions
% data = tsne(init_data);

%% Perform CDC algorithm 
% cluster = DirectionClusterKNN(k_num,T_DCM,input_data);
% Parameter setting for PCA
% iris: [17,0.03]
% seeds: [17,0.03]
% wine: [4,0.01]
% Parameter setting for t-SNE
% iris: [7,0.2]
% seeds: [9,0.16]
% wine: [21,0.02]
% ----Examples----
addpath CDC
cluster = CDC(17,0.03,data); 

%% Plot and evaluatethe the clustering results with the six validity indexes
addpath ClusterPlot
plotcluster(length(data),data,cluster);   
addpath ClusterEvaluation
[ Accuracy, NMI, ARI, Fscore, JI, RI] = ClustEval(ref, cluster); 
