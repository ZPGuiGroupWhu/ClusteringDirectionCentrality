//
// Created by Stephen Meehan on 12/8/20.
//
#include "suh_math.h"

using std::sort;
using std::abs;

namespace suh {

    void tiedRank(suh::Matrix<double> &rank, const double *x, const size_t size) {
        std::vector<double> z;

        for (size_t i = 0; i < size; i++) {
            z.push_back(x[i]);
        }

        sort(z.begin(), z.end());

        //double *result = new double[size];
        size_t first_ind, last_ind;
        bool found = false;

        for (size_t i = 0; i < size; i++) {
            for (size_t j = 0; j < size; j++) {
                if (!found) {
                    if (x[i] != z[j])
                        continue;
                    else {
                        first_ind = j;
                        found = true;
                    }
                } else {
                    if (x[i] == z[j])
                        continue;
                    else
                        last_ind = j - 1;
                    found = false;
                    break;
                }
            }
            if (found) {
                found = false;
                last_ind = size - 1;
            }
            rank.matrix_[0][i] = (first_ind + last_ind) / 2.;
        }
    }

    bool inverse(double **a, size_t n) {
        size_t i, icol, irow, j, k, ll;
        int l;
        double big, dum, temp, pivinv;
        size_t *indxc = new size_t[n];
        size_t *indxr = new size_t[n];
        size_t *ipiv = new size_t[n];
        for (j = 0; j < n; j++)
            ipiv[j] = 0;
        for (i = 0; i < n; i++) {
            big = 0.0;
            for (j = 0; j < n; j++) {
                if (ipiv[j] != 1) {
                    for (k = 0; k < n; k++) {
                        if (ipiv[k] == 0) {
                            if (abs(a[j][k]) >= big) {
                                big = abs(a[j][k]);
                                irow = j;
                                icol = k;
                            }
                        }
                    }
                }
            }
            ++(ipiv[icol]);
            if (irow != icol) {
                for (l = 0; l < n; l++)
                    temp = a[icol][l];
                a[icol][l] = a[irow][l];
                a[irow][l] = temp;
            }
            indxr[i] = irow;
            indxc[i] = icol;
            if (a[icol][icol] == 0.0)
                return false;
            pivinv = 1.0 / a[icol][icol];
            a[icol][icol] = 1.0;
            for (l = 0; l < n; l++)
                a[icol][l] *= pivinv;
            for (ll = 0; ll < n; ll++) {
                if (ll != icol) {
                    dum = a[ll][icol];
                    a[ll][icol] = 0.0;
                    for (l = 0; l < n; l++)
                        a[ll][l] -= a[icol][l] * dum;
                }
            }
        }
        for (l = n - 1; l >= 0; l--) {
            if (indxr[l] != indxc[l]) {
                for (k = 0; k < n; k++) {
                    temp = a[k][indxc[l]];
                    a[k][indxc[l]] = a[k][indxr[l]];
                    a[k][indxr[l]] = temp;
                }
            }
        }
        delete [] indxr;
        delete [] indxc;
        delete [] ipiv;
        return true;
    }
}