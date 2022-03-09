%   AUTHORSHIP
%   Primary Developer: Stephen Meehan <swmeehan@stanford.edu> 
%   Math Lead & Secondary Developer:  Connor Meehan <connor.gw.meehan@gmail.com>
%   Bioinformatics Lead:  Wayne Moore <wmoore@stanford.edu>
%   Provided by the Herzenberg Lab at Stanford University 
%   License: BSD 3 clause
%
function out=uiGetFile(clue, folder, ttl, properties, property)
out=[];
if nargin<2 || isempty(folder)
    folder=File.Documents;
end
if nargin>3
    fldr=properties.get(property, folder);
    if ~isempty(fileparts(fldr))
        folder=fldr;
    end
end
if ismac
    jd=Gui.MsgAtTopScreen(ttl,25);
else
    jd=[];
end
[file, fldr]=uigetfile(clue,ttl, [folder '/']);
if ~isempty(jd)
    jd.dispose;
end
if ~isnumeric(file) && ~isnumeric(fldr)
    out=fullfile(fldr,file);
end
if isempty(out)
    return;
end
if nargin>3
    properties.set(property, fldr);
end

end
        