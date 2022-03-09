A tookit for CDC cluster analysis on scRNA-seq data. 

---Workflow---

The entire workflow of CDC clustering on scRNA-seq data contains four steps:
Step 1: Convert the raw data to standard Seurat object. 
Step 2: Preprocess the data using standard Seurat pipeline, including normalization, HVG selection, scaling and PCA&UMAP embedding.
Step 3: Perform CDC on the embedded data.
Step 4: Visualize and evaluate clustering results, as well as compare performances with integrated baselines (Seurat, SNN-Walktrap, SNN-Louvain, K-means).

---Depends---

R (≥4.1.0) 
(optional) RStudio (≥1.3.1093)

---Imports (the latest version)---
 
argparse (≥2.0.4), assertthat (≥0.2.1), BiocGenerics (≥0.40.0), BiocSingular (≥1.10.0), ClusterR (≥1.2.5), dotCall64 (≥1.0.1), fields (≥12.5), GenomeInfoDb (≥1.30.1), GenomicRanges (≥1.46.1), geometry (≥0.4.5), ggplot2 (≥3.3.5), grid (≥4.1.0), gtools (≥3.9.2), IRanges (≥2.28.0), MatrixGenerics (≥1.6.0), mclust (≥5.4.7), parallel (≥4.1.0), prodlim (≥2019.11.13), RcppHungarian (≥0.1), readr (≥1.4.0), reshape2 (≥1.4.4), S4Vectors (≥0.30.0), scran (≥1.22.1), scuttle (≥1.4.0), Seurat (≥4.0.5), SingleCellExperiment (≥1.16.0), spam (≥2.7.0), stats4 (≥4.1.0), SummarizedExperiment (≥1.24.0), uwot (≥0.1.10)

## Please click Tools->Global Options->Packages, change CRAN repository to a near mirror. Then, execute the following code:
## Install packages from CRAN.
install.packages(c("argparse", "assertthat", "ClusterR", "dotCall64", "fields", "geometry", "ggplot2", "gtools", "mclust", "prodlim", "RcppHungarian", "readr", "reshape2", "Seurat", "spam", "uwot"))
## Determine whether the package "BiocManager" exists, if not, install this package.
if (!require("BiocManager", quietly = TRUE))
    install.packages("BiocManager")
## Install packages from Bioconductor.
BiocManager::install(c("BiocGenerics", "BiocSingular", "GenomeInfoDb", "GenomicRanges", "IRanges", "MatrixGenerics", "S4Vectors", "scran", "scuttle", "SingleCellExperiment", "SummarizedExperiment"), force = TRUE, update = TRUE, ask = FALSE)


---Sample Data---

       Dataset              Format     Label
‘Baron-Mouse’	‘csv’	‘1’
‘Muraro’	‘csv’	‘1’
‘Segerstolpe’	‘csv’	‘1’
‘Xin’	        ‘csv’   ‘1’
‘pbmc3k’	‘10X’	‘1’
‘WT_R1’	        ‘10X’   ‘1’
‘WT_R2’	        ‘10X’   ‘1’
‘NdpKO_R1’	‘10X’	‘1’
‘NdpKO_R2’	‘10X’	‘1’

---How to run---

Open the 'main.R' file in the root directory of 'scRNA-seq Cluster' folder

Before using the sample data, please decompress them in the corresponding data folder.
