/***
 * Author: Stephen Meehan, swmeehan@stanford.edu
 * 
 * Provided by the Herzenberg Lab at Stanford University
 * 
 * License: BSD 3 clause
 */

package edu.stanford.facs.swing;

import java.io.PrintStream;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collection;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.TreeMap;
import java.util.TreeSet;
import java.util.concurrent.CountDownLatch;

public class Separatrix implements Runnable {
	public int[] getBestClusterGroup() {
		if (groupsOfClues.size() == 0 || bestScore > 1) {
			return empty;
		}
		return groupsOfClues.get(bestIdx);
	}

	public double getBestScore() {
		if (groupsOfClues.size() == 0 || bestScore > 1) {
			return Double.NaN;
		}
		return bestScore;
	}

	public int[] getWorstClusterGroup() {
		if (groupsOfClues.size() == 0 || worstScore < 0 || worstIdx < 0) {
			return empty;
		}
		return groupsOfClues.get(worstIdx);
	}

	public double getWorstScore() {
		if (groupsOfClues.size() == 0 || worstScore < 0 || worstIdx < 0) {
			return Double.NaN;
		}
		return worstScore;
	}

	public TreeMap<Double, int[]> getBestScores() {
		TreeMap<Double, int[]> out = new TreeMap<>();
		for (int i = 0; i < groupsOfClues.size(); i++) {
			out.put(separatracies.get(i), groupsOfClues.get(i));
		}
		return out;
	}

	public Separatrix(final int[] clueEventCounts, final double[][] clueDistances, final int[] tooLow, final int M,
			final int[] clueGridAssignments, final double[] densityGrid, final double kld,
			final double[] normalDistribution, final double kldThreshold, final double kldFreqThreshold,
			final int minSplit) throws Exception {
		this(clueEventCounts, clueDistances, tooLow, M, clueGridAssignments, densityGrid, kld, normalDistribution,
				kldThreshold, kldFreqThreshold, minSplit, Numeric.sum(clueEventCounts), clueEventCounts);
	}

	public Separatrix(final Separatrix that) throws Exception {
		this(that.clueCnts4Balanced, that.clueDistances, that.tooLow, that.M, that.clueGridAssignments,
				that.densityGrid, that.kld, that.normalDistribution, that.kldThreshold, that.kldFreqThreshold,
				that.minSplit, that.totalEventCount, that.clueCnts4MinSplit);
		groupRule = that.groupRule;
		edgeRule = that.edgeRule;
		verboseFlags = that.verboseFlags;
		numberOfTopScoresToKeep = that.numberOfTopScoresToKeep;
		balanced = that.balanced;
		worstScore = that.worstScore;
		worstIdx = that.worstIdx;
		bestIdx = that.bestIdx;
		bestScore = that.bestScore;
		possibleGroups = that.possibleGroups;
		groupsOfClues.addAll(that.groupsOfClues);
		separatracies.addAll(that.separatracies);
	}

	public Separatrix(final int[] clueCnts4Balanced, final double[][] clueDistances, final int[] tooLow, final int M,
			final int[] clueGridAssignments, final double[] densityGrid, final double kld,
			final double[] normalDistribution, final double kldThreshold, final double kldFreqThreshold,
			final int minSplit, final int totalEventCount, final int[] clueCnts4MinSplit) throws Exception {
		numClues = clueCnts4Balanced == null ? 0 : clueCnts4Balanced.length;
		this.clueCnts4Balanced = clueCnts4Balanced;
		this.totalEventCount = totalEventCount;
		this.clueCnts4MinSplit = clueCnts4MinSplit;
		this.totalClueCnt4MinSplit = Numeric.sum(clueCnts4MinSplit);
		this.clueDistances = clueDistances;
		this.groupsOfClues = new ArrayList<int[]>(numClues);
		this.separatracies = new ArrayList<Double>(numClues);
		this.tooLow = tooLow;
		groupsOfClues.clear();
		if (numClues > 0) {
			clueLetters = new Basics.IndirectSorter<Integer>().sortLetters(Basics.toIntegers(clueCnts4Balanced), true);
		} else {
			clueLetters = null;
		}
		if (!(clueGridAssignments == null || M * M == clueGridAssignments.length)) {
			throw new Exception("M=" + M + ", so there must be " + (M * M) + " allClusterGridAssignments ID values");
		}
		if (!(densityGrid == null || M * M == densityGrid.length)) {
			throw new Exception("M=" + M + ", so there must be " + (M * M) + " density values");
		}
		this.M = M;
		this.clueGridAssignments = clueGridAssignments;
		this.densityGrid = densityGrid;
		if (densityGrid == null) {
			totalDensity = 0;
		} else {
			double totalDensity_ = 0.0;
			for (int i = 0; i < densityGrid.length; i++) {
				totalDensity_ += densityGrid[i];
			}
			totalDensity = totalDensity_;
		}
		this.kld = kld;
		this.kldThreshold = kldThreshold;
		this.kldFreqThreshold = kldFreqThreshold;
		this.normalDistribution = normalDistribution;
		if (!(normalDistribution == null || M * M == normalDistribution.length)) {
			throw new Exception("M=" + M + ", so there must be " + (M * M) + " normalDistribution values");
		}
		doKldTest = kldThreshold > 0 && kld < kldThreshold;
		doKldFreqTest = normalDistribution != null && doKldTest;
		this.minSplit = minSplit;
	}

	public Separatrix(final int[] clueEventCounts, final double[][] clueDistances, final int[] tooLow, final int M,
			final int[] clueGridAssignments, final double[] density, final double kld,
			final double[] normalDistribution, final double kldThreshold) throws Exception {
		this(clueEventCounts, clueDistances, tooLow, M, clueGridAssignments, density, kld, normalDistribution,
				kldThreshold, .0075, 0);
	}

	final static int[] empty = new int[0];
	final int minSplit;

	public int getMinSplit() {
		return minSplit;
	}

	final double[][] clueDistances;

	public double[][] getDists() {
		return clueDistances;
	}

	final int numClues;

	public int getNumClusters() {
		return numClues;
	};

	final String[] clueLetters;

	public String[] getClusterLetters() {
		return clueLetters;
	}

	final int[] tooLow;

	public int[] getTooLow() {
		return tooLow;
	}

	final int[] clueCnts4Balanced, clueCnts4MinSplit;

	public int[] getClusterCountsForBalanced() {
		return clueCnts4Balanced;
	}

	public int[] getClusterCountsForMinSplit() {
		return clueCnts4MinSplit;
	}

	final int totalEventCount, totalClueCnt4MinSplit;

	public int getTotalEventCount() {
		return totalEventCount;
	}

	ArrayList<int[]> groupsOfClues = null; // clues are 1 based cluster indexes
	ArrayList<Double> separatracies = null;

	public Separatrix(final int[] clueEventCounts, final double[][] clueDistances, final int[] tooLow)
			throws Exception {
		this(clueEventCounts, clueDistances, tooLow, clueDistances == null ? 0 : clueDistances.length, null, null, 0.0,
				null, 0.0);
	}

	final int[] clueGridAssignments;

	public int[] getClusterGridAssignments() {
		return clueGridAssignments;
	}

	final double[] densityGrid;

	public double[] getDensityGrid() {
		return densityGrid;
	}

	final int M;

	public int getM() {
		return M;
	}

	final double totalDensity;

	public double getTotalDensity() {
		return totalDensity;
	}

	public Separatrix(final int M, final int[] clueGridAssignments, final double[] density) throws Exception {
		this(null, null, null, M, clueGridAssignments, density, 0.0, null, 0.0);
	}

