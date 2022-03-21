package com.yolo.CDC.java.knnsearch.index;

import com.yolo.CDC.java.knnsearch.metric.Metric;
import com.yolo.CDC.java.knnsearch.result_set.*;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.Collections;

/**
 * Base class for all index structures.
 */
public abstract class IndexBase implements Serializable {
	public enum IndexFLANN {
		LINEAR, KDTREE_SINGLE, KDTREE, KMEANS, LSH, HIERARCHICAL, AUTOTUNED, SAVED, COMPOSITE
	}

	protected IndexFLANN type;

	public IndexFLANN getType() {
		return this.type;
	}

	protected Metric metric;
	protected double[][] data;
	protected int[][] dataBinary; // binary feature vectors
	public ArrayList<Integer> objectsIndices;

	public int numberOfObjects;
	public int numberOfDimensions;

	public IndexBase(Metric metric, double[][] data) {
		this.metric = metric;
		setDataset(data);
	}

	public IndexBase(Metric metric, int[][] dataBinary) {
		this.metric = metric;
		setDataset(dataBinary);
	}

	private void setDataset(double[][] data) {
		if (data.length == 0) {
			return;
		}

		numberOfObjects = data.length;
		numberOfDimensions = data[0].length;
//		System.out.println("numberOfObjects:"+numberOfObjects);
//		System.out.println("numberOfDimensions:"+numberOfDimensions);

		// Copy data.
		this.data = new double[numberOfObjects][numberOfDimensions];
		for (int i = 0; i < numberOfObjects; i++) {
			for (int j = 0; j < numberOfDimensions; j++) {
				this.data[i][j] = data[i][j];
			}
		}
	}

	private void setDataset(int[][] dataBinary) {
		if (dataBinary.length == 0) {
			return;
		}

		numberOfObjects = dataBinary.length;
		numberOfDimensions = dataBinary[0].length;

		// Copy data.
		this.dataBinary = new int[numberOfObjects][numberOfDimensions];
		for (int i = 0; i < numberOfObjects; i++) {
			for (int j = 0; j < numberOfDimensions; j++) {
				this.dataBinary[i][j] = dataBinary[i][j];
			}
		}
	}

	/**
	 * Hyperplane partitioning. Subdivide the list of points by a plane
	 * perpendicular to the axis corresponding to 'cutDimension' at value
	 * 'cutValue'. On return:
	 * data[objectsIndices.get(start..start+lim1-1)][cutDimension] < cutValue
	 * data[objectsIndices.get(start+lim1..start+lim2-1)][cutDimension] ==
	 * cutValue data[objectsIndices.get(start+lim2..start + count -
	 * 1)][cutDimension] > cutValue
	 */
	protected void planeSplit(int start, int count, int cutDimension,
			double cutValue, int[] lim1Andlim2Wrapper) {
		int lim1, lim2;
		int left = start;
		int right = start + count - 1;
		for (;;) {
			while (left <= right
					&& data[objectsIndices.get(left)][cutDimension] < cutValue) {
				left++;
			}
			while (left <= right
					&& data[objectsIndices.get(right)][cutDimension] >= cutValue) {
				right--;
			}
			if (left > right) {
				break;
			}
			Collections.swap(objectsIndices, left, right);
			left++;
			right--;
		}

		lim1 = left;
		right = start + count - 1;
		for (;;) {
			while (left <= right
					&& data[objectsIndices.get(left)][cutDimension] <= cutValue) {
				left++;
			}
			while (left <= right
					&& data[objectsIndices.get(right)][cutDimension] > cutValue) {
				right--;
			}
			if (left > right) {
				break;
			}
			Collections.swap(objectsIndices, left, right);
			left++;
			right--;
		}
		lim2 = left;

		// Convert 'lim1' and 'lim2' from absolute index values in
		// 'objectsIndices',
		// to relative to 'start'.
		lim1 -= start;
		lim2 -= start;

		lim1Andlim2Wrapper[0] = lim1;
		lim1Andlim2Wrapper[1] = lim2;
	}

