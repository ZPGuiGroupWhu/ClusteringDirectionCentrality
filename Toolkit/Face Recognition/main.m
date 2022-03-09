%   This application support CDC clustering for face recognition
%   If you want to input high-dimensional Gabor features (d>2), you should use UMAP to embed data into space of low dimensions (Default 'n_components'is 2; Recommended: 2~5)

%% Input ORL face images
n = 400;
imgs = zeros(112,92,n);
for i=1:40
     for j=1:10
        num1 = num2str(i);
        num2 = num2str(j);
        num = num2str(j+10*(i-1));
        file = ['Olivetti/',num1,'/',num2,'.pgm'];
        img = imread(file);
        imgs(:,:,j+10*(i-1)) = img;
     end
end

%% Extract Gabor feature
gabor = [];
for i = 1:n
    addpath GaborFeatureExtract
    gaborArray = gaborFilterBank(5,8,39,39);  % Generates the Gabor filter bank
    gabor = [gabor; (gaborFeatures(imgs(:,:,i),gaborArray,15,15))'];
end

%% Generate true labels
label = zeros(n,1);
for i=1:n
    label(i) = ceil(i/10);
end

%% Normalize the gabor features
for i=1:length(gabor(1,:))
    if((max(gabor(:,i))-min(gabor(:,i)))>0)
        gabor(:,i) = (gabor(:,i)-min(gabor(:,i)))/(max(gabor(:,i))-min(gabor(:,i)));
    end
end

%% Perform UMAP embedding
addpath UMAP/umap
[reduction, ~, ~, ~]=run_umap(pca(gabor,80),'n_components',2,'min_dist',0.1,'n_neighbors',8);

%% Perform CDC clustering
k_num = 5;
ratio = 0.7;
cluster = CDC(reduction, k_num, ratio);

%% Evaluate the clustering accuracy and plot the result
addpath ClusterEvaluation
[Accuracy, NMI, ARI, Fscore, JI, RI] = ClustEval(label, cluster);
plotcluster(reduction, label);