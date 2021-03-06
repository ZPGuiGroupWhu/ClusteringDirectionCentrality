# Clustering by measuring local direction centrality for data with heterogeneous density and weak connectivity (CDC)

# Introduction
In this work, we propose a novel Clustering algorithm by measuring Direction Centrality (CDC) locally. Its core idea is to detect the boundary points of clusters firstly, and then connect the internal points within the enclosed cages generated by surrounding boundary points. We consider the K-Nearest Neighbors (KNNs) of internal points to be different from that of boundary points in spatial distribution. Specifically, an internal point of clusters tends to be surrounded by its neighboring points in all directions, while a boundary point only includes neighboring points within a certain directional range. Taking advantage of this difference, we measure the local centrality by calculating the angle variance of KNNs to distinguish the internal and boundary points. This algorithm utilizes KNN to search the neighboring points, which is irrelevant to the point density and can preserve the completeness of sparse clusters. Meanwhile, CDC outlines the irregular cluster shapes and avoids the cross-cluster connections, thus separating weakly connected clusters effectively.

# Workflow

![image](https://github.com/ZPGuiGroupWhu/ClusteringDirectionCentrality/blob/main/pics/workflow.gif)

# Pseudocode

![image](https://github.com/ZPGuiGroupWhu/ClusteringDirectionCentrality/blob/main/pics/pseudocode.jpg)

# Implementation Environment

All the codes of the proposed algorithm CDC, the baselines (i.e., K-means, CDP, DBSCAN, LGC), the noise elimination algorithm LOF, the dimension reduction algorithm PCA, t-SNE are implemented using MATLAB.  While, the dimension reduction algorithm UMAP is implemented in JAVA, which can be accessed in https://github.com/tag-bio/umap-java. In this testing package, only the MATLAB codes are provided.

---Software---
MATLAB R2020b

---Hardware for MATLAB---

For Windows

	---Operating Systems---
	Windows 10 (version 1803 or higher)
	Windows 7 Service Pack 1
	Windows Server 2019
	Windows Server 2016

	---Processors---
	Minimum: Any Intel or AMD x86-64 processor
	Recommended: Any Intel or AMD x86-64 processor with four logical cores and AVX2 instruction set support

	---Disk---
	Minimum: 3.5 GB of HDD space for MATLAB only, 5-8 GB for a typical installation
	Recommended: An SSD is recommended
	A full installation of all MathWorks products may take up to 32 GB of disk space

	---RAM---
	Minimum: 4 GB
	Recommended: 8 GB
	For Polyspace, 4 GB per core is recommended

For Mac

	---Operating Systems---
	macOS Big Sur (11)
	macOS Catalina (10.15)
	macOS Mojave (10.14)
	Note:
	macOS High Sierra (10.13) is no longer supported
	On macOS Mojave, version 10.14.6 is recommended.

	---Processors---
	Minimum: Any Intel x86-64 processor
	Recommended: Any Intel x86-64 processor with four logical cores and AVX2 instruction set support

	---Disk---
	Minimum: 3.4 GB of HDD space for MATLAB only, 5-8 GB for a typical installation
	Recommended: A full installation of all MathWorks products may take up to 29 GB of disk space

	---RAM---
	Minimum: 4 GB
	Recommended: 8 GB
	For Polyspace, 4 GB per core is recommended

For Linux

	---Operating Systems---
	Ubuntu 20.04 LTS
	Ubuntu 18.04 LTS
	Ubuntu 16.04 LTS
	Debian 10
	Debian 9
	Red Hat Enterprise Linux 8
	Red Hat Enterprise Linux 7 (minimum 7.5)
	SUSE Linux Enterprise Desktop 12 (minimum SP2)
	SUSE Linux Enterprise Desktop 15
	SUSE Linux Enterprise Server 12 (minimum SP2) 
	SUSE Linux Enterprise Server 15
	Note:
	Red Hat Enterprise Linux 6 is no longer supported.

	---Processors---
	Minimum: Any Intel or AMD x86-64 processor
	Recommended: Any Intel or AMD x86-64 processor with four logical cores and AVX2 instruction set support

	---Disk---
	Minimum: 3.3 GB of HDD space for MATLAB only, 5-8 GB for a typical installation
	Recommended: An SSD is recommended
	A full installation of all MathWorks products may take up to 28 GB of disk space

	---RAM---
	Minimum: 4 GB
	Recommended: 8 GB
	For Polyspace, 4 GB per core is recommended
	
# How To Run The Code

This section introduces how to use the provided MATLAB codes to run the tests, including 1) the comparison with four baselines, 2) the clustering of high-dimensional datasets using dimension reduction algorithms, 3) the noise elimination experiment, 4) the handling 3D datasets using projection method, and 5) the adaptive parameter setting experiment.

