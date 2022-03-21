package com.yolo.CDC.java.index.classical_KDTree;

import java.io.Serializable;

public class Point implements Serializable {
//	private static final long serialVersionUID = 1L;
	private long id;
	// private double x;
	// private double y;
	private boolean isKey;
	private boolean isClassed;//是否被分类
	private boolean isVisited;//是否被识别
	private int clusterId;//类簇ID
	public double[] coord;//坐标 准确的说是：一维数组（记录了一个节点的所有的keys）

	{
		this.clusterId=0;
		this.isClassed=false;
		this.isVisited=false;
	}

	@Override
	public String toString() {
		return coord[0]+","+coord[1]+","+clusterId ;
	}

	public Point() {}

	public Point(long id, double[] coord) {
		this.id = id;
		this.coord = coord;
	}

	public Point(long id, String[] coord) {
		this.id = id;
		this.coord = new double[] { Double.parseDouble(coord[0]), Double.parseDouble(coord[1]) };
	}

	public Point(double[] coord) {
		this.coord = coord;
	}

	public Point(Long idCount, String lon, String lat) {
		this.id = id;
		this.coord = new double[] { Double.parseDouble(lon), Double.parseDouble(lat) };
		}

	public String printCsv() {
		return String.format("%.6f,%.6f,%d", this.coord[0], this.coord[1], this.clusterId);
	}

	public String printJson() {
		return String.format("{lng:%.6f,lat:%.6f,cluster:%d}", this.coord[0], this.coord[1], this.clusterId);
	}

	public boolean isEqual(Point other) {
		return ((Math.abs(this.coord[0] - other.coord[0]) < 0.000001)
				&& (Math.abs(this.coord[1] - other.coord[1]) < 0.000001));
	}

	public boolean isKey() {
		return isKey;
	}

	public void setKey(boolean isKey) {
		this.isKey = isKey;
		this.isClassed = true;
	}

	public boolean isClassed() {
		return isClassed;
	}

	public void setClassed(boolean isClassed) {
		this.isClassed = isClassed;
	}

	// public double getX() {
	// return x;
	// }
	//
	// public void setX(double x) {
	// this.x = x;
	// }
	//
	// public double getY() {
	// return y;
	// }
	//
	// public void setY(double y) {
	// this.y = y;
	// }
	//
	// public Point() {
	// x = 0;
	// y = 0;
	// }

	public int getClusterId() {
		return clusterId;
	}

	public void setClusterId(int clusterId) {
		this.clusterId = clusterId;
	}

	public long getId() {
		return id;
	}

	public void setId(long id) {
		this.id = id;
	}

	public double[] getCoord() {
		return coord;
	}

	public void setCoord(double[] coord) {
		this.coord = coord;
	}
	public void setCoord(String lon,String lat) {//经度和维度
		double[] tmp=new double[2];
		tmp[0]=Double.parseDouble(lon);//将字符串型转换为数值型
		tmp[1]=Double.parseDouble(lat);
		this.coord = tmp;
	}

	public boolean isVisited() {
		return isVisited;
	}

	public void setVisited(boolean isVisited) {
		this.isVisited = isVisited;
	}
	
	public double getDist(Point p){
		return Math.sqrt(Math.pow((this.coord[0]-p.coord[0]), 2)-Math.pow((this.coord[1]-p.coord[1]), 2));
	}
//pow表示幂，abs绝对值，sqrt开根号
}
