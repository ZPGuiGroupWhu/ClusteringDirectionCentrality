package com.yolo.CDC.java.index.balanced_KDTree;


import java.io.Serializable;

public class Node implements Serializable {
    private long level;//定义数据的层数，根节点为0，依次向下
    //分割的维度
    private int partitionDimention;
     //分割的值
    private double partitionValue;
     //平衡KD树每个节点都有数据
    private KDBSCANPoint value;
     //是否为叶子
    private boolean isLeaf=false;
    //左树
    private Node left;
     //右树
    private Node right;
     //每个维度的最小值
    private double[] min;
     //每个维度的最大值
    private double[] max;
    //每个节点对应的矩形区域
    private DBSCANRectange rectange;


    public long getLevel() {
        return level;
    }

    public void setLevel(long level) {
        this.level = level;
    }

    public DBSCANRectange getRectange() {
        return rectange;
    }

    public void setRectange(DBSCANRectange rectange) {
        this.rectange = rectange;
    }

    public int getPartitionDimention() {
        return partitionDimention;
    }

    public void setPartitionDimention(int partitionDimention) {
        this.partitionDimention = partitionDimention;
    }

    public double getPartitionValue() {
        return partitionValue;
    }

    public void setPartitionValue(double partitionValue) {
        this.partitionValue = partitionValue;
    }

    public KDBSCANPoint getValue() {
        return value;
    }

    public void setValue(KDBSCANPoint value) {
        this.value = value;
    }

    public boolean isLeaf() {
        return isLeaf;
    }

    public void setLeaf(boolean leaf) {
        isLeaf = leaf;
    }

    public Node getLeft() {
        return left;
    }

    public void setLeft(Node left) {
        this.left = left;
    }

    public Node getRight() {
        return right;
    }

    public void setRight(Node right) {
        this.right = right;
    }

    public double[] getMin() {
        return min;
    }

    public void setMin(double[] min) {
        this.min = min;
    }

    public double[] getMax() {
        return max;
    }

    public void setMax(double[] max) {
        this.max = max;
    }

    public static Node insert(KDBSCANPoint point,Node node,int level, DBSCANRectange rectange){
        if(node==null){
            Node nodeTemp=new Node();
            nodeTemp.setRectange(rectange);
            nodeTemp.setValue(point);
            nodeTemp.setLevel(level);
            node=nodeTemp;
        }
        else if(point.getValue()[level]>node.getValue().getValue()[level]){
            DBSCANRectange rectangeRight=new DBSCANRectange(Double.MAX_VALUE,Double.MAX_VALUE,Double.MIN_VALUE,Double.MIN_VALUE);
            if(level==0){
                rectangeRight=new DBSCANRectange(node.getValue().getValue()[level],rectange.getY(),rectange.getX2(),rectange.getY2());
            }
            if(level==1){
                rectangeRight=new DBSCANRectange(rectange.getX(),node.getValue().getValue()[level],rectange.getX2(),rectange.getY2());
            }
            node.right=insert(point,node.getRight(),(level+1)%point.getValue().length,rectangeRight);
        }else {
            //分割之后的左、右矩形
            DBSCANRectange rectangeLeft=new DBSCANRectange(Double.MAX_VALUE,Double.MAX_VALUE,Double.MIN_VALUE,Double.MIN_VALUE);
            if(level==0){
                rectangeLeft=new DBSCANRectange(rectange.getX(),rectange.getY(),node.getValue().getValue()[level],rectange.getY2());
            }
            if(level==1){
                rectangeLeft=new DBSCANRectange(rectange.getX(),rectange.getY(),rectange.getX2(),node.getValue().getValue()[level]);
            }
            node.left=insert(point,node.getLeft(),(level+1)%point.getValue().length,rectangeLeft);
        }
        return node;
    }

}
