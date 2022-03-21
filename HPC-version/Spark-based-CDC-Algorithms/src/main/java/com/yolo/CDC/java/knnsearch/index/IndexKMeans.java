package com.yolo.CDC.java.knnsearch.index;

import com.yolo.CDC.java.knnsearch.exception.ExceptionFLANN;
import com.yolo.CDC.java.knnsearch.metric.Metric;
import com.yolo.CDC.java.knnsearch.result_set.ResultSet;
import com.yolo.CDC.java.knnsearch.util.Utils;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.PriorityQueue;

public class IndexKMeans extends IndexBase implements Serializable {
    // Parameters and tree root.
    int branching;
    int iterations;

    /**
     * Cluster border index. This is used in the tree search phase when
     * determining the closest cluster to explore next. A zero value takes into
     * account only the cluster centres, a value greater then zero also take
     * into account the size of the cluster.
     */
    float cbIndex;

    public void setCbIndex(float cbIndex) {
        this.cbIndex = cbIndex;
    }

    CenterChooser.Algorithm centersInit;
    Node root;

    public static class BuildParams extends BuildParamsBase {
        public int branching;
        public int iterations;
        public float cbIndex;
        public CenterChooser.Algorithm centersInit;

        public BuildParams() {
            this.branching = 32;
            this.iterations = 11;
            this.cbIndex = 0.2f;
            this.centersInit = CenterChooser.Algorithm.FLANN_CENTERS_RANDOM;
        }

        public BuildParams(int branching, int iterations, float cbIndex,
                           CenterChooser.Algorithm centersInit) {
            this.branching = branching;
            this.iterations = iterations;
            this.cbIndex = cbIndex;
            this.centersInit = centersInit;
        }
    }

    public static class SearchParams extends SearchParamsBase {
    }

    private class Node implements Serializable {
        // The cluster center.
        public double[] pivot;
        // The cluster radius.
        public double radius;
        // The cluster variance.
        public double variance;
        // Number of points in the cluster.
        public int size;
        // Children nodes (only for non-terminal nodes).
        public ArrayList<Node> children = new ArrayList<Node>();
        // Node points (only for terminal nodes).
        public ArrayList<PointInfo> points = new ArrayList<PointInfo>();
    }

    private class PointInfo implements Serializable {
        int index;
        double[] point;
    }

    public IndexKMeans(Metric metric, double[][] data,
                       BuildParamsBase buildParams) {
        super(metric, data);
        root = null;

        // Get parameters.
        BuildParams bp = (BuildParams) buildParams;
        branching = bp.branching;
        iterations = bp.iterations;
        centersInit = bp.centersInit;
        cbIndex = bp.cbIndex;
        if (iterations < 0) {
            iterations = Integer.MAX_VALUE;
        }

        this.type = IndexFLANN.KMEANS;
    }

    @Override
    protected void buildIndexImpl() throws ExceptionFLANN {
        if (branching < 2) {
            throw new ExceptionFLANN("Branching factor must be at least 2");
        }

        // Prepare objectsIndices.
        objectsIndices = new ArrayList<Integer>();
        for (int i = 0; i < numberOfObjects; i++) {
            objectsIndices.add(i);
        }

        root = new Node();
        computeRootNodeStatistics();
        computeClustering(root, 0, numberOfObjects);
    }

    private void computeRootNodeStatistics() {
        // Compute mean per dimension from all objects.
        double[] mean = new double[numberOfDimensions];
        for (int i = 0; i < numberOfDimensions; i++) {
            mean[i] = 0;
            for (int j = 0; j < numberOfObjects; j++) {
                mean[i] += data[j][i];
            }
        }
        double divFactor = 1.0 / numberOfObjects;
        for (int i = 0; i < numberOfDimensions; i++) {
            mean[i] *= divFactor;
        }

        double radius = 0;
        double variance = 0;
        for (int i = 0; i < numberOfObjects; i++) {
            double dist = metric.distance(mean, data[i]);
            variance += dist;
            if (dist > radius) {
                radius = dist;
            }
        }
        variance /= numberOfObjects;

        // Apply new values for the root node.
        root.pivot = mean;
//		System.out.println("root pivot:"+ Arrays.toString(mean));
        root.variance = variance;
        root.radius = radius;
    }

