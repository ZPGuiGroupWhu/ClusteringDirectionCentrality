package com.yolo.CDC.java.knnsearch.index;

import java.io.Serializable;

public class SearchParamsBase implements Serializable {
	// How many leaves to visit (-1 for unlimited).
	public int checks;

	// Used when searching for eps-approximate neighbors (default: 0).
	public float eps;

	// Only for radius search, neighbors are sorted by distance (default: true).
	public boolean sorted;

	// How many neighbors should be returned (-1 for unlimited).
	public int maxNeighbors;

	// Used for radius search.
	public double radius;

	public float cbIndex;

	public SearchParamsBase() {
		this.checks = -1;
		this.eps = 0.0f;
		this.sorted = true;
		this.maxNeighbors = -1;
		this.radius = 0.0;
	}

	public SearchParamsBase(int checks, float eps, boolean sorted,
			int maxNeighbors, double radius) {
		this.checks = checks;
		this.eps = eps;
		this.sorted = sorted;
		this.maxNeighbors = maxNeighbors;
		this.radius = radius;
	}
}