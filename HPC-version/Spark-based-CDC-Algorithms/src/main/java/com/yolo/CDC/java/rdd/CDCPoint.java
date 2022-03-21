package com.yolo.CDC.java.rdd;

import java.io.Serializable;
import java.util.Arrays;

/**
 * @ClassName:CDCPoint
 * @Description:TODO
 * @Author:yolo
 * @Date:2022/2/1810:58
 * @Version:1.0
 */
public class CDCPoint implements Serializable {
    private int indexID;
    private int gridID;
    private int clusterID;
    private double[] coordinates=new double[2];
    private double X;
    private double Y;
    private int neighborsNum=0;
    private int[] neighborsIndexID;
    private double[] neighborsDistance;
    private double[] angleArray;
    private double dcmValue=0;
    private boolean visited=false;
    private Flag flag= Flag.NotFlagged;
    public enum Flag{
        Border,Inner,NotFlagged
    }
    private double reachDistance=0.0;

    public CDCPoint() {
    }

    public CDCPoint(double x, double y, int neighborsNum) {
        X = x;
        Y = y;
        this.coordinates[0]=x;
        this.coordinates[1]=y;
        this.neighborsNum = neighborsNum;
        this.neighborsIndexID=new int[neighborsNum];
        this.neighborsDistance=new double[neighborsNum];
        this.angleArray=new double[neighborsNum];
    }

    public double getX() {
        return X;
    }

    public void setX(double x) {
        X = x;
    }

    public double getY() {
        return Y;
    }

    public void setY(double y) {
        Y = y;
    }

    public int getIndexID() {
        return indexID;
    }

    public void setIndexID(int indexID) {
        this.indexID = indexID;
    }

    public int getGridID() {
        return gridID;
    }

    public void setGridID(int gridID) {
        this.gridID = gridID;
    }

    public int getClusterID() {
        return clusterID;
    }

    public void setClusterID(int clusterID) {
        this.clusterID = clusterID;
    }

    public double[] getCoordinates() {
        return coordinates;
    }

    public void setCoordinates(double[] coordinates) {
        this.coordinates=coordinates;
    }

    public int getNeighborsNum() {
        return neighborsNum;
    }

    public void setNeighborsNum(int neighborsNum) {
        this.neighborsNum = neighborsNum;
    }

    public int[] getNeighborsIndexID() {
        return neighborsIndexID;
    }

    public void setNeighborsIndexID(int[] neighborsIndexID) {
        this.neighborsIndexID = neighborsIndexID;
    }

    public double[] getNeighborsDistance() {
        return neighborsDistance;
    }

    public void setNeighborsDistance(double[] neighborsDistance) {
        this.neighborsDistance = neighborsDistance;
    }

    public double[] getAngleArray() {
        return angleArray;
    }

    public void setAngleArray(double[] angleArray) {
        this.angleArray = angleArray;
    }

    public double getDcmValue() {
        return dcmValue;
    }

    public void setDcmValue(double dcmValue) {
        this.dcmValue = dcmValue;
    }

    public boolean isVisited() {
        return visited;
    }

    public void setVisited(boolean visited) {
        this.visited = visited;
    }

    public Flag getFlag() {
        return flag;
    }

    public void setFlag(Flag flag) {
        this.flag = flag;
    }

    public double getReachDistance() {
        return reachDistance;
    }

    public void setReachDistance(double reachDistance) {
        this.reachDistance = reachDistance;
    }

    public double getDistanceSquared(CDCPoint p){
        double dis=Math.pow((this.X-p.getX()), 2)+Math.pow((this.Y-p.getY()), 2);
        return dis;
    }

    @Override
    public String toString() {
        return "CDCPoint{" +
                "indexID=" + indexID +
                ", gridID=" + gridID +
                ", clusterID=" + clusterID +
                ", coordinates=" + Arrays.toString(coordinates) +
                ", X=" + X +
                ", Y=" + Y +
                ", neighborsNum=" + neighborsNum +
                ", neighborsIndexID=" + Arrays.toString(neighborsIndexID) +
                ", neighborsDistance=" + Arrays.toString(neighborsDistance) +
                ", angleArray=" + Arrays.toString(angleArray) +
                ", dcmValue=" + dcmValue +
                ", visited=" + visited +
                ", flag=" + flag +
                ", reachDistance=" + reachDistance +
                '}';
    }
}
