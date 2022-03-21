package com.yolo.CDC.java.knnsearch;

import org.bytedeco.javacpp.FloatPointer;
import org.opencv.core.Core;

import java.nio.FloatBuffer;
import java.nio.IntBuffer;

import static org.bytedeco.javacpp.opencv_core.*;
import static org.bytedeco.javacpp.opencv_flann.*;

/**
 * @author dell
 */
public class JavaKnn
{
    // Underlying parameters for knnsearch.
    private Index flannIndex = null;
    private IndexParams indexParams = null;
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
        if (method == FLANN_DIST_EUCLIDEAN ||
                method == EUCLIDEAN ||
                method == FLANN_DIST_L2) {
            indexParams = new KDTreeIndexParams(4);  // default params = 4
        } else if (method == FLANN_DIST_HAMMING) {
            indexParams = new LshIndexParams(12, 20, 2); // using LSH Hamming distance (default params)
        } else {
            System.out.println("Bad method, use KD Tree instead!");
            indexParams = new KDTreeIndexParams(4);
        }
        searchParams = new SearchParams(64, 0, true); // maximum number of leafs checked.
    }

    // Knn search.
    public void knnSearch(Mat probes, Mat gallery) {
        int rows = probes.rows();
        indexMat = new Mat(rows, k, CV_32SC1);
        distMat = new Mat(rows, k, CV_32FC1);
        // find nearest neighbors using FLANN
        // TODO: If it can be built only once?
        flannIndex.build(gallery, indexParams, method);
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
        System.out.println(System.getProperty("java.library.path"));
        System.loadLibrary(Core.NATIVE_LIBRARY_NAME);
        // Source data.
        // float[] galleryArray = new float[25];
        float[] galleryArray = {1.1f, 1.2f, 1.3f, 2.2f, 2.3f, 3.4f, 1.2f, 7.1f, 2.1f, 2.7f, 9.0f, 1.9f, 1.0f, 0.1f, 0.2f, 9.1f, 6.1f, 6.6f, 7.8f, 2.5f, 2.3f, 2.4f, 3.5f, 4.5f, 3.4f};
        //float[] probeArray = new float[10];
        float[] probeArray = {1.05f, 1.25f, 1.33f, 2.1f, 2.05f, 3.1f, 4.1f, 3.1f, 4.1f, 5.1f};
        // Mat data.
        Mat galleryMat = new Mat(5, 5, CV_32FC1);
        final FloatPointer galleryMatData = new FloatPointer(galleryMat.data());
        galleryMatData.put(galleryArray);

        Mat probesMat = new Mat(2, 5, CV_32FC1);
        final FloatPointer probesMatData = new FloatPointer(probesMat.data());
        probesMatData.put(probeArray);
        // Knn search.
        int k = 2;
        JavaKnn javaKnn = new JavaKnn();
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
