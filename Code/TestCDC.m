X = textread('Demo_Datasets/synthetic_test1.txt');
data = X(:,1:2);
ref = X(:,3);

%% Perform CDC algorithm 
% cluster = DirectionClusterKNN(k_num,T_DCM,input_data);
% synthetic_test1: [10,0.1]
% synthetic_test2: [20,0.1]
% synthetic_test3: [20,0.1]
% synthetic_test4: [30,0.2]
% scRNAseq_pancancer_tsne: [37,0.09]
% scRNAseq_pancancer_umap: [28,0.06]
% corpus_ELSDSR_umap: [5,0.38]
% corpus_MSLT_umap: [7,0.28]
% ----Examples----
addpath CDC
cluster = DirectionClusterKNN(10,0.1,data);   

%% Perform k-means algorithm
% cluster = kmeans(data,class_num,'Distance','sqEuclidean','Start','sample','Replicates',iterations);
% ----Examples----
% cluster = kmeans(data,7,'Distance','sqEuclidean','Start','sample','Replicates',200);

%% Perform CDP algorithm
% cluster = CDP(data);
% ----Examples----
% addpath CDP
% cluster = CDP(data);

%% Perform DBSCAN algorithm
% cluster = DBSCAN(data,Minpts,Eps);
% ----Examples----
% addpath DBSCAN
% cluster = DBSCAN(data,0,1);

%% Perform LGC algorithm
% cluster = LGC(data,IM,k_num,cFactor);
% ----Examples----
% addpath LGC
% cluster = LGC(data,50,30,0.5);



%% Plot and evaluatethe the clustering results with the six validity indexes
addpath ClusterPlot
plotcluster(length(data),data,cluster);   
addpath ClusterEvaluation
[precision, recall, F1score, rand_index, ad_rand_index, jaccard] = ClusterEvaluation(cluster,ref); 