	final double kld, kldThreshold, kldFreqThreshold;

	public double getKld() {
		return kld;
	};

	public double getKldThreshold() {
		return kldThreshold;
	};

	public double getKldFreqThreshold() {
		return kldFreqThreshold;
	};

	final double[] normalDistribution;

	public double[] getKldNormal() {
		return normalDistribution;
	}

	final boolean doKldTest, doKldFreqTest;

	void resolveBestIdx() {
		final int N = separatracies.size();
		if (N == 1) {
			worstIdx = -1;
		}
		for (int i = 0; i < N; i++) {
			final double sptx = separatracies.get(i);
			if (sptx == bestScore) {
				bestIdx = i;
				return;
			}
		}
	}

	void resolveBest() {
		final int N = separatracies.size();
		double best = 100;
		int idx = 0;
		for (int i = 0; i < N; i++) {
			final double sptx = separatracies.get(i);
			if (sptx < best) {
				idx = i;
				best = sptx;
			}
		}
		bestIdx = idx;
		bestScore = best;
	}

	void resolveWorst() {
		final int N = separatracies.size();
		double worst = -1;
		int idx = 0;
		for (int i = 0; i < N; i++) {
			final double sptx = separatracies.get(i);
			if (sptx > worst) {
				idx = i;
				worst = sptx;
			}
		}
		worstIdx = idx;
		worstScore = worst;
	}

	public void merge(final Collection<Separatrix> others) {
		for (Separatrix other : others) {
			groupsOfClues.addAll(other.groupsOfClues);
			separatracies.addAll(other.separatracies);
		}
		resolveBest();
		resolveWorst();
	}

	public void compute() {
		compute(0);
	}

	private void initScoring(final int numberOfTopScoresToKeep) {
		possibleGroups = 0;
		bestScore = 100;
		worstIdx = 0;
		worstScore = -1.0;
		separatracies.clear();
		groupsOfClues.clear();
		int maxScores = count(numClues);
		if (numberOfTopScoresToKeep > 0 && numberOfTopScoresToKeep < maxScores)
			maxScores = numberOfTopScoresToKeep;
		separatracies.ensureCapacity(maxScores);
		groupsOfClues.ensureCapacity(maxScores);
		if (numberOfTopScoresToKeep < 0) {
			System.err.println("Top score count of " + numberOfTopScoresToKeep + ", re-interpreted as 0... all scores");
			this.numberOfTopScoresToKeep = 0;
		} else {
			this.numberOfTopScoresToKeep = numberOfTopScoresToKeep;
		}
	}

	public void compute(final int numberOfTopScoresToKeep) {
		if (numClues == 0) {
			System.err.println("Clusters not defined");
			return;
		}
		initScoring(numberOfTopScoresToKeep);
		final int half = numClues / 2;
		for (int i = 1; i <= half; i++) {
			addGroupsOfClusters(i, groupRule, true);
		}
		resolveBestIdx();
		if (verboseFlags > 0 && verboseFlags != 16) {
			printResult();
		}
	}

	public void printResult() {
		printResult(System.out);
	}

	public void printResult(final PrintStream ps) {
		ps.println("For all groups grid " + M + "x" + M + ", " + numClues + " clusters & edge rule #" + edgeRule
				+ "\n\t-best score is " + toString(getBestScore()) + " " + Arrays.toString(getBestClusterGroup())
				+ "\n\t-worst score is " + toString(getWorstScore()) + Arrays.toString(getWorstClusterGroup()));
		ps.println();
	}

	public int[][] toArray() {
		return groupsOfClues.toArray(new int[0][]);
	}

	public String toLetters(final int[] clues) {
		final StringBuilder sb = new StringBuilder();

		for (int j = 0; j < clues.length; j++) {
			sb.append(clueLetters[clues[j] - 1]);
			if (j < clues.length - 1) {
				sb.append(",");
			}
		}
		return sb.toString();

	}

	public String[] toLetters() {
		final String[] out = new String[groupsOfClues.size()];
		for (int i = 0; i < out.length; i++) {
			out[i] = toLetters(groupsOfClues.get(i));
		}
		return out;
	}

	public int[] getOtherClusters(final int[] clues) {
		/*
		 * clues are 1 based cluster indexes
		 */
		if (clues == null) {
			return empty;
		}
		final int n = clues.length;
		final int out[] = new int[this.numClues - n];
		int k = 0;
		for (int i = 1; i <= this.numClues; i++) {
			boolean found = false;
			for (int j = 0; j < n; j++) {
				if (i == clues[j]) {
					found = true;
					break;
				}
			}
			if (!found) {
				out[k++] = i;
			}
		}
		return out;
	}

	boolean allAreTooLow(final int[] clues) {
		if (clues == null || clues.length == 0) {
			return false;
		}
		for (int i = 0; i < clues.length; i++) {
			for (int j = 0; j < tooLow.length; j++) {
				if (clues[i] != tooLow[j]) {
					return false;
				}
			}
		}
		return true;
	}

	public boolean isContiguous(final int[] clues) {
		/*
		 * clues are 1 based cluster indexes
		 */
		if (numClues < 3) {
			return true;
		}
		final int[] otherClues = getOtherClusters(clues);
		if (tooLow != null && tooLow.length > 0) {
			if (allAreTooLow(clues) || allAreTooLow(otherClues)) {
				return false;
			}
		}
		final ContiguityChecker cc = new ContiguityChecker();
		if (!cc.isContiguous(clues)) {
			return false;
		}
		if (!cc.isContiguous(otherClues)) {
			return false;
		}
		return true;
	}

	class ContiguityChecker {
		// work "scratch pad" variables
		int[] clues; // clues are 1 based cluster indexes
		int N1;
		final TreeSet<Integer> alreadyDone = new TreeSet<>();

		boolean isContiguous(final int[] clues) {
			if (clues.length == 1) {
				return true;
			}
			this.clues = clues;
			N1 = clues.length;

			int fromClue = clues[0];
			for (int i = 1; i < clues.length; i++) {
				alreadyDone.clear();
				final int toClue = clues[i];
				alreadyDone.add(toClue);
				if (!isContiguous(fromClue, toClue)) {
					return false;
				}
			}
			return true;
		}

		boolean isContiguous(final int fromClue, final int toClue) {
			if (clueDistances[fromClue - 1][toClue - 1] <= 1.0) {
				return true;
			}
			alreadyDone.add(fromClue);
			if (N1 - alreadyDone.size() < 1) {
				return false;
			}
			for (int i = 0; i < N1; i++) {
				final int clue = clues[i];
				if (clueDistances[(int) (fromClue - 1)][(int) (clue - 1)] <= 1.0) {
					if (!alreadyDone.contains(clue)) {
						if (isContiguous(clue, toClue)) {
							return true;
						}
					}
				}
			}
			return false;
		}
	}

	public static boolean isExactlyHalf(final int N, final int K) {
		return (N % 2) == 0 && K == N / 2;
	}

	public static int count(final int N) {
		return (int) (Math.pow(2, N - 1) - 1);
	}

	public static int count(final int N, final int K) {
		int count = 1;
		for (int i = 1; i <= K; ++i) {
			count *= N - i + 1;
			count /= i;
		}
		return count;
	}

	boolean balanced = true;

	public boolean getBalanced() {
		return balanced;
	}

	public void setBalanced(final boolean yes) {
		balanced = yes;
	}

	final static int GROUP_ANY = 3, GROUP_CONTIGUOUS = 2, GROUP_SCORE = 1;
	int groupRule = GROUP_SCORE;

