//
// namespace suh contains C++ from Stanford University's Herzenberg Lab
//
// Created by Stephen Meehan on 10/29/20.
//
/*
AUTHOR
   Stephen Meehan <swmeehan@stanford.edu>

Provided by suh ( Stanford University's Herzenberg Lab)
License: BSD 3 clause
*/

/* Items in suh namespace are  migrating  towards
* a) the Google C++ style guide https://google.github.io/styleguide/cppguide.html
* b) Effective C++ idioms from Scott Meyers https://www.aristeia.com/books.html
*
* The biggest visible effect of migration a) is Google's naming conventions
* https://google.github.io/styleguide/cppguide.html#Namng
* One deviation is snake_use as does C++ std (e.g. std::string::push_back())
*  for class data names and class instance & static function names
*  instead of CamelCase or camelCase
*
* The biggest  impact of  migration b) is adding the keyword const everywhere.
*       This could help with compiler optimization for builtins that were previously non const references
*/

#ifndef SUH_H
#define SUH_H

#include <string>
#include <iostream>
#include <strstream>
#include <sstream>
#include <fstream>
#include <regex>
#include <memory>
#include <assert.h>
#include <vector>
#include <functional>
#include <cmath>
#include <numeric>      // std::iota
#include <algorithm>    // std::sort, std::stable_sort
#include <set>


using std::pow;

namespace suh {
    extern std::set<int> debug_keys;
    extern int debug_key_cnt;

#define SUH_DEBUG_CTOR_DTOR 0
    extern bool debug_ctor_dtor;
    static const bool debug_file_io = true, debug_timing = false;

    using FncProgress = std::function<bool(const int iter, const int n_iters)>;
    using FncProgressTxt = std::function<bool(const char *txt, const int iter, const int n_iters)>;
    inline double secs(long microseconds) {
        return ((double) microseconds / 1000000.0);
    }

    template<typename ... Args>
    std::string string_format(const std::string &format, Args ... args) {
        size_t size = snprintf(nullptr, 0, format.c_str(), args ...) + 1; // Extra space for '\0'
        if (size <= 0) { throw std::runtime_error("Error during formatting."); }
        std::unique_ptr<char[]> buf(new char[size]);
        snprintf(buf.get(), size, format.c_str(), args ...);
        return std::string(buf.get(), buf.get() + size - 1); // We don't want the '\0' inside
    }

    inline std::string str_secs(long microseconds) {
        return suh::string_format("%4.3f", ((double) microseconds / 1000000.0));
    }

    template<typename T>
    std::string bank_num(T num) {
        return suh::string_format("%.2f", (double) num);
    }


    template<typename T>
    void append(std::vector<T> &a, const std::vector<T> &b) {
        a.insert(std::end(a), std::begin(b), std::end(b));
    }

    template<typename T>
    void append(std::vector<std::vector<T>> &a, const std::vector<std::vector<T>> &b) {
        a.insert(std::end(a), std::begin(b), std::end(b));
    }

    template<typename T>
    std::ostream &print(
            const std::vector<T> &in,
            std::ostream &o = std::cout,
            const char *delim = ",",
            const char *title = nullptr,
            const bool sort = false) noexcept{
        const int N = in.size();
        if (title) o << title << std::endl;
        if (sort) {
            std::vector<T>copy=in;
            std::sort(copy.begin(), copy.end());
            for (int i = 0; i < N; i++)
                if (i < N - 1)
                    o << copy[i] << delim;
                else
                    o << copy[i] << std::endl;
        } else
            for (int i = 0; i < N; i++)
                if (i < N - 1)
                    o << in[i] << delim;
                else
                    o << in[i] << std::endl;
        return o;
    }

    template<typename T>
    std::ostream &operator<<(std::ostream &o, const std::vector<T> &in) {
        return print(in, o);
    }

    template<typename T>
    std::ostream &print(const std::vector<std::vector<T>> &in, const bool flat = true, std::ostream &o = std::cout,
                        const char *delim = ",") {
        const int rows = in.size();
        if (flat)
            for (int row = 0; row < rows; row++) {
                const int columns = in[row].size();
                for (int col = 0; col < columns; col++)
                    o << in[row][col] << delim;
                if (row == rows - 1)
                    o << std::endl;
            }
        else
            for (int row = 0; row < rows; row++)
                print(in[row], o, delim);
        return o;
    }

    template<typename T>
    std::ostream &operator<<(std::ostream &o, const std::vector<std::vector<T>> &in) {
        return print(in, true, o);
    }

    template<typename T>
    double mean(const T *const nums, const int size) {
        double sum = 0;
        for (int i = 0; i < size; i++) {
            sum += nums[i];
        }
        return sum / (double) size;
    }

    inline int strcmpi(const char *l, const char *r) {
        int lenDiff = strlen(l) - strlen(r);
        if (lenDiff != 0) {
            return lenDiff;
        }
        while (*r && *l) {
            const int dif = tolower(*l) - tolower(*r);
            if (dif != 0) {
                return dif;
            }
            r++;
            l++;
        }
        return 0;
    }

    inline int strcmpi(std::string l, std::string r) {
        int lenDiff = l.size() - r.size();
        if (lenDiff != 0) {
            return lenDiff;
        }
        for (int i = 0; i < l.size(); i++) {
            if (tolower(l[i]) != tolower(r[i])) {
                return l[i] - r[i];
            }
        }
        return 0;
    }

