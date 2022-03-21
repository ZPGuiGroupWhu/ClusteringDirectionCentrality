package com.yolo.CDC.java.knnsearch.result_set;

import java.util.ArrayList;
import java.util.Collections;


public class KNNRadiusResultSet implements ResultSet {
	double radius;
	int capacity;
	int count;
	double worstDistance;
	ArrayList<DistanceIndex> distanceIndexArray;

	public KNNRadiusResultSet (double radius, int capacity) {
		this.radius = radius;
		this.capacity = capacity;

		distanceIndexArray = new ArrayList<DistanceIndex>();
		for (int i = 0; i < capacity; i++) {
			distanceIndexArray.add (new DistanceIndex (Double.MAX_VALUE, -1));
		}

		clear ();
	}

	public void clear() {
		worstDistance = radius;
		count = 0;
	}

	public int size () {
		return count;
	}

	@Override
	public boolean full() {
		return count == capacity;
	}

	@Override
	public void addPoint(double distance, int index) {
		if (distance >= worstDistance)
			return;

		if (count < capacity)
			count++;

		int i;
		for (i = count-1; i > 0; i--) {
			if (distanceIndexArray.get(i-1).distance > distance ||
				(distanceIndexArray.get(i-1).distance == distance && distanceIndexArray.get(i-1).index > index)) {
				distanceIndexArray.set (i, distanceIndexArray.get (i-1));
			} else {
				break;
			}
		}
		distanceIndexArray.set (i, new DistanceIndex (distance, index));

		if (full()) {
			worstDistance = distanceIndexArray.get(capacity-1).distance;
		}
	}

	public void copy (double[] distances, int[] indices, int numElements, boolean sorted) {
		if (sorted) {
			Collections.sort (distanceIndexArray);
		} else {
			// TODO: Not clear what is going on.
		}

		int n = Math.min (size(), numElements);
		for (int i = 0; i < n; i++) {
			distances[i] = distanceIndexArray.get(i).distance;
			indices[i] = distanceIndexArray.get(i).index;
		}
	}

	public void copy (double[] distances, int[] indices, int numElements) {
		copy (distances, indices, numElements, true);
	}

	@Override
	public double worstDistance() {
		return worstDistance;
	}
}