/***
 * Author: Stephen Meehan, swmeehan@stanford.edu
 * 
 * Provided by the Herzenberg Lab at Stanford University
 * 
 * License: BSD 3 clause
 */

package edu.stanford.facs.swing;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Iterator;
import java.util.List;
import java.util.TreeSet;

public class GridClusterEdge {
	private final int M;
	public GridClusterEdge(final int M){
		this.M=M;
	}
	public void computeAll(final int []bi, final double[]mins, final double[]deltas){
		final boolean []matrix=new boolean[M*M+2];
		final int N=bi.length;
		for (int i=0;i<N;i++){
			matrix[bi[i]]=true;
		}
		final List<Integer>ux=new ArrayList<Integer>(N);
		final List<Integer>uy=new ArrayList<Integer>(N);
		
		final boolean [][]zz=new boolean[M+1][M+1];
		for (int i=0;i<N;i++){
			final int b=bi[i];
			final int x=((b-1)%M)+1;
			final int y=(b-1)/M+1;
			for (int xI=-1;xI<2;xI++){
				int x2=x+xI;
				boolean xOnGridEdge=false;
				if (x2<1){
					x2=1;
					xOnGridEdge=true;
				}else if (x2>M){
					x2=M;
					xOnGridEdge=true;
				}
				
				for (int yI=-1;yI<2;yI++){
					int y2=y+yI;
					boolean onGridEdge=xOnGridEdge;
					if (!onGridEdge){
						if (y2<1){
							y2=1;
							onGridEdge=true;
						}else if (y2>M){
							y2=M;
							onGridEdge=true;
						}
					}
					if (onGridEdge || !matrix[(y2-1)*M+x2]){
						zz[x][y]=true;
						ux.add(x);
						uy.add(y);
						break;
					}
				}
				if (zz[x][y]){
					break;
				}
			}			
			
		}
		final int N2=ux.size();
		x=new double[N2];
		y=new double[N2];
		final TreeSet<Integer> edgeTs=new TreeSet<Integer>();
		for (int i=0;i<N2;i++){
			edgeTs.add(((uy.get(i)-1)*M)+ux.get(i));
		}
		edgeBins=new int[edgeTs.size()];
		int i=0;
		for (Iterator<Integer>it=edgeTs.iterator();it.hasNext();){
			final int b=it.next();
			edgeBins[i]=b;
			x[i]=mins[0]+(b-1)%M*deltas[0];
			y[i]=mins[1]+(b-1)/M*deltas[1];
			i++;
		}
		
	}
	
	public void computeAllFast(final int []bi, final double[]mins, final double[]deltas){
		final boolean []matrix=new boolean[M*M+2];
		final int N=bi.length;
		for (int i=0;i<N;i++){
			matrix[bi[i]]=true;
		}
		boolean []edge=new boolean[N];
		int edges=0;
		for (int i=0;i<N;i++){
			final int b=bi[i];
			final int x=((b-1)%M)+1;
			final int y=(b-1)/M+1;
			for (int xI=-1;xI<2;xI++){
				int x2=x+xI;
				boolean xOnGridEdge=false;
				if (x2<1){
					x2=1;
					xOnGridEdge=true;
				}else if (x2>M){
					x2=M;
					xOnGridEdge=true;
				}
				
				for (int yI=-1;yI<2;yI++){
					int y2=y+yI;
					boolean onGridEdge=xOnGridEdge;
					if (!onGridEdge){
						if (y2<1){
							y2=1;
							onGridEdge=true;
						}else if (y2>M){
							y2=M;
							onGridEdge=true;
						}
					}
					if (onGridEdge || !matrix[(y2-1)*M+x2]){
						edge[i]=true;
						break;
					}
				}
				if (edge[i]){
					edges++;
					break;
				}
			}			
			
		}
		edgeBins=new int[edges];
		x=new double[edges];
		y=new double[edges];
		int e=0;
		for (int i=0;i<N;i++){
			if (edge[i]) {
				int b=bi[i];
				edgeBins[e]=b;
				x[e]=mins[0]+(b-1)%M*deltas[0];
				y[e]=mins[1]+(b-1)/M*deltas[1];
				e++;
			}
		}
		
	}
	
