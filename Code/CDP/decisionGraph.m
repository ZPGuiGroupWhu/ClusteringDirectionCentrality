function [numClust, centInd] = decisionGraph(rho, delta, isManualSelect)
%%DECISIONGRAPH Decision graph for choosing the cluster centroids.
%   INPUT:
%       rho: local density [row vector]
%       delta: minimum distance between each point and any other point with higher density [row vector]
%       isManualSelect: 1 denote that all the cluster centroids are selected manually, otherwise 0
%  OUTPUT:
%       numClust: number of clusters
%       centInd:  centroid index vector

    NE = length(rho);
    numClust = 0;
    centInd = zeros(1, NE);
    if isManualSelect == 1
        
        fprintf('Manually select a proper rectangle to determine all the cluster centres (use Decision Graph)!\n');
        fprintf('The only points of relatively high *rho* and high  *delta* are the cluster centers!\n');
        plot(rho, delta, 's', 'MarkerSize', 7, 'MarkerFaceColor', 'r', 'MarkerEdgeColor', 'b');
        title('Decision Graph', 'FontSize', 17);
        xlabel('\rho');
        ylabel('\delta');
        
        rectangle = getrect;
        minRho = rectangle(1);
        minDelta = rectangle(2);
        
        for i = 1 : NE
            if (rho(i) > minRho) && (delta(i) > minDelta)
                numClust = numClust + 1;
                centInd(i) = numClust;
            end
        end
        
    else
        % DO NOTHING, just for futher work ...
    end

end