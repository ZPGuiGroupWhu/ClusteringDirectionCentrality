package com.yolo.CDC.java.knnsearch.util;

import com.yolo.CDC.java.knnsearch.metric.Metric;

import java.util.ArrayList;


public class BoundingBox {
	// Min and max values for each dimension.
	public ArrayList<Double> min, max;

	public BoundingBox () {
		min = new ArrayList<Double>();
		max = new ArrayList<Double>();
	}

	public BoundingBox (BoundingBox other) {
		this();
		int size = other.min.size();
		for (int i = 0; i < size; i++) {
			min.add (other.min.get(i));
			max.add (other.max.get(i));
		}
	}

	public double getMin (int dimension) {
		return min.get(dimension);
	}

	public double getMax (int dimension) {
		return max.get(dimension);
	}

	public void setMin (int dimension, double value) {
		min.set (dimension, value);
	}

	public void setMax (int dimension, double value) {
		max.set (dimension, value);
	}

	public void add (double minValue, double maxValue) {
		min.add (minValue);
		max.add (maxValue);
	}

	public int getMaxSpanDimension () {
		double maxSpan = max.get(0) - min.get(0);
		int numberOfDimensions = max.size();
		int maxSpanDimension = 0;
		for (int i = 1; i < numberOfDimensions; i++) {
			double span = max.get(i) - min.get(i);
			if (span > maxSpan) {
				maxSpan = span;
				maxSpanDimension = i;
			}
		}
		return maxSpanDimension;
	}

	public void fitToData (double[][] data) {
		min.clear();
		max.clear();

		int numberOfObjects = data.length;
		int numberOfDimensions = data[0].length;

		for (int i = 0; i < numberOfDimensions; i++) {
			add (data[0][i], data[0][i]);
		}

		for (int k = 1; k < numberOfObjects; k++) {
			for (int i = 0; i < numberOfDimensions; i++) {
				double objectKInDimensionI = data[k][i];
				if (objectKInDimensionI < min.get(i))
					min.set (i, objectKInDimensionI);
				if (objectKInDimensionI > max.get(i))
					max.set (i, objectKInDimensionI);
			}
		}
	}
	
	public double getBoxPointDistancesPerDimension (double[] point, ArrayList<Double> distances, Metric metric) {
		double distsq = 0.0;
		int numberOfDimensions = min.size();

		for (int i = 0; i < numberOfDimensions; i++) {
			if (point[i] < min.get(i)) {
				double dist = metric.distance(point[i], min.get(i));
				distances.set (i, dist);
				distsq += dist;
			}
			if (point[i] > max.get(i)) {
				double dist = metric.distance(point[i], max.get(i));
				distances.set (i, dist);
				distsq += dist;
			}
		}

		return distsq;
	}
}