	public boolean []edge=null;
	public int []edgeBins;
	public double []x,y;
	public void compute(final int []bi, final boolean outputBins, final double[]mins, final double[]deltas){
		final boolean []matrix=new boolean[M*M+2];
		final int N=bi.length;
		for (int i=0;i<N;i++){
			matrix[bi[i]]=true;
		}
		final TreeSet<Integer>ux=new TreeSet<Integer>();
		final TreeSet<Integer>uy=new TreeSet<Integer>();
		final boolean [][]zz=new boolean[M+1][M+1];
		for (int i=0;i<N;i++){
			final int b=bi[i];
			final int x=((b-1)%M)+1;
			final int y=(b-1)/M+1;
			for (int xI=-1;xI<2;xI++){
				int x2=x+xI;
				boolean xOnGridEdge=false;
				if (x2<1){
					x2=1;
					xOnGridEdge=true;
				}else if (x2>M){
					x2=M;
					xOnGridEdge=true;
				}
				
				for (int yI=-1;yI<2;yI++){
					int y2=y+yI;
					boolean onGridEdge=xOnGridEdge;
					if (!onGridEdge){
						if (y2<1){
							y2=1;
							onGridEdge=true;
						}else if (y2>M){
							y2=M;
							onGridEdge=true;
						}
					}
					if (onGridEdge || !matrix[(y2-1)*M+x2]){
						zz[x][y]=true;
						ux.add(x);
						uy.add(y);
						break;
					}
				}
				if (zz[x][y]){
					break;
				}
			}			
		}
		final boolean [][]usedX=new boolean[M+1][M+1];
		final List<Integer>xL=new ArrayList<Integer>(N);
		final List<Integer>yL=new ArrayList<Integer>(N);
		{
			final int firstY=uy.first(), lastY=uy.last();
			for (final Iterator<Integer>it=ux.iterator();it.hasNext();){
				final int x=it.next();
				int leftY=0, rightY=0;
				for (int y=firstY;y<=lastY;y++){
					if (zz[x][y]){
						if (leftY==0){
							leftY=y;
							usedX[x][y]=true;
						}
						rightY=y;
					}
				}
				if (leftY>0){
					xL.add(x);
					yL.add(leftY);
					if (rightY>leftY){
						xL.add(x);
						yL.add(rightY);
						usedX[x][rightY]=true;
					}
				}
			}
		}
		final int firstX=ux.first(), lastX=ux.last();
		for (final Iterator<Integer>it=uy.iterator();it.hasNext();){
			final int y=it.next();
			int topX=0, bottomX=0;
			for (int x=firstX;x<=lastX;x++){
				if (zz[x][y]){
					if (topX==0){
						topX=x;
					}
					bottomX=x;
				}
			}
			if (topX>0){
				if( !usedX[topX][y]){
					yL.add(y);
					xL.add(topX);
				}
				if( !usedX[bottomX][y]){
					if (bottomX>topX){
						yL.add(y);
						xL.add(bottomX);
					}
				}
			}
		}
		final int N2=xL.size();
		x=new double[N2];
		y=new double[N2];
		if (outputBins){
			final TreeSet<Integer> edgeTs=new TreeSet<Integer>();
			for (int i=0;i<N2;i++){
				edgeTs.add(((yL.get(i)-1)*M)+xL.get(i));
			}
			edgeBins=new int[edgeTs.size()];
			int i=0;
			for (Iterator<Integer>it=edgeTs.iterator();it.hasNext();){
				final int b=it.next();
				edgeBins[i]=b;
				x[i]=mins[0]+(b-1)%M*deltas[0];
				y[i]=mins[1]+(b-1)/M*deltas[1];
				i++;
			}
		} else {
			edgeBins=new int[0];
			if (mins == null || deltas==null){
				for (int i=0;i<N2;i++){
					x[i]=xL.get(i);
					y[i]=yL.get(i);
				}
			}else{
				for (int i=0;i<N2;i++){
					x[i]=mins[0]+(xL.get(i)-1)*deltas[0];
					y[i]=mins[1]+(yL.get(i)-1)*deltas[1];
				}
			}
		}
	}

	public static int[] find(final int []allClues, final int[]clues){
		final int N=allClues.length, NN=clues.length;
		final List<Integer>l=new ArrayList<Integer>();
		for (int i=0;i<N;i++) {
			for (int j=0;j<NN;j++) {
				if (allClues[i]==clues[j]) {
					l.add(i+1); // 1 based vector indexes for MATLAB compatible
					break;
				}
			}
		}
		final int N2=l.size();
		final int []clueInds=new int[N2];
		for (int i=0;i<N2;i++){
			clueInds[i]=l.get(i);
		}
		return clueInds;
	}

	public static int[] GetUsingClues(final int M, final int []allClues, 
			final int[]clues){
		assert(M*M==allClues.length);
		return GetUsingClueInds(M, find(allClues, clues), CLUE_EDGE_ON_NON_CLUE);
	}
	
	public static int[] GetUsingClues(final int M, final int []allClues, 
			final int[]clues,final int gridEdgeRule){
		assert(M*M==allClues.length);
		return GetUsingClueInds(M, find(allClues, clues),
				gridEdgeRule);
	}
	
