package com.yolo.CDC.java.knnsearch;

import org.bytedeco.javacpp.FloatPointer;
import org.bytedeco.javacpp.opencv_core;

import java.nio.FloatBuffer;
import java.nio.IntBuffer;

import static org.bytedeco.javacpp.opencv_core.*;
import static org.bytedeco.javacpp.opencv_flann.*;

/**
 * @ClassName:JavaKnn02
 * @Description:TODO
 * @Author:yolo
 * @Date:2022/3/819:07
 * @Version:1.0
 */
public class JavaKnn02 {
    // Underlying parameters for knnsearch.
    private Index flannIndex = null;
    private AutotunedIndexParams indexParams = null;
    private SearchParams searchParams = null;
    private int k = 1;
    private int method = EUCLIDEAN;
    private Mat indexMat, distMat;

    // Initialization.
    public void init(int k, int method) {
        this.k = k;
        this.method = method;
        // Params for searching ...
        flannIndex = new Index();
        // TODO: other methods ...
        indexParams = new AutotunedIndexParams();
        searchParams = new SearchParams(64, 0, true); // maximum number of leafs checked.
    }

    // Knn search.
    public void knnSearch(opencv_core.Mat probes, opencv_core.Mat gallery) {
        int rows = probes.rows();
        indexMat = new opencv_core.Mat(rows, k, CV_32SC1);
        distMat = new opencv_core.Mat(rows, k, CV_32FC1);
        // find nearest neighbors using FLANN
        // TODO: If it can be built only once?
        flannIndex.build(gallery, indexParams, method);
        System.out.println(flannIndex.getAlgorithm());
        System.out.println(indexParams.getDouble("algorithm"));
        flannIndex.knnSearch(probes, indexMat, distMat, k, searchParams);
    }

    // Get knn results
    // Index matrix.
    public Mat getIndexMat() {
        return this.indexMat;
    }
    // Distance matrix.
    public Mat getDistMat() {
        return this.distMat;
    }

    // Main function.
    public static void main( String[] args )
    {
        // Source data.
        // float[] galleryArray = new float[25];
        float[] galleryArray = {1.1f, 1.2f, 1.3f, 2.2f, 2.3f, 3.4f, 1.2f, 7.1f, 2.1f, 2.7f, 9.0f, 1.9f, 1.0f, 0.1f, 0.2f, 9.1f, 6.1f, 6.6f, 7.8f, 2.5f, 2.3f, 2.4f, 3.5f, 4.5f, 3.4f};
        //float[] probeArray = new float[10];
        float[] probeArray = {1.05f, 1.25f, 1.33f, 2.1f, 2.05f, 3.1f, 4.1f, 3.1f, 4.1f, 5.1f};
        // Mat data.
        opencv_core.Mat galleryMat = new opencv_core.Mat(5, 5, CV_32FC1);
        final FloatPointer galleryMatData = new FloatPointer(galleryMat.data());
        galleryMatData.put(galleryArray);

        opencv_core.Mat probesMat = new opencv_core.Mat(2, 5, CV_32FC1);
        final FloatPointer probesMatData = new FloatPointer(probesMat.data());
        probesMatData.put(probeArray);
        // Knn search.
        int k = 5;
        JavaKnn02 javaKnn = new JavaKnn02();
        javaKnn.init(k, FLANN_DIST_L2);
        javaKnn.knnSearch(probesMat, galleryMat);

        // Get results.
        Mat indexMat = javaKnn.getIndexMat();
        IntBuffer indexBuf = indexMat.getIntBuffer();
        for (int i = 0; i < probesMat.rows()*k; ++i) {
            System.out.println("" + indexBuf.get(i));
        }
        Mat distsMat = javaKnn.getDistMat();
        FloatBuffer distsBuf = distsMat.getFloatBuffer();
        for (int i = 0; i < probesMat.rows()*k; ++i) {
            System.out.println("" + distsBuf.get(i));
        }
        // Release.
        galleryMatData.deallocate();
        probesMatData.deallocate();
        System.out.println("=== DONE ===");
    }
}
