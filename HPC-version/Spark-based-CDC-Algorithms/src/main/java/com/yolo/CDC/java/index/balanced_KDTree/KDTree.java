package com.yolo.CDC.java.index.balanced_KDTree;

import java.io.Serializable;
import java.util.*;

public class KDTree implements Serializable {

    private Node kdtree;

    private static class UtilZ{
        /**
         * 计算给定维度的方差
         * @param data 数据
         * @param dimention 维度
         * @return 方差
         */
        static double variance(ArrayList<double[]> data,int dimention){
//            方法一
//            double vsum = 0;
//            double sum = 0;
//            for(double[] d:data){
//                sum+=d[dimention];//给定维度数的和
//                vsum+=d[dimention]*d[dimention];//给定维度数的平方和
//            }
//            int n = data.size();
//            //这样计算的结果与下面的相同，但是复杂度更低
//            double result=vsum/n-Math.pow(sum/n, 2);
////            if(result<1e-11){
////                return 0;
////            }else{
////                return result;
////            }
//            return  result;

//            方法二
            double sum=0;
            double result=0;
            int n=data.size();
            for (double[] d1:data){
                sum+=d1[dimention];
            }
            double mean=sum/n;
            for (double[] d2:data){
                result+=(d2[dimention]-mean)*(d2[dimention]-mean);
            }
            double variance=result/n;
            return variance;



        }
        /**
         * 取排序后的中间位置数值
         * @param data 数据
         * @param dimention 维度
         * @return
         */
        static double median(ArrayList<double[]> data,int dimention){
            double[] d =new double[data.size()];
            int i=0;
            for(double[] k:data){
                d[i++]=k[dimention];
            }
            return findPos(d, 0, d.length-1, d.length/2);
        }
        static double min(ArrayList<double[]> data,int dimention){
            double[] d =new double[data.size()];
            int i=0;
            for(double[] k:data){
                d[i++]=k[dimention];
            }
            return findPos(d, 0, d.length-1, 0);
        }
        static double max(ArrayList<double[]> data,int dimention){
            double[] d =new double[data.size()];
            int i=0;
            for(double[] k:data){
                d[i++]=k[dimention];
            }
            return findPos(d, 0, d.length-1, d.length-1);
        }


        static double[] dataSort(ArrayList<double[]> data,int dimention){
            double[] d =new double[data.size()];
            int i=0;
            for(double[] k:data){
                d[i++]=k[dimention];
            }
            Arrays.sort(d);
            return d;
        }

        /**
         * 取出每一维度的最大最小值
         * @param data  数据
         * @param dimentions    数据维度
         * @return  二维数组，第一行为min，第二行为max
         */
        static double[][] maxmin(ArrayList<double[]> data,int dimentions){
            double[][] mm = new double[2][dimentions];
            //初始化 第一行为min，第二行为max
            for(int i=0;i<dimentions;i++){
                mm[0][i]=mm[1][i]=data.get(0)[i];
                for(int j=1;j<data.size();j++){
                    double[] d = data.get(j);
                    if(d[i]<mm[0][i]){
                        mm[0][i]=d[i];
                    }else if(d[i]>mm[1][i]){
                        mm[1][i]=d[i];
                    }
                }
            }
            return mm;
        }

        /**
         * 计算两个数组的距离，结果以平方计
         * @param a 数组一
         * @param b 数组二
         * @return  距离————平方
         */
        static double distance(double[] a,double[] b){
            double sum = 0;
            for(int i=0;i<a.length;i++){
                sum+=Math.pow(a[i]-b[i], 2);
            }
            return sum;
        }

        /**
         * 在max和min表示的超矩形中的点和点a的最小距离
         * @param a 点a
         * @param max 超矩形各个维度的最大值
         * @param min 超矩形各个维度的最小值
         * @return 超矩形中的点和点a的最小距离
         */
        static double mindistance(double[] a,double[] max,double[] min){
            double sum = 0;
            for(int i=0;i<a.length;i++){
                if(a[i]>max[i])
                    sum += Math.pow(a[i]-max[i], 2);
                else if (a[i]<min[i]) {
                    sum += Math.pow(min[i]-a[i], 2);
                }
            }
            return sum;
        }

