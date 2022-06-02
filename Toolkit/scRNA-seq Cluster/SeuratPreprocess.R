library(argparse)
library(Seurat)
library(ggplot2)
library(readr)
library(SingleCellExperiment)

## This code aims to preprocess the raw scRNA-seq using Seurat, inclduing normalization, HVG selection, scaling and dimension reduction.
## The intermediate results during preprocessing will be written in the data file.

SeuratPreprocess <- function(seuratSCE, filename, n_components = 2, n_neighbors = 30, min_dist = 0.3){
  
  ## Normalization
  seuratSCE <- NormalizeData(seuratSCE)
  # write.csv(seuratSCE@assays$RNA@data, file=file.path(filename, "Seurat.GeneExprMat.AllGene.Norm.csv"))
  
  ## Find HVG
  seuratSCE <- FindVariableFeatures(seuratSCE)
  p <- VariableFeaturePlot(seuratSCE)
  ggsave(file.path(filename, "Seurat.HVG_selection.pdf"), p, width = 25, height = 20, units = "cm")
  write(seuratSCE@assays$RNA@var.features, file.path(filename, "Seurat.HVG.txt"))
  
  ## Scaling Data
  seuratSCE <- ScaleData(seuratSCE, features = rownames(seuratSCE))
  # write.csv(seuratSCE@assays$RNA@scale.data, file=file.path(filename, "Seurat.GeneExprMat.AllGene.Scaled.csv"))
  
  ## PCA & UMAP Embedding
  seuratSCE <- RunPCA(seuratSCE, features = VariableFeatures(object = seuratSCE), npcs=50)
  seuratSCE <- RunUMAP(seuratSCE, n.components = n_components, n.neighbors = n_neighbors, min.dist = min_dist, dims=1:50)
  write.csv(seuratSCE@reductions$pca@cell.embeddings, file=file.path(filename, "Seurat.PCA.csv"))
  write.csv(seuratSCE@reductions$umap@cell.embeddings, file=file.path(filename, "Seurat.UMAP.csv"))
  
  return(seuratSCE) 
}


