package com.yolo.CDC.java.knnsearch.result_set;



public class DistanceIndex implements Comparable<DistanceIndex> {
	double distance;
	int index;

	public DistanceIndex (double distance, int index) {
		this.distance = distance;
		this.index = index;
	}

	@Override
	public int compareTo (DistanceIndex other) {
		if (distance < other.distance)
			return -1;
		else if (distance > other.distance)
			return 1;
		else 
			return 0;
	}
}