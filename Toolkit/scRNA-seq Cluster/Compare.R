library(argparse)
library(Seurat)
library(reshape2)
library(readr)
library(scuttle)
library(SingleCellExperiment)
library(SummarizedExperiment)
library(MatrixGenerics)
library(GenomicRanges)
library(stats4)
library(BiocGenerics)
library(parallel)
library(IRanges)
library(S4Vectors)
library(GenomeInfoDb)
library(scran)
library(BiocSingular)

## This code compares the clustering performances among Seurat, SNN-Walktrap, SNN-Louvain, K-means and CDC.
## Please input the SeuratData and filename. The results will be written into the data folder.
## Seurat is conducted in PCA sapce with different dimenisons. SNN-Walktrap, SNN-Louvain and K-means are conducted both in 50D PCA space and embedded UMAP space. CDC is conducted in embedded UMAP space
## Users can add other baseline in this function and customize the parameter space.

Compare <- function (seuratSCE, filename, seurat_dim = seq(20, 50, 5), seurat_resolution = seq(0.1, 1, 0.1), snnwalk_k = seq(5, 30, 5), snnlouv_k = seq(5, 30, 5), kmeans_k = seq(2, 50), CDC_k = seq(30, 50, 10), CDC_ratio = seq(0.75, 0.95, 0.02)){
  
  t1 <- proc.time()
  ## Seurat cluster analysis
  cat('--------------------------------------------','\n')
  cat("Running Seurat algorithm...",'\n')
  seurat_res <- data.frame()
  for(dim in seurat_dim){
    seuratSCE <- FindNeighbors(seuratSCE, dims = 1:dim)
    for(clu_resolution in seurat_resolution){
      seuratSCE <- FindClusters(seuratSCE, resolution = clu_resolution)
      ARI <- mclust::adjustedRandIndex(Idents(seuratSCE), seuratSCE@meta.data[["Cluster"]])
      tmp_ari <- data.frame(Dims=dim, Resolution=clu_resolution, Accuracy=ARI)
      seurat_res <- rbind(seurat_res, tmp_ari)
    }
  }
  write_tsv(seurat_res, file=file.path(filename, "Seurat_Results.tsv"))
  t2 <- proc.time()
  T1 <- t2-t1
  cat('--------------------------------------------','\n')
  cat(paste0('The number of times Seurat ran: ', length(seurat_dim)*length(seurat_resolution)),'\n')
  cat(paste0('Overall runtime of Seurat: ',round(T1[3][[1]],3),'s'),'\n')
  cat(paste0('Average runtime of Seurat: ', round(T1[3][[1]]/(length(seurat_dim)*length(seurat_resolution)),3),'s'),'\n')
  cat(paste0('Max/Average ARI of Seurat: ',round(max(seurat_res[,3]),3),'/',round(mean(seurat_res[,3]),3)),'\n')
  cat('--------------------------------------------','\n')
  
  ## SNN-Walktrap cluster analysis
  ## SNN-Walktrap runs slowly, so we only set 6 parameters for SNN-Walktrap-PCA and SNN-Walktrap-UMAP respectively
  cat("Running SNN-Walktrap algorithm...",'\n')
  snnwalk_pca_res <- data.frame()
  snnwalk_umap_res <- data.frame()
  for(k in snnwalk_k){
    g1 <- buildSNNGraph(t(seuratSCE@reductions[["pca"]]@cell.embeddings), k)
    g2 <- buildSNNGraph(t(seuratSCE@reductions[["umap"]]@cell.embeddings), k)
    res1 <- igraph::cluster_walktrap(g1)$membership
    res2 <- igraph::cluster_walktrap(g2)$membership
    ARI1 <- mclust::adjustedRandIndex(res1, seuratSCE@meta.data[["Cluster"]])
    ARI2 <- mclust::adjustedRandIndex(res2, seuratSCE@meta.data[["Cluster"]])
    tmp_ari1 <- data.frame(Neighbors=k, Accuracy=ARI1)
    snnwalk_pca_res <- rbind(snnwalk_pca_res, tmp_ari1)
    tmp_ari2 <- data.frame(Neighbors=k, Accuracy=ARI2)
    snnwalk_umap_res <- rbind(snnwalk_umap_res, tmp_ari2)
  }
  write_tsv(snnwalk_pca_res, file=file.path(filename, "SNN_Walktrap_PCA_Results.tsv"))
  write_tsv(snnwalk_umap_res, file=file.path(filename, "SNN_Walktrap_UMAP_Results.tsv"))
  t3 <- proc.time()
  T2 <- t3-t2
  cat('--------------------------------------------','\n')
  cat(paste0('The number of times SNN-Walktrap ran: ', 2*length(snnwalk_k)),'\n')
  cat(paste0('Overall runtime of SNN-Walktrap: ',round(T2[3][[1]],3),'s'),'\n')
  cat(paste0('Average runtime of SNN-Walktrap: ', round(0.5*T2[3][[1]]/length(snnwalk_k),3),'s'),'\n')
  cat(paste0('Max/Average ARI of SNN-Walktrap-PCA: ',round(max(snnwalk_pca_res[,2]),3),'/',round(mean(snnwalk_pca_res[,2]),3)),'\n')
  cat(paste0('Max/Average ARI of SNN-Walktrap-UMAP: ',round(max(snnwalk_umap_res[,2]),3),'/',round(mean(snnwalk_umap_res[,2]),3)),'\n')
  cat('--------------------------------------------','\n')
  
  ## SNN-Louvain cluster analysis
  cat("Running SNN-Louvain algorithm...",'\n')
  snnlouv_pca_res <- data.frame()
  snnlouv_umap_res <- data.frame()
  for(k in snnlouv_k){
    g1 <- buildSNNGraph(t(seuratSCE@reductions[["pca"]]@cell.embeddings), k)
    g2 <- buildSNNGraph(t(seuratSCE@reductions[["umap"]]@cell.embeddings), k)
    res1 <- igraph::cluster_louvain(g1)$membership
    res2 <- igraph::cluster_louvain(g2)$membership
    ARI1 <- mclust::adjustedRandIndex(res1, seuratSCE@meta.data[["Cluster"]])
    ARI2 <- mclust::adjustedRandIndex(res2, seuratSCE@meta.data[["Cluster"]])
    tmp_ari1 <- data.frame(Neighbors=k, Accuracy=ARI1)
    snnlouv_pca_res <- rbind(snnlouv_pca_res, tmp_ari1)
    tmp_ari2 <- data.frame(Neighbors=k, Accuracy=ARI2)
    snnlouv_umap_res <- rbind(snnlouv_umap_res, tmp_ari2)
  }
  write_tsv(snnlouv_pca_res, file=file.path(filename, "SNN_Louvain_PCA_Results.tsv"))
  write_tsv(snnlouv_umap_res, file=file.path(filename, "SNN_Louvain_UMAP_Results.tsv"))
  t4 <- proc.time()
  T3 <- t4-t3
  cat('--------------------------------------------','\n')
  cat(paste0('The number of times SNN-Louvain ran: ', 2*length(snnlouv_k)),'\n')
  cat(paste0('Overall runtime of SNN-Louvain: ',round(T3[3][[1]],3),'s'),'\n')
  cat(paste0('Average runtime of SNN-Louvain: ', round(0.5*T3[3][[1]]/length(snnlouv_k),3),'s'),'\n')
  cat(paste0('Max/Average ARI of SNN-Louvain-PCA: ',round(max(snnlouv_pca_res[,2]),3),'/',round(mean(snnlouv_pca_res[,2]),3)),'\n')
  cat(paste0('Max/Average ARI of SNN-Louvain-UMAP: ',round(max(snnlouv_umap_res[,2]),3),'/',round(mean(snnlouv_umap_res[,2]),3)),'\n')
  cat('--------------------------------------------','\n')
  
  ## Kmeans cluster analysis
  cat("Running K-means algorithm...",'\n')
  kmeans_pca_res <- data.frame()
  kmeans_umap_res <- data.frame()
  for(clust_num in kmeans_k){
    res1 <- kmeans(seuratSCE@reductions[["pca"]]@cell.embeddings, clust_num)
    res2 <- kmeans(seuratSCE@reductions[["umap"]]@cell.embeddings, clust_num)
    ARI1 <- mclust::adjustedRandIndex(res1[[1]], seuratSCE@meta.data[["Cluster"]])
    ARI2 <- mclust::adjustedRandIndex(res2[[1]], seuratSCE@meta.data[["Cluster"]])
    tmp_ari1 <- data.frame(ClusNum=clust_num, Accuracy=ARI1)
    kmeans_pca_res <- rbind(kmeans_pca_res, tmp_ari1)
    tmp_ari2 <- data.frame(ClusNum=clust_num, Accuracy=ARI2)
    kmeans_umap_res <- rbind(kmeans_umap_res, tmp_ari2)
  }
  write_tsv(kmeans_pca_res, file=file.path(filename, "Kmeans_PCA_Results.tsv"))
  write_tsv(kmeans_umap_res, file=file.path(filename, "Kmeans_UMAP_Results.tsv"))
  t5 <- proc.time()
  T4 <- t5-t4
  cat('--------------------------------------------','\n')
  cat(paste0('The number of times K-means ran: ', 2*length(kmeans_k)),'\n')
  cat(paste0('Overall runtime of K-means: ',round(T4[3][[1]],3),'s'),'\n')
  cat(paste0('Average runtime of K-means: ', round(0.5*T4[3][[1]]/length(kmeans_k),3),'s'),'\n')
  cat(paste0('Max/Average ARI of Kmeans-PCA: ',round(max(kmeans_pca_res[,2]),3),'/',round(mean(kmeans_pca_res[,2]),3)),'\n')
  cat(paste0('Max/Average ARI of Kmeans-UMAP: ',round(max(kmeans_umap_res[,2]),3),'/',round(mean(kmeans_umap_res[,2]),3)),'\n')
  cat('--------------------------------------------','\n')
  
  ## CDC cluster analysis
  cat("Running CDC algorithm...",'\n')
  cdc_res <- data.frame()
  for(knn in CDC_k){
    for(int_ratio in CDC_ratio){
      res <- CDC(seuratSCE@reductions[["umap"]]@cell.embeddings, k = knn, ratio = int_ratio)
      ARI <- mclust::adjustedRandIndex(res, seuratSCE@meta.data[["Cluster"]])
      tmp_ari <- data.frame(Neighbors=knn, Ratio=int_ratio, Accuracy=ARI)
      cdc_res <- rbind(cdc_res, tmp_ari)
    }
  }
  write_tsv(cdc_res, file=file.path(filename, "CDC_Results.tsv"))
  t6 <- proc.time()
  T5 <- t6-t5
  T6 <- t6-t1
  default_res <- CDC(seuratSCE@reductions[["umap"]]@cell.embeddings, k = 30, ratio = 0.9)
  default_ari <- mclust::adjustedRandIndex(default_res, seuratSCE@meta.data[["Cluster"]])
  
  cat('--------------------------------------------','\n')
  cat(paste0('The number of times CDC ran: ', length(CDC_k)*length(CDC_ratio)),'\n')
  cat(paste0('Overall runtime of CDC: ',round(T5[3][[1]],3),'s'),'\n')
  cat(paste0('Average runtime of CDC: ', round(T5[3][[1]]/(length(CDC_k)*length(CDC_ratio)),3),'s'),'\n')
  cat(paste0('Max/Average/Default ARI of CDC-UMAP: ',round(max(cdc_res[,3]),3),'/',round(mean(cdc_res[,3]),3),'/',round(default_ari,3)),'\n')
  cat('--------------------------------------------','\n')
  cat('Comparison complete!','\n')
  cat(paste0('Overall elapsed time: ',round(T6[3][[1]],3),'s'),'\n')
  
  ## Integrate the clustering results
  box_res <- list(seurat_res[,3],snnwalk_pca_res[,2],snnwalk_umap_res[,2],snnlouv_pca_res[,2],snnlouv_umap_res[,2],kmeans_pca_res[,2],kmeans_umap_res[,2],cdc_res[,3])
  names(box_res)=c('Seurat','SNN-Walktrap-PCA','SNN-Walktrap-UMAP','SNN-Louvain-PCA','SNN-Louvain-UMAP','Kmeans-PCA','Kmeans-UMAP','CDC-UMAP')
  
  return(box_res)
}


