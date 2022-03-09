//
// Created by conno on 2021-07-22.
//

#include "Polygon.h"
#include <cstddef>
#include <cstdlib>
#include <iostream>


//A naive way to check if a point is in a polygon.
int* Polygon::inPoly(const double *xc, const double *yc, size_t nPoints) {
    int* out = (int *) malloc(nPoints * sizeof(int));
    bool onPerim, outside;
    double xTrans, yTrans, offset;
    for (size_t i = 0; i < nPoints; ++i) {
        onPerim = false;
        outside = false;
        for (size_t j = 0; j < this->nVert; ++j) {
            xTrans = xc[i] - this->xv[j];
            yTrans = yc[i] - this->yv[j];
            offset = xDiff[j]*yTrans - yDiff[j]*xTrans;
            if (offset < 0) {
                outside = true;
                break;
            }
            else if (offset == 0)
                onPerim = true;
        }
        if (outside) out[i] = -1;
        else if (onPerim) out[i] = 0;
        else out[i] = 1;
    }
    return out;
}

bool * Polygon::inPoly(const float *xc, const float *yc, size_t nPoints,  bool *out) {
    bool onPerim, outside;
    double xTrans, yTrans, offset;
    for (size_t i = 0; i < nPoints; ++i) {
        onPerim = false;
        outside = false;
        for (size_t j = 0; j < this->nVert; ++j) {
            xTrans = xc[i] - this->xv[j];
            yTrans = yc[i] - this->yv[j];
            offset = xDiff[j]*yTrans - yDiff[j]*xTrans;
            if (offset < 0) {
                outside = true;
                break;
            }
            else if (offset == 0)
                onPerim = true;
        }
        if (outside) out[i] = false;
        else if (onPerim) out[i] = false;
        else out[i] = true;
    }
    return out;
}


