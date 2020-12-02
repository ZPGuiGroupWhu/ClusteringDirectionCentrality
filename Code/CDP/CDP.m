function clustInd = CDP(data)

%% Load Data Set
% NOTE that the usage of some *very useful* functions: e.g., squareform, pdist2 ...
% fileName = 'demoData.mat';
% load(fileName); % NOTE that the 'demoData.mat' file includes a matrix <X> with *NE* elements and *2* dim,
                        % NE is the number of elements of a data set

%% Settings of System Parameters for DensityClust
dist = pdist2(data, data); % [NE, NE] matrix (this case may be not suitable for large-scale data sets)
% average percentage of neighbours, ranging from [0, 1]
% as a rule of thumb, set to around 1%-2% of NE (see the corresponding *Science* paper for more details)
percNeigh = 0.05;
% 'Gauss' denotes the use of Gauss Kernel to compute rho, and
% 'Cut-off' denotes the use of Cut-off Kernel.
% For large-scale data sets, 'Cut-off' is preferable owing to computational efficiency,
% otherwise, 'Gauss' is preferable in the case of small samples (especially with noises).
kernel = 'Gauss';
% set critical system parameters for DensityClust
[dc, rho] = paraSet(dist, percNeigh, kernel); 
% figure(2);
% plot(rho, 'b*');
% xlabel('ALL Data Points');
% ylabel('\rho');
% title('Distribution Plot of \rho');

%% Density Clustering
isHalo = 1; 
[~, clustInd, ~, ~] = densityClust(dist, dc, rho, isHalo);
end
