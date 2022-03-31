%   This application support CDC clustering for synthetic data analysis
%   We have provide the 17 2D stnthetic datasets 
%   If you want to input high-dimensional data (d>2), you should use UMAP to embed data into space of low dimensions (Default 'n_components'is 2; Recommended: 2~5)

%% Specify the parameters
%   k_num: k of KNN
%   ratio: percentile ratio of internal points (Default: 0.9, Recommended: 0.70~0.95)
%   The suggested parameter settings for all dataset are as follows:
%   DS1:[30,0.70]; DS2:[4,0.75]; DS3:[11,0.92]; DS4:[17,0.77]; DS5:[10,0.70]; DS6:[30,0.80];
%   DS7:[30,0.80]; DS8:[52,0.80]; DS9:[30,0.95]; DS10:[30,0.95]; DS14:[30,0.90]; DS15:[30,0.90];
%   DS16:[9,0.60]; DS17:[20,0.70];
k_num = 30;
ratio = 0.7;

%% Input the data and labels
data = textread('SyntheticDatasets/DS1.txt');
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
cluster = CDC(X, k_num, ratio);

%% Evaluate the clustering accuracy and plot the result
addpath ClusterEvaluation
[Accuracy, NMI, ARI, Fscore, JI, RI] = ClustEval(label, cluster);
plotcluster(X, cluster);
