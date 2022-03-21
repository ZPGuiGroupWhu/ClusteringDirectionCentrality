package com.yolo.CDC.java.utils;

import java.io.*;
import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;
import java.util.stream.Stream;

/**
 * @ClassName:CSVUtil
 * @Description:拆分csv文件
 * @Author:yolo
 * @Date:2022/3/1910:07
 * @Version:1.0
 */
public class CSVUtil {
    public static void main(String[] args) throws IOException {
        String resourceFolder = System.getProperty("user.dir");
        String inputPath = resourceFolder + "/GeoDataSets/1 Million Amap Points of Interest in China/Points/1000000.csv";
        String outputPath = resourceFolder + "/GeoDataSets/1 Million Amap Points of Interest in China/Points/1000000";
        splitCSV(inputPath, outputPath, 1000000);
    }

    /**
     * 拆分csv文件
     *
     * @param inputPath
     * @param outputPath
     * @param splitSize
     * @return
     */
    public static void splitCSV(String inputPath, String outputPath, int splitSize) {
        try {
            FileInputStream inputStream = new FileInputStream(inputPath);
            InputStreamReader reader = new InputStreamReader(inputStream, "GBK");
            BufferedReader bufferedReader = new BufferedReader(reader);
            Stream<String> lines = bufferedReader.lines();
            List<String> contents = lines.collect(Collectors.toList());
            long fileCount = contents.size();
//            System.out.println(fileCount);
//            int splitNumber = (int) (fileCount-1)/splitSize;
            int splitNumber = (int) (((fileCount - 1) % splitSize == 0) ? ((fileCount - 1) / splitSize) : ((fileCount - 1) / splitSize + 1));
            //将创建的拆分文件写入流放入集合中
            List<BufferedWriter> listWriters = new ArrayList<>();
            //创建存放拆分文件的目录
            File dir = new File(outputPath);
            //文件夹存在，可能里面有内容，删除所有内容
            if (dir.exists()) {
                delAllFile(dir.getAbsolutePath());
            }
            dir.mkdirs();
            for (int i = 0; i < splitNumber; i++) {
                String splitFilePath = outputPath + File.separator + splitSize + "_" + i + ".csv";
                File splitFileName = new File(splitFilePath);
                splitFileName.createNewFile();
                BufferedWriter bufferedWriter = new BufferedWriter(new OutputStreamWriter(new FileOutputStream(splitFileName), "UTF-8"));
                listWriters.add(bufferedWriter);
            }
            for (int i = 0; i < fileCount; i++) {
//                if (i == 0) {
//                    for (int count = 0; count < splitNumber; count++) {
//                        listWriters.get(count).write(contents.get(i));
//                        listWriters.get(count).newLine();
//                    }
//                } else {
                    for (int count = 0; count < splitNumber; count++) {
                        if (i <= (count + 1) * splitSize && i > count * splitSize) {
                            listWriters.get(count).write(contents.get(i));
                            listWriters.get(count).newLine();
                        }
//                    }
//                    listWriters.get(i % splitNumber).write(contents.get(i));
//                    listWriters.get(i % splitNumber).newLine();
                }
            }
            //关流
            listWriters.forEach(it -> {
                try {
                    it.flush();
                    it.close();
                } catch (IOException e) {
                    e.printStackTrace();
                }
            });
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    /***
     * 删除文件夹
     *
     */
    public static void delFolder(String folderPath) {
        try {
            delAllFile(folderPath); // 删除完里面所有内容
            String filePath = folderPath;
            filePath = filePath.toString();
            File myFilePath = new File(filePath);
            myFilePath.delete(); // 删除空文件夹
        } catch (Exception e) {
            e.printStackTrace();
        }
    }


    /***
     * 删除指定文件夹下所有文件
     *
     * @param path 文件夹完整绝对路径
     * @return
     */
    public static boolean delAllFile(String path) {
        boolean flag = false;
        File file = new File(path);
        if (!file.exists()) {
            return flag;
        }
        if (!file.isDirectory()) {
            return flag;
        }
        String[] tempList = file.list();
        File temp = null;
        for (int i = 0; i < tempList.length; i++) {
            if (path.endsWith(File.separator)) {
                temp = new File(path + tempList[i]);
            } else {
                temp = new File(path + File.separator + tempList[i]);
            }
            if (temp.isFile()) {
                temp.delete();
            }
            if (temp.isDirectory()) {
                delAllFile(path + "/" + tempList[i]);// 先删除文件夹里面的文件
                delFolder(path + "/" + tempList[i]);// 再删除空文件夹
                flag = true;
            }
        }
        return flag;
    }
}
