library(geometry)
library(fields)
library(spam)
library(dotCall64)
library(grid)
library(prodlim)
library(ClusterR)
library(RcppHungarian)
library(gtools)
library(readr)
library(argparse)
library(reshape2)

CDC <- function(dat_mat, k, ratio, embeding_method=NULL, k_UMAP=NULL, npc=NULL, norm=NULL){
  ## This is the code of CDC algorithm
  ## dat_mat is a n ¡Á m matrix, containing n samples with m features
  
  if(is.null(embeding_method)){
    embeding_method <- "None"
  }
  
  if(is.null(k_UMAP)){
    k_UMAP <- 30
  }
  
  if(is.null(norm)){
    norm <- FALSE
  }
  
  ## Preprocess: Normalize and remove the repeated elements
  if(norm){
    for (i in 1:ncol(dat_mat)){
      if ((max(dat_mat[,i])-min(dat_mat[,i]))>0){
        dat_mat[,i]<-(dat_mat[,i]-min(dat_mat[,i]))/(max(dat_mat[,i])-min(dat_mat[,i]))
      }
    }
  }
  
  rep_ind <- which(duplicated(dat_mat))
  dat_ind <- setdiff(c(1:nrow(dat_mat)),rep_ind)
  
  X <- dat_mat[dat_ind,]
  Y <- X
  val_num <- apply(X, 2, function(x){length(unique(x))})
  X <- X[,val_num>1]
  dim <- ncol(X)
  num <- nrow(X)
  
  if(is.null(npc)){
    npc <- 2
  }
  
  assertthat::assert_that(k < num)
  assertthat::assert_that(dim >= 2)
  assertthat::assert_that(embeding_method %in% c("UMAP", "None"))
  assertthat::assert_that(dim >= npc)
  
  ## UMAP embeding
  if(embeding_method=="UMAP"){
    set.seed(142)
    X <- uwot::umap(X, n_neighbors = k_UMAP, n_components = npc)
  }
  npc <- 2
  
  ## Step 1: Search KNN
  knn <- BiocNeighbors::findKNN(X, k)
  knn_index <- knn[["index"]]
  knn_dis <- knn[["distance"]]
  
  # Step 2: Calculate DCM
  # DCM <- cal_DCM(X, knn_index, knn_dis, dim, num, k)
  PCA_DCM <- cal_PCA_DCM(X, knn_index, knn_dis, dim, num, k, npc)
  
  ## Step 3: Calculate the reachable distance of internal points and search the nearest internal point of boundary points
  reach_dis <- cal_reach_dis(X, knn_index, knn_dis, PCA_DCM, ratio, num)
  
  ## Step 4: Connect internal points to generate clusters
  int_clust <- con_int_pts(X, reach_dis, num)
  
  ## Step 5: Assign the boundary points with the label of its nearest internal point
  temp_clust <- ass_bou_pts(int_clust, reach_dis, num)
  
  ## Step 6: Assign the repeated elements with cluster labels
  cluster <- ass_rep_pts(dat_mat, Y, rep_ind, dat_ind, temp_clust)
  return(cluster)
}


cal_PCA_DCM <- function(X, knn_index, knn_dis, dim, num, k, npc){
  assertthat::assert_that(npc<=dim)
  PCA_DCM <- array(0,dim=c(1,num))
  if(dim==2){
    for(i in 1:num){
      rel_coor = abs2rel_coor(X, i, knn_index[i,], knn_dis[i,], dim, k, npc)
      PCA_DCM[i] <- cal_2D_DCM(rel_coor, k)
    }
    PCA_DCM <-  PCA_DCM/((k-1)*4*pi^2/k^2)
  }else{
    for(i in 1:num){
      rel_coor = abs2rel_coor(X, i, knn_index[i,], knn_dis[i,], dim, k, npc)
      facet <- geometry::convhulln(rel_coor)
      PCA_DCM[i] <- cal_angle_var(facet, rel_coor, npc, k)
    }
  }
  return(PCA_DCM)
}

PCA_embeding <- function(coor, npc){
  if(ncol(coor)==npc){
    return(coor)
  }
  if(nrow(coor)>ncol(coor)){
    PCA <- princomp(coor)$scores[,1:npc]
  }else{
    PCA <- prcomp(coor)$x[,1:npc]
  }
  return(PCA)
}