	public void setRuleGroup1_SeparatrixScore() {
		groupRule = GROUP_SCORE;
	};

	public void setRuleGroup2_Contiguous() {
		groupRule = GROUP_CONTIGUOUS;
	};

	public void setRuleGroup3_Any() {
		groupRule = GROUP_ANY;
	};

	double worstScore, bestScore;
	int worstIdx, bestIdx;
	int numberOfTopScoresToKeep = 10;
	public int verboseFlags = 0;

	public int getCount4Balanced(final int[] clues) {
		int cnt = 0;
		for (int clue : clues) {
			cnt += clueCnts4Balanced[clue - 1];
		}
		return cnt;
	}

	public int getCount4MinSplit(final int[] clues) {
		int cnt = 0;
		for (int clue : clues) {
			cnt += clueCnts4MinSplit[clue - 1];
		}
		return cnt;
	}

	public double getKldFreq(final int[] clues) {
		final int[] part1Inds = get1stPartInds(clues);
		final int[] borderCounts = new int[4];
		final int[] sptxInds = findEdges(part1Inds, edgeRule, borderCounts);
		int[] map012 = null;
		double[] actual = null, normal = null;

		map012 = makeMap012(part1Inds, sptxInds);
		actual = sumMap012(map012, densityGrid);
		normal = sumMap012(map012, normalDistribution);
		return tallySumsOfMap012(actual, normal);
	}

	public class Border {
		public int[] least = new int[4], most = new int[4];
		public final ArrayList<int[]> c = new ArrayList<>();
		public final int[][] edge;

		Border(final int[][] xy) {
			for (int i = 0; i < 4; i++) {
				least[i] = M + 1;
			}
			ranges(xy);

			edge = add();
		}

		void ranges(final int[][] xy) {
			final int N = xy.length;
			for (int i = 0; i < N; i++) {
				final int x = xy[i][0];
				final int y = xy[i][1];
				// go clockwise through borders
				if (x == 1) {// TOP
					range(0, y);
				} else if (y == M) { // RIGHT
					range(1, x);
				} else if (x == M) {// BOTTOM
					range(2, y);
				} else if (y == 1) { // LEFT
					range(3, x);
				}
			}
		}

		void range(final int borderIdx, final int n) {
			if (n < least[borderIdx])
				least[borderIdx] = n;
			if (n > most[borderIdx]) {
				most[borderIdx] = n;
			}
		}

		int[][] add() {
			// add xy points going clockwise through borders
			add(0, 1, 0, 1);// TOP
			add(1, M, 1, 0);// RIGHT
			add(2, M, 0, 1);// BOTTOM
			add(3, 1, 1, 0);// LEFT
			return c.toArray(new int[0][]);
		}

		void add(final int borderIdx, final int borderValue, final int borderXyIdx, final int otherXyIdx) {
			if (least[borderIdx] < M + 1) {
				int[] xy = new int[2];
				xy[borderXyIdx] = borderValue;
				xy[otherXyIdx] = least[borderIdx];
				c.add(xy);
				if (most[borderIdx] != least[borderIdx]) {
					xy = new int[2];
					xy[borderXyIdx] = borderValue;
					xy[otherXyIdx] = most[borderIdx];
					c.add(xy);
				}
			}
		}

		boolean needToDelete(final int[] point) {
			if (point[0] == 1 || point[0] == M || point[1] == 1 || point[1] == M) {
				for (int i = 0; i < edge.length; i++) {
					if (edge[i][0] == point[0] && edge[i][1] == point[1]) {
						return false;
					}
				}
				return true;
			}
			return false;
		}

	}

	public class Polygon {
		public final int[] clues;
		public final int[][] edgeXy, part1Xy;
		final int[] edgeInds, part1Ind;
		final Border border;
		final GridBoundary gb;

		public int [][]simplify(final int[][]curve, final double densityW){
			final ArrayList<int[]>out=CurveSimplifier.Run(curve, densityW);
			return out.toArray(new int[0][]);
		}

		Polygon(final int[] clues, final double densityW) {
			this.clues = clues;
			part1Ind = get1stPartInds(clues);
			part1Xy = ind2Sub(M, part1Ind);
			edgeInds = findEdges(part1Ind, EDGE_WITH_OTHER_ONLY);// EDGE_WITH_OTHER_ONLY);
			edgeXy = ind2Sub(M, edgeInds);
			border = new Border(edgeXy);
			gb = new GridBoundary(part1Xy, edgeXy, M);
			gb.compute(border, densityW);
		}

		public boolean isGood()  {
			return gb.isTruePolygon;
		}

		public void print(final PrintStream out) {
			out.print("For clues:  [");
			for (int i = 0; i < clues.length; i++) {
				out.print(clues[i]);
				if (i < clues.length - 1)
					out.print(",");
			}
			out.println("]");
			Basics.print(out, "xySplit=", edgeXy);
			//Basics.print(out, "clockwise= ", Basics.clockwise(edgeXy));
			// Basics.print(out, "orderEdge=", orderEdge(xy, M));
			Basics.print(out, "border edge=", border.edge);
			if (gb.isTruePolygon) {
				Basics.print(out, "polygonForPart1=", getPoints(true));
				out.println("Sptx.TestPolygon2(polygonForPart1, " + M + ")");
				Basics.print(out, "polygonForPart2=", getPoints(false));
				out.println("Sptx.TestPolygon2(polygonForPart2, " + M + ")");
				
			} else {
				Basics.print(out, "badPoly=", gb.line.toArray(new int[0][]));
				out.println("Sptx.TestPolygon2(badPoly, " + M + ")");
			}
			out.println();
		}

		public void print() {
			print(System.out);
		}

		public int [][]getPoints(final boolean isPart1){
			return gb.getPolygon(isPart1);
		}
		

	}

	double densityW=.006; // good for Eliver and Cytek data
	public void printPolygon(final int clue) {
		getPolygon(new int[] { clue }, densityW).print();
	}

	public void printPolygon() {
		getPolygon(getBestClusterGroup(), densityW).print();
	}

	public void printPolygon(final int[] clues) {
		getPolygon(clues, densityW).print();
	}

	public Polygon getPolygon(final int[] clues) {
		return new Polygon(clues, densityW);
	}

	public Polygon getPolygon() {
		return new Polygon(getBestClusterGroup(), densityW);
	}

	public Polygon getPolygon(final int[] clues, final double densityW) {
		return new Polygon(clues, densityW);
	}

	public Polygon getPolygon(final double densityW) {
		return new Polygon(getBestClusterGroup(), densityW);
	}

	public int[] getBest() {
		return get(getBestClusterGroup());
	}

	public int[] get(final int[] clues) {
		return findEdges(get1stPartInds(clues), edgeRule);
	}

