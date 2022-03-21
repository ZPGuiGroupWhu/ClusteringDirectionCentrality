package com.yolo.CDC.java.knnsearch.index;

import com.yolo.CDC.java.knnsearch.exception.ExceptionFLANN;
import com.yolo.CDC.java.knnsearch.metric.Metric;
import org.apache.commons.lang3.time.StopWatch;

import java.util.Arrays;

public class IndexTesting {
	public int countCorrectMatches(int[] neighbors, int[] groundTruth) {
		int n = neighbors.length;
		int count = 0;
		for (int i = 0; i < n; i++) {
			for (int k = 0; k < n; k++) {
				if (neighbors[i] == groundTruth[k]) {
					count++;
					break;
				}
			}
		}
		return count;
	}

	public double computeDistanceRaport(double[][] inputData, double[] target,
			int[] neighbors, int[] groundTruth, Metric metric) {
		int n = neighbors.length;
		double ret = 0;
		for (int i = 0; i < n; i++) {
			double den = metric.distance(inputData[groundTruth[i]], target);
			double num = metric.distance(inputData[neighbors[i]], target);

			if (den == 0 && num == 0) {
				ret += 1;
			} else {
				ret += num / den;
			}
		}
		return ret;
	}

	public float searchWithGroundTruth(IndexBase index, double[][] inputData,
			double[][] testData, int[][] matches, int nn, int checks,
			float[] time, double[] dist, Metric metric, int skipMatches) {
		int matchesCols = matches[0].length;
		if (matchesCols < nn) {
			System.out.printf("matches.cols=%d, nn=%d\n", matchesCols, nn);
			throw new ExceptionFLANN(
					"Ground truth is not computed for as many neighbors as requested");
		}

		SearchParamsBase searchParams = new SearchParamsBase();
		searchParams.checks = checks;
		searchParams.maxNeighbors = nn + skipMatches;

		int[] indices = new int[nn + skipMatches];
		double[] dists = new double[nn + skipMatches];

		int[][] indicesMat = new int[1][nn + skipMatches];
		double[][] distsMat = new double[1][nn + skipMatches];

		int[] neighbors = Arrays.copyOfRange(indices, skipMatches,
				indices.length);

		int correct = 0;
		double distR = 0;
		StopWatch timer = new StopWatch();
		int repeats = 0;

		while (timer.getTime() / 1000.0f < 0.2f) {
			repeats++;
			//timer.start();
			if(!timer.isStarted()){
				timer.start();
			}else {
				timer.resume();
			}
			correct = 0;
			distR = 0;
			int cols = testData[0].length;
			for (int i = 0; i < testData.length; i++) {
				double[][] temp = new double[1][cols];
//				temp[1] = Arrays.copyOf(testData[i], cols);
				temp[0] = Arrays.copyOf(testData[i], cols);
				index.knnSearch(temp, indicesMat, distsMat, searchParams);

				correct += countCorrectMatches(neighbors, matches[i]);
				distR += computeDistanceRaport(inputData, testData[i],
						neighbors, matches[i], metric);
			}
			timer.suspend();
		}
		time[0] = timer.getTime() / 1000.0f / repeats;

		float precision = (float) correct / (nn * testData.length);
		dist[0] = distR / (testData.length * nn);
		System.out.printf("%d, %f, %f, %f, %f \n", checks, precision, time[0],
				1000.0f * time[0] / testData.length, dist[0]);
		return precision;
	}

	public float testIndexPrecision(IndexBase index, double[][] inputData,
			double[][] testData, int[][] matches, float precision,
			int[] checks, Metric metric, int nn, int skipMatches) {
		float SEARCH_EPS = 0.001f;

		int c2 = 1;
		float p2;
		int c1 = 1;
		float[] time = new float[1];
		double[] dist = new double[1];

		p2 = searchWithGroundTruth(index, inputData, testData, matches, nn, c2,
				time, dist, metric, skipMatches);

		if (p2 > precision) {
			checks[0] = c2;
			return time[0];
		}

		while (p2 < precision) {
			c1 = c2;
			c2 *= 2;
			p2 = searchWithGroundTruth(index, inputData, testData, matches, nn,
					c2, time, dist, metric, skipMatches);
		}

		int cx;
		float realPrecision;

		if (Math.abs(p2 - precision) > SEARCH_EPS) {
			cx = (c1 + c2) / 2;
			realPrecision = searchWithGroundTruth(index, inputData, testData,
					matches, nn, cx, time, dist, metric, skipMatches);
			while (Math.abs(realPrecision - precision) > SEARCH_EPS) {

				if (realPrecision < precision) {
					c1 = cx;
				} else {
					c2 = cx;
				}
				cx = (c1 + c2) / 2;
				if (cx == c1) {
					break;
				}
				realPrecision = searchWithGroundTruth(index, inputData,
						testData, matches, nn, cx, time, dist, metric,
						skipMatches);
			}

			c2 = cx;
			p2 = realPrecision;

		} else {
			cx = c2;
			realPrecision = p2;
		}

		checks[0] = cx;
		return time[0];
	}

}