package com.yolo.CDC.java.index.balanced_KDTree;

import java.io.Serializable;
import java.util.*;

public class KDTreeChange implements Serializable {

    public  Node kdtree;

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

    public KDTreeChange() {
        this.kdtree=null;
    }
    /**
     * 构建树
     * @param input 输入
     * @return KDTree树
     */
    public static KDTreeChange build(List<KDBSCANPoint> input, DBSCANRectange rectange){
        KDTreeChange tree = new KDTreeChange();
        tree.kdtree = null;
        if(input.size()<=0){
            return tree;
        }else {
            for(KDBSCANPoint point:input){
                tree.kdtree=Node.insert(point,tree.kdtree,0,rectange);
            }
        }
        return tree;
    }


    /**
     * 获取kd树子节点
     * @return 子节点
     */
    public List<KDBSCANPoint> getNodes(){
        Node node=kdtree;
        List<KDBSCANPoint> list=new ArrayList<>();
        if(node==null)return null;
        Stack<Node> stack=new Stack<>();
        stack.push(node);
        while (!stack.isEmpty()){
            Node node1=stack.pop();
            list.add(node1.getValue());
            if(node1.getRight()!=null){
                stack.push(node1.getRight());
            }
            if(node1.getLeft()!=null){
                stack.push(node1.getLeft());
            }
        }
        return list;
    }


    public List<KDBSCANPoint> rangeSearch(KDBSCANPoint point, double eps){
        Node node=kdtree;
        List<KDBSCANPoint> list=new ArrayList<>();
        if(node==null)return null;
        Stack<Node> stack=new Stack<>();
        stack.push(node);
        while (!stack.isEmpty()){
            Node node1=stack.pop();
            double distance= UtilZ.distance(point.getValue(),node1.getValue().getValue());
            if(distance<=Math.pow(eps,2)){
                list.add(node1.getValue());
            }
            if(node1.getRight()!=null){
                if(node1.getRight().getRectange().shrink(-eps).contains(point)  ){
                    stack.push(node1.getRight());
                }
            }
            if(node1.getLeft()!=null){
                if(node1.getLeft().getRectange().shrink(-eps).contains(point)  ){
                    stack.push(node1.getLeft());
                }
            }
        }
        return list;
    }
}