	public int [][] getXy(final int []clues) {
		int []part1Ind = get1stPartInds(clues);
		return ind2Sub(M, part1Ind);
		
	}
	public double getScore(final int[] clues, final int verboseFlags) {
		final int cnt = getCount4Balanced(clues);
		final int[] part1Inds = get1stPartInds(clues);
		final int[] borderCounts = new int[4];
		final int[] sptxInds = findEdges(part1Inds, edgeRule, borderCounts);
		double sptx = computeDensity(sptxInds);
		double P = 0, rawSptx = sptx;
		if (balanced) {
			P = (double) cnt / (double) totalEventCount;
			sptx /= (4 * P * (1 - P));
		}
		int[] map012 = null;
		double[] actual = null, normal = null;
		;
		double kldFreq = 0;
		if (doKldTest) {
			if (doKldFreqTest) {
				map012 = makeMap012(part1Inds, sptxInds);
				actual = sumMap012(map012, densityGrid);
				normal = sumMap012(map012, normalDistribution);
				kldFreq = tallySumsOfMap012(actual, normal);
				if (kldFreq < kldFreqThreshold) {
					sptx = 1;
				}
			} else {
				sptx = 1;
			}
		}
		if (sptx < 1) {
			int borderCount = 0;
			for (int i = 0; i < borderCounts.length; i++) {
				if (borderCounts[i] > 0) {
					borderCount++;
				}
			}
			if (borderCount < 2) {
				if (borderCount == 1) {
					sptx += .05;
				} else {
					sptx += .1;
				}
				if (sptx > 1) {
					sptx = 1;
				}
			}
		}
		if (verboseFlags == 0 || verboseFlags == 16) { // normal production run
			return sptx;
		}
		// debug info required
		System.out.print("For clusters [");
		System.out.print(Arrays.toString(clues));
		System.out.print("](");
		System.out.print(toLetters(clues));
		System.out.print(") separatrix=");
		System.out.print(toString(sptx));
		if ((verboseFlags & 2) == 2) {
			if (sptx != rawSptx) {
				System.out.print("(raw=");
				System.out.print(toString(rawSptx));
				if (balanced) {
					System.out.print(", P=");
					if (P > .5)
						System.out.print(toString(1.0 - P));
					else
						System.out.print(toString(P));
					System.out.print(", adjusted=");
					System.out.print(toString(rawSptx / (4 * P * (1 - P))));
				}
				System.out.print(")");
			} else {
				System.out.print(" (no adjusting)");
			}
		}
		System.out.println();
		if ((verboseFlags & 1) == 1) {
			System.out.println("\tisContiguous=" + isContiguous(clues));
		}
		if ((verboseFlags & 4) == 4) {
			System.out.print("\tborders=[");
			System.out.println("]");
		}
		if ((verboseFlags & 8) == 8) {
			if (normalDistribution == null) {
				System.out.println("\tNo KLD normal distribution");
			} else {
				System.out.print("\tkld=");
				System.out.print(kld);
				System.out.print(", threshold=");
				System.out.print(kldThreshold);
				if (doKldTest) {
					if (doKldFreqTest) {
						System.out.print(", freq=");
						System.out.print(Numeric.encodeRounded(kldFreq, 4));
						if (kldFreq > kldFreqThreshold) {
							System.out.print(" > ");
						} else {
							System.out.print(" LESS than ");
						}
						System.out.print(kldFreqThreshold);
						System.out.print(", actual=[");
						System.out.print(toString(actual));
						System.out.print("], normal=[");
						System.out.print(toString(normal));
						System.out.println("]");
					} else {
						System.out.println(" ... KLD too low!");
					}
				} else {
					System.out.println(" ... no KLD test needed!");
				}
			}
		}
		return sptx;
	}

	int possibleGroups = 0;
	int nThreads = 0;
	int myThread = 0;

	public void computeInParallel(final int nThreads) throws Exception {
		computeInParallel(nThreads, 0);
	}

	public void computeInParallel(final int nThreads, final int numberOfTopScoresToKeep) throws Exception {
		if (nThreads < 2) {
			System.err.println("nThreads must be > 1 to run in parallel");
			compute(numberOfTopScoresToKeep);
			return;
		}
		initScoring(numberOfTopScoresToKeep);
		this.nThreads = nThreads;
		final Collection<Separatrix> others = new ArrayList<>();
		for (int i = 1; i < nThreads; i++) {
			final Separatrix other = new Separatrix(this);
			other.nThreads = nThreads;
			other.myThread = i;
			others.add(other);
		}
		this.numberOfTopScoresToKeep = numberOfTopScoresToKeep;
		latch = new CountDownLatch(others.size() + 1);
		if ((verboseFlags & 16) == 16) {
			System.out.println("Starting " + nThreads + " threads");
		}
		for (final Separatrix other : others) {
			other.latch = latch;
			final Thread t = new Thread(other);
			t.start();
		}
		final Thread t = new Thread(this);
		t.start();
		try {
			latch.await();
		} catch (final Exception e) {
			e.printStackTrace(System.err);
		}
		merge(others);
		if ((verboseFlags & 16) == 16) {
			printResult();
		}
	}

	public void addGroupOfClusters(final int[] clues) {
		possibleGroups++;
		if (nThreads > 0) {
			if ((possibleGroups % nThreads) != myThread) {
				if ((verboseFlags & 32) == 32) {
					System.out.println("\t\t(thread #" + myThread + " AVOIDS #" + possibleGroups);
				}
				return;
			}
			if ((verboseFlags & 16) == 16) {
				System.out.println("** thread #" + myThread + " DOES  #" + possibleGroups + Arrays.toString(clues));
			}
		}
		if (groupRule != GROUP_ANY) {
			final int cnt4MinSplit = getCount4MinSplit(clues);
			if (minSplit > 0 && (cnt4MinSplit < minSplit || totalClueCnt4MinSplit - cnt4MinSplit < minSplit)) {
				if ((verboseFlags & 1) == 1) {
					if (cnt4MinSplit < minSplit) {
						System.out.println("Size of " + Arrays.toString(clues) + "(" + toLetters(clues) + ") is "
								+ cnt4MinSplit + "... < " + minSplit);
					} else {
						final int[] other = getOtherClusters(clues);
						System.out.println("Size of " + Arrays.toString(other) + "(" + toLetters(other) + ") is "
								+ cnt4MinSplit + "... < " + minSplit);
					}
				}
			} else if (isContiguous(clues)) {
				if (groupRule != GROUP_SCORE) {
					groupsOfClues.add(clues);
					separatracies.add(Double.NaN);
				} else {
					final double sptx = getScore(clues, verboseFlags);
					if (numberOfTopScoresToKeep > 0 && groupsOfClues.size() >= numberOfTopScoresToKeep) {
						if (sptx < worstScore) {
							groupsOfClues.set(worstIdx, clues);
							separatracies.set(worstIdx, sptx);
							if (sptx < bestScore) {
								bestScore = sptx;
							}
							resolveWorst();
						}
					} else {
						if (sptx > worstScore) {
							worstScore = sptx;
							worstIdx = separatracies.size();
						}
						if (sptx < bestScore) {
							bestScore = sptx;
						}
						groupsOfClues.add(clues);
						separatracies.add(sptx);

					}
					if ((verboseFlags & 2) == 2) {
						if (sptx == bestScore || sptx == worstScore) {
							if (groupsOfClues.size() > 1) {
								if (sptx == bestScore) {
									System.out.println("\t\tBEST score so far");
								} else if (sptx == worstScore) {
									System.out.println("\t\tWORST score so far");
								}
							}
						}
					}
				}
			} else {
				if ((verboseFlags & 1) == 1) {
					System.out.println("Not contiguous: " + Arrays.toString(clues) + "(" + toLetters(clues) + ")");
				}
			}
		} else {
			groupsOfClues.add(clues);
		}
	}

	public void addGroupsOfClusters(final int K) {
		addGroupsOfClusters(K, GROUP_SCORE, true);
	}

