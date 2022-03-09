%   This application support CDC clustering for CyTOF biological data
%   We have provide the embedded 2D UMAP data of Levine and Samusik datasets 
%   If you want to input high-dimensional data (d>2), you should use UMAP to embed data into space of low dimensions (Default 'n_components'is 2; Recommended: 2~5)

%% Input the data and labels
data = textread('Data/Levine_UMAP.txt');
[n, m] = size(data);
X = data(:,1:2);
label = data(:,3);

%% Normalize data and UMAP embedding (If you input high-dimensional data)
% for i=1:length(X(1,:))
%     if((max(X(:,i))-min(X(:,i)))>0)
%         X(:,i) = (X(:,i)-min(X(:,i)))/(max(X(:,i))-min(X(:,i)));
%     end
% end
% addpath UMAP/umap
% [X, ~, ~, ~]=run_umap(X,'n_components',2,'min_dist',0.1,'n_neighbors',20);

%% Perform CDC algorithm
%   The suggested parameter settings for all dataset are as follows:
%   Levine_UMAP: k_num = 60; ratio = 0.9667;
%   Samusik_UMAP: k_num = 35; ratio = 0.556;
k_num = 60;
ratio = 0.9667;
cluster = CDC(X,k_num,ratio);

%% Remove the cells without labels
nan_id = isnan(label);
X(nan_id,:) = [];
cluster(nan_id) = [];
label(nan_id) = [];

%% Evaluate the clustering accuracy and plot the result
addpath ClusterEvaluation
[Accuracy, NMI, ARI, Fscore, JI, RI] = ClustEval(label, cluster);
plotcluster(X(1:100:length(X),:), cluster(1:100:length(X),:));