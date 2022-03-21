package com.yolo.CDC.java.knnsearch.metric;

import com.yolo.CDC.java.knnsearch.exception.ExceptionFLANN;

public class MetricHamming implements Metric {
	@Override
	public double distance(double[] a, double[] b) {
		throw new ExceptionFLANN("Unsupported types");
	}

	@Override
	public double distance(double a, double b) {
		throw new ExceptionFLANN("Unsupported types");
	}

	@Override
	public int distance(int[] a, int[] b) {
		int result = 0;
		for (int i = 0; i < a.length; i++) {
			result += distance(a[i], b[i]);
		}
		return result;
	}

	@Override
	public int distance(int a, int b) {
		return Integer.bitCount(a ^ b);
	}
}
