//
// Created by Stephen Meehan on 12/8/20.
//

#ifndef C___SUH_MATH_H
#define C___SUH_MATH_H

#include <cmath>
#include "suh.h"

namespace suh {

    //compute the rank vector of a vector (as in the MATLAB function)
    void tiedRank(suh::Matrix<double> &rank, const double* x, const size_t size);

    bool inverse(double **a, const size_t n);

    template<class T>
    class InverseCovarianceMatrix : public Matrix<T> {
    public:
        InverseCovarianceMatrix(double **prior_matrix, const size_t columns) :
                Matrix<double>(prior_matrix, columns, columns) {
            this->block_matrix_deallocation();
        }

        InverseCovarianceMatrix(const T **data, const size_t rows, const size_t columns) : Matrix<double>(columns) {
            double *columnMeans = new double[columns];

            for (size_t j = 0; j < columns; j++) {
                double sum = 0.0;
                for (size_t row = 0; row < rows; row++) {
                    sum += data[row][j];
                }
                columnMeans[j] = sum / rows;
            }

            for (size_t i = 0; i < columns; i++) {
                for (size_t j = i; j < columns; j++) {
                    double sum = 0.0;
                    for (size_t row = 0; row < rows; row++) {
                        sum += (data[row][i] - columnMeans[i]) * (data[row][j] - columnMeans[j]);
                    }
                    this->matrix_[i][j] = sum / (rows - 1);
                }
            }
            delete[]columnMeans;

            for (size_t i = 0; i < columns; i++) {
                for (size_t j = 0; j < i; j++) {
                    this->matrix_[i][j] = this->matrix_[j][i];
                }
            }
            inverse(this->matrix_, columns);
        }
    };

    template<class T>
    class VarianceVector : public Matrix<T> {
    public:

        VarianceVector(double **prior_matrix, const size_t columns)
                : Matrix<double>(prior_matrix, 1, columns) {
            this->block_matrix_deallocation();
        }

        VarianceVector(const T **data, const size_t rows, const size_t columns)
                : Matrix<double>(1, columns) {
            T mean;
            T var;
            for (size_t j = 0; j < columns; j++) {
                mean = 0;
                for (size_t i = 1; i < rows; i++) {
                    mean += data[i][j];
                }
                mean /= rows;
                var = 0;
                for (size_t i = 1; i < rows; i++) {
                    var += (data[i][j] - mean)*(data[i][j] - mean);
                }
                var /= (rows - 1);
                if (var == 0) {
                    std::cerr << "Range is 0 in one component!" << std::endl;
                    return;
                }
                this->matrix_[0][j] = var;
            }
        }
    };

}
#endif //C___SUH_MATH_H
