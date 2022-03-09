%   This application support CDC clustering for speaker recognition
%   We have provide the embedded 2D UMAP data of ELSDSR and MSLT datasets 
%   If you want to input high-dimensional RastaPLP features (d>2), you should use UMAP to embed data into space of low dimensions (Default 'n_components'is 2; Recommended: 2~5)

% % ---Conduct CDC-U2 on corpuses---
% % Extract the RastaPLP feature for 'ELSDSR' or 'MSLT'
% [feature,label] = RastaPLP ('ELSDSR');
% % Specify the parameters
% k_num = 5;
% ratio = 0.7;
% % Normalize data and UMAP embedding
% addpath UMAP/umap
% [X, ~, ~, ~]=run_umap(X,'n_components',2,'min_dist',0.1,'n_neighbors',20);
% % Perform CDC clustering
% cluster = CDC(X, k_num, ratio);
% % Evaluate the clustering accuracy and plot the result
% addpath ClusterEvaluation
% [Accuracy, NMI, ARI, Fscore, JI, RI] = ClustEval(label, cluster);
% plotcluster(X, cluster);

%% ---Conduct CDC-U2 on corpuses---
%% Input the embedded data using UMAP
data = textread('Data/ELSDSR_UMAP.txt');
[n, m] = size(data);
X = data(:,1:2);
label = data(:,3);

%% Perform CDC algorithm
%   The suggested parameter settings for all dataset are as follows:
%   ELSDSR_UMAP: k_num = 5; ratio = 0.7;
%   MSLT_UMAP: k_num = 7; ratio = 0.53;
k_num = 5;
ratio = 0.7;
cluster = CDC(X,k_num,ratio);

%% Evaluate the clustering accuracy and plot the result
addpath ClusterEvaluation
[Accuracy, NMI, ARI, Fscore, JI, RI] = ClustEval(label, cluster);
plotcluster(X, cluster);
