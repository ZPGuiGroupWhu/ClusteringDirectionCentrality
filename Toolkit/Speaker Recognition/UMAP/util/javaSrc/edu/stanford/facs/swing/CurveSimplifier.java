/***
 * Author: Stephen Meehan, swmeehan@stanford.edu
 * 
 * Provided by the Herzenberg Lab at Stanford University
 * 
 * License: BSD 3 clause
 */

package edu.stanford.facs.swing;

import java.util.ArrayList;

public class CurveSimplifier {
	private final int [][]curve;
	private final double tolerance;
	private CurveSimplifier(final int [][]separatrix, final double startingTolerance) {
		this.curve=separatrix;
		this.tolerance=startingTolerance;
	}
	
	// Ramer–Douglas–Peucker algorithm
	private void simplify(
			final ArrayList<int []>simplified,
			final int lo,
			final int hi){
		if (lo + 1 == hi)
			return;

		final double x = curve[hi][1] - curve[lo][1];
		double y = curve[hi][0] - curve[lo][0];
		final double theta = Math.atan2(y, x);
		final double c = Math.cos(theta);
		final double s = Math.sin(theta);
		double max = 0;
		int keep=0;
		for (int mid = lo + 1; mid < hi; mid++)
		{ // distance of mid from the line from lo to hi
			double d = Math.abs(c * (curve[mid][0] - curve[lo][0]) - s * (curve[mid][1] - curve[lo][1]));
			if (d > max){
				keep = mid;
				max = d;
			}
		}
		if (max > tolerance) {// significant, so something we must keep in here
			simplify(simplified, lo, keep);
			simplified.add(curve[keep]);
			simplify(simplified, keep, hi);
		}
		// but if not, we don't need any of the points between lo and hi
	}

	private ArrayList<int[]> simplify(){
		final ArrayList<int[]>polygon=new ArrayList<>(curve.length);
		polygon.add(curve[0]);
		simplify(polygon, 0, curve.length - 1);
		polygon.add(curve[curve.length - 1]);
		return polygon;
	}
	
	public static ArrayList<int[]>Run(final ArrayList<int[]>curve, final double densityW){
		return Run(curve.toArray(new int[0][]), densityW);
	}
	
	public static int[][]ToArray(final int[][]curve, final double densityW){
		final CurveSimplifier ls=new CurveSimplifier(curve, densityW);
		return ls.simplify().toArray(new int[0][]);
	}
	
	public static ArrayList<int[]>Run(final int[][]curve, final double densityW){
		final CurveSimplifier ls=new CurveSimplifier(curve, densityW);
		return ls.simplify();
	}

	public static void Test() {

		final int [][]testLine =new int[][]{
			{100, 0},{100, 1},{100, 2},{100, 3},{100, 4},{100, 5},{100, 6},{100, 7},{100, 8},{100, 9},{100, 10},
			{100, 11},{100, 12},{100, 13},{100, 14},{100, 15},{100, 16},{100, 17},{100, 18},{100, 19},{99, 20},{100, 21},{100, 22},
			{99, 23},{99, 24},{99, 25},{99, 26},{98, 27},{98, 28},{98, 29},{98, 30},{98, 31},{99, 32},{98, 33},{98, 34},
			{98, 35},{98, 36},{98, 37},{99, 38},{99, 39},{99, 40},{99, 41},{99, 42},{99, 43},{99, 44},{100, 45},{100, 46},
			{100, 47},{101, 48},{101, 49},{102, 50},{103, 51},{103, 52},{104, 53},{104, 54},{105, 55},{106, 56},{106, 57},{106, 58},
			{107, 59},{107, 60},{108, 61},{109, 62},{109, 63},{110, 64},{111, 65},{111, 66},{111, 67},{112, 68},{112, 69},{113, 70},
			{114, 71},{114, 72},{115, 73},{115, 74},{115, 75},{116, 76},{117, 77},{118, 78},{119, 79},{120, 79},{121, 80},{122, 80},
			{123, 81},{124, 81},{125, 81},{126, 82},{127, 83},{128, 83},{129, 84},{130, 84},{131, 85},{132, 86},{133, 86},{134, 87},
			{135, 87},{136, 87},{137, 88},{138, 88},{139, 89},{140, 90},{141, 90},{142, 90},{143, 90},{144, 91},{145, 92},{146, 92},
			{147, 92},{148, 93},{149, 94},{150, 94},{151, 95},{152, 95},{153, 96},{154, 96},{155, 96},{156, 96},{157, 97},{158, 97},
			{159, 98},{160, 99},{161, 98},{162, 99},{163, 99},{164, 100},{165, 100},{166, 100},{167, 99},{168, 99},{169, 99},{170, 98},
			{171, 99},{172, 98},{173, 99},{174, 98},{175, 98},{176, 98},{177, 97},{178, 97},{179, 96},{180, 96},{181, 95},{182, 95},
			{183, 94},{184, 94},{185, 93},{186, 93},{187, 92},{188, 92},{189, 92},{190, 92},{191, 91},{192, 91},{193, 91},{194, 90},
			{195, 89},{196, 90},{197, 89},{198, 89},{199, 88},{200, 87},{201, 87},{202, 87},{203, 87},{204, 86},{205, 85},{206, 85},
			{207, 85},{208, 85},{209, 84},{210, 84},{211, 84},{212, 83},{213, 83},{214, 83},{215, 82},{216, 81},{217, 82},{218, 81},
			{219, 81},{220, 80},{221, 80},{222, 80},{223, 81},{224, 80},{225, 80},{226, 79},{227, 79},{228, 79},{229, 78},{230, 78},
			{231, 78},{232, 78},{233, 78},{234, 77},{235, 78},{236, 77},{237, 78},{238, 78},{239, 78},{240, 77},{241, 77},{242, 78},
			{243, 77},{244, 77},{245, 77},{246, 78},{247, 78},{248, 78},{249, 78},{250, 78},{251, 78},{252, 78},{253, 78},{254, 77},
			{255, 77},{256, 77}
		};
		final ArrayList<int[]>c=Run(testLine, .006);
		System.out.println(testLine.length + " points simplified to "+c.size() + " points");
		System.out.println();
	}
}