    template<typename T>
    T **new_matrix(const size_t rows, const size_t columns) {
        if (rows == 0 || columns == 0)
            return nullptr;
        T **ptr = nullptr;
        T *pool = nullptr;
        try {
            ptr = new T *[rows];  // allocate pointers (can throw here)
            pool = new T[rows * columns];  // allocate pool (can throw here)

            // now point the row pointers to the appropriate positions in
            // the memory pool
            for (unsigned i = 0; i < rows; ++i, pool += columns)
                ptr[i] = pool;

            // Done.
            return ptr;
        }
        catch (std::bad_alloc &ex) {
            delete[] ptr; // either this is nullptr or it was allocated
            throw ex;  // memory allocation error
        }
    }

    template<typename T>
    T **new_matrix(const T *pool, const size_t rows, const size_t cols) {
        if (rows == 0 || cols == 0)
            return nullptr;
        T **ptr = nullptr;
        try {
            ptr = new T *[rows];  // allocate pointers (can throw here)
            // now point the row pointers to the appropriate positions in
            // the memory pool
            for (unsigned i = 0; i < rows; ++i, pool += cols)
                ptr[i] = (T *) pool;
            return ptr;
        }
        catch (std::bad_alloc &ex) {
            delete[] ptr; // either this is nullptr or it was allocated
            throw ex;  // memory allocation error
        }
    }

    // k prefix conforms to Google C++ style guide
    //kCopyColumnWise serves MatLab matrices
    enum class Transfer {
        kMove, kCopy, kCopyColumnWise
    };

    template<typename T>
    void copy(T **to, const T **from, const size_t rows, const size_t columns) {
        for (int row = 0; row < rows; row++) {
            for (int col = 0; col < columns; col++) {
                to[row][col] = from[row][col];
            }
        }
    }

    // by default copy MatLab matrices (column wise order)
    template<typename T>
    T **new_matrix(const T *pool, const size_t rows, const size_t columns, const Transfer transfer) {
        T **ptr = nullptr;
        if (transfer == Transfer::kMove) {
            ptr = new_matrix < T > (pool, rows, columns);
            for (unsigned i = 0; i < rows; ++i, pool += columns)
                ptr[i] = (T *) pool;
        } else {
            ptr = new_matrix < T > (rows, columns);
            if (transfer == Transfer::kCopyColumnWise) {
                for (int col = 0; col < columns; col++) {
                    for (int row = 0; row < rows; row++) {
                        ptr[row][col] = pool[row + rows * col];
                    }
                }
            } else { // Transfer::kCopy
                unsigned int N = rows * columns;
                T *const to = ptr[0], *end = to + N;
                for (int i = 0; i < N; i++) {
                    to[i] = pool[i];
                }
            }
        }
        return (T **) ptr;
    }


    template<typename T>
    T **new_matrix(const size_t rows, const size_t columns, const T default_value) {
        T **ptr = new_matrix < T > (rows, columns);
        std::fill_n(ptr[0], rows * columns, default_value);
        return ptr;
    }

    template<typename T>
    void delete_matrix(T **arr) {
        delete[] arr[0];  // remove the pool
        delete[] arr;     // remove the pointers
    }

    template<typename T>
    T ***new_matrices(const size_t n_matrices, const size_t rows, const size_t columns, const T *default_values) {
        T ***ptr = new T **[n_matrices];
        for (int i = 0; i < n_matrices; i++) {
            ptr[i] = new_matrix<T>(rows, columns, default_values[i]);
        }
        return ptr;
    }

    template<typename T>
    T ***new_matrices(const size_t n_matrices, const size_t rows, const size_t columns) {
        T ***ptr = new T **[n_matrices];
        for (int i = 0; i < n_matrices; i++) {
            ptr[i] = new_matrix<T>(rows, columns);
        }
        return ptr;
    }

    template<typename T>
    T ***new_matrices(const T ***prior, const size_t n_matrices, const size_t rows, const size_t columns) {
        T ***ptr = new T **[n_matrices];
        for (int i = 0; i < n_matrices; i++) {
            ptr[i] = new_matrix<T>(prior[i][0], rows, columns, Transfer::kCopy);
        }
        return ptr;
    }

    template<typename T>
    void
    delete_matrices(T ***matrices_ptr, const size_t n_matrices) {
        if (matrices_ptr != nullptr) {
            for (int i = 0; i < n_matrices; i++) {
                delete_matrix(matrices_ptr[i]);
            }
        }
    }

    inline std::string home_file(const char *path) {
        std::string home("/Users/");
        home.append(getenv("USER"));
        home.append(path);
        return home;
    }

    inline std::string documents_file(const char *path) {
        std::string home("/Users/");
        home.append(getenv("USER"));
        home.append("/Documents/");
        home.append(path);
        return home;
    }

    inline std::string run_umap_examples_file(const char *path) {
        std::string home("/Users/");
        home.append(getenv("USER"));
        home.append("/Documents/run_umap/examples/");
        home.append(path);
        return home;
    }

    inline std::string trim(std::string s) {
        std::regex e("^\\s+|\\s+$");   // remove leading and trailing spaces
        return regex_replace(s, e, "");
    }

    template<typename T>
    std::ostream &print(const T **const data, const int rows, const int columns, std::ostream &o = std::cout) {
        for (auto row = 0; row < rows; row++) {
            o << "#" << (row + 1) << ": ";
            for (auto col = 0; col < columns; col++) {
                if (col < columns - 1) {
                    o << data[row][col] << ",";
                } else {
                    o << data[row][col] << std::endl;
                }
            }
        }
        return o;
    }

    template<typename T>
    void print(const T *const data, const int size, std::ostream &o = std::cout) {
        for (int i = 0; i < size; i++) {
            if (i < size - 1) {
                std::cout << data[i] << ',';
            } else {
                std::cout << data[i] << std::endl;
            }
        }
    }

