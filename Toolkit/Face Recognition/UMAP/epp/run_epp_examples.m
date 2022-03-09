% AUTHORSHIP
%   Primary Developer: Connor Meehan <connor.gw.meehan@gmail.com> 
%   Secondary Developer:  Stephen Meehan <swmeehan@stanford.edu>
%   Bioinformatics Lead & Secondary Developer:  Wayne Moore <wmoore@stanford.edu>
%   Provided by the Herzenberg Lab at Stanford University 
%   License: BSD 3 clause
%

function run_epp_examples(whichOnes, verbose)

    addpath('../util/');
    if verLessThan('matlab', '9.3')
        msg('run_epp_examples requires MATLAB R2017b or later...')
        return;
    end
    N_RUN_EPP_EXAMPLES = 8;
    N_EXTRA_EXAMPLES = 0;
    N_EXAMPLES = N_RUN_EPP_EXAMPLES + N_EXTRA_EXAMPLES;

    if nargin<1
        verbose=false;
        whichOnes=1:N_EXAMPLES;
    else
        if nargin<2
                verbose=true;
        end
        if isempty(verbose)
            verbose=true;
        end
        if ischar(whichOnes)
            whichOnes=str2double(whichOnes);
        end
        if ~isnumeric(whichOnes) || any(isnan(whichOnes)) || any(whichOnes<0) || any(whichOnes>N_EXAMPLES)
            error(['run_epp_examples argument must be nothing or numbers from 1 to '...
                num2str(N_EXAMPLES) '!']);
        end
    end

    if all(whichOnes==0)
        whichOnes = 1:N_EXAMPLES;
    end

    srcs = exampleSources();

    if verbose
        if length(whichOnes) == 1
            DataSource.DisplaySinglePub(srcs(whichOnes));
        elseif length(whichOnes) > 1
            DataSource.DisplayMultiplePubs(values(srcs, num2cell(whichOnes)));
        end
    end
    
    CSVs = CSVMap(N_RUN_EPP_EXAMPLES);
    cytoms = CytomMap(N_RUN_EPP_EXAMPLES);

    for j = whichOnes
        printExStart(j);
        if strcmpi(srcs(j), 'omip-047')
            W = 0.015;
        elseif strcmpi(srcs(j), 'panorama')
            W = 0.024;
        else
            W = getDefaultW(cytoms(j));
        end
        if j == 1
            run_epp;
        else
            run_epp(convertStringsToChars(CSVs(j)), 'label_column', 'end', 'cytometer', cytoms(j), 'min_branch_size', 150, 'W', W);
        end
        printExEnd(j);

    end
end

function printExStart(j)
    disp(['run_epp Example ' num2str(j) ' starting...']);
end
function printExEnd(j)
    disp(['run_epp Example ' num2str(j) ' completed with no MATLAB exceptions!']);
end

function map = exampleSources()
    map = containers.Map('KeyType', 'double', 'ValueType', 'any');
    
    map(1) = 'sample10k';
    map(2) = 'omip-044';
    map(3) = 'eliver';
    map(4) = 'genentech';
    map(5) = 'maecker';
    map(6) = 'omip-069';
    map(7) = 'omip-047';
    map(8) = 'panorama';
end

function map = CSVMap(N_RUN_EPP_EXAMPLES)
    map = containers.Map('KeyType', 'double', 'ValueType', 'any');
    sources = exampleSources();
    refCSVs = DataSource.RefCSVs();
    for i = 1:N_RUN_EPP_EXAMPLES
        map(i) = refCSVs(lower(sources(i)));
    end
end

function map = CytomMap(N_RUN_EPP_EXAMPLES)
    map = containers.Map('KeyType', 'double', 'ValueType', 'any');
    sources = exampleSources();
    refCytoms = DataSource.RefCytoms();
    for i = 1:N_RUN_EPP_EXAMPLES
        map(i) = refCytoms(lower(sources(i)));
    end
end

function W = getDefaultW(cytomType)
    if strcmpi(cytomType, 'mass')
        W = 0.02;
    elseif strcmpi(cytomType, 'spectral')
        W = 0.012;
    else
        W = 0.01;
    end
end