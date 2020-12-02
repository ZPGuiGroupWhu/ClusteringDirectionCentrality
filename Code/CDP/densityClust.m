function [numClust, clustInd, centInd, haloInd] = densityClust(dist, dc, rho, isHalo)
%%DENSITYCLUST Clustering by fast search and find of density peaks.
%   SEE the following paper published in *SCIENCE* for more details:
%       Alex Rodriguez & Alessandro Laio: Clustering by fast search and find of density peaks,
%       Science 344, 1492 (2014); DOI: 10.1126/science.1242072.
%   INPUT:
%       dist: [NE, NE] distance matrix
%       dc: cut-off distance
%       rho: local density [row vector]
%       isHalo: 1 denotes that the haloInd assigment is provided, otherwise 0.
%   OUTPUT:
%       numClust: number of clusters
%       clustInd: cluster index that each point belongs to, NOTE that -1 represents no clustering assignment (haloInd points)
%       centInd:  centroid index vector
%       haloInd: haloInd row vector [0 denotes no haloInd assignment]

    [NE, ~] = size(dist);
    delta = zeros(1, NE); % minimum distance between each point and any other point with higher density
    indNearNeigh = Inf * ones(1, NE); % index of nearest neighbor with higher density
    
    [~, ordRho] = sort(rho, 'descend');
 
    for i = 2 : NE
        delta(ordRho(i)) = max(dist(ordRho(i), :));
        for j = 1 : (i-1)
            if dist(ordRho(i), ordRho(j)) < delta(ordRho(i))
                delta(ordRho(i)) = dist(ordRho(i), ordRho(j));
                indNearNeigh(ordRho(i)) = ordRho(j);
            end
        end
    end
    delta(ordRho(1)) = max(delta);
    indNearNeigh(ordRho(1)) = 0; % no point with higher density
    
    isManualSelect = 1; % 1 denote that all the cluster centroids are selected manually, otherwise 0
    [numClust, centInd] = decisionGraph(rho, delta, isManualSelect); %%

    
    clustInd = zeros(1, NE);
    for i = 1 : NE
        if centInd(ordRho(i)) == 0 % not centroid
            clustInd(ordRho(i)) = clustInd(indNearNeigh(ordRho(i)));
        else
            clustInd(ordRho(i)) = centInd(ordRho(i));
        end
    end
    
    haloInd = haloAssign(dist, clustInd, numClust, dc, rho, isHalo);
    
end

%% Local Function
function [haloInd] = haloAssign(dist, clustInd, numClust, dc, rho, isHalo)
    [NE, ~] =size(dist);
    if isHalo == 1
        haloInd = clustInd;
        bordRho = zeros(1, numClust);
        for i = 1 : (NE - 1)
            for j = (i + 1) : NE
                if (clustInd(i) ~= clustInd(j)) && ((dist(i, j) < dc))
                    avgRho = (rho(i) + rho(j)) / 2;
                    if avgRho > bordRho(clustInd(i))
                        bordRho(clustInd(i)) = avgRho;
                    end
                    if avgRho > bordRho(clustInd(j))
                        bordRho(clustInd(j)) = avgRho;
                    end
                end
            end
        end
        for i = 1 : NE
            if rho(i) < bordRho(clustInd(i))
                haloInd(i) = 0; % 0 denotes the point is a halo
            end
        end
    else
        haloInd = zeros(1, NE); % 0 denotes no halo assignment
    end
end