    private void computeClustering(Node node, int start, int count) {
        // The number of points represented by this node.
        node.size = count;

        // Construct a terminal node if not enough points
        // are left for further partitioning.
        if (count < branching) {
            for (int i = 0; i < count; i++) {
                int x = objectsIndices.get(start + i);
                PointInfo pi = new PointInfo();
                pi.index = x;
                pi.point = data[x];
                node.points.add(pi);
//                System.out.println("terminal node 第" + i + "个点：" + Arrays.toString(pi.point));
            }
            node.children.clear();
            return;
        }

        // Choose initial cluster centers according to the specified algorithm
        // in the build parameters.
        ArrayList<Integer> centersIdx = new ArrayList<Integer>(branching);
        switch (centersInit) {
            case FLANN_CENTERS_RANDOM:
                CenterChooser.Random(metric, data, branching, objectsIndices,
                        start, count, centersIdx);
                break;
            case FLANN_CENTERS_GONZALES:
                CenterChooser.Gonzales(metric, data, branching, objectsIndices,
                        start, count, centersIdx);
                break;
            case FLANN_CENTERS_KMEANSPP:
                CenterChooser.KMeansPP(metric, data, branching, objectsIndices,
                        start, count, centersIdx);
                break;
            default:
                throw new IllegalStateException("Unexpected value: " + centersInit);
        }
        int centersLength = centersIdx.size();
//        System.out.println("centersLength:" + centersLength);
//        System.out.println("braching:" + branching);

        // If necessary, make this a terminal node.
        if (centersLength < branching) {
            for (int i = 0; i < count; i++) {
                int x = objectsIndices.get(start + i);
                PointInfo pi = new PointInfo();
                pi.index = x;
                pi.point = data[x];
                node.points.add(pi);
            }
            node.children.clear();
            return;
        }

        // Copy the center points to a matrix 'dcenters'.
//		double[][] dcenters = new double[branching][numberOfDimensions];
        double[][] dcenters = new double[centersLength][numberOfDimensions];
//		for (double[] dcenter : dcenters) {
//			System.out.println(dcenter[0]);
//		}
//        System.out.println("dcenters:" + dcenters.length);
        for (int i = 0; i < centersLength; i++) {
//			System.out.println("i:"+i);
            double[] vec = data[centersIdx.get(i)];
            for (int k = 0; k < numberOfDimensions; k++) {
//				System.out.println("k:"+k);
                dcenters[i][k] = vec[k];
            }
        }

        // OK, so all this code so far just to get the initial
        // cluster center points! :)

        // Create and initialize bunch of arrays.
        double[] radiuses = new double[branching];
        int[] count2 = new int[branching];
        for (int i = 0; i < branching; i++) {
            radiuses[i] = 0;
            count2[i] = 0;
        }
        Integer[] belongsTo = new Integer[count];

        // Assign points to clusters.
        for (int i = 0; i < count; i++) {
            // Get the point and compute initial distance to the first cluster
            // center.
            double[] p = data[objectsIndices.get(start + i)];
            double sqDist = metric.distance(p, dcenters[0]);
            belongsTo[i] = 0;
            // Find the closest cluster center to this point and the distance.
            for (int j = 0; j < branching; j++) {
                double newSqDist = metric.distance(p, dcenters[j]);
                if (sqDist > newSqDist) {
                    belongsTo[i] = j;
                    sqDist = newSqDist;
                }
            }
            // If the newly added point 'p' to the cluster 'belongsTo[i]' is
            // further away from the cluster center, than its current radius,
            // then expand the current cluster radius.
            if (sqDist > radiuses[belongsTo[i]]) {
                radiuses[belongsTo[i]] = sqDist;
            }
            // Count how many points were assigned to cluster 'belongsTo[i]'.
            count2[belongsTo[i]]++;
        }

        // OK, at this point all the points are assigned to the corresponding
        // clusters! :)

        boolean converged = false;
        int iteration = 0;
        while (!converged && iteration < iterations) {
            converged = true;
            iteration++;

            // Compute the new cluster centers ----------------------
            // Initialize arrays.
            Arrays.fill(radiuses, 0.0);
            for (double[] row : dcenters) {
                Arrays.fill(row, 0.0);
            }

            for (int i = 0; i < count; i++) {
                double[] vec = data[objectsIndices.get(start + i)];
                double[] center = dcenters[belongsTo[i]];
                for (int k = 0; k < numberOfDimensions; k++) {
                    center[k] += vec[k];
                }
            }

            for (int i = 0; i < branching; i++) {
                int cnt = count2[i];
                double divFactor = 1.0 / cnt;
                for (int k = 0; k < numberOfDimensions; k++) {
                    dcenters[i][k] *= divFactor;
                }
            }
            // ------------------------------------------------------

            // Reassign points to clusters --------------------------
            for (int i = 0; i < count; i++) {
                double[] p = data[objectsIndices.get(start + i)];

                // Find the closest centroid to the current point 'p'.
                double sqDist = metric.distance(p, dcenters[0]);
                int newCentroid = 0;
                for (int j = 0; j < branching; j++) {
                    double newSqDist = metric.distance(p, dcenters[j]);
                    if (newSqDist < sqDist) {
                        newCentroid = j;
                        sqDist = newSqDist;
                    }
                }

                // If necessary, expand the radius for the cluster
                // that this point was assigned to.
                if (sqDist > radiuses[newCentroid]) {
                    radiuses[newCentroid] = sqDist;
                }

                // If the new centroid for this point differs from the
                // old one, then make the appropriate changes.
                if (newCentroid != belongsTo[i]) {
                    count2[belongsTo[i]]--;
                    count2[newCentroid]++;
                    belongsTo[i] = newCentroid;
                    converged = false;
                }
            }
            // ------------------------------------------------------

            for (int i = 0; i < branching; i++) {
                // If one cluster converges to an empty cluster,
                // move an element into that cluster.
                if (count2[i] == 0) {
                    int j = (i + 1) % branching;
                    while (count2[j] <= 1) {
                        j = (j + 1) % branching;
                    }

                    for (int k = 0; k < count; k++) {
                        if (belongsTo[k] == j) {
                            belongsTo[k] = i;
                            count2[j]--;
                            count2[i]++;
                            break;
                        }
                    }

                    converged = false;
                }
            }
        }

        // Copy values from 'dcenters' to 'centers'.
        double[][] centers = new double[branching][numberOfDimensions];
        for (int i = 0; i < branching; i++) {
            for (int j = 0; j < numberOfDimensions; j++) {
                centers[i][j] = dcenters[i][j];
            }
        }

        // Compute k-means clustering for each of the resulting clusters.
        int start2 = 0;
        int end = 0;
        for (int c = 0; c < branching; c++) {
            // The number of points the cluster 'c' has.
            int s = count2[c];

            double variance = 0;
            for (int i = 0; i < count; i++) {
                double[] p = data[objectsIndices.get(start + i)];
                // If the current point 'p' belongs to cluster 'c'.
                if (belongsTo[i] == c) {
                    variance += metric.distance(centers[c], p);

                    Collections.swap(objectsIndices, i, end);
                    Utils.swapArray(belongsTo, i, end);
                    end++;
                }
            }
            variance /= s;

            Node newNode = new Node();
            newNode.radius = radiuses[c];
            newNode.pivot = centers[c];
            newNode.variance = variance;
            node.children.add(newNode);
//			System.out.println("parentNode:"+Arrays.toString(node.pivot));
//			System.out.println("childrenNode:"+Arrays.toString(newNode.pivot));
            computeClustering(newNode, start + start2, end - start2);

            start2 = end;
        }
    }