        /**
         * 使用快速排序，查找排序后位置在point处的值
         * 比Array.sort()后去对应位置值，大约快30%
         * @param data 数据
         * @param low 参加排序的最低点
         * @param high 参加排序的最高点
         * @param point 位置
         * @return
         */
        private static double findPos(double[] data,int low,int high,int point){
            int lowt=low;
            int hight=high;
            double v = data[low];
            ArrayList<Integer> same = new ArrayList<Integer>((int)((high-low)*0.25));
            while(low<high){
                while(low<high&&data[high]>=v){
                    if(data[high]==v){
                        same.add(high);
                    }
                    high--;
                }
                data[low]=data[high];
                while(low<high&&data[low]<v)
                    low++;
                data[high]=data[low];
            }
            data[low]=v;
            int upper = low+same.size();
            if (low<=point&&upper>=point) {
                return v;
            }

            if(low>point){
                return findPos(data, lowt, low-1, point);
            }

            int i=low+1;
            for(int j:same){
                if(j<=low+same.size())
                    continue;
                while(data[i]==v)
                    i++;
                data[j]=data[i];
                data[i]=v;
                i++;
            }
            return findPos(data, low+same.size()+1, hight, point);
        }
    }
    private static double[] finaMedian(ArrayList<double[]> list,int dimension) {
        Collections.sort(list, new Comparator<double[]>() {
            @Override
            public int compare(double[] o1, double[] o2) {



                if(o1[dimension]<o2[dimension])
                    return -1;

                if(o1[dimension]==o2[dimension])
                    return 0;

                if(o1[dimension]>o2[dimension])
                    return 1;
                return 0;
            }
        });
       return list.get(list.size()/2);

    }
    private static double[] finaMax(ArrayList<double[]> list,int dimension) {
        Collections.sort(list, new Comparator<double[]>() {
            @Override
            public int compare(double[] o1, double[] o2) {

                if(o1[dimension]<o2[dimension])
                    return -1;

                if(o1[dimension]==o2[dimension])
                    return 0;

                if(o1[dimension]>o2[dimension])
                    return 1;
                return 0;
            }
        });
        return list.get(list.size()-1);

    }

