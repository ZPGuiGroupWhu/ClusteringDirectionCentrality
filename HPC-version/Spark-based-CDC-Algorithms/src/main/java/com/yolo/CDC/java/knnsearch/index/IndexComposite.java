package com.yolo.CDC.java.knnsearch.index;

import com.yolo.CDC.java.knnsearch.exception.ExceptionFLANN;
import com.yolo.CDC.java.knnsearch.index.CenterChooser.Algorithm;
import com.yolo.CDC.java.knnsearch.metric.Metric;
import com.yolo.CDC.java.knnsearch.result_set.ResultSet;

public class IndexComposite extends IndexBase {
	IndexKMeans kmeans;
	IndexKDTree kdtree;

	public IndexComposite(Metric metric, double[][] data,
			BuildParamsBase buildParams) {
		super(metric, data);

		kdtree = new IndexKDTree(metric, data, buildParams);
		kmeans = new IndexKMeans(metric, data, buildParams);
	}

	public static class BuildParams extends BuildParamsBase {
		public int trees;
		public int branching;
		public int iterations;
		public CenterChooser.Algorithm centersInit;
		public float cbIndex;

		public BuildParams(int trees, int branching, int iterations,
				Algorithm centersInit, float cbIndex) {
			this.trees = trees;
			this.branching = branching;
			this.iterations = iterations;
			this.centersInit = centersInit;
			this.cbIndex = cbIndex;
		}

		public BuildParams() {
			this.trees = 4;
			this.branching = 32;
			this.iterations = 11;
			this.centersInit = CenterChooser.Algorithm.FLANN_CENTERS_RANDOM;
			this.cbIndex = 0.2f;
		}
	}

	public static class SearchParams extends SearchParamsBase {
	}

	@Override
	protected void buildIndexImpl() {
		kmeans.buildIndex();
		kdtree.buildIndex();
	}

	@Override
	protected void findNeighbors(ResultSet resultSet, double[] query,
			SearchParamsBase searchParams) {
		kmeans.findNeighbors(resultSet, query, searchParams);
		kdtree.findNeighbors(resultSet, query, searchParams);
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
		return kmeans.usedMemory() + kdtree.usedMemory();
	}
}