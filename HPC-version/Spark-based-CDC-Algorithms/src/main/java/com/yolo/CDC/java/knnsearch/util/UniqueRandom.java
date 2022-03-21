package com.yolo.CDC.java.knnsearch.util;

import java.util.ArrayList;
import java.util.Collections;

/**
 * Random number generator that returns a distinct number from the [0,n)
 * interval each time.
 */
public class UniqueRandom {
	ArrayList<Integer> vals;
	int size;
	int counter;

	public UniqueRandom(int n) {
		init(n);
	}

	public void init(int n) {
		size = n;
		counter = 0;
		vals = new ArrayList<Integer>();
		for (int i = 0; i < size; i++) {
			vals.add(i);
		}
		Collections.shuffle(vals);
	}

	/**
	 * Returns a distinct random integer 0 <= x < n on each call. It can be
	 * called maximum 'n' times.
	 */
	public int next() {
		if (counter == size) {
			return -1;
		} else {
			return vals.get(counter++);
		}
	}
}