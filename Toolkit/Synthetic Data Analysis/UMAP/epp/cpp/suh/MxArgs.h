//
// Created by Stephen Meehan on 5/19/21.
//

#ifndef EPPCPP_FILES_MXARGS_H
#define EPPCPP_FILES_MXARGS_H


#include "MxData.h"
#include "mex.h"
#include <map>

namespace suh {

    class MxArgs;

    using FncMexC = std::function<void(int nlhs, mxArray **plhs, int nrhs, const mxArray**prhs)>;
    using FncMexCpp = std::function<void(MxArgs &)>;

    class MxArgs {
        mxArray *progress_args[4];
        mxArray **out;
        const mxArray **in;
        int bad_arg_cnt=0, bad_output_cnt=0;

    public:
        bool halt_on_any_bad_input_arg=false;
        bool halt_on_any_bad_output_arg=true;
        //static thread_local std::string tls_test;
        const int nargout;
        const int nargin;
        const char * const method_name;

        class Arg {
        public:
            void *data = nullptr;
            size_t rows = 0, cols = 0;
            const char *type = "";
            int num = -1;
            const char *name = "";

            operator bool() {
                return num > -1;
            }

            template<typename T>
            MxData<T> get() const {
                return MxData<T>((T *) data, rows, cols);
            }

            Arg()= default;

        };

        MxArgs(const char *name,
               mxArray *plhs[], const int nlhs,
               const mxArray *prhs[], const int nrhs)
                : method_name(name),
                  out(plhs), nargout(nlhs),
                  in(prhs), nargin(nrhs) {
            progress_args[0]=nullptr;
            progress_args[1]=nullptr;
            progress_args[2]=nullptr;

        }

        template<typename T> static
        MxData<T> get_data(const Arg &arg)  {
            return MxData<T>((T *) arg.data, arg.rows, arg.cols);
        }

        bool is_scalar(const int argNum) const{
            const Arg arg= get_input_arg(argNum);
            return arg.rows == 1 && arg.cols == 1;
        }

        bool is_empty(const int argNum) const{
            const Arg arg= get_input_arg(argNum);
            return arg.rows == 0 && arg.cols == 0;
        }

        FncProgressTxt get_progress_callback(
                const char *arg_name="progress_callback",
                const bool warn_if_missing=false);
        FncProgressTxt get_progress_callback(
                const int arg_num,
                const char *arg_name=nullptr);
        bool report_progress(
                const char *txt,
                const int iteration, const int nIterations);

    private:
        bool set_arg(const int arg_num, mxArray  *out);

        const Arg get_input_arg(
                const int arg_num,
                const char *arg_name = "",
                const char *expected_type = nullptr,
                const long expected_rows = -1,
                const long expected_cols = -1,
                const Expectation row_expectation = Expectation::Equal,
                const Expectation col_expectation = Expectation::Equal,
                const bool is_numeric_scalar= false) const;

        const Arg get_output_arg(
                const int arg_num,
                const char *arg_name = "",
                const char *expected_type = nullptr,
                const long expected_rows = -1,
                const long expected_cols = -1,
                const Expectation row_expectation = Expectation::Equal,
                const Expectation col_expectation = Expectation::Equal,
                const bool is_numeric_scalar= false) const;

    public:
        const Arg get_any_arg(
                const int arg_num,
                const char *arg_name = "",
                const long expected_rows = -1,
                const long expected_cols = -1,
                const Expectation row_expectation = Expectation::Equal,
                const Expectation col_expectation = Expectation::Equal) const{
            return get_input_arg(arg_num, arg_name, nullptr, expected_rows, expected_cols, row_expectation,
                                 col_expectation);
        }

         static Arg fill_arg(
                const mxArray *mxa,
                const int arg_num=0,
                const char *arg_name = "",
                const char *expected_type = nullptr,
                const long expected_rows = -1,
                const long expected_cols = -1,
                const Expectation row_expectation = Expectation::Equal,
                const Expectation col_expectation = Expectation::Equal,
                const char *method_name = "cols/mxa",
                const bool is_numeric_scalar=false,
                bool halt_on_any_bad_input_arg=false);

        void set(const int arg_num, const bool *in, const size_t rows=1, const size_t cols=1, bool from_row_wise = true){
            set_arg(arg_num, New(in,rows,cols,from_row_wise));
        }

        void set(const int arg_num, const double *in, const size_t rows=1, const size_t cols=1, bool from_row_wise = true){
            set_arg(arg_num, New(in,rows,cols,from_row_wise));
        }

        void set(const int arg_num, const size_t *in, const size_t rows=1, const size_t cols=1, bool from_row_wise = true){
            set_arg(arg_num, New(in,rows,cols,from_row_wise));
        }

        void set(const int arg_num, const int *in, const size_t rows=1, const size_t cols=1, bool from_row_wise = true){
            set_arg(arg_num, New(in,rows,cols,from_row_wise));
        }

