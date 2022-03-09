package edu.stanford.facs.swing;
/**
 * Algorithms from table 2 of
 * Quadratic Form: A Robust Metric for Quantitative Comparison of Flow Cytometric Histograms
 * Tytus Bernas,1,2 Elikplimi K. Asem,3 J. Paul Robinson,2 Bartek Rajwa2*

 * @author swmeehan
 *
 */
public class ChangeQuantification {

	public static double quadraticForm(final double dMax,
			final double[] h, final double []f, 
			final int []idxs1Based, int []x, int []y){
		double tally=0;
//		final double dMax=255*Math.sqrt(2);
		final int N=idxs1Based.length;
        for (int ii=0;ii<N;ii++){
                final int i=idxs1Based[ii]-1;	
                for (int jj=0;jj<N;jj++){
                    final int j=idxs1Based[jj]-1;
                    //1 - sqrt((x_i - x_j)^2 + (y_i - y_j)^2)
                    tally+= (1-(Math.sqrt(
                    			((x[ii]-x[jj])*(x[ii]-x[jj])) +
                    			((y[ii]-y[jj])*(y[ii]-y[jj])))
                    		/dMax)) *
                    		(h[i]-f[i]) * (h[j]-f[j]);                    
                }
        }
		return Math.sqrt(tally);
	}

	public static double quadraticForm2(final float dMax,
			final float[] h, final float []f, 
			final int []idxs1Based, int []x, int []y){
		final int N=idxs1Based.length;
		final double[]binDiff=new double[N];
		for (int ii=0;ii<N;ii++){
			final int i=idxs1Based[ii]-1;
			binDiff[ii]=h[i]-f[i];
		}
		float tally=0;
		for (int ii=0;ii<N;ii++){
			for (int jj=0;jj<N;jj++){
				tally+= (1-(Math.sqrt(
						((x[ii]-x[jj])*(x[ii]-x[jj])) +
						((y[ii]-y[jj])*(y[ii]-y[jj])))
						/dMax)) * binDiff[ii]*binDiff[jj];                    
			}
		}
		return Math.sqrt(tally);
	}

	public static double quadraticForm3(final float dMax,
			final float[] h, final float []f, 
			final int []idxs1Based, float []x, float []y){
		final int N=idxs1Based.length;
		final double[]binDiff=new double[N];
		for (int ii=0;ii<N;ii++){
			final int i=idxs1Based[ii]-1;
			binDiff[ii]=h[i]-f[i];
		}
		float tally=0;
		for (int ii=0;ii<N;ii++){
			for (int jj=0;jj<N;jj++){
				tally+= (1-(Math.sqrt(
						((x[ii]-x[jj])*(x[ii]-x[jj])) +
						((y[ii]-y[jj])*(y[ii]-y[jj])))
						/dMax)) * binDiff[ii]*binDiff[jj];                    
			}
		}
		return Math.sqrt(tally);
	}

	public static double quadraticFormHiDSlow(final double[] h, final double[]f, 
			final double [][]means){
		int N=h.length;
		final double dMax=maxDistSlow(means);
		double tally=0;
		for (int i=0;i<N;i++){
			for (int j=0;j<N;j++){
				tally+= (1-dist(means[i], means[j])/dMax) 
						* (h[i]-f[i])*(h[j]-f[j]);                    
			}
		}
		return Math.sqrt(tally);
	}

	public static double quadraticFormHiD(final double[] h, final double[]f, 
			final double [][]means){
		int N=h.length;
		final double dMax=maxDist(means);
		double tally=0;
		for (int i=0;i<N;i++){
			final double []num1=means[i];
			for (int j=0;j<N;j++){
				final double[]num2=means[j];
				double d=0;
				double diff;
				for (int k=0;k<num1.length;k++) {
					diff=num2[k]-num1[k];
					d+=diff*diff;
				}
				final double D=Math.sqrt(d);
				
				tally+= (1-D/dMax) 
						* (h[i]-f[i])*(h[j]-f[j]);                    
			}
		}
		return Math.sqrt(tally);
	}

	public static double quadraticForm(final double dMax,
			final double [] h, final double []f,double [][]means){
		return quadraticForm(dMax, h, f, means[0], means[1]);
	}

	public static double quadraticForm(final double dMax,
			final double[] h, final double []f, 
			double []x, double []y){
		int N=h.length;
		float tally=0;
		for (int i=0;i<N;i++){
			for (int j=0;j<N;j++){
				tally+= (1-Math.sqrt( ((x[i]-x[j])*(x[i]-x[j])) + ((y[i]-y[j])*(y[i]-y[j])))/dMax) 
						* (h[i]-f[i])*(h[j]-f[j]);                    
			}
		}
		return Math.sqrt(tally);
	}

	public static double quadraticForm(final float dMax,
			final float[] h, final float []f,			
			float [][]means,int []idx1Based){
		return quadraticForm(dMax, h, f, means[0], means[1], idx1Based);
	}

