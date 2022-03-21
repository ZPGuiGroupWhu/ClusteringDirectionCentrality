package com.yolo.CDC.java.knnsearch.index;

import com.yolo.CDC.java.knnsearch.metric.Metric;
import com.yolo.CDC.java.knnsearch.result_set.ResultSet;

import java.util.ArrayList;

public class IndexLSH extends IndexBase {
	ArrayList<LSHTable> tables;
	int tablesNumber;
	int keySize;

	// How far should we look for neighbors in multi-probe LSH.
	int multiProbeLevel;

	// The XOR masks to apply to a key to get the neighboring buckets.
	ArrayList<Integer> xorMasks;

	public static class BuildParams extends BuildParamsBase {
		public int tablesNumber;
		public int keySize;
		public int multiProbeLevel;

		public BuildParams() {
			this.tablesNumber = 12;
			this.keySize = 8;
			this.multiProbeLevel = 2;
		}

		public BuildParams(int tablesNumber, int keySize, int multiProbeLevel) {
			this.tablesNumber = tablesNumber;
			this.keySize = keySize;
			this.multiProbeLevel = multiProbeLevel;
		}
	}

	public static class SearchParams extends SearchParamsBase {
	}

	public IndexLSH(Metric metric, int[][] data, BuildParams buildParams) {
		super(metric, data);

		this.tablesNumber = buildParams.tablesNumber;
		this.keySize = buildParams.keySize;
		this.multiProbeLevel = buildParams.multiProbeLevel;

		xorMasks = new ArrayList<Integer>();
		fillXorMask(0, keySize, multiProbeLevel, xorMasks);

		this.type = IndexFLANN.LSH;
	}

	private void fillXorMask(int key, int lowestIndex, int level,
			ArrayList<Integer> xorMasks) {
		xorMasks.add(key);
		if (level == 0)
			return;

		for (int index = lowestIndex - 1; index >= 0; index--) {
			int newKey = key | (1 << index);
			fillXorMask(newKey, index, level - 1, xorMasks);
		}
	}

	@Override
	protected void buildIndexImpl() {
		tables = new ArrayList<LSHTable>();
		for (int i = 0; i < tablesNumber; i++) {
			LSHTable table = new LSHTable(numberOfDimensions, keySize);
			table.add(dataBinary);
			tables.add(table);
		}
	}

	@Override
	protected void findNeighbors(ResultSet resultSet, double[] query,
			SearchParamsBase searchParams) {
	}

	@Override
	protected void findNeighbor(ResultSet resultSet, double[] query) {

	}

	@Override
	protected void findNeighbors(ResultSet resultSet, int[] query,
			SearchParamsBase searchParams) {
		for (LSHTable table : tables) {
			int key = table.getKey(query);
			for (int mask : xorMasks) {
				int newKey = key ^ mask;
				Bucket bucket = table.getBucket(newKey);
				if (bucket == null)
					continue;

				for (int pointID : bucket.points) {
					// The Hammin distance is an int but for now, for
					// simplicity,
					// all distance functions return double.
					double hammingDistance = metric.distance(query,
							dataBinary[pointID]);
					resultSet.addPoint(hammingDistance, pointID);
				}
			}
		}
	}

	@Override
	public int usedMemory() {
		// TODO Auto-generated method stub
		return 0;
	}

}
