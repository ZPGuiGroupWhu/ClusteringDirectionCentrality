//
// Created by conno on 2021-07-22.
//

#ifndef INPOLYGON_POLYGON_H
#define INPOLYGON_POLYGON_H
#include <cstddef>
#include <cstdlib>
#include <algorithm>

//A naive way to represent a polygon
class Polygon {
public:
    Polygon(const double *xv, const double *yv, size_t N): xv(xv), yv(yv), nVert(N) {
        xDiff = (double *) malloc(N * sizeof(double));
        yDiff = (double *) malloc(N * sizeof(double));
        for (size_t j =0; j < N - 1; ++j) {
            xDiff[j] = xv[j+1] - xv[j];
            yDiff[j] = yv[j+1] - yv[j];
        }
        xDiff[N-1] = xv[0] - xv[N-1];
        yDiff[N-1] = yv[0] - yv[N-1];
        xMax = *std::max_element(xv, xv+N);
        yMax = *std::max_element(yv, yv+N);
        xMin = *std::min_element(xv, xv+N);
        yMin = *std::min_element(yv, yv+N);
    }

    ~Polygon(){
        free(xDiff);
        free(yDiff);
    }
    int* inPoly(const double* xc, const double* yc, size_t nPoints);
    bool * inPoly(const float* xc, const float* yc, size_t nPoints, bool *out);
private:
    size_t nVert; //Number of vertices
    const double *xv;  //x-coordinates of vertices
    const double *yv;  //y-coordinates of vertices
    double xMax, xMin, yMax, yMin; //maximum and minimum x- and y-coordinate s
    double *xDiff; //differences between x-coordinates of adjacent vertices
    double *yDiff; //differences between x-coordinates of adjacent vertices
    bool ccw = true; //Orientation of vertices; by default, counter-clockwise
};

#endif //INPOLYGON_POLYGON_H