	public void addGroupsOfClusters(final int K, final int groupRule, final boolean doHalfIfEvenNumber) {
		this.groupRule = groupRule;
		int nGroups = count(numClues, K);
		if (doHalfIfEvenNumber && isExactlyHalf(numClues, K)) {
			nGroups /= 2;
		}
		final int nOthers = K - 1;
		if (nOthers < 1) {
			if (numClues == 2) {
				addGroupOfClusters(new int[] { 1 });
			} else {
				for (int i = 1; i <= numClues; i++) {
					addGroupOfClusters(new int[] { i });
				}
			}
			return;
		}
		final int last1stMember = numClues - nOthers;
		int[] otherIdxOffsets = new int[nOthers];
		int iGroup = 0;
		for (int idxMember1 = 1; idxMember1 <= last1stMember; idxMember1++) {
			for (int j = 1; j <= nOthers; j++) {
				otherIdxOffsets[j - 1] = j;
			}
			final int lastOtherOffset = numClues - idxMember1;
			for (;;) {
				if (++iGroup > nGroups) {
					return;
				}
				final int[] clues = new int[K];// clues are 1 based cluster indexes
				clues[0] = idxMember1;
				int i = 0;
				for (; i < nOthers; i++) {
					clues[i + 1] = idxMember1 + otherIdxOffsets[i];
				}
				addGroupOfClusters(clues);
				i--;
				if (otherIdxOffsets[i] == lastOtherOffset) {
					boolean goToNextMember1 = true;
					for (i = i - 1; i >= 0; i--) {
						if (otherIdxOffsets[i] < lastOtherOffset - (nOthers - (i + 1))) {
							otherIdxOffsets[i]++;
							int add = otherIdxOffsets[i] + 1;
							for (int j = i + 1; j < nOthers; j++) {
								otherIdxOffsets[j] = add++;
							}
							goToNextMember1 = false;
							break;
						}
					}
					if (goToNextMember1) {
						break;
					}
				} else {
					otherIdxOffsets[i]++;
				}
			}
		}
	}

	public void printGroupsOfClues() {
		printGroupsOfClues(System.out);
	}

	public void printGroupsOfClues(PrintStream out) {
		if (out == null) {
			out = System.out;
		}
		int[][] done = toArray();
		final String[] letters = toLetters();
		for (int i = 0; i < done.length; i++) {
			out.print('#');
			out.print(i + 1);
			out.print(", ");
			out.print(Arrays.toString(done[i]));
			out.print("(");
			out.print(letters[i]);
			out.println(")");
		}
	}

	public boolean[] get1stSide(final int[] clues) {
		final int N = clueGridAssignments.length, NN = clues.length;
		final boolean[] side = new boolean[N];
		for (int i = 0; i < N; i++) {
			for (int j = 0; j < NN; j++) {
				if (clueGridAssignments[i] == clues[j]) {
					side[i] = true;
					break;
				}
			}
		}
		return side;
	}

	public int[] makeMap012(final int[] part1Inds, final int[] sptxInds) {
		int[] out = new int[M * M];
		int N = part1Inds.length;
		for (int i = 0; i < N; i++) {
			out[part1Inds[i] - 1] = 1;
		}
		N = sptxInds.length;
		for (int i = 0; i < N; i++) {
			out[sptxInds[i] - 1] = 2;
		}
		return out;
	}

	public double[] sumMap012(final int[] map012, final double[] data) {
		double[] sum = new double[3];
		final int N = map012.length;
		double total = 0;
		for (int i = 0; i < N; i++) {
			sum[map012[i]] += data[i];
			total += data[i];
		}
		for (int i = 0; i < 3; i++) {
			sum[i] /= total;
		}
		return sum;
	}

	public double tallySumsOfMap012(final double[] sum1, final double[] sum2) {
		final int N = sum1.length;
		double out = 0;
		for (int i = 0; i < N; i++) {
			if (sum1[i] != 0.0 && sum2[i] != 0.0) {
				out += sum1[i] * (Math.log(sum1[i]) - Math.log(sum2[i]));
			}
		}
		return out;
	}

	public int[] get1stPartInds(final int[] clues) {
		final int N = clueGridAssignments.length, NN = clues.length;
		final List<Integer> l = new ArrayList<Integer>();
		for (int i = 0; i < N; i++) {
			for (int j = 0; j < NN; j++) {
				if (clueGridAssignments[i] == clues[j]) {
					l.add(i + 1); // 1 based vector indexes for MATLAB compatible
					break;
				}
			}
		}
		final int N2 = l.size();
		final int[] clueInds = new int[N2];
		for (int i = 0; i < N2; i++) {
			clueInds[i] = l.get(i);
		}
		return clueInds;
	}

	public double getDensityWithOtherOrGrid(final int[] clues) {
		return getDensity(clues, EDGE_WITH_OTHER_OR_GRID);
	}

	public double getDensityWithOtherNotGrid(final int[] clues) {
		return getDensity(clues, EDGE_WITH_OTHER_NOT_GRID);
	}

	public double getDensityWithOtherOnly(final int[] clues) {
		return getDensity(clues, EDGE_WITH_OTHER_ONLY);
	}

	public double getDensity(final int[] clues) {
		return getDensity(clues, edgeRule);
	}

	public double getDensity(final int[] clues, final int edgeRule) {
		return computeDensity(this.getEdge(clues, edgeRule));
	}

	public double computeDensity(final int[] inds) {
		// inds are 1 based MATLAB indexes
		double sptx = 0.0;
		for (int i = 0; i < inds.length; i++) {
			final int ind = inds[i];
			// inds are 1 based MATLAB indexes
			sptx += densityGrid[ind - 1];
		}
		return sptx / totalDensity;
	}

	int edgeRule = EDGE_WITH_OTHER_NOT_GRID; // the behavior of EPP from 2018-April 2021
	final static int EDGE_WITH_OTHER_NOT_GRID = 1, EDGE_WITH_OTHER_ONLY = 2, // new idea that uses cluster grid bin on
																				// grid border edge if it borders other
																				// clusters
			EDGE_WITH_OTHER_OR_GRID = 3;

	public int getRuleEdge() {
		return edgeRule;
	}

	void setRuleEdge(final int rule) {
		edgeRule = rule;
		if (verboseFlags > 0)
			System.out.println("\n** NEW edge rule: #" + edgeRule);
	}

	public void setRuleEdge1_OtherClusterNotGridBorder() {
		setRuleEdge(EDGE_WITH_OTHER_NOT_GRID);
	}

	public void setRuleEdge2_OtherClusterOnly() {
		setRuleEdge(EDGE_WITH_OTHER_ONLY);
	}

	public void setRuleEdge3_OtherClusterOrGridBorder() {
		setRuleEdge(EDGE_WITH_OTHER_OR_GRID);
	}

	public int[] getEdgeWithOtherOrGrid(final int[] clues) {
		return findEdges(get1stPartInds(clues), EDGE_WITH_OTHER_OR_GRID);
	}

	public int[] getEdgeWithOtherNotGrid(final int[] clues) {
		return findEdges(get1stPartInds(clues), EDGE_WITH_OTHER_NOT_GRID);
	}

	public int[] getEdgeWithOtherOnly(final int[] clues) {
		return findEdges(get1stPartInds(clues), EDGE_WITH_OTHER_ONLY);
	}

	int[] getEdge(final int[] clues, final int edgeRule) {
		return findEdges(get1stPartInds(clues), edgeRule);
	}

	int[] findEdges(final int[] clueInds, final int edgeRule) {
		final int[] borderCounts = new int[4];
		return findEdges(clueInds, edgeRule, borderCounts);
	}

