package com.yolo.CDC.java.knnsearch.index;

import com.yolo.CDC.java.knnsearch.exception.ExceptionFLANN;
import com.yolo.CDC.java.knnsearch.metric.Metric;
import com.yolo.CDC.java.knnsearch.result_set.ResultSet;
import com.yolo.CDC.java.knnsearch.util.Utils;

import java.util.ArrayList;
import java.util.BitSet;
import java.util.Collections;
import java.util.PriorityQueue;

public class IndexHierarchicalClustering extends IndexBase {
	private class Node {
		// The cluster center.
		public int[] pivot;

		public int pivotIndex;

		// Children nodes (only for non-terminal nodes).
		public ArrayList<Node> children = new ArrayList<Node>();

		// Node points (only for terminal nodes).
		public ArrayList<PointInfo> points = new ArrayList<PointInfo>();
	}

	private class PointInfo {
		public int index;
		public int[] point;
	}

	public static class BuildParams extends BuildParamsBase {
		public int branching;
		public int trees;
		public int leafMaxSize;
		public CenterChooser.Algorithm centersInit;

		public BuildParams() {
			this.branching = 32;
			this.trees = 4;
			this.leafMaxSize = 100;
			this.centersInit = CenterChooser.Algorithm.FLANN_CENTERS_RANDOM;
		}

		public BuildParams(int branching, int trees, int leafMaxSize,
				CenterChooser.Algorithm centersInit) {
			this.branching = branching;
			this.trees = trees;
			this.leafMaxSize = leafMaxSize;
			this.centersInit = centersInit;
		}
	}

	public static class SearchParams extends SearchParamsBase {
	}

	ArrayList<Node> treeRoots;
	int branching;
	int trees;
	int leafMaxSize;
	CenterChooser.Algorithm centersInit;

	public IndexHierarchicalClustering(Metric metric, int[][] data,
			BuildParams buildParams) {
		super(metric, data);

		this.branching = buildParams.branching;
		this.centersInit = buildParams.centersInit;
		this.trees = buildParams.trees;
		this.leafMaxSize = buildParams.leafMaxSize;

		this.type = IndexFLANN.HIERARCHICAL;
	}

	@Override
	protected void buildIndexImpl() {
		if (branching < 2) {
			throw new ExceptionFLANN("Branching factor must be at least 2");
		}

		// Prepare objectsIndices.
		objectsIndices = new ArrayList<Integer>();
		for (int i = 0; i < numberOfObjects; i++) {
			objectsIndices.add(i);
		}

		treeRoots = new ArrayList<Node>();
		for (int i = 0; i < trees; i++) {
			for (int j = 0; j < numberOfObjects; j++) {
				objectsIndices.set(j, j);
			}
			Node node = new Node();
			treeRoots.add(node);
			computeClustering(node, 0, numberOfObjects);
		}
	}

	private void computeClustering(Node node, int start, int count) {
		// Leaf node.
		if (count < leafMaxSize) {
			for (int i = 0; i < count; i++) {
				int x = objectsIndices.get(start + i);
				PointInfo pi = new PointInfo();
				pi.index = x;
				pi.point = dataBinary[x];
				node.points.add(pi);
			}
			node.children.clear();
			return;
		}

		// Choose initial cluster centers according to the specified algorithm
		// in the build parameters.
		ArrayList<Integer> centers = new ArrayList<Integer>(branching);
		switch (centersInit) {
		case FLANN_CENTERS_RANDOM:
			CenterChooser.Random(metric, dataBinary, branching, objectsIndices,
					start, count, centers);
			break;
		case FLANN_CENTERS_GONZALES:
			CenterChooser.Gonzales(metric, dataBinary, branching,
					objectsIndices, start, count, centers);
			break;
		case FLANN_CENTERS_KMEANSPP:
			CenterChooser.KMeansPP(metric, dataBinary, branching,
					objectsIndices, start, count, centers);
			break;
		}
		int centersLength = centers.size();

		// If necessary, make this a terminal node.
		if (centersLength < branching) {
			for (int i = 0; i < count; i++) {
				int x = objectsIndices.get(start + i);
				PointInfo pi = new PointInfo();
				pi.index = x;
				pi.point = dataBinary[x];
				node.points.add(pi);
			}
			node.children.clear();
			return;
		}
		double cost[] = new double[1];
		Integer[] labels = new Integer[count];
		computeLabels(start, count, centers, labels, cost);

		int start2 = 0;
		int end = 0;
		for (int i = 0; i < branching; i++) {
			for (int j = 0; j < count; j++) {
				if (labels[j] == i) {
					Collections.swap(objectsIndices, j, end);
					Utils.swapArray(labels, j, end);
					end++;
				}
			}

			Node newNode = new Node();
			newNode.pivotIndex = centers.get(i);
			newNode.pivot = dataBinary[centers.get(i)];
			node.children.add(newNode);

			computeClustering(newNode, start + start2, end - start2);
			start2 = end;
		}
	}