    public KDTree() {}
    /**
     * 构建树
     * @param input 输入
     * @return KDTree树
     */
    public static KDTree build(List<KDBSCANPoint> input,DBSCANRectange rectange){
        KDTree tree = new KDTree();
        tree.kdtree = new Node();
        if(input.size()==0)return tree;
        int n = input.size();//数据条数
        int m=input.get(0).getValue().length;//维度
        ArrayList<double[]> data =new ArrayList<double[]>(n);
//        for(int i=0;i<n;i++){
//            double[] d = new double[m];
//            for(int j=0;j<m;j++)
//                d[j]=input.get(i).getValue()[j];
//            data.add(d);
//        }
        for(KDBSCANPoint point:input){
            data.add(point.getValue());
        }

        //原始数据每一维度的最小最大值maxmin(0)表示所有维度最小值数组，maxmin(1)表示所有维度最大值数组
//        double[][] maxmin= UtilZ.maxmin(data, m);
        //这个地方后期可以优化，传进来的直接就是整个数据集的MBR
//        DBSCANRectange rectange_kd=new DBSCANRectange(maxmin[0][0],maxmin[0][1],maxmin[1][0],maxmin[1][1]);

        int level=0;
        tree.buildDetail(tree.kdtree, data, m,rectange,level);
        return tree;
    }
    /**
     * 循环构建树
     * @param node 节点
     * @param data 数据
     * @param dimentions 数据的维度
     */
    private void buildDetail(Node node, ArrayList<double[]> data, int dimentions, DBSCANRectange rectange, int level){
        int levelNext=level+1;
        if(data.size()==0){
            return;
        }
        if(data.size()==1){
           KDBSCANPoint point=new KDBSCANPoint();
           point.setValue(data.get(0));
           node.setLeaf(true);
           node.setValue(point);
           node.setLevel(level);
           node.setRectange(rectange);
           return;
        }
        //选择方差最大的维度
        node.setPartitionDimention(-1);
        double var = -1;
        double tmpvar;
        for(int i=0;i<dimentions;i++){
            tmpvar= UtilZ.variance(data, i);
            if (tmpvar>var){
                var = tmpvar;

                node.setPartitionDimention(i);
            }
        }
        //如果方差=0，表示所有数据都相同，判定为叶子节点
        if(var==0){
            KDBSCANPoint point=new KDBSCANPoint();
            point.setValue(data.get(0));
            node.setLevel(level);
            node.setLeaf(true);
            node.setValue(point);
            node.setRectange(rectange);
            return;
        }
        double[] dataSort= UtilZ.dataSort(data,node.getPartitionDimention());
        double dataMedian=dataSort[dataSort.length/2];
        double dataMin=dataSort[0];
        node.setPartitionValue(dataMedian);
        node.setRectange(rectange);
        node.setLevel(level);

        //分割之后的左、右矩形
        DBSCANRectange rectangeLeft=new DBSCANRectange(Double.MAX_VALUE,Double.MAX_VALUE,Double.MIN_VALUE,Double.MIN_VALUE);
        DBSCANRectange rectangeRight=new DBSCANRectange(Double.MAX_VALUE,Double.MAX_VALUE,Double.MIN_VALUE,Double.MIN_VALUE);
        if(node.getPartitionDimention()==0){
            rectangeLeft=new DBSCANRectange(rectange.getX(),rectange.getY(),node.getPartitionValue(),rectange.getY2());
            rectangeRight=new DBSCANRectange(node.getPartitionValue(),rectange.getY(),rectange.getX2(),rectange.getY2());
        }
        if(node.getPartitionDimention()==1){
            rectangeLeft=new DBSCANRectange(rectange.getX(),rectange.getY(),rectange.getX2(),node.getPartitionValue());
            rectangeRight=new DBSCANRectange(rectange.getX(),node.getPartitionValue(),rectange.getX2(),rectange.getY2());
        }

        int size =data.size();
        ArrayList<double[]> left = new ArrayList<double[]>(size);
        ArrayList<double[]> right = new ArrayList<double[]>(size);

        for(double[] d:data){
            if(dataMin==dataMedian){
                if (d[node.getPartitionDimention()]<=node.getPartitionValue()) {
                    left.add(d);
                }else {
                    right.add(d);
                }
            }else {
                if (d[node.getPartitionDimention()]<node.getPartitionValue()) {
                    left.add(d);
                }else {
                    right.add(d);
                }
            }
        }

        Node leftnode = new Node();
        Node rightnode = new Node();

        node.setLeft(leftnode);
        node.setRight(rightnode);

        buildDetail(leftnode, left, dimentions,rectangeLeft,levelNext);
        buildDetail(rightnode, right, dimentions,rectangeRight,levelNext);


    }

    /**
     * 获取kd树子节点
     * @return 子节点
     */
    public List<KDBSCANPoint> getNodes(){
        Node node=kdtree;
        List<KDBSCANPoint>list=new ArrayList<>();
        Stack<Node> stack=new Stack<>();
        while (!node.isLeaf()){
            if(node.getLeft()!=null){
                stack.push(node.getRight());
                node=node.getLeft();
            }
            else if(node.getRight()!=null){
                stack.push(node.getLeft());
                node=node.getRight();
            }
        }
        if(node.isLeaf()){
            list.add(node.getValue());
        }
        Node nodeRec=null;
        while (!stack.isEmpty()){
            nodeRec=stack.pop();
            if(nodeRec.isLeaf()){
                list.add(nodeRec.getValue());
            }else{
                while (!nodeRec.isLeaf()){
                    if(nodeRec.getLeft()!=null){
                        stack.push(nodeRec.getRight());
                        nodeRec=nodeRec.getLeft();
                    }
                    else if(nodeRec.getRight()!=null){
                        stack.push(nodeRec.getLeft());
                        nodeRec=nodeRec.getRight();
                    }
                }
                if(nodeRec.isLeaf()){
                    list.add(nodeRec.getValue());
                }
            }
        }
        return list;
    }

