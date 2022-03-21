package com.yolo.CDC.java.index.classical_KDTree;

import java.io.Serializable;
import java.util.Vector;

// K-D Tree node 
class KDNode implements Serializable {

	/**
	 * 
	 */
//	private static final long serialVersionUID = 1L;
	protected Point key;  //存储的 geoPoint.coord
	protected KDNode left, right;//左右节点
	protected boolean deleted;//是否被删除
	Point value;

	// default constructor 默认构造方法
	private KDNode(Point key, Point val) {

		this.key = key;
		value = val;
		left = null;
		right = null;
		deleted = false;
	}

	// insert Node /这里的 key是传入的 geoPoint.coord 通过public Point(double[] coord) 转化来的，val就是传入的 geoPoint
	protected static KDNode insertNode(Point key, Point val, KDNode node, int level, int dimension) {
/**
 * 插入操作
 * 这里的 level 就是算法论文里面描述的 discriminator，根节点为第 0 层，下面一次是 1,2，...，k-1，再从0循环
 */
		if (node == null) {//如果为空则新建节点
			node = new KDNode(key, val);
		} else if (key.equals(node.key)) {//防止插入重复的值
			// "re-insert" 重新插入
			if (node.deleted) {//如果原始节点被删除
				node.deleted = false;
				node.value = val;
			}

		} else if (key.coord[level] > node.value.coord[level]) {
			node.right = insertNode(key, val, node.right, (level + 1) % dimension, dimension);
		} else {
			node.left = insertNode(key, val, node.left, (level + 1) % dimension, dimension);
		}

		return node;
	}


	
	// search Node
	protected static KDNode searchNode(Point key, KDNode node, int dimension) {

		for (int lev = 0; node != null; lev = (lev + 1) % dimension) {

			if (!node.deleted && key.equals(node.key)) {
				return node;
			} else if (key.coord[lev] > node.value.coord[lev]) {
				node = node.right;
			} else {
				node = node.left;
			}
		}

		return null;
	}

	// range Search                   左下角         右上角          根节点          level         维度
	protected static void rangeSearch(Point lowKey, Point upKey, KDNode node, int divide, int dimensions,
			//     查询值       搜索半径       向量
			double[] key,double Eps,Vector<KDNode> nodeVector) {

		if (node == null) {
			return;
		}
		if (node.value.coord[divide] >= lowKey.coord[divide]) {
			rangeSearch(lowKey, upKey, node.left, (divide + 1) % dimensions, dimensions,key,Eps, nodeVector);
		}

		if (node.value.coord[divide] < upKey.coord[divide]) {
			rangeSearch(lowKey, upKey, node.right, (divide + 1) % dimensions, dimensions, key,Eps,nodeVector);
		}
		
		int j;
		for (j = 0; j < dimensions && node.value.coord[j] >= lowKey.coord[j]
				&& node.value.coord[j] <= upKey.coord[j]; j++)
			;
		
		if((j == dimensions)&&(node.value.getDist(new Point(key))<Eps)){// 这里应该是小于等于吧
			nodeVector.add(node);
		}
//		nodeVector.add(node);
		
	}

}