	public void knnSearch(double[][] queries, int[][] indices,
			double[][] distances, SearchParamsBase searchParams) {
		int k = searchParams.maxNeighbors;
		KNNSimpleResultSet resultSet = new KNNSimpleResultSet(k);
		for (int i = 0; i < queries.length; i++) {
			resultSet.clear();
			findNeighbors(resultSet, queries[i], searchParams);
			int n = Math.min(resultSet.size(), k);
			resultSet.copy(distances[i], indices[i], n);
		}
	}
	public void knnSearch(double[] queries, int[] indices,
						  double[] distances, SearchParamsBase searchParams) {
		int k = searchParams.maxNeighbors;
		KNNSimpleResultSet resultSet = new KNNSimpleResultSet(k);
		findNeighbors(resultSet, queries, searchParams);
		int n = Math.min(resultSet.size(), k);
		resultSet.copy(distances, indices, n);
	}
	public void knnSearch(double[] queries, int[] indices,
						  double[] distances) {
		int k = 1;
		KNNSimpleResultSet resultSet = new KNNSimpleResultSet(k);
		findNeighbor(resultSet, queries);
		int n = Math.min(resultSet.size(), k);
		resultSet.copy(distances, indices, n);
	}
	public int radiusSearch(double[][] queries, int[][] indices,
			double[][] distances, SearchParamsBase searchParams) {
		double radius = searchParams.radius;
		int maxNeighbors = searchParams.maxNeighbors;
		int outputColumns = indices[0].length;
		if (maxNeighbors < 0) {
			maxNeighbors = outputColumns;
		} else {
			maxNeighbors = Math.min(maxNeighbors, outputColumns);
		}

		// Only count the neighbors, without returning them.
		int count = 0;
		if (maxNeighbors == 0) {
			CountRadiusResultSet resultSet = new CountRadiusResultSet(radius);
			for (int i = 0; i < queries.length; i++) {
				resultSet.clear();
				findNeighbors(resultSet, queries[i], searchParams);
				count += resultSet.size();
			}
		} else {
			// Unlimited result-set.
			if (searchParams.maxNeighbors < 0
					&& numberOfObjects <= outputColumns) {
				RadiusResultSet resultSet = new RadiusResultSet(radius);
				for (int i = 0; i < queries.length; i++) {
					resultSet.clear();
					findNeighbors(resultSet, queries[i], searchParams);
					int n = resultSet.size();
					count += n;
					n = Math.min(n, outputColumns);
					resultSet.copy(distances[i], indices[i], n);

					// Mark the position after the last element as unused.
					if (n < outputColumns) {
						distances[i][n] = Double.MAX_VALUE;
						indices[i][n] = -1;
					}
				}
				// Limited result-set.
			} else {
				KNNRadiusResultSet resultSet = new KNNRadiusResultSet(radius,
						maxNeighbors);
				for (int i = 0; i < queries.length; i++) {
					resultSet.clear();
					findNeighbors(resultSet, queries[i], searchParams);
					int n = resultSet.size();
					count += n;
					n = Math.min(n, maxNeighbors);
					resultSet.copy(distances[i], indices[i], n);

					// Mark the position after the last element as unused.
					if (n < outputColumns) {
						distances[i][n] = Double.MAX_VALUE;
						indices[i][n] = -1;
					}
				}
			}
		}

		return count;
	}

	public void knnSearch(int[][] queries, int[][] indices,
			double[][] distances, SearchParamsBase searchParams) {
		int k = searchParams.maxNeighbors;
		KNNSimpleResultSet resultSet = new KNNSimpleResultSet(k);
		for (int i = 0; i < queries.length; i++) {
			resultSet.clear();
			findNeighbors(resultSet, queries[i], searchParams);
			int n = Math.min(resultSet.size(), k);
			resultSet.copy(distances[i], indices[i], n);
		}
	}

	public int radiusSearch(int[][] queries, int[][] indices,
			double[][] distances, SearchParamsBase searchParams) {
		double radius = searchParams.radius;
		int maxNeighbors = searchParams.maxNeighbors;
		int outputColumns = indices[0].length;
		if (maxNeighbors < 0)
			maxNeighbors = outputColumns;
		else
			maxNeighbors = Math.min(maxNeighbors, outputColumns);

		// Only count the neighbors, without returning them.
		int count = 0;
		if (maxNeighbors == 0) {
			CountRadiusResultSet resultSet = new CountRadiusResultSet(radius);
			for (int i = 0; i < queries.length; i++) {
				resultSet.clear();
				findNeighbors(resultSet, queries[i], searchParams);
				count += resultSet.size();
			}
		} else {
			// Unlimited result-set.
			if (searchParams.maxNeighbors < 0
					&& numberOfObjects <= outputColumns) {
				RadiusResultSet resultSet = new RadiusResultSet(radius);
				for (int i = 0; i < queries.length; i++) {
					resultSet.clear();
					findNeighbors(resultSet, queries[i], searchParams);
					int n = resultSet.size();
					count += n;
					n = Math.min(n, outputColumns);
					resultSet.copy(distances[i], indices[i], n);

					// Mark the position after the last element as unused.
					if (n < outputColumns) {
						distances[i][n] = Double.MAX_VALUE;
						indices[i][n] = -1;
					}
				}
				// Limited result-set.
			} else {
				KNNRadiusResultSet resultSet = new KNNRadiusResultSet(radius,
						maxNeighbors);
				for (int i = 0; i < queries.length; i++) {
					resultSet.clear();
					findNeighbors(resultSet, queries[i], searchParams);
					int n = resultSet.size();
					count += n;
					n = Math.min(n, maxNeighbors);
					resultSet.copy(distances[i], indices[i], n);

					// Mark the position after the last element as unused.
					if (n < outputColumns) {
						distances[i][n] = Double.MAX_VALUE;
						indices[i][n] = -1;
					}
				}
			}
		}

		return count;
	}

	public void buildIndex() {
		buildIndexImpl();
	}

	protected abstract void buildIndexImpl();

	protected abstract void findNeighbor(ResultSet resultSet, double[] query);

	protected abstract void findNeighbors(ResultSet resultSet, double[] query,
			SearchParamsBase searchParams);

	protected abstract void findNeighbors(ResultSet resultSet, int[] query,
			SearchParamsBase searchParams);

	public abstract int usedMemory();
}
