![image](https://img.shields.io/badge/R-4.1.0-brightgreen) ![image](https://img.shields.io/badge/MATLAB-R2020b-red) ![image](https://img.shields.io/badge/Python-3.9.1-blue)
# Clustering by measuring local direction centrality for data with heterogeneous density and weak connectivity (CDC)


We propose a novel Clustering algorithm by measuring Direction Centrality (CDC) locally. It adopts a density-independent metric based on the distribution of K-nearest neighbors (KNNs) to distinguish between internal and boundary points. The boundary points generate enclosed cages to bind the connections of internal points, thereby preventing cross-cluster connections and separating weakly-connected clusters.

This is a toolkit for CDC cluster analysis on various applications, including ‘scRNA-seq Cluster’, ‘UCI Benchmark Test’, ‘Synthetic Data Analysis’, ‘CyTOF Cluster’, ‘Speaker Recognition’, ‘Face Recognition’. They are implemented using MATLAB, R and Python languages.

![image](https://github.com/ZPGuiGroupWhu/ClusteringDirectionCentrality/blob/master/pics/index.jpg)

# Depends
## R (≥4.1.0)
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

Download the code and run the 'main' file in the root directory of each application. Details can be found in the [Tutorial](https://github.com/ZPGuiGroupWhu/ClusteringDirectionCentrality/blob/master/Tutorial.pdf).

> **scRNA-seq Cluster**

This application is implemented using **R** and adopts [Seurat](https://satijalab.org/seurat) pipeline to preprocess the scRNA-seq dataset. It supports '10X' and 'csv' data formats. Before running the code, you can specify the name and format of the scRNA-seq data and determine to read to label file or not. We provide 9 sample datasets in this application. ***To be noted, the sample datasets have been compressed into .zip files due the data size limit of GitHub. Before using them, please decompress them into the corresponding data folders named by the datasets.***
If you want to test your own datasets, you must name and organize the data files as the description of Data Format in [Tutorial](https://github.com/ZPGuiGroupWhu/ClusteringDirectionCentrality/blob/master/Tutorial.pdf). 
```ruby
filename = 'Baron-Mouse
format = 'csv'
labels = '1'

source('BuildSeuratObject.R')
SeuratData <- BuildSeuratObject(filename, format, labels))

source('SeuratPreprocess.R')
UMAP_Dim = 2
SeuratData <- SeuratPreprocess(SeuratData, filename, UMAP_Dim)

source('CDC.R')
k = 30
ratio = 0.9
Idents(SeuratData) <- CDC(SeuratData@reductions[["umap"]]@cell.embeddings, k, ratio)

DimPlot(SeuratData, pt.size=1) + NoLegend()
ARI <- mclust::adjustedRandIndex(Idents(SeuratData), SeuratData@meta.data[["Cluster"]])

```


> **Synthetic Data Analysis**

This application is implemented using **MATLAB** and supports for cluster analysis on synthetic datasets. It contains two main files, ‘main1.m’ and ‘main2.m’. The first handles noise-free datasets, and the second integrates noise elimination methods, LOF, RKNN and IDM. We provide 17 synthetic 2D datasets with different shapes of clusters in this application, where DS10-DS13 contain noise points. These datasets can help users to understand the capabilities of the different clustering algorithms under representative 2D data distributions.

```ruby
k = 30;
ratio = 0.7;

data = textread('SyntheticDatasets/DS1.txt');
[n, m] = size(data);
X = data(:,1:2);
label = data(:,3);

cluster = CDC(X, k, ratio);

addpath ClusterEvaluation
[Accuracy, NMI, ARI, Fscore, JI, RI] = ClustEval(label, cluster);
plotcluster(X, cluster);
```

CDC supports cluster analysis on high-dimensional data. But considering to make direction centrality of CDC more applicable, we recommend you to normalize and embed the data into low-dimensional space (2D~5D) before preforming CDC algorithm if you input high-dimensional data in this application.
```ruby
for i = 1 : length(X(1, :))
    if ((max(X(:, i))-min(X(:, i)))>0)
        X(:, i) = (X(:, i)-min(X(:, i)))/(max(X(:, i))-min(X(:, i)));
    end
end

addpath UMAP/umap
[X, ~, ~, ~] = run_umap(X, 'n_components', 2, 'min_dist', 0.1, 'n_neighbors', 20);
```

# Schematic

![image](https://github.com/ZPGuiGroupWhu/ClusteringDirectionCentrality/blob/master/pics/workflow.gif)

# License

This project is covered under the Apache 2.0 License.