	int[] findEdges(final int[] clueInds, final int edgeRule, int[] borderCounts) {
		final boolean[] clueArea = new boolean[M * M + 2];
		final int N = clueInds.length;
		for (int i = 0; i < N; i++) {
			clueArea[clueInds[i]] = true;
		}
		final List<Integer> ux = new ArrayList<Integer>();
		final List<Integer> uy = new ArrayList<Integer>();
		final boolean[][] anyEdge = new boolean[M + 1][M + 1];
		final boolean[][] gridEdge = new boolean[M + 1][M + 1];
		final boolean[][] nonClueEdge = new boolean[M + 1][M + 1];
		for (int i = 0; i < N; i++) {
			final int b = clueInds[i];

			final int x = ((b - 1) % M) + 1;
			final int y = (b - 1) / M + 1;
			/*
			 * if (x==0 || y==0) { System.out.println("herp"); } if (x==M || y==M) {
			 * System.out.println("herp"); }
			 */
			for (int xI = -1; xI < 2; xI++) {
				int x2 = x + xI;
				boolean xOnGridEdge = false;
				if (x2 < 1) {
					x2 = 1;
					xOnGridEdge = true;
					borderCounts[0]++;
				} else if (x2 > M) {
					x2 = M;
					xOnGridEdge = true;
					borderCounts[1]++;
				}

				for (int yI = -1; yI < 2; yI++) {
					int y2 = y + yI;
					boolean onGridEdge = xOnGridEdge;
					if (!onGridEdge) {
						if (y2 < 1) {
							y2 = 1;
							onGridEdge = true;
							borderCounts[2]++;
						} else if (y2 > M) {
							y2 = M;
							onGridEdge = true;
							borderCounts[3]++;
						}
					}
					if (edgeRule == EDGE_WITH_OTHER_OR_GRID) {
						// include every clue edge

						if (onGridEdge || !clueArea[(y2 - 1) * M + x2]) {
							anyEdge[x][y] = true;
							ux.add(x);
							uy.add(y);
							break;
						}
					} else {
						if (onGridEdge) {
							gridEdge[x][y] = true;
						} else if (!clueArea[(y2 - 1) * M + x2]) {
							nonClueEdge[x][y] = true;
						}
					}
				}
				if (edgeRule == EDGE_WITH_OTHER_OR_GRID) {
					if (anyEdge[x][y]) {
						break;
					}
				}
			}
			if (edgeRule != EDGE_WITH_OTHER_OR_GRID) {
				if (nonClueEdge[x][y]) {
					if (edgeRule == EDGE_WITH_OTHER_NOT_GRID) {
						if (!gridEdge[x][y]) {
							ux.add(x);
							uy.add(y);
						}
					} else if (edgeRule == EDGE_WITH_OTHER_ONLY) {
						ux.add(x);
						uy.add(y);
					}
				}
			}
		}
		final int N2 = ux.size();
		final int[] out = new int[N2];
		for (int i = 0; i < N2; i++) {
			out[i] = ((uy.get(i) - 1) * M) + ux.get(i);
		}
		return out;
	}

	static class GridBoundary {

		private void compute(final Border border, final double densityW) {
			if (line.size() == 0) {
				draw(border, densityW);
			}
		}

		GridBoundary(final int[][] part1Xy, final int[][] edge, final int M) {
			this.part1Xy = part1Xy;
			meanX = (int) Math.round(Basics.mean(part1Xy, 0));
			meanY = (int) Math.round(Basics.mean(part1Xy, 1));
			N = edge.length;
			this.M = M;
			shouldDraw = new boolean[M + 1][M + 1];
			for (int i = 0; i < N; i++) {
				shouldDraw[edge[i][0]][edge[i][1]] = true;
			}
			directNeighbors = new int[M + 1][M + 1][][];
			indirectNeighbors = new int[M + 1][M + 1][][];
			ArrayList<int[]> directs = new ArrayList<>(), indirects = new ArrayList<>();
			int dist = Integer.MAX_VALUE;
			for (int i = 0; i < N; i++) {
				directs.clear();
				indirects.clear();
				final int x = edge[i][0], y = edge[i][1];
				if (x + y < dist) {
					dist = x + y;
					closestToOrigin[0] = x;
					closestToOrigin[1] = y;
				}
				final Range rows = new Range(x), cols = new Range(y);
				for (int row = rows.start; row < rows.end; row++) {
					for (int col = cols.start; col < cols.end; col++) {
						if (col != 0 || row != 0) { // skip self
							final int x2 = x + row, y2 = y + col;
							if (shouldDraw[x2][y2]) {
								if (col == 0 || row == 0) { // only direct neighbor same x or y
									directs.add(new int[] { x2, y2 });
								} else {
									indirects.add(new int[] { x2, y2 });
								}
							}
						}
					}
				}
				int[][] result = directs.toArray(empty);
				directNeighbors[x][y] = result;
				result = indirects.toArray(empty);
				indirectNeighbors[x][y] = result;
			}
		}

		boolean isTruePolygon = false;
		final int meanX, meanY;
		final boolean[][] shouldDraw;
		final int[][] part1Xy;
		final int N, M;
		final int[][][][] directNeighbors, indirectNeighbors;
		final static int[][] empty = new int[0][];
		final int[] closestToOrigin = new int[] {1,1};
		ArrayList<int[]> line = new ArrayList<>();

		class Range {
			final int start, end;

			Range(final int p) {
				if (p <= 1) {
					start = 0;
					end = 2;
				} else if (p == M) {
					start = -1;
					end = 1;
				} else {
					start = -1;
					end = 2;
				}

			}
		}

		int[] setDrawn(final int[] point) {
			if (point != null) {
				shouldDraw[point[0]][point[1]] = false;
				line.add(point);
			}
			return point;
		}

		private void draw(final Border border, final double densityW) {
			int[] point = null;
			if (border == null || border.edge == null || border.edge.length == 0)
				point = setDrawn(closestToOrigin);
			else
				point = setDrawn(border.edge[0]);
			while (point != null) {
				int[] next = nextPoint(true, directNeighbors, point);
				if (next == null)
					next = nextPoint(false, indirectNeighbors, point);
				point = setDrawn(next);
			}
			//line = smoothen(line);
			//System.out.print("Had "+line.size()+" points...");
			line=CurveSimplifier.Run(line, densityW);
			//System.out.println("Simplified down to "+line.size()+" points...");
			this.isTruePolygon = addPolygonPointsForPart1(part1Polygon);
			if (this.isTruePolygon) {
				addPolygonPointsForPart2(part2Polygon);
			}
		}
		
		
		final ArrayList<int[]> part1Polygon = new ArrayList<>(), 
				part2Polygon = new ArrayList<>();

		int[][] getPolygon(final boolean firstPart) {
			if (isTruePolygon) {
				final ArrayList<int[]> l = new ArrayList<>(line);
				if (firstPart)
					l.addAll(part1Polygon);
				else
					l.addAll(part2Polygon);
				return l.toArray(empty);
			}
			return null;
		}

		/**
		 * @param point
		 * @return neighbor of point that has the least direct neighbors that has not
		 *         been drawn
		 */
		int[] nextPoint(final boolean direct, int[][][][] neighbors, final int[] point) {
			int[] found = null;
			final int x = point[0], y = point[1];
			int leastNays = Integer.MAX_VALUE;
			int distToMean = 0;
			final Range rows = new Range(x), cols = new Range(y);
			for (int row = rows.start; row < rows.end; row++) {
				for (int col = cols.start; col < cols.end; col++) {
					if (col != 0 || row != 0) { // skip self
						final boolean good;
						if (col == 0 || row == 0) {
							good = direct;
						} else {
							good = !direct;
						}
						if (good) {// only direct neighbor same x or y
							final int x2 = x + row, y2 = y + col;
							if (shouldDraw[x2][y2]) {
								final int nays = countUndrawnNeighbors(direct, neighbors, x2, y2);
								if (nays <= leastNays) {
									boolean newFind = true;
									final int d2 = ((x2 - meanX) * (x2 - meanX)) + ((y2 - meanY) * (y2 - meanY));
									if (nays == leastNays) {
										if (d2 < distToMean)
											newFind = false;
										else if (found != null) {
											final int nays1 = countUndrawnNeighbors(direct, neighbors, x2, y2, x2 - x,
													y2 - y, x - found[0], y - found[1]);
											final int nays2 = countUndrawnNeighbors(direct, neighbors, found[0],
													found[1], found[0] - x, found[1] - y, x - x2, y - y2);
											if (nays1 > nays2) {
												newFind = false;
											}
										}
									}
									if (newFind) {
										found = new int[] { x2, y2 };
										distToMean = d2;
										leastNays = nays;
									}
								}
							}
						}
					}
				}
			}
			return found;
		}