    inline void Debug(double **nums, const int row, const int size) {
        std::cout << "#" << row << " *=" << suh::mean(nums[row], size) << ":";
        suh::print(nums[row], size);
    }

    template<typename T>
    void Debug(T *nums, const int size) {
        std::cout << " *=" << suh::mean(nums, size) << ":";
        suh::print(nums, size);
    }

    //Utility for bounds checking of Matrix
    template<class T>
    class Row {
    public:
        T *const row;
        const int columns;

        inline Row(T *const row, const int columns) : row(row), columns(columns) {
        }

        inline T operator[](int column) const {
            assert(column >= 0 && column < columns && row != nullptr);
            return row[column];
        }
    };

#if(SUH_DEBUG_CTOR_DTOR == 1)
#define SUH_ID_FACTORY \
                   namespace suh{ \
                   int suh_ids=0; \
                   int id_factory(){ \
                   std::cout<<"ID #" << (suh_ids+1) << std::endl; \
                   return suh_ids++;\
                   }\
                   };

    int id_factory();
#else
#define SUH_ID_FACTORY
#endif

// Matrix is a class that contains 2D arrays allocated externally typically of builtin type
// It serves these externally builtin 2D arrays by providing a way to destruct them when the container
// loses scope.  Matrix can be a stack variable and simplify destruction.  It can also be built on the stack
// and then be switched to the heap with shared_ptr at which point the original allocation is not lost when
// and then be switched to the heap with shared_ptr at which point the original allocation is not lost when
// the stack variable leaves scope of its closure
    template<class T>
    class Matrix {
    public:
#if(SUH_DEBUG_CTOR_DTOR == 1)
        const int id=id_factory();
#endif

        //Utility for bounds checking indexing of matrix otherwise use this->matrix[row][col]
        inline suh::Row<T> operator[](int row) const {
            assert(row >= 0 && row < rows_ && matrix_ != nullptr);
            return Row<T>(matrix_[row], columns_);
        }

        T **matrix_;
        size_t columns_;
        size_t rows_;

        const T *const *operator()() { return (const T *const *) matrix_; }

        const T *const *operator*() { return (const T *const *) matrix_; }

        Matrix() : matrix_(nullptr), columns_(0), rows_(0) {
        }

        Matrix(const T *pool, const size_t rows, const size_t columns, const Transfer transfer = Transfer::kCopy)
                : matrix_(nullptr), columns_(columns), rows_(rows) {
            matrix_ = new_matrix(pool, rows, columns, transfer);
#if(SUH_DEBUG_CTOR_DTOR == 1)
            std::cout<<"Matrix(pool, rows, columns)"<<std::endl;
#endif
        }

        Matrix(T **const matrix, const size_t rows, const size_t columns) : matrix_(matrix), rows_(rows),
                                                                            columns_(columns) {

#if(SUH_DEBUG_CTOR_DTOR == 1)
            std::cout<<"Matrix(matrix, rows, columns)"<<std::endl;
#endif
        }

        Matrix(const size_t size) : matrix_(suh::new_matrix<T>(size, size)), rows_(size), columns_(size) {
#if(SUH_DEBUG_CTOR_DTOR == 1)
            std::cout<<"Matrix(size)"<<std::endl;
#endif

        }

        Matrix(const size_t rows, const size_t columns) : matrix_(suh::new_matrix<T>(rows, columns)), rows_(rows),
                                                          columns_(columns) {
#if(SUH_DEBUG_CTOR_DTOR == 1)
            std::cout << "Matrix(rows,columns)" << std::endl;
#endif
        }

        Matrix<T> &operator=(const Matrix<T> &other) = delete;

        void block_matrix_deallocation() {
            shared = this;
        }

        void clear() {
            if (delete_each_row) {
                for (int row = 0; row < rows_; row++) {
                    std::memset(matrix_[row], 0, columns_ * sizeof(T));
                }
            } else {
                //everybody out of the pool!
                std::memset(matrix_[0], 0, rows_ * columns_ * sizeof(T));
            }
        }

        T **reset(const T default_value) {
            if (delete_each_row) {
                for (auto row = 0; row < rows_; row++)
                    std::fill_n(matrix_[row], columns_, default_value);
            } else
                std::fill_n(matrix_[0], rows_ * columns_, default_value);
            return matrix_;
        }

        T *resetRow(const T default_value, const size_t row) {
            std::fill_n(matrix_[row], columns_, default_value);
            return matrix_[row];
        }

        virtual ~Matrix() {
            if (shared == nullptr) {
                if (matrix_ != nullptr) {

                    if (delete_each_row) {
                        for (int row = 0; row < rows_; row++) {
                            delete[] matrix_[row];
                        }
                        if (debug_ctor_dtor)
                            std::cout << " destructing matrix & rows ";
                    } else { // delete the pool of rows X columns of T
                        delete[] matrix_[0];
                        if (debug_ctor_dtor)
                            std::cout << " destructing matrix & pool ";
                    }
                    delete matrix_;
                    if (debug_ctor_dtor)
                        std::cout << std::string(*this) << std::endl;
                } else {
                    if (debug_ctor_dtor)
                        std::cout << "destructing matrix with nullptr " << rows_ << " X " << columns_ << std::endl;
                }
            }
        }

        virtual operator std::string() const {
            std::strstream s;
            s << "matrix: " << rows_ << " X " << columns_;
            return s.str();
        }

        void copy_column_wise(T *to) const {
            for (int row = 0; row < rows_; row++) {
                for (int col = 0; col < columns_; col++) {
                    to[row + rows_ * col] = matrix_[row][col];
                }
            }
        }

