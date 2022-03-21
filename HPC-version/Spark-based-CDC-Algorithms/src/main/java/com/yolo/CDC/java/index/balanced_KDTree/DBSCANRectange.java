package com.yolo.CDC.java.index.balanced_KDTree;

import java.io.Serializable;

public class DBSCANRectange implements Serializable {
    private double x;
    private double y;
    private double x2;
    private double y2;

    public DBSCANRectange(double x, double y, double x2, double y2) {
        this.x = x;
        this.y = y;
        this.x2 = x2;
        this.y2 = y2;
    }

    public double getX() {
        return x;
    }

    public void setX(double x) {
        this.x = x;
    }

    public double getY() {
        return y;
    }

    public void setY(double y) {
        this.y = y;
    }

    public double getX2() {
        return x2;
    }

    public void setX2(double x2) {
        this.x2 = x2;
    }

    public double getY2() {
        return y2;
    }

    public void setY2(double y2) {
        this.y2 = y2;
    }
    /**
     * 矩形在矩形内部（包含边界）
     */
    public  Boolean contains(DBSCANRectange other){
        if(x <= other.x && other.x2 <= x2 && y <= other.y && other.y2 <= y2){
            return true;
        }
        return null;
    }
    /**
     * Returns whether point is contained by this box
     * 点在矩形内部（包含边界）
     * 第一位为x，第二位为y
     */
    public Boolean contains(com.yolo.CDC.java.index.balanced_KDTree.KDBSCANPoint p){
        double[] value=p.getValue();
        if(x <= value[0] && value[0] <= x2 && y <= value[1] && value[1] <= y2){
            return true;
        }
        return false;
    }
    /**
     * Returns a new box from shrinking this box by the given amount
     * 矩形缩放amount
     */
    public DBSCANRectange shrink (double amount){
        DBSCANRectange dbscanRectange =new DBSCANRectange(x + amount,y + amount,x2 - amount,y2 - amount);
        return dbscanRectange;
    }
    /**
     * Returns a whether the rectangle contains the point, and the point
     * is not in the rectangle's border
     * 点在矩形内部(不包括边界)
     */
    public Boolean almostContains(KDBSCANPoint p){
        double[] value=p.getValue();
        if(x <= value[0] && value[0] < x2 && y < value[1] && value[1] < y2){
            return true;
        }
        return false;
    }
}
