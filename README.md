![image](https://img.shields.io/badge/R-4.1.0-brightgreen) ![image](https://img.shields.io/badge/MATLAB-R2020b-red) ![image](https://img.shields.io/badge/Python-3.9.1-blue)
# Clustering by measuring local direction centrality for data with heterogeneous density and weak connectivity (CDC)


We propose a novel Clustering algorithm by measuring Direction Centrality (CDC) locally. It adopts a density-independent metric based on the distribution of K-nearest neighbors (KNNs) to distinguish between internal and boundary points. The boundary points generate enclosed cages to bind the connections of internal points, thereby preventing cross-cluster connections and separating weakly-connected clusters.

This is a toolkit for CDC cluster analysis on various applications, including ‘scRNA-seq Cluster’, ‘UCI Benchmark Test’, ‘Synthetic Data Analysis’, ‘CyTOF Cluster’, ‘Speaker Recognition’, ‘Face Recognition’. They are implemented using MATLAB, R and Python languages.


![image](https://github.com/ZPGuiGroupWhu/ClusteringDirectionCentrality/blob/master/pics/index.jpg)

# Depends
## R (≥4.1.0) RStudio (optional)
argparse (≥2.0.4), assertthat (≥0.2.1), BiocGenerics (≥0.40.0), BiocSingular (≥1.10.0), ClusterR (≥1.2.5), dotCall64 (≥1.0.1), fields (≥12.5), GenomeInfoDb (≥1.30.1), GenomicRanges (≥1.46.1), geometry (≥0.4.5), ggplot2 (≥3.3.5), grid (≥4.1.0), gtools (≥3.9.2), IRanges (≥2.28.0), MatrixGenerics (≥1.6.0), mclust (≥5.4.7), parallel (≥4.1.0), prodlim (≥2019.11.13), RcppHungarian (≥0.1), readr (≥1.4.0), reshape2 (≥1.4.4), S4Vectors (≥0.30.0), scran (≥1.22.1), scuttle (≥1.4.0), Seurat (≥4.0.5), SingleCellExperiment (≥1.16.0), spam (≥2.7.0), stats4 (≥4.1.0), SummarizedExperiment (≥1.24.0), uwot (≥0.1.10)

Noted: all R packages can be installed from the [CRAN repository](https://cran.r-project.org/) or [Bioconductor](https://www.bioconductor.org/). You can also use the following R scripts to install them all.
```ruby
## Please click Tools->Global Options->Packages, change CRAN repository to a near mirror. Then, execute the following code:
## Install packages from CRAN.
install.packages(c("argparse", "assertthat", "ClusterR", "dotCall64", "fields", "geometry", "ggplot2", "gtools", "mclust", "prodlim", "RcppHungarian", "readr", "reshape2", "Seurat", "spam", "uwot"))
## Determine whether the package "BiocManager" exists, if not, install this package.
if (!require("BiocManager", quietly = TRUE))
    install.packages("BiocManager")
## Install packages from Bioconductor.
BiocManager::install(c("BiocGenerics", "BiocSingular", "GenomeInfoDb", "GenomicRanges", "IRanges", "MatrixGenerics", "S4Vectors", "scran", "scuttle", "SingleCellExperiment", "SummarizedExperiment"), force = TRUE, update = TRUE, ask = FALSE)
```
## MATLAB (R2020b)
[Signal Processing Toolbox](https://www.mathworks.com/products/signal.html)

# How To Run

This section introduces how to use the provided MATLAB, Python and R codes to run the CDC algorithm

--- 1) MATLAB for 2D data ---

```ruby
	data = textread('DS1.txt');
	[n,~] = size(data);
	X = data(:,1:2);
	ref = data(:,3);
	% Read TXT file (this matlab code only for 2D data)
```
	
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

# Schematic

![image](https://github.com/ZPGuiGroupWhu/ClusteringDirectionCentrality/blob/master/pics/workflow.gif)

# License

This project is covered under the Apache 2.0 License.
