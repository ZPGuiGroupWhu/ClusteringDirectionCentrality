package com.yolo.CDC.java.knnsearch.index;

import com.yolo.CDC.java.knnsearch.metric.Metric;
import com.yolo.CDC.java.knnsearch.util.UniqueRandom;
import com.yolo.CDC.java.knnsearch.util.Utils;

import java.util.ArrayList;

public class CenterChooser {
	public enum Algorithm {
		FLANN_CENTERS_RANDOM, FLANN_CENTERS_GONZALES, FLANN_CENTERS_KMEANSPP
	}

	public static void Random(Metric metric, double[][] data, int k,
			ArrayList<Integer> objectsIndices, int start, int count,
			ArrayList<Integer> centers) {
		UniqueRandom r = new UniqueRandom(count);

		int index;
		for (index = 0; index < k; index++) {
			boolean duplicate = true;
			int rnd;
			while (duplicate) {
				duplicate = false;
				rnd = r.next();
				if (rnd < 0)
					return;

				centers.add(objectsIndices.get(start + rnd));

				for (int j = 0; j < index; j++) {
					double sq = metric.distance(data[centers.get(index)],
							data[centers.get(j)]);
					if (sq < 1E-16) {
						duplicate = true;
					}
				}
			}
		}
	}

	public static void Gonzales(Metric metric, double[][] data, int k,
			ArrayList<Integer> objectsIndices, int start, int count,
			ArrayList<Integer> centers) {
		// Pick the first center randomly.
		int rnd = Utils.genRandomNumberInRange(0, count - 1);
		centers.add(objectsIndices.get(start + rnd));

		int index;
		for (index = 1; index < k; index++) {
			int bestIndex = -1;
			double bestValue = 0;
			for (int j = 0; j < count; j++) {
				double dist = metric.distance(data[centers.get(0)],
						data[objectsIndices.get(start + j)]);
				for (int i = 1; i < index; i++) {
					double tmpDist = metric.distance(data[centers.get(i)],
							data[objectsIndices.get(start + j)]);
					if (tmpDist < dist) {
						dist = tmpDist;
					}
				}
				if (dist > bestValue) {
					bestValue = dist;
					bestIndex = j;
				}
			}
			if (bestIndex != -1) {
				centers.add(objectsIndices.get(start + bestIndex));
			} else {
				break;
			}
		}
	}

	public static void KMeansPP(Metric metric, double[][] data, int k,
			ArrayList<Integer> objectsIndices, int start, int count,
			ArrayList<Integer> centers) {
		int n = count;
		double currentPotential = 0;
		double[] closestDistSq = new double[n];

		// Chose one random center and set the closestDistSq values.
		int index = Utils.genRandomNumberInRange(0, n - 1);
		centers.add(objectsIndices.get(start + index));

		for (int i = 0; i < n; i++) {
			closestDistSq[i] = metric.distance(
					data[objectsIndices.get(start + i)],
					data[objectsIndices.get(start + index)]);
			currentPotential += closestDistSq[i];
		}

		int NUM_LOCAL_TRIES = 1;

		// Choose each center.
		int centerCount;
		for (centerCount = 1; centerCount < k; centerCount++) {
			double bestNewPotential = -1;
			int bestNewIndex = 0;

			for (int localTrial = 0; localTrial < NUM_LOCAL_TRIES; localTrial++) {
				double randVal = Utils.genRandomNumberInRange(0.0,
						currentPotential);
				for (index = 0; index < n - 1; index++) {
					if (randVal <= closestDistSq[index])
						break;
					else
						randVal -= closestDistSq[index];
				}

				// Compute the new potential.
				double newPotential = 0;
				for (int i = 0; i < n; i++) {
					double d = metric.distance(
							data[objectsIndices.get(start + i)],
							data[objectsIndices.get(start + index)]);
					newPotential += Math.min(d, closestDistSq[i]);
				}

				// Store the best result.
				if (bestNewPotential < 0 || newPotential < bestNewPotential) {
					bestNewPotential = newPotential;
					bestNewIndex = index;
				}
			}

			centers.add(objectsIndices.get(start + bestNewIndex));
			currentPotential = bestNewPotential;
			for (int i = 0; i < n; i++) {
				double d = metric.distance(data[objectsIndices.get(start + i)],
						data[objectsIndices.get(start + bestNewIndex)]);
				closestDistSq[i] = Math.min(d, closestDistSq[i]);
			}
		}
	}