        void copy_column_wise(T *to, const T add) const {
            for (int row = 0; row < rows_; row++) {
                for (int col = 0; col < columns_; col++) {
                    to[row + rows_ * col] = matrix_[row][col] + add;
                }
            }
        }

    private:
        Matrix<T> *shared = nullptr;
        std::shared_ptr<Matrix<T>> sh;

        // TODO since this constructor is not orthodox copy constructor
        // and lives on all for shared_ptr() method it should be replaced
        // with a constructor that the compiler does not notice
        // and a REAL copy constructor must be built this with a PROPER and safe copy constructor
        Matrix(const Matrix<T> &other)
                : matrix_(other.matrix_), rows_(other.rows_),
                  columns_(other.columns_), delete_each_row(other.delete_each_row) {
        }
    public:

        Matrix(Matrix<T> &&other)
                : matrix_(other.matrix_), rows_(other.rows_),
                  columns_(other.columns_), delete_each_row(other.delete_each_row) {
            other.matrix_=nullptr;
            std::cout<<"hmm move?"<<std::endl;
        }
// TODO must create proper copy asignment and move asignment functions .... not that hard to do
    protected:
        bool delete_each_row = false;

        std::vector<std::string> columnNames;

    public:
        bool isDeleteEachRow() const{return delete_each_row;}
         T*pool() const {return matrix_[0];}
        std::shared_ptr<Matrix<T>> shared_ptr() {
            if (shared == nullptr) {
                shared = new Matrix<T>(*this);
                sh = std::shared_ptr<Matrix < T>>
                (shared);
            }
            return std::shared_ptr<Matrix < T>>
            (sh);
        }

        inline T *vector(int row = 0) const {
            if (rows_ != 1) {
                std::cerr << "vector() called for matrix with "
                          << rows_ << " rows???" << std::endl;
            }
            return matrix_[0];
        }

        std::ostream &print(std::ostream &o = std::cout) const {

            for (int col = 0; col < this->columns_; col++) {
                if (col < columnNames.size()) {
                    o << columnNames[col];
                } else {
                    o << "col " << (col + 1);
                }
                if (col < this->columns_ - 1) {
                    o << ',';
                } else {
                    o << std::endl;
                }
            }
            suh::print((const T **) this->matrix_, this->rows_, this->columns_, o);
            return o;
        }

        std::ostream &print(const int row, std::ostream &o = std::cout) const {
            suh::print(this->matrix_[row], this->columns_, o);
            return o;
        }

        std::vector<T> to_vector(const Transfer tr = Transfer::kCopyColumnWise) {
            std::vector<T> vector;
            int i = 0;
            if (tr == Transfer::kCopyColumnWise)
                for (int y = 0; y < columns_; y++)
                    for (int x = 0; x < rows_; x++)
                        vector.push_back(matrix_[x][y]);
            else
                for (int x = 0; x < rows_; x++)
                    for (int y = 0; y < columns_; y++)
                        vector.push_back(matrix_[x][y]);
            return vector;
        }
    };

    template<typename T>
    int count_unequal(const std::vector<T> v1, const std::vector<T> v2,
                      const double tolerance = .0002) {
        int dif = abs((long) (v1.size() - v2.size()));
        for (int row = 0; row < v1.size(); row++)
            if (row < v2.size()) {
                T value1 = v1[row], value2 = v2[row];
                T d = abs(value1 - value2);
                if (d > tolerance)
                    dif++;
            }
        return dif;
    }

    template<typename T>
    int count_unequal(const std::vector<std::vector<T>> v1, const std::vector<std::vector<T>> v2,
                      const double tolerance = .0002) {
        int dif = abs((long) (v1.size() - v2.size()));
        for (int row = 0; row < v1.size(); row++)
            if (row < v2.size()) {
                dif += abs((long) (v1[row].size() - v2[row].size()));
                for (int col = 0; col < v1[0].size(); col++) {
                    if (col < v2[row].size()) {
                        T value1 = v1[row][col], value2 = v2[row][col];
                        T d = abs(value1 - value2);
                        if (d > tolerance)
                            dif++;
                    }
                }
            }
        return dif;
    }

    template<typename T>
    int count_unequal(const T **thisPtr, const T **thatPtr, const size_t rows, const size_t columns) {
        int dif = 0;
        for (int row = 0; row < rows; row++)
            for (int col = 0; col < columns; col++)
                if (thisPtr[row][col] != thatPtr[row][col])
                    dif++;
        return dif;
    }

    template<typename T>
    int count_unequal(const T *thisPtr, const T *thatPtr, const size_t rows, const size_t columns) {
        int dif = 0;
        const size_t N = rows * columns;
        for (int i = 0; i < N; i++)
            if (thisPtr[i] != thatPtr[i])
                dif++;
        return dif;
    }

    template<typename T>
    int count_unequal(const Matrix<T> &this_matrix, const Matrix<T> &that_matrix) {
        const size_t rows = this_matrix.rows_ > that_matrix.rows_ ? that_matrix.rows_ : this_matrix.rows_;
        const size_t columns =
                this_matrix.columns_ > that_matrix.columns_ ? that_matrix.columns_ : this_matrix.columns_;
        return count_unequal((const T **) this_matrix.matrix_, (const T **) that_matrix.matrix_, rows, columns);
    }


