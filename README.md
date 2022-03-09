# Clustering by measuring local direction centrality for data with heterogeneous density and weak connectivity (CDC)

# Introduction

We propose a novel Clustering algorithm by measuring Direction Centrality (CDC) locally. It adopts a density-independent metric based on the distribution of K-nearest neighbors (KNNs) to distinguish between internal and boundary points. The boundary points generate enclosed cages to bind the connections of internal points, thereby preventing cross-cluster connections and separating weakly-connected clusters.

# Schematic

![image](https://github.com/ZPGuiGroupWhu/ClusteringDirectionCentrality/blob/master/pics/workflow.gif)

# Toolkit

This is a toolkit for CDC cluster analysis on various applications, including ‘scRNA-seq Cluster’, ‘UCI Benchmark Test’, ‘Synthetic Data Analysis’, ‘CyTOF Cluster’, ‘Speaker Recognition’, ‘Face Recognition’. They are implemented using MATLAB, R and Python languages.

# Implementation Environment

MATLAB (recommended version: R2020b) only for 2D

Python (recommended version: 3.9.1) only for 2D

R (recommended version: 4.1.0) for any dimension

library(geometry)

library(fields)

library(spam)

library(dotCall64)

library(grid)

library(prodlim)

library(ClusterR)

library(RcppHungarian)

library(gtools)

# How To Run

This section introduces how to use the provided MATLAB, Python and R codes to run the CDC algorithm

--- 1) MATLAB for 2D data ---

	data = textread('DS1.txt');
	[n,~] = size(data);
	X = data(:,1:2);
	ref = data(:,3);
	% Read TXT file (this matlab code only for 2D data)
	
	clus = CDC(X,30,1,0.1);
	% Run CDC algorithm
	
	[ACC, NMI, ARI, Fscore, JI, RI] = ClustEval(ref, clus);
	% Calculate the validity metrics
	
	plotcluster(n,X,clus);
	% Plot the clustering result

--- 2) Python for 2D data ---

	raw_data = pd.read_table('DS1.txt', header=None)
	X = np.array(raw_data)
	data = X[:, :2]
	ref = X[:, 2]
	res = CDC(30, 0.1, data)

	plt.scatter(data[:, 0], data[:, 1], c=res, s=20, cmap='hsv', marker='o')
	plt.show()

--- 3) R for any dimension ---

	data <- read.table('wine.txt',header = FALSE,sep = '\t')
	dat_mat <- as.matrix(data[,1:(ncol(data)-1)])
	dat_mat <- dat_mat[,colSums(dat_mat)>0]
	dat_label <- unlist(data[,ncol(data)])
	norm_dat_mat <- dat_mat
	### Read TXT data

	for (i in 1:ncol(dat_mat)){
  	    if ((max(dat_mat[,i])-min(dat_mat[,i]))>0){
    	        norm_dat_mat[,i]<-(dat_mat[,i]-min(dat_mat[,i]))/(max(dat_mat[,i])-min(dat_mat[,i]))
  	    }
	}
	### Normalize the input data (You can also not normalize the data)

	res <- CDC(norm_dat_mat, embeding_method = "UMAP", npc = 5, k = 20, ratio = 0.8)
	clus <- as.integer(res)
	### Run CDC algorithm
	# embedding_method: {"UMAP": Use UMAP to reduce the dimensions; "None": Do not reduce the dimensions}
	# npc: The dimension of the space to embed into using UMAP
	# k: k of KNN
	# ratio: A percentile ratio measuring the proportion of internal points

	metrics <- matrix(0,nrow=1,ncol=4)
	metrics[1,1] <- mclust::adjustedRandIndex(clus, dat_label)
	metrics[1,2] <- ACC(dat_label,clus)
	metrics[1,3] <- ClusterR::external_validation(dat_label,clus,method="nmi")
	metrics[1,4] <- ClusterR::external_validation(dat_label,clus,method="jaccard_index")
	### Calculate the validity metrics (ARI, ACC, NMI, JI)


# License

This project is covered under the Apache 2.0 License.
