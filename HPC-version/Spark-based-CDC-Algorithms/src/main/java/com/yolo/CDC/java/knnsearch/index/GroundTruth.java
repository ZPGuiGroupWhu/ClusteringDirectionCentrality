package com.yolo.CDC.java.knnsearch.index;

import com.yolo.CDC.java.knnsearch.metric.Metric;
import com.yolo.CDC.java.knnsearch.util.Utils;

public class GroundTruth {

	private static void findNearest(double[][] dataset, double[] query, int[] matches,
									int nn, int skip, Metric metric) {
		int n = nn + skip;

		Integer[] match = new Integer[n];
		Double[] dists = new Double[n];
		dists[0] = metric.distance(dataset[0], query);
		match[0] = 0;
		int dcnt = 1;

		for (int i = 1; i < dataset.length; i++) {
			double tmp = metric.distance(dataset[i], query);

			if (dcnt < n) {
				match[dcnt] = i;
				dists[dcnt++] = tmp;
			} else if (tmp < dists[dcnt - 1]) {
				dists[dcnt - 1] = tmp;
				match[dcnt - 1] = i;
			}

			int j = dcnt - 1;
			while (j >= 1 && dists[j] < dists[j - 1]) {
				Utils.swapArray(dists, j, j - 1);
				Utils.swapArray(match, j, j - 1);
				j--;
			}
		}

		for (int i = 0; i < nn; i++) {
			matches[i] = match[i + skip];
		}
	}

	public static void computeGroundTruth(double[][] dataset, double[][] testset,
			int[][] matches, int skip, Metric metric) {
		for (int i = 0; i < testset.length; i++) {
			findNearest(dataset, testset[i], matches[i], matches[0].length,
					skip, metric);
		}
	}
}
