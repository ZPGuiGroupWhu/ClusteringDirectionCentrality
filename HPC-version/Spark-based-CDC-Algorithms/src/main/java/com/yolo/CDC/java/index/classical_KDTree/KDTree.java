package com.yolo.CDC.java.index.classical_KDTree;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.List;
import java.util.Vector;

public class KDTree<T> implements Serializable {//实现序列化接口

	/**
	 * 
	 */
//	private static final long serialVersionUID = 1L;
	public int dimensions;//数据维度
	public KDNode root;//根节点
	public int nodeCount;//节点数量

	public KDTree(int k) {//构造函数

		dimensions = k;//默认维度为k，k作为参数输入
		root = null;//默认节点为空
	}

	//插入树结构
	public void insertTree(double[] key, Point value) {
		if (key.length!=dimensions){
			throw new RuntimeException("KDTree_v2: wrong key size!");
		}else
		{                           // 将坐标作为 key
			root = KDNode.insertNode(new Point(key), value, root, 0, dimensions);//根节点level为0
		}
		nodeCount++;
	}



	public Object searchTree(double[] key) {

		KDNode kdNode = KDNode.searchNode(new Point(key), root, dimensions);
		return (kdNode == null ? null : kdNode.value);
	}


	// 范围查询 lowKey是左下角 upKey是右上角
	public List<Point> range(double[] lowKey, double[] upKey,double[] key,double Eps) {

		Vector<KDNode> nodeVector = new Vector<>();
		KDNode.rangeSearch(new Point(lowKey), new Point(upKey), root, 0, dimensions, key,Eps, nodeVector);

		List<Point> valueList = new ArrayList<>(nodeVector.size());
		for (int i = 0; i < nodeVector.size(); ++i) {
			KDNode node = nodeVector.elementAt(i);// 获取指定位置的值
			valueList.add(i, node.value); //在指定的位置插入指定的值
		}
		return valueList;
	}

	// !!!!!!!!!!!!!!!!!!!!ERROR!!!!!!!!!!!!!!!!!!!!!!!
	private static double getHaversineDistance(double v, double v1, double v2, double v3) {
		return 0.0;
	}

	public List<Point> rangeSearch(double[] key, double Eps) {
		//构造一个矩形
		double[][] corners = new double[][] { { key[0] - Eps, key[1] - Eps }, { key[0] + Eps, key[1] + Eps } };
		return range(corners[0], corners[1],key,Eps);
	}

//	public String toString() {
//		return root.toString(0);
//	}

	public static class Result<S> implements Serializable {
		public double distance;
		public S payload;

		Result(double dist, S load) {
			distance = dist;
			payload = load;
		}
	}
}
