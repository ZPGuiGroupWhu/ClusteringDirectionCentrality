package com.yolo.CDC.java.knnsearch.index;

import com.yolo.CDC.java.knnsearch.exception.ExceptionFLANN;
import com.yolo.CDC.java.knnsearch.metric.Metric;
import com.yolo.CDC.java.knnsearch.result_set.ResultSet;
import com.yolo.CDC.java.knnsearch.util.Utils;
import org.apache.commons.lang3.time.StopWatch;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.Map;

import static com.yolo.CDC.java.knnsearch.index.GroundTruth.computeGroundTruth;

public class IndexAutotuned extends IndexBase {
	public static class BuildParams extends BuildParamsBase {
		public float targetPrecision;
		public float buildWeight;
		public float memoryWeight;
		public float sampleFraction;

		public BuildParams() {
			this.targetPrecision = 0.8f;
			this.buildWeight = 0.01f;
			this.memoryWeight = 0.0f;
			this.sampleFraction = 0.1f;
		}

		public BuildParams(float targetPrecision, float buildWeight,
				float memoryWeight, float sampleFraction) {
			this.targetPrecision = targetPrecision;
			this.buildWeight = buildWeight;
			this.memoryWeight = memoryWeight;
			this.sampleFraction = sampleFraction;
		}
	}

	public static class SearchParams extends SearchParamsBase {
	}

	private class CostData {
		float searchTimeCost;
		float buildTimeCost;
		float memoryCost;
		float totalCost;
		Map<String, Object> params=new HashMap<>();

	}

	float targetPrecision;
	float buildWeight;
	float memoryWeight;
	float sampleFraction;

	float speedup;

	IndexBase bestIndex;

	double[][] sampledData;
	double[][] testData;

	Map<String, Object> bestBuildParams;
	SearchParamsBase bestSearchParams;

	int[][] gtMatches;

	public IndexAutotuned(Metric metric, double[][] data,
			BuildParams buildParams) {
		super(metric, data);

		this.targetPrecision = buildParams.targetPrecision;
		this.buildWeight = buildParams.buildWeight;
		this.memoryWeight = buildParams.memoryWeight;
		this.sampleFraction = buildParams.sampleFraction;

		this.speedup = 0;
		this.bestIndex = null;

		this.type = IndexFLANN.AUTOTUNED;
	}

	@Override
	public void knnSearch(double[][] queries, int[][] indices,
			double[][] distances, SearchParamsBase searchParams) {
		if (searchParams.checks == -2) { // FLANN_CHECKS_AUTOTUNED = -2
			bestSearchParams.maxNeighbors = searchParams.maxNeighbors;
			bestIndex.knnSearch(queries, indices, distances, bestSearchParams);
		} else {
			bestIndex.knnSearch(queries, indices, distances, searchParams);
		}
	}

	@Override
	public int radiusSearch(double[][] queries, int[][] indices,
			double[][] distances, SearchParamsBase searchParams) {
		if (searchParams.checks == -2) { // FLANN_CHECKS_AUTOTUNED = -2
			bestSearchParams.radius = searchParams.radius;
			return bestIndex.radiusSearch(queries, indices, distances,
					bestSearchParams);
		} else {
			return bestIndex.radiusSearch(queries, indices, distances,
					searchParams);
		}
	}

	@Override
	protected void findNeighbors(ResultSet resultSet, double[] query,
			SearchParamsBase searchParams) {
		throw new ExceptionFLANN("Not supposed to enter this code.");
	}

	@Override
	protected void findNeighbors(ResultSet resultSet, int[] query,
			SearchParamsBase searchParams) {
		throw new ExceptionFLANN("Unsupported types");
	}

	@Override
	protected void findNeighbor(ResultSet resultSet, double[] query) {

	}

	@Override
	public int usedMemory() {
		return 0;
	}

	private void evaluateKMeans(CostData cost) {
		StopWatch timer = new StopWatch();
		int[] checks = new int[1];
		int nn = 1;

		int iterations = (Integer) cost.params.get("iterations");
		int branching = (Integer) cost.params.get("branching");
		CenterChooser.Algorithm centersInit = (CenterChooser.Algorithm) cost.params
				.get("centersInit");
		System.out.printf(
				"KMeansTree using params: max_iterations=%d, branching=%d\n",
				iterations, branching);

		IndexKMeans.BuildParams buildParams = new IndexKMeans.BuildParams();
		buildParams.branching = branching;
		buildParams.iterations = iterations;
		buildParams.centersInit = centersInit;
		IndexKMeans kmeans = new IndexKMeans(metric, sampledData, buildParams);

		// Measure index build time.
		timer.start();
		kmeans.buildIndex();
		timer.stop();
		float buildTime = timer.getTime() / 1000.0f;

		// Measure search time.
		IndexTesting testing = new IndexTesting();
		float searchTime = testing.testIndexPrecision(kmeans, sampledData,
				testData, gtMatches, targetPrecision, checks, metric, nn, 1);

		int sampledDataRows = sampledData.length;
		int sampledDataCols = sampledData[0].length;
		float datasetMemory = sampledDataRows * sampledDataCols * 4;
		cost.memoryCost = (kmeans.usedMemory() + datasetMemory) / datasetMemory;
		cost.searchTimeCost = searchTime;
		cost.buildTimeCost = buildTime;
	}