    /**
     * 获取kd树节点矩形
     * @return 节点矩形
     */
    public List<DBSCANRectange> getRectange(int numPartition){
        int partitionNum= (int) (Math.log(numPartition)/Math.log(2));
        Node node=kdtree;
        List<DBSCANRectange>list=new ArrayList<>();
        Stack<Node> stack=new Stack<>();
        while (!node.isLeaf()){
            if(node.getLevel()==partitionNum){
                list.add(node.getRectange());
            }
            if(node.getLeft()!=null){
                stack.push(node.getRight());
                node=node.getLeft();
            }
            else if(node.getRight()!=null){
                stack.push(node.getLeft());
                node=node.getRight();
            }
        }
        if(node.isLeaf() && node.getLevel()==partitionNum ){
            list.add(node.getRectange());
        }
        Node nodeRec=null;
        while (!stack.isEmpty()){
            nodeRec=stack.pop();
            if(nodeRec.isLeaf() && nodeRec.getLevel()==partitionNum){
                list.add(nodeRec.getRectange());
            }else{
                while (!nodeRec.isLeaf()){
                    if(nodeRec.getLevel()==partitionNum ){
                        list.add(nodeRec.getRectange());
                    }

                    if(nodeRec.getLeft()!=null){
                        stack.push(nodeRec.getRight());
                        nodeRec=nodeRec.getLeft();
                    }
                    else if(nodeRec.getRight()!=null){
                        stack.push(nodeRec.getLeft());
                        nodeRec=nodeRec.getRight();
                    }
                }
                if(nodeRec.isLeaf() && nodeRec.getLevel()==partitionNum){
                    list.add(nodeRec.getRectange());
                }
            }
        }
        return list;
    }

    /**
     * 范围查询——kdTree
     * @param input 查询的点
     * @param eps   邻域半径
     * @return      邻域列表
     */
    public List<KDBSCANPoint> rangeSearch(double [] input, double eps){
        Node node=kdtree;
        List<KDBSCANPoint>list=new ArrayList<>();
        Stack<Node> stack = new Stack<Node>();
        //自顶向下，直至叶节点
        while(!node.isLeaf()){
            if(input[node.getPartitionDimention()]<node.getPartitionValue()){
                stack.push(node.getRight());
                node=node.getLeft();
            }else{
                stack.push(node.getLeft());
                node=node.getRight();
            }
        }
        double distance= UtilZ.distance(input,node.getValue().getValue());
        if(distance<=Math.pow(eps,2)){
            list.add(node.getValue());
        }
        //回溯
        Node nodeRec=null;
        double tdis;
        while(stack.size()!=0){
            nodeRec = stack.pop();
            if(nodeRec.isLeaf()){
                tdis= UtilZ.distance(input, nodeRec.getValue().getValue());
                if(tdis<=Math.pow(eps,2)){
                    list.add(nodeRec.getValue());
                }
            }else {
                /**
                 * 得到该节点代表的超矩形中点到查找点的最小距离mindistance
                 * 找到mindistance<=Math.pow(eps,2)区域进行判断
                 */
                double[] max=new double[]{nodeRec.getRectange().getX2(),nodeRec.getRectange().getY2()};
                double[] min=new double[]{nodeRec.getRectange().getX(),nodeRec.getRectange().getY()};
                double mindistance = UtilZ.mindistance(input, max, min);
                if (mindistance<=Math.pow(eps,2)) {
                    while(!nodeRec.isLeaf()){
                        if(input[nodeRec.getPartitionDimention()]<nodeRec.getPartitionValue()){
                            stack.add(nodeRec.getRight());
                            nodeRec=nodeRec.getLeft();
                        }else{
                            stack.push(nodeRec.getLeft());
                            nodeRec=nodeRec.getRight();
                        }
                    }
                    tdis= UtilZ.distance(input, nodeRec.getValue().getValue());
                    if(tdis<=Math.pow(eps,2)){
                        list.add(nodeRec.getValue());
                    }
                }
            }
        }
        return list;
    }
public static void main(String[] args){
        ArrayList<double[]> list=new ArrayList<>();
        list.add(new double[]{111.30303, 30.688351});
        list.add(new double[]{111.30303, 30.688354});
        list.add(new double[]{111.30303, 30.688353});
        double a= UtilZ.variance(list,0);
        double b= UtilZ.variance(list,1);
        System.out.println(a+"  "+b);
}
}

