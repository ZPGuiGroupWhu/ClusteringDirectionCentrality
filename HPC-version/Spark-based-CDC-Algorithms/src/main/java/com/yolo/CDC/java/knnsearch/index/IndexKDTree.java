package com.yolo.CDC.java.knnsearch.index;

import com.yolo.CDC.java.knnsearch.metric.Metric;
import com.yolo.CDC.java.knnsearch.result_set.ResultSet;
import com.yolo.CDC.java.knnsearch.util.Utils;

import java.util.ArrayList;
import java.util.BitSet;
import java.util.Collections;
import java.util.PriorityQueue;

public class IndexKDTree extends IndexBase {
	ArrayList<Node> treeRootNodes;
	int trees;

	int SAMPLE_MEAN = 100;
	int RAND_DIM = 5;

	public static class BuildParams extends BuildParamsBase {
		public int trees;

		public BuildParams() {
			this.trees = 4;
		}

		public BuildParams(int trees) {
			this.trees = trees;
		}
	}

	public static class SearchParams extends SearchParamsBase {
	}

	private class Node {
		public Node child1, child2;
		public double[] point;
		public int cutDimension;
		public double cutDimensionValue;
	}

	public IndexKDTree(Metric metric, double[][] data,
			BuildParamsBase buildParams) {
		super(metric, data);

		this.trees = ((BuildParams) buildParams).trees;
		treeRootNodes = new ArrayList<Node>();

		objectsIndices = new ArrayList<Integer>();
		for (int i = 0; i < numberOfObjects; i++) {
			objectsIndices.add(i);
		}

		this.type = IndexFLANN.KDTREE;
	}

	@Override
	protected void buildIndexImpl() {
		// Construct the randomized trees.
		for (int i = 0; i < trees; i++) {
			// Randomize the order of objects to allow for unbiased sampling.
			Collections.shuffle(objectsIndices);
			treeRootNodes.add(divideTree(0, numberOfObjects));
		}
	}

	private Node divideTree(int start, int count) {
		Node node = new Node();

		// If too few objects remain, then make this a leaf node.
		if (count == 1) {
			node.child1 = node.child2 = null;
			int index = objectsIndices.get(start);
			node.cutDimension = index; // Use cutDimension to store the point
										// index.
			node.point = data[index];
		} else {
			meanSplitResult out = new meanSplitResult();
			meanSplit(start, count, out);

			node.cutDimension = out.cutDimension;
			node.cutDimensionValue = out.cutDimensionValue;

			int cutObjectIndex = out.cutObjectIndex;
			node.child1 = divideTree(start, cutObjectIndex);
			node.child2 = divideTree(start + cutObjectIndex, count
					- cutObjectIndex);
		}

		return node;
	}

	private class meanSplitResult {
		public int cutObjectIndex;
		public int cutDimension;
		public double cutDimensionValue;
	}

	/**
	 * Choose which feature to use in order to subdivide this set of vectors.
	 * Make a random choice among those with the highest variance, and use its
	 * mean as the threshold value.
	 */
	private void meanSplit(int start, int count, meanSplitResult out) {
		double[] mean = new double[numberOfDimensions];
		double[] var = new double[numberOfDimensions];

		for (int i = 0; i < numberOfDimensions; i++) {
			mean[i] = var[i] = 0.0;
		}

		// Estimate mean values by sampling only the first
		// SAMPLE_MEAN values.
		int cnt = Math.min(SAMPLE_MEAN + 1, count);
		for (int j = 0; j < cnt; j++) {
			double[] v = data[objectsIndices.get(start + j)];
			for (int k = 0; k < numberOfDimensions; k++) {
				mean[k] += v[k];
			}
		}
		double divFactor = 1.0 / cnt;
		for (int k = 0; k < numberOfDimensions; k++) {
			mean[k] *= divFactor;
		}

		// Compute variances (no need to divide by count).
		for (int j = 0; j < cnt; j++) {
			double[] v = data[objectsIndices.get(start + j)];
			for (int k = 0; k < numberOfDimensions; k++) {
				double dist = v[k] - mean[k];
				var[k] += dist * dist;
			}
		}

		// Select one of the highest variance indices at random.
		out.cutDimension = selectDivision(var);
		out.cutDimensionValue = mean[out.cutDimension];

		// Hyperplane partitioning.
		int[] lim1Andlim2Wrapper = new int[2];
		planeSplit(start, count, out.cutDimension, out.cutDimensionValue,
				lim1Andlim2Wrapper);
		int lim1 = lim1Andlim2Wrapper[0];
		int lim2 = lim1Andlim2Wrapper[1];

		// Choose the object through which the hyperplane goes through.
		int countHalf = count / 2;
		if (lim1 > countHalf) {
			out.cutObjectIndex = lim1;
		} else if (lim2 < countHalf) {
			out.cutObjectIndex = lim2;
		} else {
			out.cutObjectIndex = countHalf;
		}

		// If either list is empty, it means that all remaining features
		// are identical. Split in the middle to maintain a balanced tree.
		if (lim1 == count || lim2 == 0) {
			out.cutObjectIndex = countHalf;
		}
	}

