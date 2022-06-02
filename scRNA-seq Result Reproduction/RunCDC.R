library(ggplot2)
library(gridExtra)
RunCDC <- function(dataname,mode){
  if (mode=="All"){
    if (dataname=="pbmc3k"){
      CDC_k = seq(30,50,10)
      CDC_ratio = seq(0.55, 0.65, 0.01)
    }
    else if(dataname=="SCINA"){
      CDC_k = seq(30,50,10)
      CDC_ratio = seq(0.70, 0.80, 0.01)
    }
    else if(dataname=="AMB"){
      CDC_k = seq(30,50,10)
      CDC_ratio = seq(0.95, 0.99, 0.005)
    }
    else{
      CDC_k = seq(30,50,10)
      CDC_ratio = seq(0.85, 0.99, 0.01)
    }
  }
  else if (mode=="Best"){
    if (dataname=="Baron-Human"){
      CDC_k = 30
      CDC_ratio = 0.88
    }
    else if(dataname=="Baron-Mouse"){
      CDC_k = 50
      CDC_ratio = 0.95
    }
    else if(dataname=="Muraro"){
      CDC_k = 30
      CDC_ratio = 0.94
    }
    else if(dataname=="Segerstolpe"){
      CDC_k = 40
      CDC_ratio = 0.90
    }
    else if(dataname=="Xin"){
      CDC_k = 30
      CDC_ratio = 0.97
    }
    else if(dataname=="AMB"){
      CDC_k = 40
      CDC_ratio = 0.99
    }
    else if(dataname=="ALM"){
      CDC_k = 40
      CDC_ratio = 0.96
    }
    else if(dataname=="VISp"){
      CDC_k = 50
      CDC_ratio = 0.93
    }
    else if(dataname=="TM"){
      CDC_k = 30
      CDC_ratio = 0.97
    }
    else if(dataname=="WT_R1"){
      CDC_k = 50
      CDC_ratio = 0.96
    }
    else if(dataname=="WT_R2"){
      CDC_k = 40
      CDC_ratio = 0.98
    }
    else if(dataname=="NdpKO_R1"){
      CDC_k = 30
      CDC_ratio = 0.85
    }
    else if(dataname=="NdpKO_R2"){
      CDC_k = 50
      CDC_ratio = 0.98
    }
    else if(dataname=="pbmc3k"){
      CDC_k = 40
      CDC_ratio = 0.62
    }
    else if(dataname=="SCINA"){
      CDC_k = 50
      CDC_ratio = 0.80
    }
  }
  else {
    cat("Please select one mode to reproduce our results !")
  }
  
  
  umap_mat <- read.csv(paste('Seurat_UMAP_Results/',dataname,'.csv',sep = ""))
  dat_mat <- as.matrix(umap_mat[,3:ncol(umap_mat)-1])
  ref <- umap_mat$labels

  tsne_mat <- read.csv(paste('Seurat_UMAP_Results/tsne_plot/',dataname,'.csv',sep = ""))
  
  ## Cluster the cells using CDC algorithm
  ## --Arguments--
  ##     k: k of KNN (Default: 30, Recommended: 30~50)
  ##     ratio: percentile ratio of internal points (Default: 0.9, Recommended: 0.75~0.95, 0.55~0.65 for pbmc3k)
  source('CDC.R')
  source('CDCv2.R')
  UMAP_Dim <- 2
  cdc_res <- data.frame()
  t1 <- proc.time()
  if (nrow(dat_mat)<40000){
  for(knn in CDC_k){
    for(int_ratio in CDC_ratio){
      res <- CDC(dat_mat, k = knn, ratio = int_ratio)
      ARI <- mclust::adjustedRandIndex(res, ref)
      cat(paste0('ARI = ', sprintf("%0.4f", ARI),' (n_components = ',UMAP_Dim,', k = ',knn,', ratio = ', sprintf("%0.3f", int_ratio),')'),'\n')
      tmp_ari <- data.frame(Neighbors=knn, Ratio=int_ratio, ARI=ARI, Parameters=paste0(knn,',',int_ratio))
      cdc_res <- rbind(cdc_res, tmp_ari)
    }
  }
  }else{
    for(knn in CDC_k){
      for(int_ratio in CDC_ratio){
        res <- CDCv2(dat_mat, k = knn, ratio = int_ratio)
        ARI <- mclust::adjustedRandIndex(res, ref)
        cat(paste0('ARI = ', sprintf("%0.4f", ARI),' (n_components = ',UMAP_Dim,', k = ',knn,', ratio = ', sprintf("%0.3f", int_ratio),')'),'\n')
        tmp_ari <- data.frame(Neighbors=knn, Ratio=int_ratio, ARI=ARI, Parameters=paste0(knn,',',int_ratio))
        cdc_res <- rbind(cdc_res, tmp_ari)
      }
    }
  }

  t2 <- proc.time()
  T1 <- t2-t1
  max_id <- which(cdc_res[,3]==max(cdc_res[,3]))[1]
  max_K <- cdc_res[max_id,1]
  max_ratio <- cdc_res[max_id,2]
  max_res <-  CDCv2(dat_mat, k = max_K, ratio = max_ratio)
  cat('-------------------------------------------------','\n')
  cat(paste0('The number of times CDC ran: ', length(CDC_k)*length(CDC_ratio)),'\n')
  cat(paste0('Overall runtime of CDC: ',sprintf("%0.3f",T1[3][[1]]),'s'),'\n')
  cat(paste0('Average runtime of CDC: ',sprintf("%0.3f",T1[3][[1]]/(length(CDC_k)*length(CDC_ratio))),'s'),'\n')
  cat('-------------------------------------------------','\n')
  cat(paste0('Average ARI = ', sprintf("%0.4f",mean(cdc_res[,3])),' (n_components = ',UMAP_Dim,', k = ',min(CDC_k),'~',max(CDC_k),', ratio = ',min(CDC_ratio),'~',max(CDC_ratio),')'),'\n')
  cat(paste0('Max ARI = ', sprintf("%0.4f",max(cdc_res[,3])),' (n_components = ',UMAP_Dim,', k = ',max_K,', ratio = ',max_ratio,')'),'\n')
  

  g1<-ggplot(data=cdc_res, aes(x=Parameters, y=ARI, group=1))+
    geom_line(color="#1E90FF",size=1.3)+
    geom_point(color="red",size=3)+
    theme(legend.position="none")+
    ggtitle("Accuracy Curve")+
    theme(plot.title=element_text(hjust=0.5, face='bold'),axis.text.x = element_text(angle = 45, hjust=1))
  
  if(dataname=="pbmc3k"||dataname=="SCINA"||dataname=="WT_R1"||dataname=="WT_R2"||dataname=="NdpKO_R1"||dataname=="NdpKO_R2"){
    g2<-ggplot(data=umap_mat, aes(x=UMAP_1, y=UMAP_2, color=ref))+
      geom_point(size=1)+
      theme(legend.position="none")+
      ggtitle("Ground Truth")+
      theme(plot.title=element_text(hjust=0.5, face='bold'))
    
    g3<-ggplot(data=umap_mat, aes(x=UMAP_1, y=UMAP_2, color=as.character(max_res)))+ 
      geom_point(size=1)+ 
      theme(legend.position="none")+
      ggtitle(paste0("Best CDC Result",' (ARI = ',sprintf("%0.4f",max(cdc_res[,3])),')'))+
      theme(plot.title=element_text(hjust=0.5, face='bold'))
  }else{
    g2<-ggplot(data=tsne_mat, aes(x=tSNE_1, y=tSNE_2, color=ref))+
      geom_point(size=1)+
      theme(legend.position="none")+
      ggtitle("Ground Truth")+
      theme(plot.title=element_text(hjust=0.5, face='bold'))
    
    g3<-ggplot(data=tsne_mat, aes(x=tSNE_1, y=tSNE_2, color=as.character(max_res)))+ 
      geom_point(size=1)+ 
      theme(legend.position="none")+
      ggtitle(paste0("Best CDC Result",' (ARI = ',sprintf("%0.4f",max(cdc_res[,3])),')'))+
      theme(plot.title=element_text(hjust=0.5, face='bold'))
  }

  grid.arrange(g1, arrangeGrob(g2, g3, ncol=2), nrow = 2)
  
}