    @Override
    protected void findNeighbors(ResultSet resultSet, double[] query,
                                 SearchParamsBase searchParams) {
        int maxChecks = searchParams.checks;
        if (maxChecks == -1) {
            findExactNN(root, resultSet, query);
        } else {
            // Priority queue storing intermediate branches in the
            // best-bin-first search.
            PriorityQueue<Branch<Node>> heap = new PriorityQueue<Branch<Node>>(
                    numberOfObjects);

            int checks[] = new int[1];
            checks[0] = 0;
            findNN(root, resultSet, query, checks, maxChecks, heap);

            Branch<Node> branch;
            while ((branch = heap.poll()) != null
                    && (checks[0] < maxChecks || !resultSet.full())) {
                findNN(branch.node, resultSet, query, checks, maxChecks, heap);
            }
        }
    }

    @Override
    protected void findNeighbor(ResultSet resultSet, double[] query) {
        findExactNN(root, resultSet, query);
    }

    // Function that performs exact nearest neighbor search by traversing the
    // entire tree.
    private void findExactNN(Node node, ResultSet resultSet, double[] query) {
        // Pruning. Ignore those clusters that are too far away -----
        double bsq = metric.distance(query, node.pivot);
        double rsq = node.radius;
        double wsq = resultSet.worstDistance();

        double val = bsq - rsq - wsq;
        double val2 = val * val - 4 * rsq * wsq;

        if (val > 0 && val2 > 0) {
            return;
        }
        // ----------------------------------------------------------

        // Terminal node.
        if (node.children.isEmpty()) {
            for (int i = 0; i < node.size; i++) {
                PointInfo pointInfo = node.points.get(i);
                int index = pointInfo.index;
                double dist = metric.distance(pointInfo.point, query);
                resultSet.addPoint(dist, index);
//                System.out.println("index:"+pointInfo.index);
//                System.out.println("point:"+ Arrays.toString(pointInfo.point));
            }
        }
        // Internal node.
        else {
            int[] sortIndices = new int[branching];
            getCenterOrdering(node, query, sortIndices);
            for (int i = 0; i < branching; i++) {
                findExactNN(node.children.get(sortIndices[i]), resultSet, query);
            }
        }
    }