abs2rel_coor <- function(X, cid, knn_index, knn_dis, dim, k, npc){
  merge_coor <- X[c(cid, knn_index),]
  if(dim==2){
    pca_coor <- merge_coor
  }else{
    pca_coor <- PCA_embeding(merge_coor, npc)
  }
  c_coor <- matrix(rep(pca_coor[1,], k), nrow=k, byrow=TRUE)
  knn_coor <- pca_coor[2:nrow(pca_coor),]
  delta_coor <- knn_coor - c_coor
  dist_li <- apply(delta_coor, 1, function(x){return(sqrt(x%*%x))})
  rel_coor <- delta_coor/dist_li
  return(rel_coor)
}

cal_2D_DCM <- function(rel_coor, k){
  angle <- array(0, dim=c(k, 1))
  for (i in 1:k){
    if(rel_coor[i,1]==0){
      if(rel_coor[i,2]==0){
        angle[i] <- 0
      }
      else if(rel_coor[i,2] > 0){
        angle[i] <- pi/2
      }
      else{
        angle[i] <- 3*pi/2
      }
    }
    else if(rel_coor[i,1] > 0){
      if(atan(rel_coor[i,2]/rel_coor[i,1])>=0){
        angle[i] <- atan(rel_coor[i,2]/rel_coor[i,1])
      }
      else{
        angle[i] <- 2*pi+atan(rel_coor[i,2]/rel_coor[i,1])
      }
    }
    else{
      angle[i] <- pi+atan(rel_coor[i,2]/rel_coor[i,1])
    }
  }
  angle_dif <- array(0, dim=c(k, 1))
  angle_sort <- sort(angle)
  for (i in 1:k-1){
    angle_dif[i] <- angle_sort[i+1]-angle_sort[i]
  }
  angle_dif[k] <- angle_sort[1]-angle_sort[k]+2*pi
  ang_var <- var(angle_dif)
  return(ang_var)
}

compute_total_angle <- function(dim){
  S <- 2*pi^(dim/2) / gamma(dim/2)
  return(S)
}

compute_pyramid_volume <- function(triangle_cart_coor){
  nsample <- nrow(triangle_cart_coor)
  if(nsample==2){
    delta_coor <- triangle_cart_coor[2,] - triangle_cart_coor[1,]
    res <- sqrt(delta_coor %*% delta_coor)
  }else{
    delta_coor <- t(t(triangle_cart_coor) - triangle_cart_coor[1,])
    delta_coor <- delta_coor[2:nsample,]
    res <- sqrt(det(delta_coor %*% t(delta_coor))) / gamma(nsample)
  }
  return(as.numeric(res))
}

cal_angle_var <- function(facet, rel_coor, dim, k){
  uniq_rel_coor <- duplicated(rel_coor)
  rep_pts_num <- nrow(rel_coor)-nrow(uniq_rel_coor)
  angle <- c()
  fac_num <- nrow(facet)
  for(i in 1:fac_num){
    if(dim==2){
      v1 <- rel_coor[facet[i,1],]
      v2 <- rel_coor[facet[i,2],]
      edg_len <- sqrt((v1-v2)%*%(v1-v2))
      ang_temp <- 2*asin(edg_len/2)
    }else{
      if(dim==3){
        OA <- rel_coor[facet[i,1],]
        OB <- rel_coor[facet[i,2],]
        OC <- rel_coor[facet[i,3],]
        inner_BOC <- OB %*% OC
        inner_COA <- OC %*% OA
        inner_AOB <- OA %*% OB
        inner_BOC <- inner_BOC / max(1, abs(inner_BOC))
        inner_COA <- inner_COA / max(1, abs(inner_COA))
        inner_AOB <- inner_AOB / max(1, abs(inner_AOB))
        a <- acos(inner_BOC)
        b <- acos(inner_COA)
        c <- acos(inner_AOB)
        p <- (a + b + c) / 2
        part1 <- sqrt(sin(p)*sin(p-a)*sin(p-b)*sin(p-c))
        if(part1==0){
          ang_temp <- 0
        }else{
          part2 <- 2*cos(a/2)*cos(b/2)*cos(c/2)
          part3 <- part1/part2
          part3 <- part3 / max(1, abs(part3))
          ang_temp <- 2*asin(part3)
        }
      }else{
        ## TODO: Cyclotomy
        ang_temp <- compute_pyramid_volume(rel_coor[facet[i,],])
      }
    }
    angle <- c(angle,ang_temp)
  }
  
  total_angle <- compute_total_angle(dim)
  if(dim > 2){
    angle <- angle + (total_angle-sum(angle))/(length(angle))
  }
  
  angle <- c(angle,array(0, dim=c(1,rep_pts_num*(dim-1))))
  ang_var <- var(angle)*(fac_num + rep_pts_num*(dim-1))/(total_angle^2)
  
  return(ang_var)
}