    template<typename T>
    std::vector<int> get_unequal(const Matrix<T> &this_matrix, const Matrix<T> &that_matrix, const int row,
                                 const double tolerance = .0002) {
        const size_t columns =
                this_matrix.columns_ > that_matrix.columns_ ? that_matrix.columns_ : this_matrix.columns_;
        std::vector<int> notEqual;
        T *thisRow = this_matrix.matrix_[row], *thatRow = that_matrix.matrix_[row];
        for (int col = 0; col < columns; col++) {
            if (thisRow[col] != thatRow[col]) {
                if (tolerance == 0) {
                    notEqual.push_back(col);
                } else {
                    if (abs(thisRow[col] - thatRow[col]) > tolerance)
                        notEqual.push_back(col);
                }
            }
        }
        return notEqual;
    }

    template<typename T>
    int print_inequalities(const Matrix<T> &this_matrix, const Matrix<T> &that_matrix, const int row,
                           const bool print_if_equal = false, const double tolerance = .0002) {
        std::vector<int> bad = suh::get_unequal(this_matrix, that_matrix, row, tolerance);
        if (print_if_equal && !bad.empty()) {
            std::cout << "Row #" << row << " has " << bad.size() << " inequal values @ columns:" << std::endl;
            std::cout << "    ->";
            for (int i = 0; i < bad.size(); i++) {
                std::cout << " " << bad[i];
            }
            std::cout << std::endl;
        }
        return bad.size();
    }

    template<typename T>
    int
    print_inequalities(const Matrix<T> &this_matrix, const Matrix<T> &that_matrix, const bool print_if_equal = false,
                       const double tolerance = .0002) {
        const size_t rows = this_matrix.rows_ > that_matrix.rows_ ? that_matrix.rows_ : this_matrix.rows_;
        int badCnt = 0;
        for (int row = 0; row < rows; row++) {
            badCnt += print_inequalities(this_matrix, that_matrix, row);
        }
        if (badCnt > 0 || print_if_equal) {
            if (badCnt == 0) {
                std::cout << "PERFECT:  ";
            }
            std::cout << bank_num(100.0 - (100.0 * (double) badCnt / (double) (rows * this_matrix.columns_)))
                      << "% similar (" << badCnt << "/" << (rows * this_matrix.columns_);

            int inexact;
            if (tolerance > 0)
                inexact = count_unequal(this_matrix, that_matrix);
            else
                inexact = badCnt;
            if (badCnt != inexact) {
                std::cout << " more than .0002 different, " << bank_num(inexact) << " unequal";
            } else {
                std::cout << " are unequal";
            }
            std::cout << ")" << std::endl;
        }
        return badCnt;
    }

    using MatrixPtr = std::shared_ptr<suh::Matrix<double>>;
    using MatrixIntPtr = std::shared_ptr<suh::Matrix<int>>;

    template<class T>
    class CsvMatrix : public Matrix<T> {
    public:
        inline suh::Row<T> operator[](int row) const {
            return Row<T>(this->matrix_[row], this->columns_);
        }

        CsvMatrix(const std::string file_path, const std::string suffix = "")
                : Matrix<T>() {
            if (suh::debug_file_io) {
                std::cout << "Reading " << file_path << "...";
                std::cout.flush();
            }
            std::vector<T *> matrixVector;
            std::string s(file_path);
            s.append(suffix);
            std::ifstream csv_file(s);
            this->delete_each_row = true;
            if (!csv_file.good()) {
                std::cerr << "The file " << s << " does NOT exist !!!" << std::endl;
            }
            if (csv_file.is_open()) {
                std::string line, colName;
                while (std::getline(csv_file, line) && trim(line).empty());
                std::stringstream lineOfNames(line);
                while (std::getline(lineOfNames, colName, ','))
                    this->columnNames.push_back(colName);
                this->columns_ = this->columnNames.size();
                while (std::getline(csv_file, line) && trim(line).empty());
                while (!line.empty()) {
                    std::stringstream rowOfValues(line);
                    int colIdx = 0;
                    T *const row = new T[this->columns_];
                    std::string token;
                    while (std::getline(rowOfValues, token, ',')) {
                        std::stringstream tokenLine(token);
                        tokenLine >> row[colIdx];
                        if (colIdx++ == this->columns_)
                            break;
                        if (rowOfValues.peek() == ',')
                            rowOfValues.ignore();
                    }
                    matrixVector.push_back(row);
                    if (!std::getline(csv_file, line)) {
                        break;
                    }
                }
            }
            csv_file.close();
            if (this->columns_ > 1) {
                this->rows_ = matrixVector.size();
                this->matrix_ = new T *[this->rows_];
                for (int row = 0; row < this->rows_; ++row) {
                    this->matrix_[row] = matrixVector[row];
                }
            } else {
                this->rows_ = 1;
                this->columns_ = matrixVector.size();
                T *row = new T[this->columns_];
                this->matrix_ = new T *[this->rows_];
                this->matrix_[0] = row;
                for (int col = 0; col < this->columns_; ++col) {
                    T *p = matrixVector[col];
                    row[col] = p[0];
                    delete[] p;
                }
            }
            if (suh::debug_file_io)
                std::cout << this->rows_ << " X " << this->columns_ << " values read." << std::endl;

        }

        T *operator[](const int row) {
            return this->matrix_[row];
        }

    };

    template<typename T>
    struct Deserialize {
        std::string name;
        int columns_ = 0;
        std::vector<std::vector<T>> v2;

        Deserialize(const std::string &in) {
            std::stringstream rowOfValues(in);
            std::vector<T> v1;
            std::getline(rowOfValues, name, ',');
            if (!name.empty()) {
                std::string token;
                std::getline(rowOfValues, token, ',');
                std::stringstream c(token);
                c >> columns_;
                if (columns_ > 0) {
                    size_t colIdx = 0;
                    T value;
                    while (std::getline(rowOfValues, token, ',')) {
                        std::stringstream tokenLine(token);
                        tokenLine >> value;
                        v1.push_back(value);
                        if (colIdx == this->columns_ - 1) {
                            v2.push_back(v1);
                            v1.clear();
                            colIdx = 0;
                        } else {
                            colIdx++;
                        }
                        if (rowOfValues.peek() == ',')
                            rowOfValues.ignore();
                    }
                }
            }
        }
    };