	private void evaluateKDTree(CostData cost) {
		StopWatch timer = new StopWatch();
		int[] checks = new int[1];
		int nn = 1;

		int trees = (Integer) cost.params.get("trees");
		IndexKDTree.BuildParams buildParams = new IndexKDTree.BuildParams();
		buildParams.trees = trees;
		IndexKDTree kdtree = new IndexKDTree(metric, sampledData, buildParams);

		// Measure index build time.
		timer.start();
		kdtree.buildIndex();
		timer.stop();
		float buildTime = timer.getTime() / 1000.0f;

		// Measure search time.
		IndexTesting testing = new IndexTesting();
		float searchTime = testing.testIndexPrecision(kdtree, sampledData,
				testData, gtMatches, targetPrecision, checks, metric, nn, 1);

		int sampledDataRows = sampledData.length;
		int sampledDataCols = sampledData[0].length;
		float datasetMemory = sampledDataRows * sampledDataCols * 4;
		cost.memoryCost = (kdtree.usedMemory() + datasetMemory) / datasetMemory;
		cost.searchTimeCost = searchTime;
		cost.buildTimeCost = buildTime;
	}

	private void optimizeKDTree(ArrayList<CostData> costs) {
		System.out.println("KD-TREE, Step 1: Exploring parameter space");

		// Explore KD-Tree parameters space using the parameters below.
		int testTrees[] = { 1, 4, 8, 16, 32 };

		// Evaluate KD-Tree for all parameter combinations.
		for (int i = 0; i < testTrees.length; i++) {
			CostData cost = new CostData();
			cost.params.put("trees", testTrees[i]);
			evaluateKDTree(cost);
			costs.add(cost);
		}
	}

	private void optimizeKMeans(ArrayList<CostData> costs) {
		System.out.println("KMEANS, Step 1: Exploring parameter space");

		// Explore K-Means parameters space using combinations of parameters.
		int[] maxIterations = { 1, 5, 10, 15 };
		int[] branchingFactors = { 16, 32, 64, 128, 256 };

		int kMeansParamSpaceSize = maxIterations.length
				* branchingFactors.length;
		// Evaluate K-Means for all parameters combinations.
		for (int i = 0; i < maxIterations.length; i++) {
			for (int j = 0; j < branchingFactors.length; j++) {
				CostData cost = new CostData();

				cost.params.put("centersInit",
						CenterChooser.Algorithm.FLANN_CENTERS_RANDOM);
				cost.params.put("iterations", maxIterations[i]);
				cost.params.put("branching", branchingFactors[j]);

				evaluateKMeans(cost);
				costs.add(cost);
			}
		}
	}

