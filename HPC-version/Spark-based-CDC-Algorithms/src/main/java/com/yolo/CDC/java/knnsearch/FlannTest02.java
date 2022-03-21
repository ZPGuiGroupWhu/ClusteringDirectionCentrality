package com.yolo.CDC.java.knnsearch;

import java.io.BufferedWriter;
import java.io.File;
import java.io.FileWriter;
import java.io.IOException;

/**
 * @ClassName:FlannTest02
 * @Description:TODO
 * @Author:yolo
 * @Date:2022/3/814:53
 * @Version:1.0
 */
public class FlannTest02 {
    public static void main(String[] args) {
        String outputPath="";
        File file= new File(outputPath);

        try {
            if (file.exists()) {
                file.delete();
            }

            BufferedWriter bw = new BufferedWriter(new FileWriter(file));

            StringBuffer out = new StringBuffer();


            bw.write(out.toString());

            bw.flush();

            bw.close();

        } catch (IOException e) {
            e.printStackTrace();
        }
    }
}
