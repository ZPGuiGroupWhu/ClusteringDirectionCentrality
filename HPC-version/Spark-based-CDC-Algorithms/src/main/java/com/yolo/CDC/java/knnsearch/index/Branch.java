package com.yolo.CDC.java.knnsearch.index;

public class Branch<NodeType> implements Comparable<Branch<NodeType>> {
	NodeType node;
	double mindist;
	
	Branch (NodeType node, double mindist) {
		this.node = node;
		this.mindist = mindist;
	}
	
	public int compareTo (Branch<NodeType> other) {
		if (mindist < other.mindist)
			return -1;
		else if (mindist > other.mindist)
			return 1;
		else 
			return 0;
	}
}