package com.yolo.CDC.java.knnsearch.util;

import java.util.Arrays;

public class Utils {
	// Generate a random number min <= x <= max.
	public static int genRandomNumberInRange(int min, int max) {
		return min + (int) (Math.random() * ((max - min) + 1));
	}

	// Generate a random number min <= x < max.
	public static double genRandomNumberInRange(double min, double max) {
		return min + Math.random() * (max - min);
	}

	public static <T> boolean swapArray(T[] array, int i, int j) {
		int size = array.length;
		if (size < 2 || i == j || i < 0 || i >= size || j < 0 || j >= size) {
			return false;
		}
		T temp = array[i];
		array[i] = array[j];
		array[j] = temp;
		return true;
	}

	public static double[][] randomSample(double[][] m, int size, boolean remove) {
		int mr = m.length;
		int mc = m[0].length;
		UniqueRandom randUnique = new UniqueRandom(mr);

		double[][] newSet = new double[size][mc];

		for (int i = 0; i < size; i++) {
			int r = randUnique.next();
			newSet[i] = Arrays.copyOf(m[r], mc);
		}

		return newSet;
	}

}