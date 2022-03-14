path <- getwd()
setwd(path)

## Read UCI data (Iris, Seeds, Wine and Digits are txt files, others are in csv format)
data <- read.table('./UCI benchmarks/Iris.txt',header = FALSE,sep = '\t')
# data <- read.csv('./UCI benchmarks/MNIST10k.csv',header = FALSE)
dat_mat <- as.matrix(data[,1:(ncol(data)-1)])
dat_mat <- dat_mat[,colSums(dat_mat)>0]
dat_label <- unlist(data[,ncol(data)])


## Normalize the data
norm_dat_mat <- dat_mat
for (i in 1:ncol(dat_mat)){
  if ((max(dat_mat[,i])-min(dat_mat[,i]))>0){
    norm_dat_mat[,i]<-(dat_mat[,i]-min(dat_mat[,i]))/(max(dat_mat[,i])-min(dat_mat[,i]))
  }
}


## UMAP Embedding
## --Arguments--
##     n_neighbors: The number of neighboring points for UMAP (Recommended: 5~50)
##     n_components: The dimension of the space to embed into using UMAP (Recommended: 2~5)
n_neighbors = 25
n_components = 2
set.seed(142)
umap_dat <- uwot::umap(norm_dat_mat, n_neighbors, n_components)


## Run CDC algorithm
## --Arguments--
##     k: k of KNN (Recommended: 5~50) 
##     ratio: percentile ratio of internal points (Recommended: 0.70~0.95)
k = 8
ratio = 0.75
source('CDC.R')
res <- CDC(umap_dat, k, ratio)
clus <- as.integer(res)

## Calculate the validity metrics (ARI, ACC, NMI, JI)
metrics <- matrix(0, nrow=1, ncol=4)
metrics[1,1] <- mclust::adjustedRandIndex(clus, dat_label)
metrics[1,2] <- ACC(dat_label, clus)
metrics[1,3] <- ClusterR::external_validation(dat_label, clus, method="nmi")
metrics[1,4] <- ClusterR::external_validation(dat_label,clus,method="jaccard_index")
cat(paste('ARI: ', round(metrics[,1],4),' ACC: ', round(metrics[,2],4),' NMI: ',round(metrics[,3],4),' JI: ', round(metrics[,4],4)),'\n')