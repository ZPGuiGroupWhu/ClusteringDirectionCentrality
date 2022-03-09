library(readr)
library(Seurat)

## This code aims to read the scRNA-seq data and convert it to a Seurat object. 
## The input data is required to be organized as the following standard csv or 10X formats.

BuildSeuratObject <- function (filename, datatype, labels){
  
  if(datatype=='csv'){
    expr_mat_df <- read.csv(paste(filename,'/Matrix.csv',sep = ""))
    expr_mat <- as.matrix(expr_mat_df[,2:ncol(expr_mat_df)])
    rownames(expr_mat) <- expr_mat_df$X
    seuratSCE <- CreateSeuratObject(t(expr_mat), project=filename)
    if(labels=='1'){
      sample_info_df <- read.csv(paste(filename,'/Labels.csv',sep = ""))
      seuratSCE$Cluster <- sample_info_df$x
    }
    return(seuratSCE)
    # save(seuratSCE, file = paste(filename,'/',filename,'.seuratSCE.RData',sep = ""))
  }
  else if(datatype=='10X'){
    data <- Read10X(data.dir = filename)
    seuratSCE <- CreateSeuratObject(data, project=filename)
    if(labels=='1'){
      sample_info_df <- read.csv(paste(filename,'/Labels.csv',sep = ""))
      seuratSCE$Cluster <- sample_info_df$x
    }
    return(seuratSCE)
    # save(seuratSCE, file = paste(filename,'/',filename,'.seuratSCE.RData',sep = ""))
  }else{
    cat(paste(datatype,'is not supported!',sep = " "))
  }
}

