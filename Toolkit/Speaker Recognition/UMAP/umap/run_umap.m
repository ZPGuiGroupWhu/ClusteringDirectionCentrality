function [reduction, umap, clusterIdentifiers, extras]=run_umap(varargin)
%%RUN_UMAP reduces data matrices with 3+ parameters down to fewer parameters using
%   the algorithm UMAP (Uniform Manifold Approximation and Projection).
%
%   [reduction,umap,clusterIdentifiers,extras]=RUN_UMAP(csv_file_or_data,...
%   'NAME1',VALUE1, 'NAMEN',VALUEN) 
%   
%   OUTPUT ARGUMENTS
%   Invoking run_umap returns these values:
%   1)  reduction, the actual data that UMAP reduces from the data specified by the
%       input argument csv_file_or_data.
%   2)  umap, an instance of the UMAP class made ready for the invoker to save in a
%       MATLAB file for further use as a template.
%   3)  clusterIdentifiers, identifiers of clusters found by dbscan or DBM methods
%       when run on the reduction of umap.
%   4)  extras, an instance of the class UMAP_extra_results. See properties comments
%       in UMAP_extra_results.m.
%
%   REQUIRED INPUT ARGUMENT
%   The argument csv_file_or_data is either 
%   A) a char array identifying a CSV text file containing the data to be reduced.
%   B) the actual data to be reduced; a numeric matrix.
%
%   If A), then the CSV file must have data column names in the first line. These
%   annotate the parameters which UMAP reduces.  If B), then parameter names are
%   needed by the name-value pair argument 'parameter_names' when creating or running
%   a template.
%
%   Invoke run_umap with no arguments to download CSV files that our
%   examples below rely upon.
%
%   OPTIONAL NAME VALUE PAIR ARGUMENTS
%   Some of these are identical to those in the original Python implementation
%   documented by the inventors in their document "Basic UMAP parameters", which can
%   be retrieved at https://umap-learn.readthedocs.io/en/latest/parameters.html. The
%   optional argument name/value pairs are:
%
%    NAME                   VALUE
%
%   'min_dist'              Controls how tightly UMAP is allowed to pack points
%                           together as does the same input argument for the original
%                           implementation.
%                           Default is 0.3.
%
%   'spread'                Controls the effective distance scale of embedded points
%   (v3.0)                  as does the same input argument for the original
%                           implementation.
%                           Default is 1.
%
%   'n_neighbors'           Controls local and global structure as does the same
%                           input argument for the original implementation.
%                           Default is 15. 
%   
%   'metric'                A synonym argument name is 'Distance'.  This controls how
%                           distance is computed in the ambient space as does the
%                           same input argument for the original Python
%                           implementation.
%                           Accepted values for metric include:
%              'euclidean'   - Euclidean distance (default).
%              'seuclidean'  - Standardized Euclidean distance. Each coordinate 
%                              difference between X and a query point is scaled by
%                              dividing by a scale value S. The default value of S is
%                              the standard deviation computed from X, S=NANSTD(X).
%                              To specify another value for S, use the 'Scale'
%                              argument.
%              'cityblock'   - City Block distance.
%              'chebychev'   - Chebychev distance (maximum coordinate difference).
%              'minkowski'   - Minkowski distance. The default exponent is 2. To 
%                              specify a different exponent, use the 'P' argument.
%              'mahalanobis' - Mahalanobis distance, computed using a positive 
%                              definite covariance matrix C. The default value of C
%                              is the sample covariance matrix of X, as computed by
%                              NANCOV(X). To specify another value for C, use the
%                              'Cov' argument.
%              'cosine'      - One minus the cosine of the included angle between 
%                              observations (treated as vectors).
%              'correlation' - One minus the sample linear correlation between
%                              observations (treated as sequences of values).
%              'spearman'    - One minus the sample Spearman's rank correlation 
%                              between observations (treated as sequences of values).
%              'hamming'     - Hamming distance, proportion of coordinates that 
%                              differ.
%              'jaccard'     - One minus the Jaccard coefficient, the proportion 
%                              of nonzero coordinates that differ.
%              function      - A distance function specified using @ (for example, 
%                              @KnnFind.ExampleDistFunc). The user-defined function
%                              expected by MATLAB's knnsearch function must be of the
%                              form
% 
%                                function D2 = DISTFUN(ZI, ZJ),
% 
%                              taking as arguments a 1-by-N vector ZI containing a
%                              single row of X or Y, an M2-by-N matrix ZJ containing
%                              multiple rows of X or Y, and returning an M2-by-1
%                              vector of distances D2, whose Jth element is the
%                              distance between the observations ZI and ZJ(J,:).
%
%   'P'                     A positive scalar indicating the exponent of Minkowski 
%                           distance. This argument is only valid when 'metric' (or
%                           'Distance') is 'minkowski'.
%                           Default is 2.
%   
%   'Cov'                   A positive definite matrix indicating the covariance 
%                           matrix when computing the Mahalanobis distance. This
%                           argument is only valid when 'metric' (or 'Distance') is
%                           'mahalanobis'.
%                           Default is NANCOV(X).
%
%   'Scale'                 A vector S containing non-negative values, with length 
%                           equal to the number of columns in X. Each coordinate
%                           difference between X and a query point is scaled by the
%                           corresponding element of Scale. This argument is only
%                           valid when 'Distance' is 'seuclidean'.
%                           Default is NANSTD(X).
%
%   'NSMethod'              Nearest neighbors search method. Values:
%              'kdtree'      - Instructs run_umap to use knnsearch with a k-d tree to 
%                              find nearest neighbors. This is only valid when
%                              'metric' is 'euclidean', 'cityblock', 'minkowski' or
%                              'chebychev'.
%              'exhaustive'  - Instructs run_umap to use knnsearch with the 
%                              exhaustive search algorithm. The distance values from
%                              all the points in X to each point in Y are computed to
%                              find nearest neighbors.
%              'nn_descent'  - Instructs run_umap to use KnnFind.Approximate which
%                              uses the nn_descent C++ MEX function. This tends to
%                              deliver the fastest search given certain data
%                              conditions and name-value pair arguments.  Any speedup
%                              benefit, however, comes at the cost of a slight loss
%                              of accuracy; usually < 1%. This is only valid if
%                              'metric' is NOT 'spearman', 'hamming', 'jaccard', or a
%                              user-defined function.
%
%                           Default is 'nn_descent' when n_neighbors<=45 and the
%                           unreduced data is not a sparse matrix and has
%                           rows>=40,000 & cols>10. If 'metric'=='mahalanobis' then
%                           this nn_descent lower limit for rows is 5,000 and for
%                           cols is 3. Otherwise 'kdtree' is the default if cols<=10,
%                           the unreduced data is not a sparse matrix, and the
%                           distance metric is 'euclidean', 'cityblock', 'minkowski'
%                           or 'chebychev'. Otherwise 'exhaustive' is the default.
%
%   'IncludeTies'           A logical value indicating whether knnsearch will 
%                           include all the neighbors whose distance values are equal
%                           to the Kth smallest distance.
%                           Default is false.
%
%   'BucketSize'            The maximum number of data points in the leaf node of the 
%                           k-d tree. This argument is only meaningful when k-d tree
%                           is used for finding nearest neighbors.
%                           Default is 50.
%
%   'randomize'             true/false.  If false run_umap invokes MATLAB's "rng 
%                           default" command to ensure the same random sequence of
%                           numbers between invocations.  If true then our MEX
%                           functions generate a new side based on the return value
%                           of time(NULL).
%                           Default is true.
%
%   'set_op_mix_ratio'      Interpolate between (fuzzy) union (1.0) and intersection 
%                           (0.0) as the set operation used to combine local fuzzy
%                           simplicial sets to obtain a global fuzzy simplicial set.
%                           Both fuzzy set operations use the product t-norm.
%                           Default is 1.
%
%   'target_weight'         Weighting factor between data topology (0.0) and target
%                           topology (1.0).
%                           Default is 0.5.
%
%   'template_file'         This identifies a .mat file with a saved instance of the 
%                           UMAP class that run_umap previously produced. The
%                           instance must be be a suitable "training set" for the
%                           current "test set" of data supplied by the argument
%                           csv_file_or_data. Template processing accelerates the
%                           UMAP reduction and augments reproducibility. run_umap
%                           prechecks the suitability of the template's training set
%                           for the test set by checking the name and standard
%                           deviation distance from the mean for each parameter (AKA
%                           data column).
%                           Default is empty ([]...no template).
%
%   'see_training'          true/false to see/hide plots of both the supervising data
%                           and the supervised data with label coloring and legend.
%                           This takes effect when applying a UMAP template of a
%                           supervised reduction and when the input argument
%                           verbose='graphic'. Examples 5, 10, 11, 12 and 16 apply a
%                           supervised template.  Example 16 illustrates this.
%                           Default is false.
%
%   'parameter_names'       Cell of char arrays to annotate each column of the data 
%                           matrix specified by csv_file_or_data. This is only needed
%                           if a template is being used or saved.
%                           Default is {}.
%                           
%   'verbose'               Accepted values are 'graphic', 'text', or 'none'. If 
%                           verbose='graphic' then the data displays with probability
%                           coloring and contours as is conventional in flow
%                           cytometry analysis. If method='Java' or method='MEX',
%                           then the display refreshes as optimize_layout progresses
%                           and a progress bar is shown along with a handy cancel
%                           button. If verbose='text', the progress is displayed in
%                           the MATLAB console as textual statements.
%                           Default is 'graphic'.
%                           
%   'method'                Selects 1 of 7 implementations for UMAP's optimize_layout 
%                           processing phase which does stochastic gradient descent.
%                           Accepted values are 'MEX', 'C++', 'Java', 'C', 'C
%                           vectorized', 'MATLAB' or 'MATLAB Vectorized'. 'MEX' is
%                           our fastest & most recent implementation. The source
%                           umap/sgdCpp_files/mexStochasticGradientDescent.cpp
%							provides an illustration of the simplicity and power of
%                           MATLAB's C++ MEX programming framework.
%
%                           The other methods are provided for educational value.
%                           They represent our iterative history of speeding up the
%                           slowest area of our translation from Python. We found
%                           stochastic gradient descent to be the least vectorizable.
%                           'C' and 'C vectorized', produced by MATLAB's "C coder"
%                           app, were our first attempts to accelerate our MATLAB
%                           programming. We were surprised to find our next attempt
%                           with 'Java' was faster than the code produced by C Coder.
%                           Thus we proceeded to speed up with the 'C++' and then
%                           'MEX' implementations. 'C++', our 2nd fastest, is a
%                           separate spawned executable.  The build script and cpp
%                           source file are found in umap/sgdCpp_files.
%
%							Note that MathWorks open source license prevented the 'C'
%                           and 'C vectorized' modules to be distributed.  You can
%                           download them too from
%                           http://cgworkspace.cytogenie.org/GetDown2/demo/umapAndEpp.zip
%                           MEX, Java and C++ support the progress plots and
%                           cancellation options given by argument verbose='graphic'.
%                           Default is 'MEX'.
%
%  'progress_callback'      A MATLAB function handle that run_umap invokes when 
%                           method is 'Java', 'C++', or 'MEX' and verbose='graphic'.
%                           The input/output expected of this function is
%                           keepComputing=progress_report(objectOrString). The
%                           function returns true/false to tell the reduction to keep
%                           computing or stop computing. The objectOrString argument
%                           is either a status description before stochastic gradient
%                           descent starts or an object with properties
%                           (getEmbedding, getEpochsDone and getEpochsToDo) which
%                           convey the state of progress. The function
%                           progress_report here in run_umap.m exemplifies how to
%                           write a callback.
%                           Default is the function progress_report in run_umap.m.
%
%   'ask_to_save_template'  true/false instructs run_umap to ask/not ask to save a 
%                           template PROVIDING method='Java', verbose='graphic', and
%                           template_file is empty.
%                           Default is false.
%
%   'label_column'          number identifying the column in the input data matrix 
%                           which contains numeric identifiers to label the data for
%                           UMAP supervision mode. If the value is 'end' then the
%                           last column in the matrix is the label_column.
%                           Default is 0, which indicates no label column.
%
%   'label_file'            The name of a properties file that contains the label 
%                           names and colors for annotating UMAP supervisor
%                           information when 'verbose'=='graphic'. If no folder is
%                           provided run_umap's default folder is
%                           <home>/Documents/run_umap/examples. If the file does not
%                           exist in this folder then run_umap attempts to download
%                           it from our server.
% 
%                           The color format is RGB numbers from 0 to 255. For
%                           example, the pinkish colored "Large macrophages" cell
%                           subset has a label of 37143. Thus it is represented in
%                           the file balbcLabels.properties downloaded to the default
%                           folder with these property settings:
%                               37413=Large macrophages
%                               38413.color=250 230 209
%                           Default is [].
%
%   'color_file'            The name of a properties file of editable default colors
%   (v2.1.2)                for annotating supervisor information when 
%                           'verbose'=='graphic'. If no folder is provided run_umap's
%                           default folder is <home>/Documents/run_umap/examples. If
%                           the file does not exist in this folder then run_umap
%                           attempts to download it from our server.
%
%                           The color format is RGB numbers from 0 to 255. For
%                           example, the pinkish colored "Large macrophages" cell
%                           subset has a label of 37143. Thus it is represented in
%                           the file
%                           <home>/Documents/run_umap/examples/colorsByName.properties
%                           with this property setting
%                               large\ macrophages=255  204  204
%                           Because the property key is lowercase the original
%                           spelling for display in the editor table is looked for in
%                           a companion file in the same folder with the extension
%                           spell.properties. Thus spelling for
%                           colorsByName.properties is found in
%                           colorsByName.spell.properties.
%                           Default is colorsByName.properties.  
%
%   'color_defaults'        True/false directing run_umap to override supervisor 
%   (v2.1.2)                colors found in the label_file with color values in the 
%                           color_file that have the same lowercase property key.
%                           Default is false. 
%
%   'n_components'          The dimension of the space into which to embed the data.
%                           Default is 2.
%
%   'epsilon'               The epsilon input argument used by MATLAB's dbscan 
%                           algorithm. 
%                           Default is 0.6.
%
%   'minpts'                The minpts input argument used by MATLAB's dbscan.
%                           Default is 5.
%
%   'dbscan_distance'       The distance input argument used by MATLAB's dbscan. 
%                           Default is 'euclidean'.
%
%   'cluster_output'        Allowed values: 'none', 'numeric', 'graphic'.  
%                           When the value~='none' && nargout>2 cluster results are
%                           returned in the 3rd output argument clusterIdentifiers.
%                           Default is 'numeric'.
%
%   'cluster_method_2D'     Clustering method when n_components==2.
%                           Allowed values are 'dbscan' or 'dbm'.
%                           Default is our own method 'dbm'.
%
%   'cluster_detail'        Used when (nargout>2 and the input argument 
%                           'cluster_output'~='none') OR 'cluster_output'=='graphic'.
%                           Allowed values are 'very low', 'low', 'medium', 'high',
%                           'very high', 'most high', 'adaptive' or 'nearest
%                           neighbor' or 'dbscan arguments' if 'dbscan arguments'
%                           then run_umap uses the input arguments 'epsilon' and
%                           'minpts' to determine cluster detail IF the dbscan method
%                           is needed.  If needed and 'cluster_detail' value is
%                           'adaptive' or 'nearest neighbor' then run_umap replaces
%                           with 'dbscan arguments'.
%                           Default is 'very high'.
%
%   'save_template_file'    Fully qualified path of the file to save the resulting 
%                           UMAP object as a template.  One can also save run_umap's
%                           2nd output argument.
%                           Default is [].
%
%   'match_supervisors'     A number indicating how to relabel data points in the 
%                           embedding data if the UMAP reduction is guided by a
%                           template that in turn is guided by supervisory labels.
%                           1 matches supervised and supervising data groupings by
%                             distance of medians. Supervising groupings are data
%                             points in the template's embedding that have the same
%                             supervisory label. Supervised groupings are DBM
%                             clusters in the final template-guided embedding. The
%                             publication that introduces DBM clustering is
%                             http://cgworkspace.cytogenie.org/GetDown2/demo/dbm.pdf.
%                           2 (default) matches groupings by QFMatch (quadratic form
%                             dissimilarity).  The publication that introduces QF
%                             dissimilarity is
%                             https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5818510/.
%                           3 matches supervised DBM clusters by assigning the label 
%                             of the closest supervising data point to each
%                             supervised data point (in UMAP reduced space) and then
%                             choosing the most frequent label in the cluster.
%                             Closeness is based on Euclidean distance in the
%                             supervised and supervising embedding data spaces.
%                           4 is similar to 2, except it only uses closeness to the 
%                             supervising data point to relabel the supervised data
%                             points without the aid of DBM clustering.  Thus
%                             supervised groupings in the embedding space may have
%                             small fragments of data points that occur in distant
%                             islands/clusters of the embedding.
%                           Default is 3.
%
%   'match_3D_limit'        The lower limit for the # of data rows before 3D progress 
%                           plotting avoids supervisor label matching.  This applies
%                           only when reducing with a supervised template and the
%                           n_components>2 and verbose=graphic. If > limit then
%                           supervisor matching ONLY occurs in the final plot
%                           ...otherwise supervisor label matching occurs during
%                           progress plotting before epochs finish.
%                           Default is 20000. 
%                           
%   'qf_dissimilarity'      Show QF dissimilarity scores between data groupings in 
%                           the supervised and supervising embeddings. The showing
%                           uses a sortable data table as well as a histogram.
%                           Default is false.
%                           run_umap only consults this argument when it guides a
%                           reduction with a supervised template.
%                           
%   'qf_tree'               Show a dendrogram plot that represents the relatedness of
%                           data groupings in the supervising and supervised
%                           embeddings. The above documentation for the
%                           match_supervisors argument defines "data groupings". The
%                           publication that introduces the QF tree is
%                           https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6586874/.
%                           This uses phytree from MATLAB's Bioinformatics Toolbox,
%                           hence changing this value to true requires the
%                           Bioinformatics Toolbox.
%                           Default is false.
%                           run_umap only consults this argument when it guides a
%                           reduction with a supervised template.
%                           
%   'joined_transform'      true/false for a new transform method to avoid false 
%                           positives when applying a template whose training data
%                           differs too much from test set data. This feature is not
%                           part of UMAP's original Python implementation.
%                           Currently this not supported when method is not Java.
%                           Default is false.
%
%   'python'                true/false to use UMAP's original implementation written
%                           in Python instead of this one written in MATLAB, C++ and
%                           Java.  The Python implementation is from Leland McInnes,
%                           John Healy, and James Melville. If true then certain
%                           arguments are ignored: joined_transform, method, verbose,
%                           and progress_callback.
%                           Default is false.
%
%   'nn_descent_min_rows'   the # of input data rows needed before UMAP version 2.0 
%                           engages its NEW fast fuzzy simplicial set processing.
%                           Default is 40,000.
%
%   'nn_descent_min_cols'   the # of input data columns needed before UMAP version
%                           2.0 engages its NEW fast fuzzy simplicial set processing.
%                           Default is 11.
%
%   'nn_descent_transform_queue_size' 
%                           a factor of "slack" used for fuzzy simplicial set 
%                           optimization with UMAP supervised templates. 1 means no
%                           slack and 4 means 400% slack. The more slack the greater
%                           accuracy but the less the acceleration.
%                           Default is 1.35.
%
%   'nn_descent_max_neighbors'
%                           the maximum # of n_neighbors after which the NEW
%                           acceleration of fuzzy simplicial set processing UMAP
%                           version 2.0 becomes too slow.
%							The default is 45.
%
%           The above 4 nn_descent* arguments guide accelerants of fuzzy simplicial
%           set processing released in version 2.0 of our UMAP for MATLAB. The MEX
%           accelerants engage when metric is anything other than mahalanobis or
%           spearman, when n_neighbors <= 30 and the input data matrix has rows >=
%           65,000 & columns>=11. NOTE: there could be a slight loss of accuracy
%           (usually < 1%), so you may want to set this option off.
%
%   'nn_descent_tasks'      The # of parallel tasks to use for nearest neighbor 
%                           descent if 'randomize' == true. Set to 1 if you suspect
%                           accuracy or threading issues on your computer. We have
%                           found no such issues on 3 versions of MATLAB using
%                           Windows or Mac with 2 to 6 cores. Instead we find
%                           significantly better speed than running with no
%                           parallelism.
%                           Default is set to the # of logical CPU cores assigned to
%                           MATLAB by the OS.
%                           
%   'match_scenarios'       Mostly used for "ust/UST" scenarios where UMAP uses a 
%                           previously created supervised template. This parameter
%                           produce a table of comparison statistics for each class
%                           in the supervision.
%                           1 compares the classification of the training set with a 
%                               prior classification of the test set if (and only if)
%                               the test set input data has a label column denoting
%                               this prior classification.
%                           2 is the typical comparison scenario between the 
%                               classification of the training set and the
%                               classification UST produces on the test set.
%                           3 compares a prior classification of the test set with
%                               the classification which UST produces.  The test set
%                               input data must include a label_column denoting the
%                               prior classification.  The comparison metric used is
%                               QF dissimilarity.  See
%                               https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6586874/
%                               https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5818510/
%                           4 same as 3 except the comparison metric used as
%                               F-measure.  See
%                               https://en.wikipedia.org/wiki/F-score.
%                           For non-UST scenarios, run_umap interprets 3 and 4 as
%                           requesting the comparison statistics between the clusters
%                           of the reduction and the groups defined by the arguments
%                           label_column and label_file.
%                           Default is 0.
%
%   'match_histogram_figs'  This parameter applies to match scenarios described 
%                           above.  If true then run_umap shows histograms for the 2
%                           comparison metrics of QF mass+distance similarity and
%                           F-measure. This is only in play when match_scenarios is
%                           1-5.
%                           Default is true.
%
%   'match_predictions'     true/false to invoke the PredictionAdjudicator window. 
%   (v3.0)                  This contains a table of mass+distance similarities 
%                           between the predicted and predicting subsets.  Selecting
%                           a row activates our DimensionExplorer which shows each
%                           dimension's measurement distribution, informativeness
%                           (via Kullback-Leibler divergence) and other statistics
%                           for the row's subset. You can adjudicate classification
%                           disagreement by comparing the prior classification's
%                           false negatives to the UMAP classification's false
%                           positives ... and then comparing both to the agreed upon
%                           true positives as well as the prior classification's
%                           predicted subset. The prerequisites for this are: a) a
%                           prior classification is conveyed by the 'label_column'
%                           argument; b) UMAP's Hi-D to Lo-D reduction is either
%                           basic or by a supervised template ... NOT by a supervised
%                           or template reduction.
%                           Default is false.
%
%   'false_positive_negative_plot'
%                           Used for parameter match_scenarios 4 where run_umap uses
%                           F-measure metric to compare the classification done by
%                           UST on a test set with a prior classification for the
%                           test set.  The test set input data must include a
%                           label_column denoting the prior classification. The false
%                           +/- displays includes several graphs to illustrate how
%                           the UST classification compares to the prior
%                           classification which is assumed to be more correct.
%                           Default is false.
%
%  'override_template_args' If false use the UMAP settings found in the template 
%                           rather than those found in the provided as arguments to
%                           run_umap.  This affects the arguments metric, P, Cov,
%                           Scale, n_neighbors and min_dist. The arguments for
%                           n_components and parameter_names are ALWAYS ignored when
%                           using a template (either supervised or unsupervised).
%                           Default is false.
%
%   'sgd_tasks'           	The # of parallel tasks to use for stochastic gradient 
%                           descent if using our MEX ('method' == 'MEX') and if
%                           'randomize' == true.  Set to 1 if you suspect inaccuracy
%                           or threading issues of any kind on your computer. We have
%                           found no such issues on 3 versions of MATLAB using
%                           Windows or Mac with 2 to 6 cores. What we find is
%                           significantly better speed than when running with no
%                           parallelism for the "epoch processing" phase that usually
%                           costs over 50% of UMAP's time when reducing without
%                           templates.
%                           Default is set to the # of logical CPU cores assigned to
%                           MATLAB by the OS.
%
%   'contour_percent'       From 0 to 25.  This changes the probability contour 
%   (v2.1.2)                display when 'n_components'==2 and 'verbose'=='graphic'.
%                           Default is 10. Range is 0 to 25 where 0 eliminates the
%                           contours.
%                           The algorithm is described at 
%                           http://v9docs.flowjo.com/html/graphcontours.html#:~:text=FlowJo%20draws%20only%20one%20type,of%20relative%20frequencies%20of%20subpopulations.
%
%   'marker'                The plot marker to use when 'n_components'==2 and 
%   (v2.1.2)                'verbose'=='graphic'.  For options, see MATLAB's 
%                           documentation for plot function.
%                           Default is '.'
%
%   'marker_size'           The size of marker to use when 'n_components'==2 and 
%   (v2.1.2)                'verbose'=='graphic'.  For options, see MATLAB's
%                           documentation for plot function.
%                           Default is 2.
%
%   'eigen_limit'           The limit on the number of rows in the input data before 
%   (v2.1.2)                accelerating eigenvector calculation with LOBPCG.  We 
%                           have not observed any loss of global or local structure
%                           with LOBPCG compared to MATLAB's eigs or the Leland
%                           McInnes Python implementation which uses SciPy package's
%                           eigsh. We have observed LOBPCG 5 times faster with over
%                           160k rows. This has no effect when using templates.
%                           Default is 8192. Range is 4096 to 32768.
%                           
%   'probability_bin_limit' The limit on number of rows in the input data before 
%   (v2.1.2)                accelerating eigenvector calculation by first compressing 
%                           the data into probability bins. The compression is ONLY
%                           used for eigenvectors. We have only seen minor loss of
%                           global structure with this compression.  This is usually
%                           more than 20 times faster than LOBPCG. This has no effect
%                           when using templates.
%                           Default is 262144. Range is 49152 to 1310720.
%                           The probability binning algorithm is described at                           
%                           https://onlinelibrary.wiley.com/doi/full/10.1002/1097-0320(20010901)45:1%3C37::AID-CYTO1142%3E3.0.CO%3B2-E
%
%   'init'                  How to initialize the low-dimensional embedding. 
%                           Options are:
%                               'spectral': use a spectral embedding of the fuzzy 
%                                   1-skeleton
%                               'random': assign initial embedding positions 
%                                   uniformly at random.
%                           This has no effect when using templates.
%                           Default is 'spectral'.
%
%  'supervised_metric'      The metric used to measure distance for a target array if
%                           using supervised dimension reduction. By default this is
%                           'categorical' which will measure distance in terms of
%                           whether categories match or are different. Furthermore,
%                           if semi-supervised is required target values of -1 will
%                           be treated as unlabelled under the 'categorical' metric.
%                           If the target array takes continuous values (e.g. for a
%                           regression problem) then metric of 'l1' or 'l2' is
%                           probably more appropriate.
%
%                           If not 'categorical' then value must be one of the values
%                           supported by knnsearch.  Since only the label dimension
%                           is searched by knnsearch the nn descent speed up is not
%                           attempted. One might want to do this if the supervisor
%                           labels are ordinal and not categorical. Default is
%                           'categorical'.
%
%  'supervised_dist_args'   If supervised_metric is a knnsearch metric then 
%                           supervised_dist_args is a numeric value that meets the
%                           requirements if supervised_metric is Mahalanobis (see
%                           'Cov'), or Minkowski (see 'P') or SEuclidean (see
%                           'Scale').
%                           Default is [].
%
%  'compress'               The number of data points to sample at random from the 
%                           input data before performing dimension reduction. If
%                           performing supervised UMAP, 'compress' can also accept a
%                           1-by-2 array [D L], where D is the argument above. If L
%                           is supplied, then all labels with at least L data points
%                           will have at least L data points sampled for the
%                           compressed set; other labels will not be compressed at
%                           all.
%                           Default is [] (no compression).
%
%  'synthesize'             The size of the synthetic dataset to be generated. This
%                           is only valid when running supervised UMAP: for each of
%                           the data classes conferred by the labels, the mean and
%                           covariance matrix is used to generate a synthetic dataset
%                           with proportional representation of the original labels.
%                           If a 1-by-2 array [D L] is supplied, then D is the above
%                           argument and the dataset is generated so that each label
%                           has at least L synthetic points.
%                           Default is [] (no synthesis).
%
%   'roi_table'             A number from 0 to 3 for popping up a table that shows 
%                           the distribution and Kullback-Leibler divergence of input
%                           data associated with UMAP output regions that are defined
%                           by labels or MATLAB ROIs.  Valid values are
%                            0  - never pop up a table
%                            1  - only pop up a table for ROIs which are activated by 
%                                 clicking 1 of the 3 buttons on the right of the
%                                 toolbar for the window that run_umap shows when the
%                                 argument verbose==graphic. ROIs supported are
%                                 ellipses, rectangles, and polygons.
%                            2 -  only pop up a table when selecting a row in the 
%                                 mass+distance similarity table produced by a
%                                 run_umap argument for match_scenarios AND when
%                                 run_umap is reducing dimensions with a supervised
%                                 template.
%                            3 -  pop up a table for both ROIs or the mass+distance 
%                                 similarity table.
%                                 Default is 3.  This only takes effect if the
%                                 run_umap argument verbose==graphic.  In 3D plots it
%                                 is easier to manipulate the ROI if you rotate the
%                                 plot to a 2 dimensional perspective.
% 
%   'roi_scales'            A matrix of numbers for guiding any further scaling that
%                           is needed in the roi_table's display of jet-colored bars
%                           for the density distribution of each input dimension's
%                           data. The matrix must have no more rows than there are
%                           columns for the input data.  Moreover, the matrix for
%                           roi_scales must have 3 columns where column 1 is the
%                           index of the column of the input data needing scaling;
%                           column 2 is the minimum value for this input data's
%                           column; and 3 is the maximum value.
%                           Default is [] (no scaling).
% 
%   'locate_fig'            When verbose is graphic this cell data indicates how to 
%   (v3.0)                  position the umap figure relative a parent figure. The 
%                           cell as 3 data items: 1=parent figure, 2=location
%                           (west/east/south/north), 3=true if close when parent fig.
%                           Default is {} (no parent locating). 
%
%   'save_output'           Capture figures in PNG files.
%   (v3.0)                  Default is false.
% 
%   'output_folder'         Folder into which to deposit PNG files.
%   (v3.0)                  Default is same folder as the CSV file or
%                           ~/Documents/run_umap if no CSV file.
% 
%   'output_suffix'         Suffix for PNG file name.
%   (v3.0)                  Default is ''. 
% 
%   'fast_approximation'    true/false to compress data for faster reductions.
%   (v3.0)                  Compression uses our lab's probability binning algorithm                           
%                           described at:
%                           https://onlinelibrary.wiley.com/doi/full/10.1002/1097-0320(20010901)45:1%3C37::AID-CYTO1142%3E3.0.CO%3B2-E
%                           Probability bins represent open covers of a more basic
%                           kind than UMAP's simplicial complexes. For most data sets
%                           the loss of accuracy with this approximation is
%                           negligible.  In example 27 UMAP's reduction of
%                           1.8+million X 27 measurements takes ~17 minutes on our 6
%                           core MacBook ... but with fast approximation it takes ~20
%                           seconds yet this speed up costs little accuracy when
%                           comparing UMAP's data islands to cell subsets defined by
%                           by expert biologists:  fast approximation forms data
%                           islands that are ~97% similar ... compared to ~99%
%                           similarity without fast approximation.  The merits of
%                           approximation for particular data sets can be tested with
%                           automatic computation of ROI polygons for populations
%                           with classification labels as described below in
%                           roi_percent_closest.
%                           Default is false.
%           
%   'roi_percent_closest'   % of a labeled subset to include within the boundaries of 
%                           a computed polygon. This is used when verbose=graphic,
%                           n_components is 2 and label_column is not empty.  Users
%                           pick labeled population(s) and then click the button
%                           "Regions of interest" south of the legend window to
%                           compute an automatic polygon ROI around the regions where
%                           MOST of their labeled data points lay. MOST is based on
%                           Euclidean closeness to the median of the data with the
%                           same labels.
%                           Default is .94 if fast_approximation is false and .91 if
%                           fast_approximation is true.
%                          
%   'plot_title'  		    Add plot title if verbose is 'graphic'.
%   (v3.0)                  Default is empty/blank.
%
%   'mlp_train'             TensorFlow or "fitcnet" builds an multilayer perceptron 
%   (v4.0)                  neural network to work in concert with a UMAP supervised 
%                           template. Thus you must provide the arguments needed for
%                           making a supervised template: 1) label_column argument
%                           denoting the classification that will be both for UMAP
%                           supervision and MLP prediction; 2) the save_template_file
%                           argument. To provide non default arguments for MLP change
%                           the mlp_train argument value to a struct with a type char
%                           field indicating TensorFlow or fitcnet PLUS fields for
%                           arguments described in the Train function of mlp/Mlp.m
%                           file (if using fitcnet) or in the Train function of
%                           mlp/MlpPython.m file (if using TensorFlow).
%
%                           If you choose TensorFlow then the Train function checks
%                           for the installation of Python and TensorFlow
%                           dependencies.  Tensorflow needs Python version 3.7 to
%                           3.9. If Python is missing you are guided to the website
%                           to download the one we test with.  If TensorFlow or other
%                           packages are missing we try to automatically install
%                           them.  To alter how we use TensorFlow you can look at the
%                           open source Python files in the mlp folder. By default we
%                           invoke TensorFlow out of process with the system command.
%                           If you are using MATLAB r2019b or later we invoke the
%                           predict service faster in process using MATLAB's py
%                           rotuines.  To do this you must call pyenv (only once)
%                           immediately after MATLAB starts to identify where the
%                           Python with TensorFlow is located.  For example on a Mac
%                           the command might be something like
%                               pyenv('Version', '/usr/local/bin/python3.7');
%                           We display the exact command needed the first time the 
%                           function MlpPython.Predict runs without having this done.  
%                           The function always continues with the out of process 
%                           calling until the pyenv command is called correctly 
%                           immediately after starting MATLAB.
%                           Default is empty/blank.
%
%   'mlp_confidence'        number >= 0 and <=1 denoting a % confidence threshold 
%   (v4.0)                  run_umap uses this argument in scenarios where the 
%                           template_file argument denotes a template that was
%                           previously created with the train_mlp argument as
%                           discussed above. run_umap loads the MLP neural network
%                           and predicts supervisory labels using it instead of the
%                           normal matching method for supervised templates that are
%                           discussed previously for the argument match_supervisors.
%                           For MLP classifications with confidence below
%                           mlp_confidence run_umap uses the classification found
%                           using the normal matching method for supervising
%                           templates. Example 32 below illustrates usage of this
%                           argument.
%                           Default is 0.
%
%   'job_folder'            Denotes a folder to watch for new files containing
%   (v4.0)                  run_umap jobs to run.  This allows programs outside of 
%                           MATLAB to invoke run_umap. The watching is efficient
%                           using the services of java.io.file package as illustrated
%                           in the source file FolderWatch.java. To stop the
%                           watching, close the pipeline window. with the title
%                           prefix JobWatch.
%                           Default is empty/blank.
%           
%  'confusion_chart'        true/false to produce MATLAB's confusion chart. If true 
%   (v4.0)                  then the argument 'label_column' must provide a prior 
%                           classification AND the UMAP reduction must be either
%                           basic or a supervised template.
%                           Default is empty/blank.
%
%   'all_prediction_figs'   true/false to set prediction view arguments to true 
%   (v4.0)                  except for those that are explicitly argued 
%                           as false.  These arguments are: match_histogram_figs,
%                           confusion_chart, match_predictions, and 
%                           false_positive_negative_plot.
%                           For example if I argue (...
%                           'all_prediction_figs', true, 'confusion_chart',
%                           false) then all prediction figurfes except the 
%                           confusion chart will be produced.
%                           Default is false
%
%  'match_webpage_file'     true or name of a file to put web content into.  This 
%   (v4.0)                  content is all match related figures figures argued for:
%                           Hi-D match table, histograms, confusion chart,
%                           predictions table and false positive negative plot then
%                           these items are added. If this argument is true the
%                           webpage location is computed if the csv_file_or_data is a
%                           file. If you want run_umap to clear the file before
%                           accumulating then argue match_webpage_reset == true.
%                           Default is empty/blank.
%
%  'match_webpage_reset'    true/false.  True clears the prior webpage file before 
%   (v4.0)                  accumulating.  Otherwise the file keeps growing.   
%                           Default is false.
%
%   EXAMPLES 
%   Note these examples assume your current MATLAB folder is where run_umap.m is
%   stored.
%
%   1.  Download the example CSV files and run sample10k.csv.
%
%       run_umap
%
%   2.  Reduce parameters for sample30k.csv and save as UMAP template (ut).
%
%       run_umap sample30k.csv save_template_file utBalbc2D.mat;
%
%   3.  Reduce parameters for sample130k.csv using prior template.
%
%       run_umap sample130k.csv template_file utBalbc2D.mat;
%
%       Run again with fast_approximation
%       run_umap sample130k.csv template_file utBalbc2D.mat fast_approximation true;
%
%   4.  Reduce parameters for sampleBalbcLabeled55k.csv supervised by labels produced 
%       by EPP and save as a UMAP supervised template (UST), EPP is a conservative
%       clustering technique described at
%       https://www.nature.com/articles/s42003-019-0467-6. EPP stands for "Exhaustive
%       Projection Pursuit".  By clustering exhaustively in 2 dimension pairs, this
%       technique steers more carefully away from the curse of dimensionality than
%       does UMAP or t-SNE.
%
%       To use EPP you can download AutoGate from CytoGenie.org which contains
%       tutorials on using EPP.
%
%       run_umap sampleBalbcLabeled55k.csv label_column end label_file balbcLabels.properties save_template_file ustBalbc2D.mat;
%
%   5.  Reduce parameters for sampleRag148k.csv using template that is supervised by 
%       EPP.  This takes the clusters created by EPP on the lymphocytes of a normal
%       mouse strain (BALB/c) and applies them via a template to a mouse strain (RAG)
%       that has neither T cells nor B cells.
%
%       [reduction, umap, clusterIds, extras]=run_umap('sampleRag148k.csv', 'template_file', 'ustBalbc2D.mat', 'cluster_detail', 'medium', 'match_supervisors', 0);
%
%       Now in console display supervision results with this command
%
%       disp(UmapUtil.DescribeResults(reduction, umap, clusterIds, extras, 'Example 5 completed!'));    
%
%   6.  Reduce parameters for sample30k.csv and return & plot cluster identifiers 
%       using density-based merging described at
%       http://cgworkspace.cytogenie.org/GetDown2/demo/dbm.pdf.
%
%       [~,~, clusterIds]=run_umap('sample30k.csv', 'cluster_output', 'graphic', 'cluster_detail', 'medium');
%
%   7.  Repeat sample 2 but for 3D output and return cluster identifiers and save the
%       result as a 3D template.
%
%       [~, ~, clusterIds]=run_umap('sample30k.csv', 'n_components', 3, 'save_template_file', 'utBalbc3D.mat');
%
%   8.  Repeat example 3 in 3D.
%
%       run_umap sample130k.csv template_file utBalbc3D.mat;
%
%       Run again with fast_approximation
%       run_umap sample130k.csv template_file utBalbc3D.mat fast_approximation true;
%
%   9.  Reduce parameters and save template for sampleRagLabeled60k.csv using labels 
%       produced by an expert biologist drawing manual gate sequences on lymphocyte
%       data taken from a RAG mouse strain which has no T cells or B cells.
%
%       run_umap sampleRagLabeled60k.csv label_column 11 label_file ragLabels.properties save_template_file ustRag2D.mat;
%
%   10. Reduce parameters for lymphocyte data taken from a BALB/c mouse strain using 
%       template created in example 9.  This takes the clusters created on the
%       lymphocyte data of a knockout mouse strain (RAG) with no B cells or T cells
%       and applies them to a normal mouse strain (BALB/c) which has both cell types.
%       This illustrates logic to prevent false positives for data not seen when
%       training/creating supervised templates.  Choose to re-supervise to see
%       effect.
%
%       run_umap sample30k.csv template_file ustRag2D.mat;
%
%   11. Repeat example 10 but use joined_transform.  Currently 'method'=='Java' is 
%       the only support for this.
%
%        run_umap sample30k.csv template_file ustRag2D.mat method Java joined_transform true;
%
%   12. Run example 5 again showing training/test set plot pair, QF tree and QF 
%       dissimilarity plots.
%
%       run_umap sampleRag148k.csv template_file ustBalbc2D.mat qf_tree true qf_dissimilarity true see_training true);
%
%   13. Compare our implementation to the original Python implementation by repeating 
%       example 2 as follows.
%       
%       run_umap sample30k.csv
%       run_umap sample30k.csv python true;
%
%   14. Compare our implementation with MEX method to the original Python 
%       implementation by repeating example 4 as follows.
%
%       run_umap sampleBalbcLabeled55k.csv label_column 11 label_file balbcLabels.properties save_template_file ustBalbc2D.mat;
%       run_umap sampleBalbcLabeled55k.csv python true label_column 11 label_file balbcLabels.properties save_template_file pyUstBalbc2D.mat;
%
%   15. Compare our implementation to the original Python implementation by repeating
%       example 5 as follows.
%
%       run_umap sampleRag148k.csv template_file ustBalbc2D.mat;
%       run_umap sampleRag148k.csv template_file pyUstBalbc2D.mat;
%
%   16. Combining aspects of previous examples, this one creates a UMAP supervised 
%       template for 3D output, then applies this template to a different example.
%       The final run_umap returns all possible outputs, including the extras
%       argument that contains supervisor matching labels (1 per row of input data
%       matrix) and qf_tree and qf_dissimilarity arguments. The main plot shows
%       training/test set plot pair.
%
%       run_umap sampleBalbcLabeled55k.csv label_column 11 label_file balbcLabels.properties qf_tree true n_components 3 save_template_file ustBalbc3D.mat;
%       [reduction, umap, clusterIdentifiers,extras]=run_umap('sample10k.csv', 'template_file', 'ustBalbc3D.mat', 'qf_tree', true, 'qf_dissimilarity', true, 'see_training', true, 'cluster_output', 'graphic');
%
%   17. Reduce parameters for sampleBalbCLabeled12k.csv using template that is 
%       supervised by EPP and invoke match_scenarios 4 to analyze dissimilarity
%       between subsets defined by umap supervised templates and the previously
%       classified subsets in the test set sample. Also set match_predictions true to
%       inspect similarity of prior classifications to true+, false+ and false-
%       results.
%
%       run_umap sampleBalbcLabeled12k.csv template_file ustBalbc2D.mat label_column end label_file balbcLabels.properties match_scenarios 4 see_training true match_predictions true;
%
%   18. Same as example 17 but add a false positive/negative plot.
%
%        run_umap sampleBalbcLabeled12k.csv template_file ustBalbc2D.mat label_column end label_file balbcLabels.properties match_scenarios 4 see_training true false_positive_negative_plot true;
%
%   19. Do false positive/negative test on 3 different types of match_supervisors:      
%           1) clusters with 'most high' cluster_detail
%           3) nearest neighbors in reduced space (2D)
%           4) nearest neighbors in non-reduced space (29D)
%       The samples are from the panoramic data set used by the Nolan Lab at Stanford
%       University.  This is often referenced in gate automation publications for
%       flow cytometry including FlowCAP. Leland McInnes references this in his UMAP
%       publication:
%           https://www.nature.com/articles/nbt.4314
%       Nikolay Samusik references it in:
%           https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4896314/
%       The first time you run this example you must be online to get the data from
%       http://cgworkspace.cytogenie.org.
%
%       run_umap s1_samusikImported_29D.csv label_column end label_file s1_29D.properties n_components 3 save_template_file ust_s1_samusikImported_29D_15nn_3D.mat;
%       run_umap('s2_samusikImported_29D.csv', 'template_file', 'ust_s1_samusikImported_29D_15nn_3D.mat', 'label_column', 'end', 'label_file', 's2_samusikImported_29D.properties', 'match_scenarios', [1 2 4],  'match_histogram_figs', false, 'see_training', true, 'false_positive_negative_plot', true, 'match_supervisors', [3 1 4]);
%
%   20. Check the speed difference processing 87,772 rows by 29 columns with UMAP.m 
%       version 2.0. No acceleration as with previous versions:
%
%       run_umap cytofExample.csv nn_descent_min_rows 0;
%               
%       WITH NN descent acceleration:
%   
%       run_umap cytofExample.csv;
%
%       WITH NN descent acceleration and fast_approximation:
%   
%       run_umap cytofExample.csv fast_approximation true;
%

