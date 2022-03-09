%   This file support CDC clustering for data with noise

%% Specify the parameters
%   k_num: k of LOF, RKNN, IDM and CDC 
%   Tnoise: noise threshold
%   ratio: percentile ratio of internal points (Default: 0.9, Recommended: 0.70~0.95)
%   The suggested parameter settings for all dataset are as follows:
%   DS10: LOF [20, 0.06, 0.90], RKNN [20, 0.38, 0.80], IDM [20, 0.30, 0.90]
%   DS11: LOF [30, 0.09, 0.90], RKNN [30, 0.20, 0.90], IDM [20, 0.53, 0.90]
%   DS12: LOF [30, 0.05, 0.90], RKNN [30, 0.35, 0.90], IDM [30, 0.10, 0.90]
%   DS13: LOF [25, 0.10, 0.60], RKNN [30, 0.35, 0.80], IDM [30, 0.50, 0.70]
k_num = 20;
Tnoise = 0.3;
ratio = 0.9;

%% Input the data and labels
data = textread('SyntheticDatasets/DS10.txt');
[n, ~] = size(data);
X = data(:,1:2);
label = data(:,3);

%% Detect the noise points
% noise = LOF(X, k_num, Tnoise);
% noise = RKNN(X, k_num, Tnoise);
noise = IDM(X, k_num, Tnoise);

%% Remove the noise points
Y = X;
Y(noise,:) = [];

%% Perform CDC algorithm
temp_clust = CDC(Y, k_num, ratio);
cluster = zeros(n,1);
cluster(setdiff(1:n,noise)) = temp_clust;

%% Evaluate the clustering accuracy and plot the result
addpath ClusterEvaluation
[Accuracy, NMI, ARI, Fscore, JI, RI] = ClustEval(label, cluster);
plotcluster(X, cluster);