        double *setDouble(const int arg_num, const size_t rows, const size_t cols){
            mxArray *p = mxCreateNumericMatrix(rows, cols, mxDOUBLE_CLASS, mxREAL);
            set_arg(arg_num,p);
            return (double *) mxGetPr(p);
        }

        int *setInt(const int arg_num, const size_t rows, const size_t cols){
            mxArray *p = mxCreateNumericMatrix(rows, cols, mxINT32_CLASS, mxREAL);
            set_arg(arg_num,p);
            return  (int *) mxGetPr(p);
        }

        template <typename  T>void set(const int arg_num, const C<T> &c, bool from_row_wise = true){
            set(arg_num, c.data, c.N, 1, from_row_wise);
        }
        template <typename  T>void set(const int arg_num, const std::shared_ptr<suh::Matrix<T>>m, bool from_row_wise = true){
            if (!m){
                set(arg_num, (T*)nullptr, 0, 0, true);
                return;
            } else if (m->isDeleteEachRow()){
                handle_bad_arg(method_name,"Matrix must not delete each row", halt_on_any_bad_input_arg);
                set(arg_num, (T*)nullptr, 0, 0, true);
                return;
            }
            set(arg_num, m->pool(), m->rows_, m->columns_, from_row_wise);
        }
        template <typename  T>void set(const int arg_num, const std::vector<T> &v, bool from_row_wise = true){
            C<T>c(v);
            set(arg_num, c.data, c.N, 1, from_row_wise);
        }

        template <typename  T>void set(const int arg_num, const T scalar){
            set(arg_num, &scalar);
        }
        static mxArray *New(const bool *in, const size_t rows=1, const size_t cols=1, bool from_row_wise = true);

        static mxArray *New(const double *in, const size_t rows=1, const size_t cols=1, bool from_row_wise = true);

        static mxArray *New(const float *in, const size_t rows=1, const size_t cols=1, bool from_row_wise = true);

        static mxArray *New(const size_t *in, const size_t rows=1, const size_t cols=1, bool from_row_wise = true);

        static mxArray *New(const int *in, const size_t rows=1, const size_t cols=1, bool from_row_wise = true);