%   21. Determine if metric=minkowski and P=1.8 produces better false
%       positive/negative results than those reported in example 19. Setting P=1.8
%       causes Minkowski space to combine aspects of cityblock and Euclidean space.
%
%       run_umap('s1_samusikImported_29D.csv', 'metric', 'minkowski', 'P', 1.8, 'label_column', 'end', 'label_file', 's1_29D.properties', 'n_components', 3, 'save_template_file', 'ust_s1_samusikImported_minkowski_1.80_29D_15nn_3D.mat');
%       run_umap s2_samusikImported_29D.csv template_file ust_s1_samusikImported_minkowski_1.80_29D_15nn_3D.mat label_column end label_file s2_samusikImported_29D.properties match_scenarios 4 see_training true match_table_fig false match_histogram_figs false false_positive_negative_plot true match_supervisors 3;
%
%   22. Check the speed difference processing 600,483 rows by 29 columns with our 
%       version 2.1.01's scaling of parallelism up to the # of logical CPU cores
%       assigned to MATLAB. First, WITH version 2.1.01 acceleration:
%   
%       run_umap cytekExample.csv;
%
%       WITHOUT acceleration as with version 2.0:
%   
%       run_umap cytekExample.csv sgd_tasks 1 nn_descent_tasks 1;
%
%   23. Observe the "prediction strength/quality" of the data islands formed by basic
%       unsupervised reductions when matched to prior classifications labels made
%       manually by expert biologists to define lymphocyte cell subpopulations.
%
%       The command pattern is this
%       [~,~,~,extras]=run_umap(arg1, 'label_column','end', 'match_scenarios', 3, 'cluster_detail', 'medium','match_predictions', true, 'fast_approximation', true);
%       
%       Set argument 1 to the following files to see UMAP's power when compared to
%       the manual classifications of separate published data sets.
%
%       arg1 File name                      Publication URL
%       ----------                          ---------------
%       arg1='eliverLabeled.csv'            https://www.pnas.org/content/107/6/2568
%       arg1='omip044Labeled400k.csv'       https://onlinelibrary.wiley.com/doi/10.1002/cyto.a.23331
%       arg1='genentechLabeled100k.csv'     https://www.frontiersin.org/articles/10.3389/fimmu.2019.01194/full
%       arg1='maeckerLabeled.csv'           https://www.sciencedirect.com/science/article/pii/S0022175917304908?via%3Dihub
%       arg1='omip69Labeled200k.csv'        https://onlinelibrary.wiley.com/doi/full/10.1002/cyto.a.24213
%       
%       
%       After any/all of the above runs complete this command extracts the true+,
%       false+, and false- summary shown on the PredictionAdjudicator window at the
%       top left.
%       [testSetWins, nPredicted, means]=extras.getPredictionSummary;
%       fprintf(['Similarity true+/false+/false-:  %3.1f%%/%3.1f%%/%3.1f%%; Test set wins %d/%d!\n'],  means(1), means(2), means(3), testSetWins, nPredicted);
%       
%       This command extracts the match summary shown at the top left of the
%       mass+distance similarity window.
%       [similarity, overlap, missingTrainingSubsets, newTestSubsets]=extras.getMatchSummary;
%       fprintf('%d training subsets not found, %4.1f%% overlap, %4.1f%% similar, %d new test subsets\n',  missingTrainingSubsets, overlap, similarity, newTestSubsets);
%       
%       And these commands pull out details of subset match records for the top 2
%       matches, the worst 2 matches and no matches.  See the function getMatches in
%       UMAP_extra_results.m for how to programmatically retrieve match information.
%       records4best2=extras.getMatches(2); String.PrintStruct(records4best2, 'Top 2 matches!');
%       records4worst2=extras.getMatches(-2); String.PrintStruct(records4worst2, 'Worst 2 matches!');
%       records4NoMatch=extras.getMatches(0); String.PrintStruct(records4NoMatch, 'No match!');
%
%       Run again with fast_approximation and observe accuracy of match
%       run_umap sampleBalbcLabeled55k.csv fast_approximation true label_column end label_file balbcLabels.properties match_scenarios 4 cluster_detail high roi_table 2; 
%
%   24. Review the similarity between the clusters of a basic UMAP reduction for 
%       lymphocyte data and the cell type labels on that same data predefined by
%       expert biologists who used 35 biomarkers and published their result as a
%       standard protocol in
%       https://onlinelibrary.wiley.com/doi/full/10.1002/cyto.a.24213.
%
%       run_umap s1_omip69_35D.csv label_column end label_file s1_omip69_35D.properties match_scenarios 4 cluster_detail medium;
%
%   25. Use the same data and definition labels of the prior example to create a 
%       supervised template to act as a training set for other comparable samples.
%       In order for the training set to be fast, compress the training set from data
%       by about 60% without allowing any cell subset fall below a frequency of 50
%       cells (x 35 measurements).
%
%       run_umap('s1_omip69_35D.csv', 'label_column', 'end', 'label_file', 's1_omip69_35D.properties', 'compress', [125000 500], 'save_template_file', 'ust_s1_omip69_35D.mat');
%     
%   26. This examples takes example 4's data to illustrate the 'synthesize' argument 
%       to create a synthetic data set. In this case we want to get 24000 rows out of
%       the 55,000 that appear similar and make sure that no single class (defined by
%       label) falls below 30 rows.
%
%       run_umap('sampleBalbcLabeled55k.csv', 'label_column', 11, 'label_file', 'balbcLabels.properties', 'synthesize', [24000 30]);
%
%   27. This example is like example 24 but with a larger data set and higher 
%       similarity between the "data islands" formed by basic UMAP reduction and the
%       subsets predefined by expert biologists. This is a standard flow cytometry
%       protocol published in 2018 at
%       https://onlinelibrary.wiley.com/doi/10.1002/cyto.a.23331. Basic UMAP finds
%       ALL of the publication's cell subsets when comparing with BOTH F-measure
%       overlap or mass + distance similarity.  Using fast_approximation the loss of
%       accuracy for both is 3%. UMAP's reduction for 1.8+ million rows and 27
%       columns takes ~20 seconds on our 6-core MacBook with fast approximation and
%       17 minutes without. Comparing takes ~2 minutes.
%
%       Run with fast approximation true or false using 
%       run_umap omip044Labeled400k.csv fast_approximation true label_column end label_file omip044Labeled.properties match_scenarios 4 cluster_detail medium;
%
%   28.  This example illustrates using EPP (our lab's unsupervised Hi-D data 
%        classifier) to create data subset labels for supervising UMAP's formation of
%        "data islands".  EPP takes a more conservative approach to the curse of
%        dimensionality than does UMAP's topology and set theory.  The curse of
%        dimensionality is described more fully at:
%        https://www.nature.com/articles/nri.2017.150?proof=t
%        For more details on EPP's curse-sensitive approach see
%        https://onedrive.live.com/?authkey=%21ALyGEpe8AqP2sMQ&cid=FFEEA79AC523CD46&id=FFEEA79AC523CD46%21209192&parId=FFEEA79AC523CD46%21204865&o=OneUp
%
%        epp=run_epp('eliverLabeled.csv', 'label_column', 'end',  'cytometer',  'conventional', 'min_branch_size', 150, 'umap_option', 6, 'cluster_detail', 'medium', 'match_predictions', true);
%
%        These post reduction commands provide a summary true+, false+ and false-
%        prediction strength for both the EPP classification and the UMAP
%        classification from basic reduction to data islands with clusters.
%
%       [testSetWins, nPredicted, means]=epp.getPredictionSummary;
%       fprintf(['EPP prediction of prior classification:   similarity true+/false+/false-:  %3.1f%%/%3.1f%%/%3.1f%%; test set wins %d/%d!\n'],  means(1), means(2), means(3), testSetWins, nPredicted);
%       [testSetWins, nPredicted, means]=epp.getUmapPredictionSummary;
%       fprintf(['UMAP prediction of prior classification:  similarity true+/false+/false-:  %3.1f%%/%3.1f%%/%3.1f%%; Test set wins %d/%d!\n'],  means(1), means(2), means(3), testSetWins, nPredicted);
%
%   29.  Using the published data set described in example 19 test compare the 
%        classification accuracy done by UST reduction to 2D for all match scenarios
%        versus basic UMAP reduced.
%        
%        run_umap s1_samusikImported_29D.csv label_column end label_file s1_29D.properties save_template_file ust_s1_samusikImported_29D_15nn_2D.mat;
%        [~,~,~,ustExtras]=run_umap('s2_samusikImported_29D.csv', 'template_file', 'ust_s1_samusikImported_29D_15nn_2D.mat', 'label_column', 'end', 'match_scenarios', 1:4,  'see_training', true);
%        [~,~,~,ubExtras]=run_umap('s2_samusikImported_29D.csv', 'label_column', 'end', 'label_file', 's2_samusikImported_29D.properties', 'match_scenarios', [3 4]);
%
%        These post reduction commands display the average match goodness of UST and
%        basic UMAP for each of this example's match_scenarios 1, 2 and 4.  To
%        understand a simple programmatic access to these results see the
%        showAllMatchScenarios function in the file UMAP_extra_results.m.
%
%        ustExtras.showAllMatchScenarios('Match results for UMAP supervised template reduction');
%        ubExtras.showAllMatchScenarios('Match results for UMAP basic reduction');
%
%   30.  Reduce parameters for sample30k.csv while adjusting the 'min_dist' and 
%        'spread' parameters to change the output plot. Reducing 'min_dist' moves
%        embedded points closer to nearest neighbours, while increasing 'spread'
%        moves other pairs of points farther apart, and vice-versa.
%
%        run_umap sample30k.csv min_dist 0.5 spread 5;
%        run_umap sample30k.csv min_dist 0.05 spread 0.5;
%
%   31.  Create supervised template (as in example 4) adding an MLP neural network 
%        based on Python TensorFlow.  This template can classify any compatible data
%        set.  The sample in use here is a mouse BALB/c strain.
%
%        run_umap balbc4FmoLabeled.csv label_column end save_template_file ustBalbcFmoMlp.mat mlp_train tensorflow;
%
%   32.  Classify a separate sample using the MLP enriched supervised template 
%        created in example 31.
%
%        run_umap balbcFmoLabeled.csv label_column end template_file ustBalbcMlpPy.mat cluster_detail medium match_supervisors 0 mlp_confidence 0 see_training true;
%
%   33.  Repeat example 31 except use MATLAB's fitcnet introduced in release r2021a. 
%        Use all default arguments which have been effective for flow cytometry data.
%        By default a maximum of 1000 iterations is done but 20% of the data is held
%        out for validation that prevents over-fitting and accelerates.  To gain
%        slight more predictive power change the mlp_train argument from fitcnet to
%        struct('type', 'fitcnet', 'validate', false)
%
%        run_umap balbc4FmoLabeled.csv label_column end save_template_file ustBalbcFmoMlp.mat mlp_train fitcnet;
%
%   34.  Now classify a completely separate sample using example 33's MLP enriched
%        supervised template.  Set confusion_chart to true. Invoke the detailed
%        predictions processing.  Accumulate visual results in an html file
%        ~/Documents/run_umap/MlpResults/example34.html
%
%        run_umap balbcFmoLabeled.csv label_column end match_scenarios 4 template_file ustBalbcFmoMlp.mat mlp_confidence 0 confusion_chart true see_training true match_supervisors 0 match_predictions true match_webpage_file ~/Documents/run_umap/MlpResults/example34.html false_positive_negative_plot true; 
%
%        If you want to work programmatically with the match results from example 34
%        then reinvoke it with return values for both run_umap &
%        UmapUtil.DescribeResults.  argout 3 is all run_umap's match tables in an
%        array of structures.  The field tableData is a MATLAB table containing the
%        data presented in the Hi-D Match visual table.
%
%        [reduction, umap, clusterIds, extras]=run_umap('balbcFmoLabeled.csv', 'label_column', 'end', 'template_file', 'ustBalbcFmoMlp.mat', 'mlp_confidence',  0, 'confusion_chart', true, 'see_training', true, 'match_supervisors', 0); 
%        [statement, results, tables]=UmapUtil.DescribeResults(reduction,
%        umap, clusterIds, extras, 34);
%        disp(tables{1}.tableData);
%        disp(statement);
%
%        To run this example as a background job run this command:
%        run_umap job_folder ~/Documents/run_umap/backgroundJobs
%
%        After this starts then copy the run_umap command into a file named
%        ~/Documents/run_umap/backgroundJobs/example34.job and save it.
%
%       Documentation for more detailed use of this and other run_umap functionality
%       can be found in
%       https://drive.google.com/drive/folders/1obEEUIj4nC-Lj77YB2esGr-jwZRM3C7w?usp=sharing
%
%   35.  Repeat example 33 except use a data file with the 12D that a RAG mouse
%        strain sample file has.
%
%        run_umap balbc4RagLabeled.csv label_column end save_template_file ustBalbc4RagMlp.mat mlp_train fitcnet;
%
%   36.  Now classify a completely different type sample using example 35's MLP
%        enriched supervised template.  Set all_prediction_figs to true. This sample
%        is from a RAG strain mouse which lacks T cells or B cells.
%
%        run_umap ragLabeled.csv label_column end template_file ustBalbc4RagMlp.mat mlp_confidence 0 all_prediction_figs true see_training true match_supervisors 0; 
%
%   37.  Repeat example 33 except use a data file that has the 10D data set that a
%        C57 mouse strain sample.
%
%        run_umap balbc4C57Labeled.csv label_column end save_template_file ustBalbc4C57Mlp.mat mlp_train fitcnet;
%
%   38.  Now classify the C57 sample using example 37's MLP enriched supervised
%        template.  Set confusion_chart to true.
%
%        run_umap c57Labeled.csv label_column end template_file ustBalbc4C57Mlp.mat mlp_confidence 0 confusion_chart true see_training true match_supervisors 0; 
%
%
%   NOTE that you can do supervised UMAP and templates with n_components
%       ...but we have not had time to update the 3D GUI to show where the supervised
%       regions fall.
%
%   ALGORITHMS
%   UMAP is the invention of Leland McInnes, John Healy and James Melville at
%   Canada's Tutte Institute for Mathematics and Computing.  See
%   https://umap-learn.readthedocs.io/en/latest/.
%
%   AUTHORSHIP
%   Primary Developer+math lead: Connor Meehan <connor.gw.meehan@gmail.com>
%   Secondary Developer:  Stephen Meehan <swmeehan@stanford.edu> 
%   Bioinformatics Lead:  Wayne Moore <wmoore@stanford.edu>
%   Provided by the Herzenberg Lab at Stanford University. 
%   License: BSD 3 clause
%
%   REQUIRED PATHS
%   This distribution has 3 folders: umap, util, and epp. You must set paths to these
%   folders plus the Java inside of umap.jar. Assume you have put these 2 folders
%   under /Users/Stephen. The commands that MATLAB requires would be:
%
%   addpath /Users/Stephen/umap
%   addpath /Users/Stephen/util
%   addpath /Users/Stephen/epp
%   javaaddpath('/Users/Stephen/util/suh.jar');
%
%
%
%   IMPLEMENTATION NOTES
%   This is a total rewrite of the original Python implementation from Leland
%   McInnes, John Healy and James Melville. This implementation is written in MATLAB,
%   C++, and Java. The source is distributed openly on MathWorks File Exchange. This
%   implementation follows a very similar structure to the Python implementation, and
%   many of the function descriptions are nearly identical. Leland McInnes has looked
%   over it and considered it "a fairly faithful direct translation of the original
%   Python code (except for the nearest neighbor search)". If you have UMAP's Python
%   implementation you can check how faithful and fast this re-implementation is by
%   using the argument python=true. When python is false and method is MEX we observe
%   superior performance on our Mac and Windows laptops in most cases. For the cases
%   of template-guided and supervised parameter reduction the performance is
%   significantly faster than the Python implementation regardless of data size.
%
%   If you wish to have a simple user GUI to run these UMAP features, download
%   AutoGate at CytoGenie.org.
%   
%
mf=mfilename('fullpath');
this=SuhRunUmap(nargout, varargin{:});
reduction=this.reduced_data;
umap=this.umap;
clusterIdentifiers=this.clusterIdentifiers;
extras=this.extras;
end
