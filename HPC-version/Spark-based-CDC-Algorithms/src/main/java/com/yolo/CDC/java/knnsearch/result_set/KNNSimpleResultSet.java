package com.yolo.CDC.java.knnsearch.result_set;

import java.util.ArrayList;


public class KNNSimpleResultSet implements ResultSet {
	int capacity;
	int count;
	double worstDistance;
	ArrayList<DistanceIndex> distanceIndexArray;

	public KNNSimpleResultSet (int capacity) {
		this.capacity = capacity;

		distanceIndexArray = new ArrayList<DistanceIndex>();
		for (int i = 0; i < capacity; i++) {
			distanceIndexArray.add (new DistanceIndex (Double.MAX_VALUE, -1));
		}

		clear();
	}

	public void clear () {
		worstDistance = Double.MAX_VALUE;
		DistanceIndex di = new DistanceIndex (worstDistance, -1);
		distanceIndexArray.set (capacity-1, di);
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
	public double worstDistance() {
		return worstDistance;
	}

	@Override
	public void addPoint (double distance, int index) {
		if (distance >= worstDistance)
			return;

		if (count < capacity) {
			count++;
		}

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
		
        worstDistance = distanceIndexArray.get(capacity-1).distance;
	}

	public void copy (double[] distances, int[] indices, int numElements) {
		int n = Math.min (count, numElements);
		for (int i = 0; i < n; i++) {
			distances[i] = distanceIndexArray.get(i).distance;
			indices[i] = distanceIndexArray.get(i).index;
		}
	}
}