    struct KnnSelfOtherUseCaseCsv {
        suh::CsvMatrix<int> indices, indptr;
        suh::CsvMatrix<double> self, other, correctKnnIndices, correctKnnDists;

        inline KnnSelfOtherUseCaseCsv(const std::string trainingSetPath, const std::string testSetPath) :
                other(trainingSetPath, ".csv"),
                self(testSetPath, ".csv"),
                indptr(trainingSetPath, ".indptr.csv"),
                indices(trainingSetPath, ".indices.csv"),
                correctKnnDists(testSetPath, ".knnDists.csv"),
                correctKnnIndices(testSetPath, ".knnIndices.csv") {
            assert(other.rows_ + 1 == indptr.columns_);
        }

    };

    using strs = std::vector<std::string>;
    using ints = std::vector<int>;
    using grid_idxs=std::vector<int>; // grid size of M*M rarely exceeds INT_MAX

    using ints2D = std::vector<std::vector<int>>;
    using size_ts = std::vector<size_t>;
    using size_ts2D = std::vector<std::vector<size_t>>;
    using doubles = std::vector<double>;
    using doubles2D = std::vector<std::vector<double>>;

    template<typename T>
    std::vector<int> sort_indexes(const std::vector<T> &v) {

        // initialize original index locations
        std::vector<int> idx(v.size());
        std::iota(idx.begin(), idx.end(), 0);

        // sort indexes based on comparing values in v
        // using std::stable_sort instead of std::sort
        // to avoid unnecessary index re-orderings
        // when v contains elements of equal values
        std::stable_sort(idx.begin(), idx.end(),
                         [&v](size_t i1, size_t i2) { return v[i1] < v[i2]; });
        return idx;
    }

    template<typename T>
    std::vector<T> to_vector(const std::initializer_list<T> in) noexcept{
        std::vector<T> v(in);
        return v;
    }

    template<typename T>
    std::vector<T> to_vector(const T *ptr, const size_t N) noexcept{
        std::vector<T> v;
        for (int i = 0; i < N; i++) {
            v.push_back(ptr[i]);
        }
        return v;
    }

    inline std::vector<int> to_original_order(const std::vector<int> idxs, bool ascending = true) {
        std::vector<int> original(idxs);
        const int N = idxs.size();
        if (ascending) {
            for (auto i = 0; i < N; i++) {
                const int idx = idxs[i];
                original[idx] = i;
            }
        } else {
            const int mx = N - 1;
            for (auto i = 0; i < N; i++) {
                const int idx = idxs[i];
                original[idx] = mx - i;
            }
        }
        return original;
    }

    template<typename T>
    std::vector<std::string> sort_letters(
            const T *ptr,
            const size_t N,
            bool ascending = false,
            bool verbose = false) {
        std::vector<std::string> letters;
        std::vector<int> idxs = sort_indexes(to_vector(ptr, N));
        idxs = to_original_order(idxs, ascending);
        char letter[2];
        letter[1] = '\0';
        for (auto i = 0; i < N; i++) {
            letter[0] = 'A' + idxs[i];
            letters.push_back(std::string(letter));
        }
        if (verbose) {
            for (auto i = 0; i < N; i++) {
                const T value = ptr[i];
                std::cout << value << " is #" << idxs[i] << ":" << letters[i] << std::endl;
            }
        }
        return letters;
    }

    template<typename T>
    T *to_c(const std::vector<T> &vector) {
        const size_t N = vector.size();
        T *raw;
        raw = new T[N];
        for (int i = 0; i < N; i++) {
            raw[i] = vector[i];
        }
        return raw;
    }

    template<class T>
    class C {
    public:
        C() : data(nullptr), N(0), delete_in_destructor(false){}

        C(const size_t sz, const T*default_value= nullptr):data(new T[sz]), N(sz), delete_in_destructor(true){
            if (default_value!= nullptr)
                reset(*default_value);
        }
        C(const std::vector<T> &vector)
                : data(to_c(vector)), N(vector.size()), delete_in_destructor(true) {
        }

        // TODO force invokers to KNOW if data is on heap ... FATAL if not known
        C(T  *const data, const size_t N, const bool destructor_deletes_data) noexcept :
                data(data),
                N(N),
                delete_in_destructor(destructor_deletes_data) {
        }

        C(const size_t N, const T default_value)  noexcept : data(new T[N]), N(N), delete_in_destructor(true) {
            std::fill_n((T *) data, N, default_value);
        }

        // use noexcept on copy+move constructor+assignment
        // https://stackoverflow.com/questions/10787766/when-should-i-really-use-noexcept
        C(const C<T> &that)
                : delete_in_destructor(that.delete_in_destructor),
                  N(that.N),
                  data(that.duplicate_if_delete_in_destructor()) {
            if (that.moved_and_dangerous)
                throw std::invalid_argument("copy from object has been moved and is dangerous");
        }

        C<T>&operator =(const C<T> &that) {
            if (that.moved_and_dangerous)
                throw std::invalid_argument("copy from object has been moved and is dangerous");
            if (this != &that){
                if (!delete_in_destructor){
                    N=that.N;
                    data=that.data;
                } else if (N != that.N) {
                    if (delete_in_destructor)
                        delete data;
                    data = that.duplicate();
                    delete_in_destructor=true;
                    N=that.N;
                } else
                    std::memcpy(data, that.data, sizeof(T)*N);
                moved_and_dangerous=false;
            }
            return *this;
        }

