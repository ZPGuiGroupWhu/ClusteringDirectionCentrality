package com.yolo.CDC.java.knnsearch.index;

import com.yolo.CDC.java.knnsearch.exception.ExceptionFLANN;
import com.yolo.CDC.java.knnsearch.metric.Metric;
import com.yolo.CDC.java.knnsearch.result_set.ResultSet;

public class IndexLinear extends IndexBase {

	public IndexLinear(Metric metric, double[][] data, BuildParams buildParams) {
		super(metric, data);
		this.type = IndexFLANN.LINEAR;
	}

	public static class BuildParams extends BuildParamsBase {
	}

	public static class SearchParams extends SearchParamsBase {
	}

	@Override
	protected void buildIndexImpl() {

	}

	@Override
	protected void findNeighbors(ResultSet resultSet, double[] query,
			SearchParamsBase searchParams) {
		int size = data.length;
		for (int i = 0; i < size; i++) {
			double distance = metric.distance(data[i], query);
			resultSet.addPoint(distance, i);
		}
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
}
