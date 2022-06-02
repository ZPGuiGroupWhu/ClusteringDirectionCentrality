## Specify the filename, format and labels.
## --Arguments--
##     filename: filename of the scRNA-seq dataset (We provide nine sample datasets in this application, please decompress them in the corresponding data folder before starting)
##     format: data format of the scRNA-seq dataset (We currently support two data formats, csv and 10X)
##     labels: whether the file contains the true label of cells ('1' is Yes, '0' is No)
filename = 'Baron-Mouse'
format = 'csv'
labels = '1'

## Generate Seurat Object from the raw data
source('BuildSeuratObject.R')
SeuratData <- BuildSeuratObject(filename, format, labels)

## Preprocess scRNA-seq using standard Seurat pipeline
## --Arguments--
##    n_components: The dimension of UMAP space to embed into (Default: 2, Recommended: 2~5)
##    n_neighbors: The number of neighboring points of UMAP (Default: 30, Recommended: 5~50)
##    min_dist: It controls how tightly the UMAP embedding is allowed compress points together (Default: 0.3, Recommended: 0.1~1)
source('SeuratPreprocess.R')
n_components = 2
n_neighbors = 30
min_dist = 0.3
SeuratData <- SeuratPreprocess(SeuratData, filename, n_components, n_neighbors, min_dist)

## Cluster the cells using CDC algorithm
## --Arguments--
##     k: k of KNN (Default: 30, Recommended: 5~50) 
##     ratio: percentile ratio of internal points (Default: 0.9, Recommended: 0.85~0.99, 0.55~0.65 for pbmc3k, 0.7~0.8 for SCINA)
source('CDC.R')
k = 30
ratio = 0.9
Idents(SeuratData) <- CDC(SeuratData@reductions[["umap"]]@cell.embeddings, k, ratio)

## Plot the clustering result
DimPlot(SeuratData, pt.size=1) + NoLegend()

## Evaluate the clustering accuracy using ARI metric
ARI <- mclust::adjustedRandIndex(Idents(SeuratData), SeuratData@meta.data[["Cluster"]])

## Compare the clustering performance with Seurat, SNN-Walktrap, SNN-Louvain, K-means
## Noted: Comparison is usually time consuming, if you just want to run CDC algorithm and don't 
##        want to compare with other algorithm by traversing different settings in the parameter 
##        spaces, please just comments out this part of the code
## --Arguments--
##     seurat_dim: dimension of reduction to use as input in Seurat (Default: seq(20, 50, 5)) 
##     seurat_resolution: resolution of Louvain algorithm in Seurat (Default: seq(0.1, 1, 0.1))
##     snnwalk_k: k of SNN graph in SNN-Walktrap (Default: seq(5, 30, 5))
##     snnlouv_k: k of SNN graph in SNN-Louvain (Default: seq(5, 30, 5))
##     kmeans_k: k of K-means (Default: seq(2, 50))
##     CDC_k: k of KNN in CDC (Default: seq(30, 50, 10))
##     CDC_ratio: ratio of CDC (Default: seq(0.85, 0.99, 0.02))
seurat_dim = seq(20, 50, 5)
seurat_resolution = seq(0.1, 1, 0.1)
snnwalk_k = seq(5, 30, 5)
snnlouv_k = seq(5, 30, 5)
kmeans_k = seq(2, 50)
CDC_k = seq(30, 50, 10)
CDC_ratio = seq(0.85, 0.99, 0.02)

source('Compare.R')
box_res <- Compare(SeuratData, filename, seurat_dim, seurat_resolution, snnwalk_k, snnlouv_k, kmeans_k, CDC_k, CDC_ratio)
boxplot(box_res, ylab='ARI', col=c('#FF69B4', '#4682B4', '#3CB371', '#FF7F50','#008B8B','#FFD700','#FF0000','#1E90FF'))

## Output the ARI score of CDC with the customized arguments
cat(paste0('ARI = ', round(ARI,4),' (n_components = ',n_components,', k = ',k,', ratio = ', ratio,')'),'\n')