		int countUndrawnNeighbors(final boolean direct, final int x, final int y) {
			int count = 0;
			final Range rows = new Range(x), cols = new Range(y);
			for (int row = rows.start; row < rows.end; row++) {
				for (int col = cols.start; col < cols.end; col++) {
					if (col != 0 || row != 0) { // skip self
						final int x2 = x + row, y2 = y + col;
						if (shouldDraw[x2][y2]) {
							if (col == 0 || row == 0) { // only direct neighbor same x or y
								if (direct)
									count++;
							} else {
								if (!direct)
									count++;
							}
						}
					}
				}
			}
			return count;
		}

		boolean isInsideBoundary(final int x, final int y) {
			final int N = part1Xy.length;
			for (int i = 0; i < N; i++) {
				if (part1Xy[i][0] == x && part1Xy[i][1] == y)
					return true;
			}
			return false;
		}

		int countUndrawnNeighbors(final boolean direct, final int[][][][] hood, final int x, final int y) {
			final int[][] neighbors = hood[x][y];
			if (neighbors != null) {
				int count = 0;
				for (int i = 0; i < neighbors.length; i++)
					if (shouldDraw[neighbors[i][0]][neighbors[i][1]])
						count++;
				return count;
			}
			if (isInsideBoundary(x, y))
				return countUndrawnNeighbors(direct, x, y);
			return 0;
		}

		int countUndrawnNeighbors(final boolean direct, final int[][][][] hood, final int x, final int y,
				final int difX1, final int difY1, final int difX2, final int difY2) {
			return countUndrawnNeighbors(direct, hood, x, y, difX1, difY1)
					+ countUndrawnNeighbors(direct, hood, x, y, difX2, difY2);
		}

		int countUndrawnNeighbors(final boolean direct, final int[][][][] hood, final int x, final int y,
				final int difX, final int difY) {
			final int nextX = x + difX;
			if (nextX < 1 || nextX > M)
				return 0;
			final int nextY = y + difY;
			if (nextY < 1 || nextY > M)
				return 0;
			return countUndrawnNeighbors(direct, hood, nextX, nextY);
		}

		static ArrayList<int[]> smoothen(final ArrayList<int[]> in) {
			final ArrayList<int[]> out = new ArrayList<>();
			final java.util.Iterator<int[]> it = in.iterator();
			out.add(it.next());
			out.add(it.next());
			int i = 1;
			while (it.hasNext()) {
				int[] point = it.next();
				final int x = point[0], y = point[1];
				int[] point1 = out.get(i);
				int[] point0 = out.get(i - 1);
				if (x == point1[0] && x == point0[0]) {
					out.set(i, point);
				} else if (y == point1[1] && y == point0[1]) {
					out.set(i, point);
				} else {
					out.add(point);
					i++;
				}
			}
			return out;
		}

		final static int NONE = 0, LEFT = 1, TOP = 2, RIGHT = 3, BOTTOM = 4;

		int getSide(int[] point) {
			if (point[1] == 1)
				return LEFT;
			if (point[0] == M)
				return TOP;
			if (point[0] == 1)
				return BOTTOM;
			if (point[1] == M)
				return RIGHT;
			return NONE;
		}

		boolean addPolygonPointsForPart1(final ArrayList<int[]> points) {
			final int[] first = line.get(0), last = line.get(line.size() - 1);
			final int firstSide = getSide(first), lastSide = getSide(last);
			if (firstSide == NONE || lastSide == NONE) {
				return false;
			}
			// x is height, y is width
			int[] topLeft = new int[] { M, 1 }, topRight = new int[] { M, M }, bottomLeft = new int[] { 1, 1 },
					bottomRight = new int[] { 1, M };
			if (firstSide == lastSide) {

			} else if ((firstSide == LEFT && lastSide == BOTTOM) || (firstSide == BOTTOM && lastSide == LEFT)) {
				points.add(bottomLeft); // bottom left corner
			} else if ((firstSide == LEFT && lastSide == TOP) || (firstSide == TOP && lastSide == LEFT)) {
				points.add(topLeft);// top left corner
			} else if ((firstSide == BOTTOM && lastSide == TOP)) {
				points.add(topLeft); // top left corner
				points.add(bottomLeft); // bottom left corner
			} else if ((firstSide == TOP && lastSide == BOTTOM)) {
				points.add(bottomLeft);// bottom left corner
				points.add(topLeft); // top left corner
			} else if ((firstSide == BOTTOM && lastSide == RIGHT) || (firstSide == RIGHT && lastSide == BOTTOM)) {
				points.add(bottomRight); // bottom right corner
			} else if (firstSide == LEFT && lastSide == RIGHT) {
				points.add(topRight); // top right corner
				points.add(topLeft); // top left corner
			} else if (firstSide == RIGHT && lastSide == LEFT) {
				points.add(topLeft); // top left corner
				points.add(topRight); // top right corner
			} else /*
					 * if( (start==TOP && end==RIGHT) || (start==RIGHT && end==TOP))
					 */ {
				points.add(topRight); // top right corner
			}
			points.add(first);
			return true;
		}

