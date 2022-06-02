source('RunCDC.R')

## ---Specify the name of scRNA-seq dataset---
## We provide preprocessed UMAP results of 15 scRNA-seq datasets used in our manuscript: 
## 'Baron-Human', 'Baron-Mouse', 'Muraro', 'Segerstolpe', 'Xin', 'AMB', 'ALM', 'VISp', 'TM'
## 'pbmc3k', 'SCINA', 'WT_R1', 'WT_R2', 'NdpKO_R1', 'NdpKO_R2'

## ---Specify the mode to reproduce our results---
## We provide two modes to reproduce our results: 'Best' and 'All'
## 'Best': This mode only runs the algorithm with the best results of each scRNA-seq dataset directly.
## 'All': This mode goes through the entire parameter space and can obtain the same results of our paper.

RunCDC('Segerstolpe','All')