--- 1) the comparison with four baselines (i.e., K-means, CDP, DBSCAN, LGC) ---
Open file TestCDC.m and run the following code, the exemplary datasets and the parameters can be changed accordingly. The following datasets in the "Demo_Datasets" folders can be selected, i.e., synthetic_test1, synthetic_test2, synthetic_test3, synthetic_test4, scRNAseq_pancancer_tsne, scRNAseq_pancancer_umap, corpus_ELSDSR_umap, corpus_MSLT_umap.

	X = textread('Demo_Datasets/synthetic_test1.txt');
	data = X(:,1:2);
	ref = X(:,3);
	addpath CDC
	cluster = CDC(10,0.1,data);

--- 2) the clustering of high-dimensional datasets using dimension reduction algorithms (PCA and t-SNE) ---
Open file TestHDCDC.m and run the following code, the exemplary datasets and the parameters can be changed accordingly. The following datasets in the "Demo_Datasets" folders can be selected, i.e., UCI_iris.txt, UCI_seeds.txt, and UCI_wine.txt.

	X = textread('Demo_Datasets/UCI_iris.txt');
	init_data = X(:,1:4);
	ref = X(:,5);

	% Perform PCA to reduce the dimensions
	[coeff,score,latent,tsquare] = pca(init_data);
	X0 = bsxfun(@minus,init_data,mean(init_data,1));
	data = X0*coeff(:,1:2);

	% Perform t-SNE to reduce the dimensions
	% data = tsne(init_data);

	addpath CDC
	cluster = CDC(17,0.03,data); 

--- 3) the noise elimination experiment ---
Open file TestLOFCDC.m and run the following code, the exemplary datasets and the parameters can be changed accordingly. The following datasets in the "Demo_Datasets" folders can be selected, i.e., synthetic_test_noise_1.txt, synthetic_test_noise_2.txt, and synthetic_test_noise_3.txt.

	X = textread('Demo_Datasets/synthetic_test_noise_1.txt');
	data = X(:,1:2);
	ref = X(:,3);
	addpath CDC-Noise
	cluster = LOF(data,20,0.19,0.06);

--- 4) the handling 3D datasets using projection method ---
Open file TestProjCDC.m and run the following code, the exemplary datasets and the parameters can be changed accordingly. The following datasets in the "Demo_Datasets" folders can be selected, i.e., synthetic_test_3d_1.txt, synthetic_test_3d_2.txt, and synthetic_test_3d_3.txt.

	X = textread('Demo_Datasets/synthetic_test_3d_1.txt');
	data = X(:,1:3);
	ref = X(:,4);
	addpath CDC
	cluster = VDD(20,0.26,data);  

--- 5) the adaptive parameter setting experiment ---
Open file TestAdaptCDC.m and run the following code, the exemplary datasets and the parameters can be changed accordingly. All the datasets for the comparison with four baselines can be used here.

	X = textread('Demo_Datasets/synthetic_test2.txt');
	data = X(:,1:2);
	ref = X(:,3);
	addpath CDC
	cluster = CDCParaAdapt(data);

# License

This project is covered under the Apache 2.0 License.