	private void computeLabels(int start, int count,
			ArrayList<Integer> centers, Integer[] labels, double[] cost) {
		cost[0] = 0.0;
		int centersLength = centers.size();
		for (int i = 0; i < count; i++) {
			int[] point = dataBinary[objectsIndices.get(start + i)];
			double dist = metric.distance(point, dataBinary[centers.get(0)]);
			labels[i] = 0;
			for (int j = 1; j < centersLength; j++) {
				double newDist = metric.distance(point,
						dataBinary[centers.get(j)]);
				if (dist > newDist) {
					labels[i] = j;
					dist = newDist;
				}
			}
			cost[0] += dist;
		}
	}

	@Override
	protected void findNeighbors(ResultSet resultSet, int[] query,
			SearchParamsBase searchParams) {
		int maxChecks = searchParams.checks;

		// Priority queue storing intermediate branches in the
		// best-bin-first search.
		PriorityQueue<Branch<Node>> heap = new PriorityQueue<Branch<Node>>(
				numberOfObjects);

		BitSet checked = new BitSet(numberOfObjects);
		int checks[] = new int[1];
		checks[0] = 0;
		for (int i = 0; i < trees; i++) {
			findNN(treeRoots.get(i), resultSet, query, checks, maxChecks, heap,
					checked);
		}

		Branch<Node> branch;
		while ((branch = heap.poll()) != null
				&& (checks[0] < maxChecks || !resultSet.full())) {
			findNN(branch.node, resultSet, query, checks, maxChecks, heap,
					checked);
		}
	}

	@Override
	protected void findNeighbor(ResultSet resultSet, double[] query) {

	}

	private void findNN(Node node, ResultSet resultSet, int[] query,
						int[] checks, int maxChecks, PriorityQueue<Branch<Node>> heap,
						BitSet checked) {
		// Terminal node.
		if (node.children.isEmpty()) {
			if (checks[0] >= maxChecks && resultSet.full())
				return;

			for (int i = 0; i < node.points.size(); i++) {
				PointInfo pointInfo = node.points.get(i);
				int index = pointInfo.index;
				if (checked.get(index))
					continue;
				double dist = metric.distance(pointInfo.point, query);
				resultSet.addPoint(dist, index);
				checked.set(index);
				checks[0]++;
			}
		}
		// Internal node.
		else {
			double[] domainDistances = new double[branching];
			domainDistances[0] = metric.distance(query,
					node.children.get(0).pivot);
			int bestIndex = 0;
			for (int i = 1; i < branching; i++) {
				domainDistances[i] = metric.distance(query,
						node.children.get(i).pivot);
				if (domainDistances[i] < domainDistances[bestIndex]) {
					bestIndex = i;
				}
			}

			for (int i = 0; i < branching; i++) {
				if (i != bestIndex) {
					Node child = node.children.get(i);
					heap.add(new Branch<Node>(child, domainDistances[i]));
				}
			}

			findNN(node.children.get(bestIndex), resultSet, query, checks,
					maxChecks, heap, checked);
		}
	}

	@Override
	protected void findNeighbors(ResultSet resultSet, double[] query,
			SearchParamsBase searchParams) {
		throw new ExceptionFLANN("Unsupported types");
	}

	@Override
	public int usedMemory() {
		// TODO Auto-generated method stub
		return 0;
	}
}
