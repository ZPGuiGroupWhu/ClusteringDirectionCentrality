package com.yolo.CDC.java.knnsearch.metric;

import com.yolo.CDC.java.knnsearch.exception.ExceptionFLANN;

import java.io.Serializable;

/**
 * Euclidean squared distance.
 */
public class MetricEuclideanSquared implements Metric, Serializable {
	@Override
	public double distance(double[] a, double[] b) {
		double result = 0.0;
		for (int i = 0; i < a.length; i++) {
			result += distance(a[i], b[i]);
		}
		return result;
	}

	@Override
	public double distance(double a, double b) {
		double diff = a - b;
		return diff * diff;
	}

	@Override
	public int distance(int[] a, int[] b) {
		throw new ExceptionFLANN("Unsupported types");
	}

	@Override
	public int distance(int a, int b) {
		throw new ExceptionFLANN("Unsupported types");
	}
}