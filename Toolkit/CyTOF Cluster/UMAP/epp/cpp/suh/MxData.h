//
// Created by Stephen Meehan on 5/19/21.
//

#ifndef EPPCPP_FILES_MXDATA_H
#define EPPCPP_FILES_MXDATA_H
#include "suh.h"

// this header does not coupule includers to  a MATLAB installation
// unless they invoke methods of MxArgs

namespace suh {

    //MxData does not require MATLAB implementation

    template <class T> class MxData {

    public:
        const T *const data;
        const size_t rows,cols;

        // empty
        MxData(): data(nullptr), rows(0), cols(0){
        }

        operator bool () const noexcept{
            return data!= nullptr;
        }

        const T operator[](int idx) noexcept{
            return data[idx];
        }
        bool empty () const{
            return data==nullptr;
        }

        MxData(const T * data, const size_t rows, const size_t cols)
        : data(data), rows(rows), cols(cols){
        }

        T get(const size_t row, const size_t col) const  noexcept{
            return data[ row + rows * col ];
        }

        C<T> get_C() const  noexcept{
            return C<T>((T *)data, rows * cols, false);
        }

        std::vector<std::vector<T>> get_2d_vector() const noexcept{
            std::vector<std::vector<T>> out;
            if (data != nullptr) {
                for (int r = 0; r < rows; r++) {
                    std::vector<T> row;
                    for (int c = 0; c < cols; c++) {
                        row.push_back(data[r + rows * c]);
                    }
                    out.push_back((row));
                }
            }
            return out;
        }

        std::shared_ptr<Matrix<T>> get_matrix_ptr() const noexcept {
            Matrix<T>matrix(data, rows, cols, Transfer::kCopyColumnWise);
            return matrix.shared_ptr();
        }

        const T *get_column_ptr(const int column) const noexcept{
            if (column<0 ||  column>= rows){
                return nullptr;
            }
            return this->data+(column*rows);
        }

        Matrix<T> get_matrix() const  noexcept{
            Matrix<T>matrix(data, rows, cols, Transfer::kCopyColumnWise);
            return matrix;
        }

        T get_scalar(const T default_value, const size_t idx=0) const noexcept{
            return empty()?default_value : data[idx];
        }

        std::ostream &print(
                std::ostream &o = std::cout,
                const bool printRowNum = true,
                const bool printRowEndl=true) const noexcept {
            for (auto row = 0; row < rows; row++) {
                if (printRowNum)
                    o << "#" << (row + 1) << ": ";
                for (auto col = 0; col < cols; col++) {
                    o << get(row, col);
                    if (col < cols - 1) {
                        o  << ",";
                    } else if (printRowEndl || row < (rows-1)){
                        o << std::endl;
                    }
                }
            }
            return o;
        }

        std::string to_string() const noexcept{
            std::strstream s;
            print(s, false, false);
            return s.str();
        }

        void decrement(){
            const T *end=data+(rows*cols);
            for(T *p=(T*)data;p<end;p++)
                (*p)--;
        }

        size_t size(){return rows*cols;}
    };

    template <typename  T> C<T> reshape_to_MATLAB_Vector(
            T **matrix, const size_t rows, const size_t cols){
        Matrix<int> ids_and_0((int *) matrix, rows, cols);
        C<int> c1D(ids_and_0.to_vector());
        return c1D;
    }

}

#endif //EPPCPP_FILES_MXDATA_H
