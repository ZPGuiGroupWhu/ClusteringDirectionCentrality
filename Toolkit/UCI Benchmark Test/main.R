path <- getwd()
setwd(path)

## Read UCI data
## Iris, Seeds, Wine and Digits are txt files, others are in csv format.

data <- read.table('./UCI benchmarks/Wine.txt',header = FALSE,sep = '\t')
# data <- read.csv('./UCI benchmarks/Dermatology.csv',header = FALSE)
dat_mat <- as.matrix(data[,1:(ncol(data)-1)])
dat_mat <- dat_mat[,colSums(dat_mat)>0]
dat_label <- unlist(data[,ncol(data)])

## Run CDC algorithm
## --Arguments--
##     embedding_method: ("UMAP": Use UMAP to reduce the dimensions; "None": Do not reduce the dimensions)
##     npc: The dimension of the space to embed into using UMAP (Default: 2, Recommended: 2~5)
##     norm: Normalize the data using max-min function (TRUE: Yes; FALSE: No)
##     k: k of KNN (Default: 30, Recommended: 10~50) 
##     ratio: percentile ratio of internal points (Default: 0.9, Recommended: 0.70~0.95)
source('CDC.R')
res <- CDC(dat_mat, embeding_method = "UMAP", npc = 2, norm = TRUE, k = 30, ratio = 0.7)
clus <- as.integer(res)

## Calculate the validity metrics (ARI, ACC, NMI, JI)
metrics <- matrix(0, nrow=1, ncol=4)
metrics[1,1] <- mclust::adjustedRandIndex(clus, dat_label)
metrics[1,2] <- ACC(dat_label, clus)
metrics[1,3] <- ClusterR::external_validation(dat_label, clus, method="nmi")
metrics[1,4] <- ClusterR::external_validation(dat_label,clus,method="jaccard_index")
cat(paste('ARI: ', round(metrics[,1],4),' ACC: ', round(metrics[,2],4),' NMI: ',round(metrics[,3],4),' JI: ', round(metrics[,4],4)),'\n')
