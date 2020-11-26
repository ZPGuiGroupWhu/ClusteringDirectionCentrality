data = textread('test1.txt');
X = data(:,1:2);
ref = data(:,3);

%% Perform the CDC algorithm
cluster = DirectionClusterKNN(10,0.1,data); 

%% Plot the clustering results
plotcluster(length(data),data,cluster);   

%% Evaluate the results with the six validity indexes
[precision, recall, Fscore, rand_index, ad_rand_index, jaccard] = ClusterEvaluation(cluster,ref); 
