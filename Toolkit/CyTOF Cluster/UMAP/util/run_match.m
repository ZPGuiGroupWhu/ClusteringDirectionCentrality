%   AUTHORSHIP
%   Primary Developer: Stephen Meehan <swmeehan@stanford.edu> 
%   Provided by the Herzenberg Lab at Stanford University 
%   License: BSD 3 clause
%
function [match, matchTable, trainingQfTreeMatch, ...
    trainingQfTree, testQfTreeMatch,  testQfTree]...
    =run_match(varargin)

%%Wrapper for SuhMatch.Run so that the command line syntax can be used with
%%extra characters such as ( or ) or , or '
[match, matchTable, trainingQfTreeMatch, ...
    trainingQfTree, testQfTreeMatch, testQfTree]...
    =SuhMatch.Run(varargin{:});
end