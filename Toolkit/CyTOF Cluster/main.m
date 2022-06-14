%% Input the data and labels
data = textread('Data/Levine_UMAP.txt');
[n, m] = size(data);
X = data(:,1:2);
label = data(:,3);
nan_id = isnan(label);
label(nan_id) = [];
X(nan_id,:) = [];

%% Perform CDC algorithm
% Recommended Arguments
% Levine_UMAP: k_num = 60; ratio = 0.9667;
% Samusik_UMAP: k_num = 27; ratio = 0.9750;
k_num = 60;
ratio = 0.9667;
cluster = CDC(X,k_num,ratio);  

%% Evaluate the clustering accuracy and visualization
addpath ClusterEvaluation
[~, ~, ARI, ~, ~, ~] = ClustEval(label, cluster);
plotcluster(X(1:10:length(X),:), cluster(1:10:length(X),:));