		boolean addPolygonPointsForPart2(final ArrayList<int[]> points) {
			// part 1 vs part 2
			// one 0 corner condition is four 4 corner conditions
			// four 1 corner conditions are eight 3 corner conditions
			final int[] first = line.get(0), last = line.get(line.size() - 1);
			final int firstSide = getSide(first), lastSide = getSide(last);
			if (firstSide == NONE || lastSide == NONE) {
				return false;
			}
			// x is height, y is width
			int[] topLeft = new int[] { M, 1 }, topRight = new int[] { M, M }, bottomLeft = new int[] { 1, 1 },
					bottomRight = new int[] { 1, M };
			if (firstSide == lastSide) {
				// part 1's one 9 corner condition is four 4 corner conditions

				if (firstSide == LEFT) {
					if (first[0] < last[0]) { // last point is higher on left side
						points.add(topLeft);
						points.add(topRight);
						points.add(bottomRight);
						points.add(bottomLeft);
					} else {// last point is lower on left side
						points.add(bottomLeft);
						points.add(bottomRight);
						points.add(topRight);
						points.add(topLeft);
					}
				} else if (firstSide == TOP) {
					if (first[1] < last[1]) {// last point is on right of top side
						points.add(topRight);
						points.add(bottomRight);
						points.add(bottomLeft);
						points.add(topLeft);
					} else {// last point is on left of top side
						points.add(topLeft);
						points.add(bottomLeft);
						points.add(bottomRight);
						points.add(topRight);
					}
				} else if (firstSide == BOTTOM) {
					if (first[1] < last[1]) {// last point is on right of bottom side
						points.add(bottomRight);
						points.add(topRight);
						points.add(topLeft);
						points.add(bottomLeft);
					} else {// last point is on left of bottom side
						points.add(bottomLeft);
						points.add(topLeft);
						points.add(topRight);
						points.add(bottomRight);
					}
				} else { // RIGHT
					if (first[0] < last[0]) {// last point is higher on right side
						points.add(topRight);
						points.add(topLeft);
						points.add(bottomLeft);
						points.add(bottomRight);
					} else {// last point is lower on right side
						points.add(bottomRight);
						points.add(bottomLeft);
						points.add(topLeft);
						points.add(topRight);
					}
				}
			}
			// part 1's 1 corner becomes 3
			else if (firstSide == LEFT && lastSide == BOTTOM) {
				points.add(bottomRight);
				points.add(topRight);
				points.add(topLeft);
			} else if (firstSide == BOTTOM && lastSide == LEFT) {
				points.add(topLeft);
				points.add(topRight);
				points.add(bottomRight);
			}
			// part 1's 1 corner becomes 3
			else if (firstSide == LEFT && lastSide == TOP) {
				points.add(topRight);
				points.add(bottomRight);
				points.add(bottomLeft);
			} else if (firstSide == TOP && lastSide == LEFT) {
				points.add(bottomLeft);
				points.add(bottomRight);
				points.add(topRight);
			} else if (firstSide == BOTTOM && lastSide == TOP) {
				points.add(topRight); // top left corner
				points.add(bottomRight);// bottom left corner
			} else if ((firstSide == TOP && lastSide == BOTTOM)) {
				points.add(bottomRight); // bottom left corner
				points.add(topRight); // top left corner
			}
			// part 1's 1 corner becomes 3
			else if (firstSide == BOTTOM && lastSide == RIGHT) {
				points.add(topRight);
				points.add(topLeft);
				points.add(bottomLeft);
			} else if (firstSide == RIGHT && lastSide == BOTTOM) {
				points.add(bottomLeft);
				points.add(topLeft);
				points.add(topRight);
			}

			else if (firstSide == LEFT && lastSide == RIGHT) {
				points.add(bottomRight); // top right corner
				points.add(bottomLeft); // top left corner
			} else if (firstSide == RIGHT && lastSide == LEFT) {
				points.add(bottomLeft); // top left corner
				points.add(bottomRight); // top right corner
			}
			// part 1's 1 corner becomes 3
			else if (firstSide == TOP && lastSide == RIGHT) {
				points.add(bottomRight);
				points.add(bottomLeft);
				points.add(topLeft);
			} else if (firstSide == RIGHT && lastSide == TOP) {
				points.add(topLeft);
				points.add(bottomLeft);
				points.add(bottomRight);
			}
			points.add(first);
			return true;
		}

	}

	public static int[][] orderEdge(int[][] xy, final int M) {
		final ArrayList<int[]> l = new ArrayList<>();
		Integer one = new Integer(1);
		int N = xy.length;
		for (int i = 0; i < N; i++) {
			l.add(xy[i]);
		}
		final HashMap<int[], Integer> unused1away = new HashMap<>();
		final LinkedHashSet<int[]> order = new LinkedHashSet<>();
		int next = 0;
		while (N > 1) {
			int notBackward = 0;
			int[] point1 = l.remove(next);
			final int x1 = point1[0], y1 = point1[1];
			if (!unused1away.containsKey(point1) || notBackward == 0)
				order.add(point1);
			N--;
			if (N == 1) {
				if (!unused1away.containsKey(l.get(0)))
					order.add(l.get(0));
			} else {
				int dist = Integer.MAX_VALUE;
				next = -1;
				boolean isGrid1 = point1[0] == 1 || point1[0] == M || point1[1] == 1 || point1[1] == M;
				for (int i = 0; i < N; i++) {
					int[] point2 = l.get(i);
					final int x2 = point2[0], y2 = point2[1];
					boolean isGrid2 = point2[0] == 1 || point2[0] == M || point2[1] == 1 || point2[1] == M;
					int tally = 0;
					if (isGrid1 != isGrid2)
						tally = 2;
					for (int j = 0; j < 2; j++) {
						int dif = point1[j] - point2[j];
						tally += dif * dif;
					}
					/*
					 * if (tally==2 && !isGrid1 && !isGrid2) { //prefer a ZAG next=i; dist=2; }else
					 * {
					 */
					if (tally == 1) {
						Integer backwardDemerit = unused1away.get(point2);
						if (backwardDemerit != null) {
							tally += backwardDemerit;
							unused1away.put(point2, backwardDemerit + 1);
						} else {
							unused1away.put(point2, one);
						}
					} else {
						notBackward++;
					}
					if (tally < dist) {
						next = i;
						dist = tally;
					}
					// }
				}

				int[] point2 = l.get(next);
				// System.out.println(point1[0]+"/"+point1[1]+" is "+ dist +" to
				// "+point2[0]+"/"+point2[1]);
				if (one.equals(unused1away.get(point2))) {
					unused1away.remove(point2);
				}

			}
		}
		N = order.size();
		if (N < 3)
			return order.toArray(new int[0][]);
		final ArrayList<int[]> out = new ArrayList<>();
		final java.util.Iterator<int[]> it = order.iterator();
		out.add(it.next());
		out.add(it.next());
		int i = 1;
		while (it.hasNext()) {
			int[] point = it.next();
			final int x = point[0], y = point[1];
			int[] point1 = out.get(i);
			int[] point0 = out.get(i - 1);
			if (x == point1[0] && x == point0[0]) {
				out.set(i, point);
			} else if (y == point1[1] && y == point0[1]) {
				out.set(i, point);
			} else {
				out.add(point);
				i++;
			}
		}
		out.add(out.get(0));
		return out.toArray(new int[0][]);
	}

	public static int dfltDecimalPlaces = 5;

	public static String toString(final double[] data, final int decimalPlaces) {
		final StringBuilder sb = new StringBuilder();
		for (int i = 0; i < data.length; i++) {
			sb.append(Numeric.encodeRounded(data[i], decimalPlaces));
			if (i < data.length - 1) {
				sb.append(",");
			}
		}
		return sb.toString();
	}

	public static String toString(final double[] data) {
		return toString(data, dfltDecimalPlaces);
	}

	public static String toString(final double value) {
		if (Double.isNaN(value)) {
			return "nan";
		}
		return (String) Numeric.encodeRounded(value, dfltDecimalPlaces);
	}

	public static int[] matrixToVector(final int M, final int[][] matrix) {
		// sub2ind and Density.ToVectorIdx
		// always travels column-wise not row=wise
		// I.e. it goes down a row and over a column
		// ... not over a row and down a column
		int[] vector = new int[M * M];
		int i = 0;
		for (int y = 0; y < M; y++) {
			for (int x = 0; x < M; x++) {
				vector[i++] = matrix[x][y];
			}
		}
		return vector;
	}

	public static int[][] ind2Sub(final int M, final int[] inds) {
		// sub2ind and Density.ToVectorIdx
		// always travels column-wise not row=wise
		// I.e. it goes down a row and over a column
		// ... not over a row and down a column
		final int N = inds.length;
		int[][] xy = new int[N][2];
		for (int i = 0; i < N; i++) {
			final int idx = inds[i];
			final int m = idx % M;
			if (m == 0) {
				xy[i][1] = idx / M;
				xy[i][0] = M;
			} else {
				xy[i][1] = idx / M + 1;
				xy[i][0] = m;
			}
		}
		return xy;
	}

	CountDownLatch latch;

	public void run() {
		compute(numberOfTopScoresToKeep);
		latch.countDown();
	}

}