	public static void Random(Metric metric, int[][] data, int k,
			ArrayList<Integer> objectsIndices, int start, int count,
			ArrayList<Integer> centers) {
		UniqueRandom r = new UniqueRandom(count);

		int index;
		for (index = 0; index < k; index++) {
			boolean duplicate = true;
			int rnd;
			while (duplicate) {
				duplicate = false;
				rnd = r.next();
				if (rnd < 0)
					return;

				centers.add(objectsIndices.get(start + rnd));

				for (int j = 0; j < index; j++) {
					double sq = metric.distance(data[centers.get(index)],
							data[centers.get(j)]);
					if (sq < 1E-16) {
						duplicate = true;
					}
				}
			}
		}
	}

	public static void Gonzales(Metric metric, int[][] data, int k,
			ArrayList<Integer> objectsIndices, int start, int count,
			ArrayList<Integer> centers) {
		// Pick the first center randomly.
		int rnd = Utils.genRandomNumberInRange(0, count - 1);
		centers.add(objectsIndices.get(start + rnd));

		int index;
		for (index = 1; index < k; index++) {
			int bestIndex = -1;
			double bestValue = 0;
			for (int j = 0; j < count; j++) {
				double dist = metric.distance(data[centers.get(0)],
						data[objectsIndices.get(start + j)]);
				for (int i = 1; i < index; i++) {
					double tmpDist = metric.distance(data[centers.get(i)],
							data[objectsIndices.get(start + j)]);
					if (tmpDist < dist) {
						dist = tmpDist;
					}
				}
				if (dist > bestValue) {
					bestValue = dist;
					bestIndex = j;
				}
			}
			if (bestIndex != -1) {
				centers.add(objectsIndices.get(start + bestIndex));
			} else {
				break;
			}
		}
	}

	public static void KMeansPP(Metric metric, int[][] data, int k,
			ArrayList<Integer> objectsIndices, int start, int count,
			ArrayList<Integer> centers) {
		int n = count;
		double currentPotential = 0;
		double[] closestDistSq = new double[n];

		// Chose one random center and set the closestDistSq values.
		int index = Utils.genRandomNumberInRange(0, n - 1);
		centers.add(objectsIndices.get(start + index));

		for (int i = 0; i < n; i++) {
			closestDistSq[i] = metric.distance(
					data[objectsIndices.get(start + i)],
					data[objectsIndices.get(start + index)]);
			currentPotential += closestDistSq[i];
		}

		int NUM_LOCAL_TRIES = 1;

		// Choose each center.
		int centerCount;
		for (centerCount = 1; centerCount < k; centerCount++) {
			double bestNewPotential = -1;
			int bestNewIndex = 0;

			for (int localTrial = 0; localTrial < NUM_LOCAL_TRIES; localTrial++) {
				double randVal = Utils.genRandomNumberInRange(0.0,
						currentPotential);
				for (index = 0; index < n - 1; index++) {
					if (randVal <= closestDistSq[index])
						break;
					else
						randVal -= closestDistSq[index];
				}

				// Compute the new potential.
				double newPotential = 0;
				for (int i = 0; i < n; i++) {
					double d = metric.distance(
							data[objectsIndices.get(start + i)],
							data[objectsIndices.get(start + index)]);
					newPotential += Math.min(d, closestDistSq[i]);
				}

				// Store the best result.
				if (bestNewPotential < 0 || newPotential < bestNewPotential) {
					bestNewPotential = newPotential;
					bestNewIndex = index;
				}
			}

			centers.add(objectsIndices.get(start + bestNewIndex));
			currentPotential = bestNewPotential;
			for (int i = 0; i < n; i++) {
				double d = metric.distance(data[objectsIndices.get(start + i)],
						data[objectsIndices.get(start + bestNewIndex)]);
				closestDistSq[i] = Math.min(d, closestDistSq[i]);
			}
		}
	}
}
