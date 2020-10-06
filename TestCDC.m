data = textread('test1.txt');
X = data(:,1:2);
ref = data(:,3);
cluster = DirectionClusterKNN(10,0.1,data);   %% Perform CDC
plotcluster(length(data),data,cluster);     %% Plot the clustering results
[precision,recall,Fscore,rand_index,ad_rand_index, jaccard] = ClusterEvaluation(cluster,ref); %% Quantitative evaluation