	private void estimateBuildParams() {
		ArrayList<CostData> costs = new ArrayList<CostData>();

		int sampleSize = (int) (sampleFraction * data.length);
		int testSampleSize = Math.min(sampleSize / 10, 1000);

		if (testSampleSize < 10) {
			// return LinearIndexParams();
		}

		// We use a fraction of the original dataset to speedup the autotune
		// algorithm.
		sampledData = Utils.randomSample(data, sampleSize, false);
		testData = Utils.randomSample(sampledData, testSampleSize, true);

		// We compute the ground truth using linear search.
		System.out.println("Computing ground truth...");
		gtMatches = new int[testData.length][1];

//		StopWatch timer = new StopWatch();
		int repeats = 0;
		long startTime = System.currentTimeMillis();
		long endTime = 0;
		while ((endTime-startTime)/ 1000.0f < 0.2f) {
			repeats++;
//			timer.reset();
//			timer.start();
			computeGroundTruth(sampledData, testData, gtMatches, 0, metric);
//			timer.stop();
//			time=timer.getTime();
			endTime=System.currentTimeMillis();
//			System.out.println(time);
		}

		CostData linearCost = new CostData();
//		linearCost.searchTimeCost = timer.getTime() / 1000.0f / repeats;
		linearCost.searchTimeCost = (endTime-startTime)/ 1000.0f / repeats;
		linearCost.buildTimeCost = 0;
		linearCost.memoryCost = 0;
		costs.add(linearCost);

		// Start parameter autotune process.
		System.out.println("Autotuning parameters...");

		optimizeKMeans(costs);
		optimizeKDTree(costs);

		float bestTimeCost = costs.get(0).buildTimeCost * buildWeight
				+ costs.get(0).searchTimeCost;
		for (int i = 0; i < costs.size(); i++) {
			float timeCost = costs.get(i).buildTimeCost * buildWeight
					+ costs.get(i).searchTimeCost;
			if (timeCost < bestTimeCost) {
				bestTimeCost = timeCost;
			}
		}

		bestBuildParams = costs.get(0).params;
		if (bestTimeCost > 0) {
			float bestCost = (costs.get(0).buildTimeCost * buildWeight + costs
					.get(0).searchTimeCost) / bestTimeCost;
			for (int i = 0; i < costs.size(); i++) {
				float crtCost = (costs.get(i).buildTimeCost * buildWeight + costs
						.get(i).searchTimeCost)
						/ bestTimeCost
						+ memoryWeight
						* costs.get(i).memoryCost;
				if (crtCost < bestCost) {
					bestCost = crtCost;
					bestBuildParams = costs.get(i).params;
				}
			}
		}
	}

	private float estimateSearchParams(SearchParamsBase searchParams) {
		int nn = 1;
		int SAMPLE_COUNT = 1000;

		assert (bestIndex != null);

		float speedup = 0;

		int samples = Math.min(data.length / 10, SAMPLE_COUNT);

		if (samples > 0) {
			double[][] testDataset = Utils.randomSample(data, samples, false);
			int[][] gtMatches = new int[testDataset.length][1];
			StopWatch timer = new StopWatch();
			int repeats = 0;
			timer.reset();
			while (timer.getTime() / 1000.0f < 0.2) {
				repeats++;
				timer.start();
				// computeGroundTruth(data, testDataset, gtMatches, 1, metric);
				timer.stop();
			}
			float linear = timer.getTime() / 1000.0f / repeats;
			int[] checks = new int[1];
			float searchTime;
			float cbIndex;
			if (bestIndex.getType() == IndexFLANN.KMEANS) {
				IndexKMeans kmeans = (IndexKMeans) bestIndex;
				float bestSearchTime = -1;
				float bestCbIndex = -1;
				int bestChecks = -1;
				for (cbIndex = 0; cbIndex < 1.1f; cbIndex += 0.2f) {
					kmeans.setCbIndex(cbIndex);
					IndexTesting testing = new IndexTesting();
					searchTime = testing.testIndexPrecision(kmeans, data,
							testDataset, gtMatches, targetPrecision, checks,
							metric, nn, 1);
					if (searchTime < bestSearchTime || bestSearchTime == -1) {
						bestSearchTime = searchTime;
						bestCbIndex = cbIndex;
						bestChecks = checks[0];
					}
				}
				searchTime = bestSearchTime;
				cbIndex = bestCbIndex;
				checks[0] = bestChecks;
				kmeans.setCbIndex(cbIndex);
				bestSearchParams.cbIndex = cbIndex;
			} else {
				IndexTesting testing = new IndexTesting();
				searchTime = testing.testIndexPrecision(bestIndex, data,
						testDataset, gtMatches, targetPrecision, checks,
						metric, nn, 1);
			}

			searchParams.checks = checks[0];
			speedup = linear / searchTime;
		}

		return speedup;
	}

	@Override
	protected void buildIndexImpl() {
		estimateBuildParams();

		IndexFLANN indexType = (IndexFLANN) bestBuildParams
				.get("algorithm");
		// bestIndex = createIndexByType(indexType, data, bestBuildParams,
		// metric);
		bestIndex.buildIndex();

		speedup = estimateSearchParams(bestSearchParams);

		bestBuildParams.put("searchParams", bestSearchParams);
		bestBuildParams.put("speedup", speedup);
	}

	private IndexBase createIndexByType(IndexFLANN indexType, double[][] data,
			BuildParamsBase buildParams, Metric metric) {
		IndexBase index;
		switch (indexType) {
		case LINEAR:
			break;
		case KDTREE_SINGLE:
			break;
		case KDTREE:
			break;
		case KMEANS:
			break;
		case LSH:
			break;
		case HIERARCHICAL:
			break;
		case AUTOTUNED:
			break;
		case SAVED:
			break;
		case COMPOSITE:
			break;
		}
		return null;
	}

}