	final static int CLUE_EDGE_ANY=0, CLUE_EDGE_OFF_GRID_EDGE=-1,
			CLUE_EDGE_ON_NON_CLUE=1;
	public static int[] GetUsingClueInds(final int M, final int []clueInds, 
			final int edgeRule){
		final boolean []clueArea=new boolean[M*M+2];
		final int N=clueInds.length;
		for (int i=0;i<N;i++){
			clueArea[clueInds[i]]=true;
		}
		final List<Integer>ux=new ArrayList<Integer>();
		final List<Integer>uy=new ArrayList<Integer>();
		final boolean [][]anyEdge=new boolean[M+1][M+1];
		final boolean [][]gridEdge=new boolean[M+1][M+1];
		final boolean [][]nonClueEdge=new boolean[M+1][M+1];
		for (int i=0;i<N;i++){
			final int b=clueInds[i];
			if (b==24) {
				System.out.print("");
			}
			final int x=((b-1)%M)+1;
			final int y=(b-1)/M+1;
			for (int xI=-1;xI<2;xI++){
				int x2=x+xI;
				boolean xOnGridEdge=false;
				if (x2<1){
					x2=1;
					xOnGridEdge=true;
				}else if (x2>M){
					x2=M;
					xOnGridEdge=true;
				}
				
				for (int yI=-1;yI<2;yI++){
					int y2=y+yI;
					boolean onGridEdge=xOnGridEdge;
					if (!onGridEdge){
						if (y2<1){
							y2=1;
							onGridEdge=true;
						}else if (y2>M){
							y2=M;
							onGridEdge=true;
						}
					}
					if (edgeRule==CLUE_EDGE_ANY) {
						// include every clue edge 
						
						if (onGridEdge || !clueArea[(y2-1)*M+x2]){
							anyEdge[x][y]=true;
							ux.add(x);
							uy.add(y);
							break;
						}
					} else {
						if (onGridEdge ) {
							gridEdge[x][y]=true;
						}else if (!clueArea[(y2-1)*M+x2]){
							nonClueEdge[x][y]=true;
						}
					}
				}
				if (edgeRule==CLUE_EDGE_ANY) {
					if (anyEdge[x][y]){
						break;
					}
				}
			}
			if (edgeRule != CLUE_EDGE_ANY) {
				if (nonClueEdge[x][y]) {
					if (edgeRule==CLUE_EDGE_OFF_GRID_EDGE) {
						if (!gridEdge[x][y]) {
							ux.add(x);
							uy.add(y);
						}
					}else if (edgeRule==CLUE_EDGE_ON_NON_CLUE) {
						ux.add(x);
						uy.add(y);

					}
				}
			}
		}
		final int N2=ux.size();
		final int []out=new int[N2];
		for (int i=0;i<N2;i++){
			out[i]=((uy.get(i)-1)*M)+ux.get(i);
		}
		return out;
	}
	
	public static void main(String []args) {
		int [][]matrix=new int[][] {
				{3, 3, 3, 3, 3, 3},
				{3, 1, 1, 3, 3, 3},
				{1, 1, 1, 3, 3, 3},
				{1, 1, 1, 2, 2, 2},
				{1, 1, 1, 2, 2, 2},
				{2, 2, 2, 2, 2, 2}
		};
		final int M=matrix.length;
		int []vector=new int[M*M];
		
		int i=0;
		for (int x=0;x<M;x++) {
			for (int y=0;y<M;y++) {
				vector[i++]=matrix[x][y];
			}
		}
		test(M,vector, new int[] {2});
		int []search=new int[] {2,3};
		int []clueInds=find(vector, search);
		System.out.println(Arrays.toString(
				GetUsingClues(M, vector, search, CLUE_EDGE_ANY)));
		System.out.println(Arrays.toString(
				GetUsingClues(M, vector, search, CLUE_EDGE_OFF_GRID_EDGE)));
		System.out.println(Arrays.toString(
				GetUsingClues(M, vector, search, CLUE_EDGE_ON_NON_CLUE)));
		
		search=new int[] {2};
		clueInds=find(vector, search);
		System.out.println(Arrays.toString(clueInds));
		System.out.println(Arrays.toString(
				GetUsingClueInds(M, clueInds, 1)));
		System.out.println(Arrays.toString(
				GetUsingClues(M, vector, search, 0)));
		
		search=new int[] {2,3};
		clueInds=find(vector, search);
		System.out.println(Arrays.toString(clueInds));
		int []out=GetUsingClueInds(M, clueInds, 1);
		System.out.println(Arrays.toString(out));
		System.out.println(Arrays.toString(GetUsingClues(M, vector, search, -1)));
	}
	
	static void test(final int M, final int []vector, final int []search) {
		System.out.println(Arrays.toString(
				GetUsingClues(M, vector, search, CLUE_EDGE_ANY)));
		System.out.println(Arrays.toString(
				GetUsingClues(M, vector, search, CLUE_EDGE_OFF_GRID_EDGE)));
		System.out.println(Arrays.toString(
				GetUsingClues(M, vector, search, CLUE_EDGE_ON_NON_CLUE)));
		
	}
}
