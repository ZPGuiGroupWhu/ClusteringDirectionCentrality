package com.yolo.CDC.java.knnsearch.result_set;

import java.util.ArrayList;
import java.util.Collections;


/**
 * 
 */
public class RadiusResultSet implements ResultSet {
	double radius;
	ArrayList<DistanceIndex> distanceIndexArray;

	public RadiusResultSet (double radius) {
		this.radius = radius;
		// Reserve some memory to decrease the number of reallocations.
		distanceIndexArray.ensureCapacity (1024);
		clear ();
	}

	public void clear () {
		distanceIndexArray.clear ();
	}

	public int size () {
		return distanceIndexArray.size ();
	}

	@Override
	public boolean full() {
		return true;
	}

	@Override
	public void addPoint (double distance, int index) {
		if (distance < worstDistance())
			distanceIndexArray.add (new DistanceIndex (distance, index));
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
	public double worstDistance () {
		return radius;
	}
}