        C(C<T> &&that)
                : delete_in_destructor(that.delete_in_destructor), data(that.data), N(that.N) {
            if (that.moved_and_dangerous)
                throw std::invalid_argument("copy from object has been moved and is dangerous");
            if (debug_key < 0)
                std::cerr << "C<T>( T &&) called more than once for " << debug_key << std::endl;
            else
                that.debug_key = 0 - that.debug_key; // flag as touched by move ctor
            that.moved_and_dangerous=true;
            that.data= nullptr;
        }

        C<T>&operator =(C<T> &&that) {
            if (that.moved_and_dangerous)
                throw std::invalid_argument("copy from object has been moved and is dangerous");
            if (this != &that){
                if (delete_in_destructor)
                    delete data;
                data=that.data;
                N=that.N;
                delete_in_destructor=that.delete_in_destructor;
                moved_and_dangerous=that.moved_and_dangerous;
                that.moved_and_dangerous=true;
                that.data=nullptr;
            }
            return *this;
        }

        T*duplicate() const noexcept{
            T *new_data=new T[N];
            if (data!= nullptr)
                std::memcpy(new_data, data, sizeof(T)*N);
            return new_data;
        }

        C<T> clone() const noexcept{
            T *new_data= duplicate();
            return C<T>(new_data, N, true);
        }

        T *reset(const T default_value) noexcept{
            std::fill_n((T *) data, N, default_value);
            return data;
        }
        T &operator[](const int i) const  noexcept { return data[i]; }

        const size_t size() const noexcept { return N; }

        const T *const operator()() noexcept{ return data; }

        const T *const operator*() noexcept { return data; }

        T *ptr() const noexcept { return data; }

        bool empty()const noexcept{return N==0;}

        bool operator ==(const C<T>&that) const{
            if (N!=that.N)
                return false;
            for (int i=0;i<N;i++)
                if (data[i]!=that.data[i])
                    return false;
            return true;
        }
        operator std::vector<T> () const noexcept{return to_vector();}
        std::vector<T> to_vector() const noexcept {
            return suh::to_vector(data, N);
        }

        ~C() noexcept {
            if (debug_key != 0) {
                if (debug_key < 0) {
                    if (data!=nullptr)
                        std::cerr << "~C<T>() after C<T>(T &&) called with non null data.... debug_key==" << 0 - debug_key << std::endl;
                    debug_key = 0 - debug_key;
                }
                if (debug_keys.count(debug_key))
                    std::cerr << "YEEEeeeooocuh double ~C<T>() call to" << debug_key << std::endl;
                else
                    debug_keys.insert(debug_key);
            }
            if (delete_in_destructor && !moved_and_dangerous)
                delete[]data;
        }

        void increment() noexcept{
            const T *end=data+N;
            for(T *p=(T*)data;p<end;p++)
                (*p)++;
        }

        void decrement() noexcept{
            const T *end=data+N;
            for(T *p=(T*)data;p<end;p++)
                (*p)--;
        }

        void print(std::ostream &out=std::cout) const noexcept{
            if (moved_and_dangerous){
                out<<"moved and dangerous"<<std::endl;
                return;
            }
            suh::print(data, N);
        }

        void resetCnt(const size_t new_cnt){
            N=new_cnt;
        }
        bool moved_and_dangerous=false;
        T *  data;
        size_t N;
        int debug_key = 0;
        private:
        bool delete_in_destructor;

        T *duplicate_if_delete_in_destructor() const noexcept{
            return delete_in_destructor ? duplicate() : data;
        }
    };

    using ptrSize_t = std::shared_ptr<C<size_t>>;
    using ptrInt = std::shared_ptr<C<int>>;

    inline std::shared_ptr<C<size_t>> shared_size_ptr(const size_t N) {
        size_t *out = new size_t[N];
        std::fill_n(out, N, 0ul);
        return std::shared_ptr<C < size_t>>(new C<size_t>(out, N, true));
    }

    template<typename T>
    std::shared_ptr<C<T>> to_c_shared_ptr(const size_t N, T defaultValue) {
        T *out = new T[N];
        std::fill_n(out, N, defaultValue);
        return std::shared_ptr<C < T>>(new C<T>(out, N));
    }

    template<typename T>
    std::shared_ptr<C<T>> to_c_ptr(std::vector<T> vector) {
        const size_t N = vector.size();
        T *const data = new T[N];
        for (int i = 0; i < N; i++) {
            data[i] = vector[i];
        }
        return std::shared_ptr<C < T>>(new C<T>(data, N, true));
    }

    using RawInts = std::shared_ptr<C<int>>;
    using RawDoubles = std::shared_ptr<C<double>>;

    template<typename T>
    void remove(std::vector<T> &vector, const size_t i) noexcept {
        vector.erase(vector.begin() + i);
    }

    template<typename T>
    T sum(const std::vector<T> &vector) noexcept {
        T sum = 0;
        const size_t N = vector.size();
        for (int i = 0; i < N; i++) {
            sum += vector[i];
        }
        return sum;
    }

    template<typename T>
    T sum(const T *const ptr, const size_t N) noexcept {
        T sum = 0;

        for (int i = 0; i < N; i++) {
            sum += ptr[i];
        }
        return sum;
    }

    extern const std::string empty;

