package com.yolo.CDC.java.knnsearch.index;

import java.util.ArrayList;
import java.util.Collections;

public class LSHTable {
	private class Buckets {
		// ArrayList of buckets. Each bucket is an ArrayList of
		// Integer values, that represent points indices.
		public ArrayList<Bucket> buckets = new ArrayList<Bucket>();

		// A bucket is accessed with a key, and then the pointIndex
		// is added in the bucket corresponding to that key.
		public void add(int key, int pointIndex) {
			buckets.get(key).add(pointIndex);
		}

		public Bucket getBucket(int key) {
			if (key >= 0 && key < buckets.size()) {
				return buckets.get(key);
			} else {
				return null;
			}
		}
	}

	Buckets buckets;

	// Size of the key in bits.
	int keySize;

	// The mask to apply to a point to get the hash key.
	ArrayList<Integer> mask;

	// The point is just bunch of bits. In this case it is represented as an
	// int[], but all those int values should be thought of as a string of bits.
	public void add(int pointIndex, int[] point) {
		int key = getKey(point);
		buckets.add(key, pointIndex);
	}

	public void add(int[][] points) {
		for (int i = 0; i < points.length; i++) {
			add(i, points[i]);
		}
	}

	public Bucket getBucket(int key) {
		return buckets.getBucket(key);
	}

	// Hash a point and get the key. Example: given ABCDEF, and the mask 001011,
	// the output is 000CEF.
	public int getKey(int[] point) {
		int key = 0;
		int bitIndex = 1;

		int maskSize = mask.size();
		for (int i = 0; i < maskSize; i++) {
			// Get 32 bits from the point and the mask.
			int pointBlock = point[i];
			int maskBlock = mask.get(i);

			while (maskBlock != 0) {
				// Get the lowest set bit in the mask block.
				int lowestBit = maskBlock & (-maskBlock);
				key += ((pointBlock & lowestBit) != 0) ? bitIndex : 0;

				// Reset the mask bit.
				maskBlock ^= lowestBit;

				// Move one bit to the left.
				bitIndex <<= 1;
			}
		}

		return key;
	}

	// 'pointSize' is the number of elements in a point
	// represented as 'int[] point'.
	public LSHTable(int pointSize, int keySize) {
		this.keySize = keySize;

		buckets = new Buckets();
		int size = 1 << keySize;
		for (int i = 0; i < size; i++) {
			buckets.buckets.add(new Bucket());
		}

		mask = new ArrayList<Integer>();
		for (int i = 0; i < pointSize; i++) {
			mask.add(0);
		}

		int indicesSize = pointSize * 32;
		ArrayList<Integer> indices = new ArrayList<Integer>(indicesSize);
		for (int i = 0; i < indicesSize; i++) {
			indices.add(i);
		}
		Collections.shuffle(indices);

		int divisor = 32;
		for (int i = 0; i < keySize; i++) {
			int index = indices.get(i);
			int idx = index / divisor;
			int maskValue = mask.get(idx);
			maskValue |= (1 << (index % divisor));
			mask.set(idx, maskValue);
		}
	}
}