	public static double maxDistSlow(final double [][]means) {
		double max=0;
		final int N=means.length;
		for (int i=0;i<N;i++) {
			for (int j=0;j<N;j++) {
				final double D=dist(means[i], means[j]);
				if (D>max) {
					max=D;
				}
			}
		}
		return max;
	}
	public static double dist(final double []num1, final double []num2) {
		double d=0;
		double diff;
		for (int i=0;i<num1.length;i++) {
			diff=num2[i]-num1[i];
			d+=diff*diff;
		}
		return Math.sqrt(d);
	}
	
	public static double maxDist(final double [][]means) {
		double max=0;
		final int N=means.length;
		for (int i=0;i<N;i++) {
			final double []num1=means[i];
			for (int j=0;j<N;j++) {
				final double[]num2=means[j];
				double d=0;
				double diff;
				for (int k=0;k<num1.length;k++) {
					diff=num2[k]-num1[k];
					d+=diff*diff;
				}
				final double D=Math.sqrt(d);
				if (D>max) {
					max=D;
				}
			}
		}
		return max;
	}
	public static double quadraticForm(final float dMax,
			final float[] h, final float []f,			
			float []x, float []y,int []idx1Based){
		final int N=idx1Based.length;
		float tally=0;
		for (int ii=0;ii<N;ii++){
			final int i=idx1Based[ii]-1;
			//System.out.print(i+"-->");
			for (int jj=0;jj<N;jj++){
				final int j=idx1Based[jj]-1;
				tally+= (1-Math.sqrt( ((x[ii]-x[jj])*(x[ii]-x[jj])) + ((y[ii]-y[jj])*(y[ii]-y[jj])))/dMax) 
						* (h[i]-f[i])*(h[j]-f[j]);
				//System.out.print( j+" ");
			}
			//System.out.println();
		}
		return Math.sqrt(tally);
	}

	public static double quadraticFormGaussian(
			final double dMax, final double[] h, final double []f,			
			double [][]means,int []idx1Based){
		return quadraticFormGaussian(dMax, h, f, means[0], means[1], idx1Based);
	}

	public static double quadraticFormGaussian(double dMax,
			final double [] h, final double []f,			
			final double []x, final double []y, int []idx1Based){
		final int N=idx1Based.length;
		float tally=0;
		final double k=1;
		for (int ii=0;ii<N;ii++){
			final int i=idx1Based[ii]-1;			
			for (int jj=0;jj<N;jj++){
				final int j=idx1Based[jj]-1;
				final double distance=Math.sqrt( ((x[ii]-x[jj])*(x[ii]-x[jj])) + ((y[ii]-y[jj])*(y[ii]-y[jj])));
				tally+= Math.exp(-k*((distance/dMax)*(distance/dMax))) 
						* (h[i]-f[i])*(h[j]-f[j]);
			}
		}
		return Math.sqrt(tally);
	}

	public static double chiSquare(final double[] h, final double []f, final int []idxs1Based){
		double tally=0;
		final int N=idxs1Based.length;
        for (int ii=0;ii<N;ii++){
        	final int i=idxs1Based[ii]-1;
        	if (h[i]+f[i]>0){
        		tally=tally+(((h[i]-f[i])*(h[i]-f[i]))/(h[i]+f[i]));                	
        	}
        }
        return tally;
	}
	
	public static void main(final String []args){
		double[][]a={{15, 44, 33}, {100, 2, 4}};
		double [][]b={{ 125, 4, 31}, {10, 22, 14}, {92, 88, 121}};
		for (int i=0;i<a.length;i++) {
			for (int j=0;j<b.length;j++) {
				System.out.print(dist(a[i], b[j]));
				System.out.print('\t');
			}
			System.out.println();;
		}
		double d=Math.exp(5);
				d=Math.exp(10);
		int [][]ii=new int[][]{{1,4,5},{11,44,55}};
		int []i1=ii[0],i2=ii[1];
		
		final int[]idxs=new int[]{1,2,4};
		final double []h={.5, .25,  0, .13,   0, .55, .66},
					  f={ 0, .6, .19,   0, .04, .99, .4};
		final double[][] means={
			{15, 3}, {1, 4}, {100, 24}, {255, 155}, {15, 244}, {128, 128}, {173, 73} 
		};
		double []X=new double[means.length];
		double []Y=new double[X.length];
		for (int i=0;i<X.length;i++) {
			X[i]=means[i][0];
			Y[i]=means[i][1];
		}
		final double dMax=maxDist(means);
		double qf1=quadraticForm(dMax, h, f, X, Y);
		double qf2=quadraticFormHiD(h, f, means);
		final double chi=chiSquare(h, f, idxs);
		System.out.println("Qf ND="+qf2+", Qf 2D="+qf1+", chi square="+ chi);
	}
}