	// Select the top RAND_DIM largest values from v and return
	// the index of one of these at random.
	public int selectDivision(double[] v) {
		int num = 0;
		int[] topind = new int[RAND_DIM];

		for (int i = 0; i < numberOfDimensions; i++) {
			if (num < RAND_DIM || v[i] > v[topind[num - 1]]) {
				if (num < RAND_DIM) {
					topind[num++] = i;
				} else {
					topind[num - 1] = i;
				}

				// Bubble the right-most value to left.
				int j = num - 1;
				while (j > 0 && v[topind[j]] > v[topind[j - 1]]) {
					// Swap.
					int temp = topind[j];
					topind[j] = topind[j - 1];
					topind[j - 1] = temp;
					j--;
				}
			}
		}

		int rnd = Utils.genRandomNumberInRange(0, num - 1);
		return topind[rnd];
	}

	@Override
	protected void findNeighbors(ResultSet resultSet, double[] query,
			SearchParamsBase searchParams) {
		int maxChecks = searchParams.checks;
		float epsError = 1 + searchParams.eps;

		if (maxChecks == -1) { // unlimited number of checks
			getExactNeighbors(resultSet, query, epsError);
		} else {
			getNeighbors(resultSet, query, maxChecks, epsError);
		}
	}

	/**
	 * This is an exact nearest neighbor search that performs a full traversal
	 * of the tree.
	 */
	private void getExactNeighbors(ResultSet resultSet, double[] query,
			float epsError) {
		if (trees > 1) {
			System.out
					.println("It doesn't make any sense to use more than one tree for exact search");
			return;
		}

		if (trees > 0) {
			searchLevelExact(resultSet, query, treeRootNodes.get(0), 0.0,
					epsError);
		}
	}

	/**
	 * Performs approximate nearest-neighbor search. The search is approximate
	 * because the tree traversal is stopped after a given number of descends in
	 * the tree.
	 */
	private void getNeighbors(ResultSet resultSet, double[] query,
			int maxChecks, float epsError) {
		Branch<Node> branch;
		int[] checkCount = new int[1];
		checkCount[0] = 0;

		PriorityQueue<Branch<Node>> heap = new PriorityQueue<Branch<Node>>(
				numberOfObjects);
		BitSet checked = new BitSet(numberOfObjects);

		// Search once through each tree.
		for (int i = 0; i < trees; i++) {
			searchLevel(resultSet, query, treeRootNodes.get(i), 0, checkCount,
					maxChecks, epsError, heap, checked);
		}

		// Keep searching other branches from heap until finished.
		while ((branch = heap.poll()) != null
				&& (checkCount[0] < maxChecks || !resultSet.full())) {
			searchLevel(resultSet, query, branch.node, branch.mindist,
					checkCount, maxChecks, epsError, heap, checked);
		}
	}

	private void searchLevelExact(ResultSet resultSet, double[] query,
			Node node, double mindist, float epsError) {
		// If this is a leaf node.
		if (node.child1 == null && node.child2 == null) {
			int index = node.cutDimension;
			double dist = metric.distance(node.point, query);
			resultSet.addPoint(dist, index);
			return;
		}

		// Which child branch should be taken first?
		double val = query[node.cutDimension];
		double diff = val - node.cutDimensionValue;
		Node bestChild = diff < 0 ? node.child1 : node.child2;
		Node otherChild = diff < 0 ? node.child2 : node.child1;

		double newDistSq = mindist
				+ metric.distance(val, node.cutDimensionValue);

		// Call recursively to search next level down.
		searchLevelExact(resultSet, query, bestChild, mindist, epsError);

		if (mindist * epsError <= resultSet.worstDistance()) {
			searchLevelExact(resultSet, query, otherChild, newDistSq, epsError);
		}
	}

	/**
	 * Search starting from a given node of the tree. Based on any mismatches at
	 * higher levels, all exemplars below this level must have a distance of at
	 * least "mindistsq".
	 */
	private void searchLevel(ResultSet resultSet, double[] query, Node node,
			double mindist, int[] checkCount, int maxChecks, float epsError,
			PriorityQueue<Branch<Node>> heap, BitSet checked) {
		// Ignore branch.
		if (resultSet.worstDistance() < mindist) {
			return;
		}

		// If this is a leaf node.
		if (node.child1 == null && node.child2 == null) {
			int index = node.cutDimension;

			// Do not check the same node more than once when
			// searching multiple trees.
			if (checked.get(index)
					|| (checkCount[0] >= maxChecks && resultSet.full())) {
				return;
			}
			checked.set(index);
			checkCount[0]++;
			double dist = metric.distance(node.point, query);
			resultSet.addPoint(dist, index);
			return;
		}

		// Which child branch should be taken first?
		double val = query[node.cutDimension];
		double diff = val - node.cutDimensionValue;
		Node bestChild = diff < 0 ? node.child1 : node.child2;
		Node otherChild = diff < 0 ? node.child2 : node.child1;

		double newDistSq = mindist
				+ metric.distance(val, node.cutDimensionValue);
		if (newDistSq * epsError < resultSet.worstDistance()
				|| !resultSet.full()) {
			heap.add(new Branch<Node>(otherChild, newDistSq));
		}

		// Call recursively to search next level down.
		searchLevel(resultSet, query, bestChild, mindist, checkCount,
				maxChecks, epsError, heap, checked);
	}

	@Override
	protected void findNeighbors(ResultSet resultSet, int[] query,
			SearchParamsBase searchParams) {
	}

	@Override
	protected void findNeighbor(ResultSet resultSet, double[] query) {

	}

	@Override
	public int usedMemory() {
		// TODO Auto-generated method stub
		return 0;
	}
}