%   AUTHORSHIP
%   Primary Developer: Stephen Meehan <swmeehan@stanford.edu> 
%   Math Lead & Secondary Developer:  Connor Meehan <connor.gw.meehan@gmail.com>
%   Bioinformatics Lead:  Wayne Moore <wmoore@stanford.edu>
%   Provided by the Herzenberg Lab at Stanford University 
%   License: BSD 3 clause
%

function [edgeInd, gce]=gridEdgeInd(clusterId, M, mins, deltas, pointers)
cluInd=find(pointers==clusterId);
gce=edu.stanford.facs.swing.GridClusterEdge(M);
gce.computeAll(cluInd, mins, deltas)
edgeInd=gce.edgeBins;
end