    template<typename T>
    std::string to_string(const std::vector<T> &in, const char *delim = ",") noexcept{
        if (in.empty()) return empty;
        std::strstream s;
        s << "[";
        const int N = in.size();
        for (int i = 0; i < N; i++) {
            s << in[i];
            if (i < N - 1)
                s << delim;
        }
        s << "]";
        return s.str();
    }

    std::string to_string(const double num, const int decimals = 5, const bool separateThousands = true) noexcept;

/**
 * Provides services equivalent to MATLAB sub2ind() and ind2sub()
 * for either column-wise (MATLAB) vector traversal or row-wise
 * and for one based (MATLAB) indexing or zero (Java/C++)
 */
    class MatVectIndexer {
    public:
        MatVectIndexer(const size_t rows, const size_t cols) noexcept: rows(rows), cols(cols) {
        }

        MatVectIndexer(const size_t M) noexcept : rows(M), cols(M) {
        }

        size_t base = 1;
        bool columnWise = true;
        const size_t rows, cols;

        size_t toRow(const size_t ind) const noexcept{
            if (columnWise)
                return ((ind - base) % rows) + base;
            else
                return ((ind - base) / cols) + base;
        }

        size_t toCol(const size_t ind) const noexcept{
            if (columnWise)
                return ((ind - base) / rows) + base;
            else
                return ((ind - base) % cols) + base;
        }

        size_t toInd(const size_t row, const size_t col) const noexcept{
            if (columnWise)
                return row + rows * (col - base);
            else
                return col + cols * (row - base);
        }

        class XY { // intended for GRID where index should not exceed INT_MAX
        public:
            int *const x, *const y;
            const MatVectIndexer &mvi;
            const size_t N;

            XY(const MatVectIndexer &mvi, const ints &inds)noexcept
                    : mvi(mvi), N(inds.size()), x(new int[inds.size()]), y(new int[inds.size()]) {
                for (size_t i = 0; i < N; i++) {
                    x[i] = mvi.toRow(inds[i]);
                    y[i] = mvi.toCol(inds[i]);
                    //std::cout<< inds[i] << "..." << to_string(i) <<std::endl;
                }
            }

            std::string to_string(const size_t i) const noexcept {
                std::strstream s;
                const size_t ind = mvi.toInd(x[i], y[i]);
                s << ind << "(" << x[i] << "/" << y[i] << ")";
                return s.str();
            }

            ~XY() noexcept{
                delete[]x;
                delete[]y;
            }
        };
    };

    template<typename T>
    size_t add_all(std::vector<T> &to, const std::vector<T> &from) noexcept{
        to.insert(to.end(), from.begin(), from.end());
        return from.size();
    }

    template<typename T>
    size_t add_all(std::vector<T> &to, const C<T> &from) noexcept{
        const int N=from.size();
        const int *p=from.ptr();
        to.reserve(to.size()+N);
        for (int i=0;i<N;i++) {
            to.push_back(p[i]);
        }
        return N;
    }

    enum class Expectation {
        More, Less, Equal, LessEq, MoreEq
    };

    template<typename T>
    static bool according_to_expectation(
            const T expected,
            const T actual,
            Expectation expectation,
            std::string &s) noexcept{
        bool ok;
        const char *wrong_op, *good_op;
        switch (expectation) {
            case Expectation::More:
                ok = actual > expected;
                wrong_op = "<=";
                good_op = ">";
                break;
            case Expectation::Less:
                ok = actual < expected;
                wrong_op = ">=";
                good_op = "<";
                break;
            case Expectation::MoreEq:
                ok = actual >= expected;
                wrong_op = "<";
                good_op = ">=";
                break;
            case Expectation::LessEq:
                ok = actual <= expected;
                wrong_op = ">";
                good_op = "<=";
                break;
            default:
                ok = expected == actual;
                good_op = "==";
                wrong_op = "not equal to ";
        }
        if (!ok) {
            s += "...expecting";
            s += good_op;
            s += to_string(expected);
            s += " but got ";
            s += to_string(actual);
            s += " which is instead ";
            s += wrong_op;
            s += to_string(expected);
        }
        return ok;
    }

    inline size_t getM(
            const size_t vectorized_grid_size
    ) {
        const double M = sqrt(vectorized_grid_size);
        if (floor(M) != M)
            throw std::invalid_argument("grid_cluster_and_noise_ids needs to be a square matrix");
        return static_cast<size_t>(M);
    }

    inline size_t getM(const C<int> &square_grid){
        return getM(square_grid.N);
    }

    template <typename T> T max(const T* numbers,const size_t N)noexcept{
        T result=numbers[0];
        const T * const p=numbers+N;
        for (const T *const end=numbers+N;numbers<end;numbers++)
            if (*numbers>result){
                result=*numbers;
            }
        return result;
    }

    template <typename T> T max(const C<T> &numbers)noexcept{
        return max(numbers.data, numbers.size());
    }

    template <typename T> T min(const T* numbers,const size_t N)noexcept{
        T result=numbers[0];
        const T * const p=numbers+N;
        for (const T *const end=numbers+N;numbers<end;numbers++)
            if (*numbers<result){
                result=*numbers;
            }
        return result;
    }


    template <typename T> T min(const C<T> &numbers)noexcept{
        return min(numbers.data, numbers.size());
    }


    template<typename T> void decrement(std::vector<T> &v)noexcept{
        const size_t N=v.size();
        for (int i=0;i<N;i++){
            v[i]=v[i]-1;
        }
    }


#define SIZE_1D(N) (sizeof(N)/sizeof(N[0]))

#define SIZE_2D(N) (sizeof(N)/sizeof(N[0][0]))

#define ROWS(N) SIZE_1D(N)

#define COLS(N) (SIZE_2D(N)/ROWS(N))
}
#endif //SUH_H