cal_reach_dis <- function(X, knn_index, knn_dis, DCM, ratio, num){
  sort_dcm <- sort(DCM)
  T_DCM <- sort_dcm[round(num*ratio)]
  int_bou_mark <- array(0, dim=c(num, 1))
  reach_dis <- array(0, dim=c(num, 2))
  for(i in 1:num){
    if(DCM[i] < T_DCM){
      int_bou_mark[i] <- 1
    }
  }
  int_pts <- which(int_bou_mark==1)
  bou_pts <- which(int_bou_mark==0)
  for(i in 1:length(int_pts)){
    curr_knn <- knn_index[int_pts[i],]
    nearest_bpts <- which(int_bou_mark[curr_knn]==0)
    if(length(nearest_bpts)>0){ 
      reach_dis[int_pts[i],1] <- sqrt((X[curr_knn[nearest_bpts[1]],]-X[int_pts[i],])%*%(X[curr_knn[nearest_bpts[1]],]-X[int_pts[i],]))
    }else{
      int_coor <- matrix(X[int_pts[i],], nrow=1)
      bou_coor <- matrix(X[bou_pts,], nrow=length(bou_pts))
      int_bou_dis <- fields::rdist(int_coor, bou_coor)
      reach_dis[int_pts[i],1] <- min(int_bou_dis)
    }
  }
  for(i in 1:length(bou_pts)){
    curr_knn <- knn_index[bou_pts[i],]
    nearest_bpts <- which(int_bou_mark[curr_knn]==1)
    if(length(nearest_bpts)>0){
      reach_dis[bou_pts[i],1] <- curr_knn[nearest_bpts[1]]
    }else{
      int_coor <- matrix(X[int_pts,], nrow=length(int_pts))
      bou_coor <- matrix(X[bou_pts[i],], nrow=1)
      int_bou_dis <- fields::rdist(int_coor, bou_coor)
      reach_dis[bou_pts[i],1] <- int_pts[which(int_bou_dis==min(int_bou_dis))[1]]
    }
  }
  reach_dis[,2] <- int_bou_mark
  return(reach_dis)
}

con_int_pts <- function(X, reach_dis, num){
  int_clust <- array(0, dim=c(num, 1))
  clust_id <- 1
  int_id <- which(reach_dis[,2]==1)
  int_dis <- as.matrix(dist(X[int_id,]))
  
  for(i in 1:length(int_id)){
    ti <- int_id[i]
    if(int_clust[ti]==0){
      int_clust[ti] <- clust_id
      for(j in 1:length(int_id)){
        tj = int_id[j]
        if(int_dis[i,j]<=reach_dis[ti,1]+reach_dis[tj,1]){
          if(int_clust[tj]==0){
            int_clust[tj] <- clust_id
          }else{
            temp_clust_id <- int_clust[tj]
            int_clust[which(int_clust==temp_clust_id)] <- clust_id
          }
        }
      }
      clust_id <- clust_id + 1
    }
  }
  return(int_clust)
}

ass_bou_pts <- function(int_clust, reach_dis, num){
  bou_pts <- which(reach_dis[,2]==0)
  int_clust[bou_pts[reach_dis[bou_pts,1]!=0]] <- int_clust[reach_dis[bou_pts,1]]
  all_clust_id <- unique(int_clust)
  cluster <- array(0, dim=c(num, 1))
  for(i in 1:length(all_clust_id)){
    id <- which(int_clust==all_clust_id[i])
    cluster[id] <- i
  }
  return(cluster)
}

ass_rep_pts <- function(dat_mat, X, rep_ind, dat_ind, temp_clust){
  cluster <- array(0, dim=c(nrow(dat_mat), 1))
  cluster[dat_ind] <- temp_clust
  id <- prodlim::row.match(data.frame(dat_mat[rep_ind,]),data.frame(X))
  cluster[rep_ind] <- temp_clust[id]
  return(cluster)
}