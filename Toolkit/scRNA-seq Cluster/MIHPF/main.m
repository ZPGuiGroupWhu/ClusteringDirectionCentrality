X = readtable('Data/metadata.csv');
ori_barcode = X(:,1);
class_label = X(:,2);
subclass_label = X(:,3);
class_label = table2array(class_label);
subclass_label = table2array(subclass_label);
ori_barcode = table2array(ori_barcode);

for i=1:length(ori_barcode)
    str = ori_barcode{i};
    ori_barcode{i} = strrep(str,'-','.');
end

C = {}; 
fid = fopen('Data/brain_1M.UMAP.n_neighbors_50.min_dist_0.5.n_components_2.tsv');
C = textscan(fid, '%s %f %f', 'HeaderLines', 1); 
fclose(fid); 
umap_barcode = C{1};
c1 = cell2mat(C(2));
c2 = cell2mat(C(3));
X = [c1,c2];

id = zeros(length(ori_barcode),1);
for i=1:length(ori_barcode)
	id(i) = find(strcmp(ori_barcode, umap_barcode{i}));
end

class_label = class_label(id);
subclass_label = subclass_label(id);
ind = ismissing(class_label);
class_label(ind) = [];
subclass_label(ind) = [];
X(ind,:) = [];

k = 30;
ratio = 0.99;
clus = CDC(X,k,ratio); 

addpath ClusterEvaluation
[ ~, ~, ARI, ~, ~, ~] = ClustEval(class_label, clus);
plotcluster(X(1:100:length(X),:),clus(1:100:length(X),:));