    /**
     * It computes the order in which to traverse the child nodes of a
     * particular node.
     */
    private void getCenterOrdering(Node node, double[] q, int[] sortIndices) {
        double[] domainDistances = new double[branching];
        for (int i = 0; i < branching; ++i) {
            double dist = metric.distance(q, node.children.get(i).pivot);

            int j = 0;
            while (domainDistances[j] < dist && j < i) {
                j++;
            }

            // Move elements one place to the right.
            for (int k = i; k > j; k--) {
                domainDistances[k] = domainDistances[k - 1];
                sortIndices[k] = sortIndices[k - 1];
            }

            domainDistances[j] = dist;
            sortIndices[j] = i;
        }
    }

    private void findNN(Node node, ResultSet resultSet, double[] query,
                        int[] checks, int maxChecks, PriorityQueue<Branch<Node>> heap) {
        // Pruning. Ignore those clusters that are too far away -----
        double bsq = metric.distance(query, node.pivot);
        double rsq = node.radius;
        double wsq = resultSet.worstDistance();

        double val = bsq - rsq - wsq;
        double val2 = val * val - 4 * rsq * wsq;

        if (val > 0 && val2 > 0) {
            return;
        }
        // ----------------------------------------------------------

        // Terminal node.
        if (node.children.isEmpty()) {
            if (checks[0] >= maxChecks && resultSet.full()) {
                return;
            }

            for (int i = 0; i < node.size; i++) {
                PointInfo pointInfo = node.points.get(i);
                int index = pointInfo.index;
                double dist = metric.distance(pointInfo.point, query);
                resultSet.addPoint(dist, index);
                checks[0]++;
            }
        }
        // Internal node.
        else {
            int closestCenter = exploreNodeBranches(node, query, heap);
            findNN(node.children.get(closestCenter), resultSet, query, checks,
                    maxChecks, heap);
        }

    }

    /**
     * Helper function that computes the nearest child of a node to a given
     * query point.
     */
    private int exploreNodeBranches(Node node, double[] q,
                                    PriorityQueue<Branch<Node>> heap) {
        double[] domainDistances = new double[branching];
        domainDistances[0] = metric.distance(q, node.children.get(0).pivot);

        // Compute and record the smallest among the distance values from
        // the query point to each child.
        int bestIndex = 0;
        for (int i = 1; i < branching; i++) {
            domainDistances[i] = metric.distance(q, node.children.get(i).pivot);
            if (domainDistances[i] < domainDistances[bestIndex]) {
                bestIndex = i;
            }
        }

        // Add all children to the heap, except the best one.
        for (int i = 0; i < branching; i++) {
            if (i != bestIndex) {
                Node child = node.children.get(i);
                domainDistances[i] -= cbIndex * child.variance;
                heap.add(new Branch<Node>(child, domainDistances[i]));
            }
        }

        return bestIndex;
    }

    @Override
    protected void findNeighbors(ResultSet resultSet, int[] query,
                                 SearchParamsBase searchParams) {
    }

    @Override
    public int usedMemory() {
        // TODO Auto-generated method stub
        return 0;
    }

    public void printTree(Node node) {
        if (node != null && !node.children.isEmpty()) {
            System.out.println("nonTerminalNode:"+Arrays.toString(node.pivot));
            node.children.forEach(childNode ->
            {
                System.out.println("child:" + Arrays.toString(childNode.pivot));
                printTree(childNode);
            });
        }else if(node!=null &&!node.points.isEmpty()){
            System.out.println("terminalNode:"+Arrays.toString(node.pivot));
            node.points.forEach(childNode ->
            {
                System.out.println("point:" + Arrays.toString(childNode.point));
//                printTree(childNode);
            });
        }
        return;
    }

    public void printTree() {
        System.out.println("root:" + Arrays.toString(root.pivot));
        if (root != null && !root.children.isEmpty()) {
            root.children.forEach(childNode ->
            {
                System.out.println("=================");
                System.out.println("rootChild:" + Arrays.toString(childNode.pivot));
                System.out.println("=================");
                printTree(childNode);
            });
        }
        return;
    }
}