        template <typename  T> static mxArray *New( const C<T> &c, bool from_row_wise = true){
            return New( c.data, 1, c.N, from_row_wise);
        }
        template <typename  T>static mxArray* New( const Matrix<T> &m, bool from_row_wise = true){
            if (m.isDeleteEachRow()){
                handle_bad_arg("""","Matrix must not be delete each row", true);
                return New(static_cast<T *>(nullptr), 0, 0, from_row_wise);
            }
            return New( m.pool(), m.rows_, m.columns_, from_row_wise);
        }
        template <typename  T>static mxArray* New ( const std::vector<T> &v, bool from_row_wise = true){
            C<T>c(v);
            return New( c.data, 1, c.N, from_row_wise);
        }

    private:
        static std::string complain(
                const int argNum,
                const char *expected_type,
                const char *arg_name,
                const bool in=true);

        // allowed type names available at
        // https://www.mathworks.com/help/matlab/apiref/mxisclass.html

        static bool check_size(
                const char *method_name,
                const Arg &arg,
                bool is_row,
                const long expected,
                const Expectation expectation,
                bool halt_mex_function_if_bad);

        static void handle_bad_arg(
                const char *method_name,
                const char *msg,
                bool halt_mex_function_immediately);

        std::map<std::string, int> named_args;

    public:
        // too big of an inline ? https://stackoverflow.com/questions/9370493/inline-function-members-inside-a-class
        void invokeMexMan(FncMexC fncMex, const int start_of_in_args=0, const int start_of_out_args=0);

        void handle_bad_args(const bool halt_the_mex_function);

        void gather_named_args(const int starting_at_arg_num);
        bool has_named_arg(const std::string arg_name) const {
            return named_args.count(arg_name) > 0;
        }

//      https://www.mathworks.com/help/matlab/apiref/mxisclass.html
        constexpr static const char * ARG_DOUBLE = "double";
        constexpr static const char *  ARG_FLOAT = "single";
        constexpr static const char *  ARG_BOOL = "logical";
        constexpr static const char *  ARG_STRUCT = "struct";
        constexpr static const char *  ARG_CELL = "cell";
        constexpr static const char *  ARG_CHAR = "char";

        //https://www.mathworks.com/matlabcentral/answers/318878-how-can-i-store-function_handle-objects-in-mex-code
        //https://stackoverflow.com/questions/38268669/passing-function-handle-as-input-for-mex-for-matlab
        constexpr static const char *  ARG_FUNCTION = "function_handle";

        constexpr static const char *  ARG_INT8 = "int8";
        constexpr static const char *  ARG_INT16 = "int16";
        constexpr static const char *  ARG_INT32 = "int32";
        constexpr static const char *  ARG_INT64 = "int64";
        constexpr static const char *  ARG_UINT8 = "uint8";
        constexpr static const char *  ARG_UINT16 = "uint16";
        constexpr static const char *  ARG_UINT32 = "uint32";
        constexpr static const char *  ARG_UINT64 = "uint64";
        constexpr static const char *  ARG_SHORT = ARG_INT16;
        constexpr static const char *  ARG_INT = ARG_INT32;
        constexpr static const char *  ARG_SIZE_T = ARG_UINT64;

        static bool is_non_numeric_arg(const char *type);

        template <typename T>const MxData<T> get_input_data(
                const int arg_num,
                const long expected_rows = -1,
                const long expected_cols = -1,
                const char *expected_type = "double",
                const Expectation row_expectation = Expectation::Equal,
                const Expectation col_expectation = Expectation::Equal,
                const char *arg_name = ""){
            Arg arg= get_input_arg(arg_num, arg_name, expected_type,
                                   expected_rows, expected_cols,
                                   row_expectation, col_expectation);
            if (!arg)
                bad_arg_cnt++;
            return this->template get_data<T>(arg);
        }

        template <typename T>const MxData<T> get_output_data(
                const int arg_num,
                const long expected_rows = -1,
                const long expected_cols = -1,
                const char *expected_type = "double",
                const Expectation row_expectation = Expectation::Equal,
                const Expectation col_expectation = Expectation::Equal,
                const char *arg_name = ""){
            Arg arg= get_output_arg(arg_num, arg_name, expected_type,
                                   expected_rows, expected_cols,
                                   row_expectation, col_expectation);
            if (!arg)
                bad_arg_cnt++;
            return this->template get_data<T>(arg);
        }

        std::string get_string(
                const int arg_num,
                const char *arg_name="",
                const strs*allowed=nullptr);

        std::string get_string(
                const char *arg_name,
                const char* default_value= nullptr,
                const strs*allowed= nullptr);

        const char *get_c_str(
                const int arg_num,
                const char *arg_name="",
                const strs*allowed=nullptr);

        const char *get_c_str(
                const char *arg_name,
                const char* default_value= nullptr,
                const strs*allowed= nullptr);

        bool complain_if_missing_named_arg=true;
        template<typename T>
        const MxData<T> get_named_arg(
                const std::string &arg_name,
                const long expected_rows = -1,
                const long expected_cols = -1,
                const char *expected_type = "double",
                const Expectation row_expectation = Expectation::Equal,
                const Expectation col_expectation = Expectation::Equal) {

            if (!has_named_arg(arg_name)) {
                if (complain_if_missing_named_arg){
                    std::string s= "\"" + arg_name + "\" is not a named argument ";
                    handle_bad_arg(method_name, s.c_str(), halt_on_any_bad_input_arg);
                }
                return MxData<T>();
            }
            Arg arg= get_input_arg(
                    named_args[arg_name],
                    arg_name.c_str(), expected_type,
                    expected_rows, expected_cols,
                    row_expectation, col_expectation);
            if (!arg)
                bad_arg_cnt++;
            return this->template get_data<T>(arg);
        }

        template<typename T>
        const T get_named_arg_scalar(
                const std::string arg_name,
                const char *expected_type,
                const T default_value) {
            if (!has_named_arg(arg_name)) {
                return default_value;
            }
            Arg arg = get_input_arg(
                    named_args[arg_name],
                    arg_name.c_str(), expected_type,
                    1, 1,
                    Expectation::Equal, Expectation::Equal, true);
            if (!arg) {
                bad_arg_cnt++;
                return default_value;
            }
            if (strcmp(arg.type, expected_type)!=0){
                if (strcmp(arg.type, ARG_DOUBLE)==0){
                   return static_cast<T>(*((double *)arg.data));
                }
            }
            return *((T *)arg.data);
        }

        template<typename T>
        const T get_arg_scalar(
                const int arg_num,
                const char *expected_type,
                const T default_value,
                const char *arg_name="") {
            Arg arg = get_input_arg(
                    arg_num,
                    arg_name, expected_type,
                    1, 1,
                    Expectation::Equal, Expectation::Equal);
            if (!arg) {
                bad_arg_cnt++;
                return default_value;
            }
            return *((T *)arg.data);
        }

        struct Test {
            static void case1();
            static void case2(
                    const C<int> &grid_cluster_ids_and_0,
                    const C<int> &event_grid_idxs);
            static void case3();
            static void case4();
            static ints case5(
                    const C<int> &grid_cluster_ids_and_0,
                    const C<int> &event_grid_idxs,
                    const double *grid_density,
                    const double verbose_flags,
                    const bool exclude_border_edge=true, // default behavior ... otherwise include cluster_ids that touch both grid border and other cluster
                    const  char *balance="nearby_noise",
                    const double *normal_distribution=nullptr,
                    const bool parallelize=true
            );
            static void case6(const C<int> &event_grid_idxs);
        };

        friend class Test;

#define MX_ARGS(method_name) MxArgs mx_args(method_name, plhs, nlhs, prhs, nrhs)

#define MX_ARG(T, arg_name, arg_num) \
    MxData<T> arg_name = mx_args.get_input_data<T>(arg_num,-1,-1,#T,Expectation::Equal,Expectation::Equal, #arg_name)

#define MX_ARG_MATRIX(T, arg_name, arg_num, rows, cols) \
    MxData<T> arg_name = mx_args.get_input_data<T>(arg_num, rows, cols, #T,Expectation::Equal, Expectation::Equal, #arg_name)

#define MX_ARG_MATRIX2(T, arg_name, arg_num) \
    MxData<T> arg_name = mx_args.get_input_data<T>(arg_num, 2, 2, #T,Expectation::MoreEq, Expectation::MoreEq, #arg_name)

#define MX_ARG_ANY(T, arg_name, arg_num, rows, cols, row_expectation, col_expectation) \
    MxData<T> arg_name = mx_args.get_input_data<T>(arg_num, -1, -1, #T, row_expectation, col_expectation, #arg_name)

#define MX_ARG_SQUARE(T, arg_name, arg_num, size) \
    MxData<T> arg_name = mx_args.get_input_data<T>(arg_num, size, size, #T, Expectation::Equal, Expectation::Equal, #arg_name)

#define MX_ARG_SCALAR(T, arg_name, arg_num, default_value) \
    T arg_name = mx_args.get_arg_scalar<T>(arg_num, #T, default_value, #arg_name)

#define MX_ARG_ANY_VECTOR(T, arg_name, arg_num) \
    MxData<T> arg_name=mx_args.get_input_data<T>(arg_num, 1, 1, #T, Expectation::Equal, Expectation::More, #arg_name)

#define MX_ARG_VECTOR(T, arg_name, arg_num, cols) \
    MxData<T> arg_name=mx_args.get_input_data<T>(arg_num, 1, cols, #T, Expectation::Equal, Expectation::Equal, #arg_name)

#define MX_ARG_PRINT(T, arg_name, arg_num, rows, cols)\
    {MxData<T> arg_name = mx_args.get_input_data<T>(arg_num, rows, cols, #T, Expectation::Equal, Expectation::Equal, #arg_name);\
    print(arg_name.get_2d_vector(), false);}

#define MX_ARG_C_STR(arg_name, arg_num) const char *arg_name=mx_args.get_c_str(arg_num)

#define MX_GET(object, T, arg_num, rows, cols) object.get_input_data<T>(arg_num, rows, cols, #T)

#define MX_GET_LESS(object, T, arg_num, rows, cols) object.get_input_data<T>(arg_num, rows, cols, #T, Expectation::Less)
    };

#define MX_NAMED_ARG_SCALAR(T, arg_name, DEFAULT_VALUE) \
    T arg_name=mx_args.get_named_arg_scalar<T>(#arg_name,  #T, DEFAULT_VALUE)

#define MX_NAMED_ARG_VECTOR(T, arg_name,  cols) \
    MxData<T> arg_name=mx_args.get_named_arg<T>(#arg_name, 1, cols, #T)

#define MX_NAMED_ARG_SQUARE(T, arg_name,  size) \
    MxData<T> arg_name=mx_args.get_named_arg<T>(#arg_name, size, size, #T)

#define MX_NAMED_ARG(arg_name, T) \
    MxData<T> arg_name = mx_args.get_named_arg<T>(#arg_name,-1,-1,#T)

#define MX_NAMED_ARG_MATRIX(T, arg_name,  rows, cols) \
    MxData<T> arg_name = mx_args.get_named_arg<T>(#arg_name, rows, cols, #T)

#define MX_NAMED_ARG_MATRIX2(T, arg_name) \
    MxData<T> arg_name = mx_args.get_named_arg<T>(#arg_name, 2, 2, #T,Expectation::MoreEq, Expectation::MoreEq)


#define MX_NAMED_ARG_C_STR(arg_name, default_value, allowed) \
    const char *arg_name=mx_args.get_c_str(#arg_name, default_value, allowed)

#define MX_NAMED_ARG_STRING(arg_name, default_value, allowed) \
    std::string arg_name=mx_args.get_string(#arg_name, default_value, allowed)

    class OutIndexer : public MatVectIndexer {
    public:
        OutIndexer(const size_t rows, const size_t cols, bool rowWise) : MatVectIndexer(rows, cols) {
            base = 0;
            columnWise = !rowWise;
        }
    };


}
#endif //EPPCPP_FILES_MXARGS_H
