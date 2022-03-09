//
// Created by Stephen Meehan on 5/19/21.
//

#include "MxArgs.h"

// help dealing with MATLAB data types can be see at
//https://www.mathworks.com/help/matlab/cc-mx-matrix-library.html

namespace suh {
    //thread_local  std::string MxArgs::tls_test("Hello thread");

    std::string  MxArgs::complain(
            const int argNum,
            const char *expected_type,
            const char *arg_name,
            const bool in) {
        const char *b1 = "(", *b2 = ")";
        if ((arg_name == nullptr || !*arg_name)
            && (expected_type == nullptr || !*expected_type)) {
            b1 = "";
            b2 = "";
        }
        std::string s= (in ? "in" : "out");
        s += "put #";
        s += std::to_string(argNum + 1);
        s+=" ";
        s+= b1;
        s+= expected_type;
        s += (arg_name == nullptr || !*arg_name ? "" : " ");
        s += (arg_name != nullptr ? arg_name : "");
        s += b2;
        s += " must ";
        return s;
    }

    bool MxArgs::check_size(
            const char *method_name,
            const Arg &arg,
            bool is_row,
            const long expected,
            const Expectation expectation,
            const bool halt_mex_function) {
        if (expected < 0)
            return true;
        const char *word;
        const size_t *sz;
        if (is_row) {
            word = "rows";
            sz = &arg.rows;
        } else {
            word = "columns";
            sz = &arg.cols;
        }
        std::string bad;
        if (!according_to_expectation((size_t) expected, *sz, expectation, bad)) {
            std::string s=complain(arg.num, arg.type, arg.name);
            s += "have the correct # of ";
            s += word;
            s += " --> ";
            s += bad.c_str();
            handle_bad_arg(method_name, s.c_str(),halt_mex_function);
            return false;
        }
        return true;
    }

    const MxArgs::Arg MxArgs::get_input_arg(
            const int arg_num,
            const char *arg_name,
            const char *expected_type,
            const long expected_rows,
            const long expected_cols,
            const Expectation row_expectation,
            const Expectation col_expectation,
            const bool is_numeric_scalar) const {
        if (arg_num < 0 || arg_num >= nargin) {
            std::string s=complain(arg_num, expected_type, arg_name);
            s += "be an argument # between 0 && ";
            s += std::to_string(nargin - 1);
            handle_bad_arg(method_name, s.c_str(), halt_on_any_bad_input_arg);
            return Arg();
        }
        Arg arg = fill_arg(in[arg_num], arg_num, arg_name,
                           expected_type, expected_rows, expected_cols,
                           row_expectation, col_expectation,
                           method_name, is_numeric_scalar,
                           halt_on_any_bad_input_arg);
        return arg;
    }


    const MxArgs::Arg MxArgs::get_output_arg(
            const int arg_num,
            const char *arg_name,
            const char *expected_type,
            const long expected_rows,
            const long expected_cols,
            const Expectation row_expectation,
            const Expectation col_expectation,
            const bool is_numeric_scalar) const {
        if (arg_num < 0 || arg_num >= nargout) {
            std::string s=complain(arg_num, expected_type, arg_name);
            s += "be an argument # between 0 && ";
            s += std::to_string(nargin - 1);
            handle_bad_arg(method_name, s.c_str(), halt_on_any_bad_output_arg);
            return Arg();
        }
        Arg arg = fill_arg(out[arg_num], arg_num, arg_name,
                           expected_type, expected_rows, expected_cols,
                           row_expectation, col_expectation,
                           method_name, is_numeric_scalar,
                           halt_on_any_bad_input_arg);
        return arg;
    }

    void MxArgs::handle_bad_args(const bool halt_the_mex_function) {
        if (bad_arg_cnt > 0 || bad_output_cnt > 0) {
            std::string s = "Cannot proceed with MEX function \"";
            s += method_name;
            s += "\": ";
            if (bad_arg_cnt > 0)
                 s += std::to_string(bad_arg_cnt);
            s += " bad inputs(s)";
            if (bad_output_cnt > 0)
                s += std::to_string(bad_output_cnt);
            s += " bad output(s)";
            s += " ...sigh";
            if (halt_the_mex_function)
                mexErrMsgTxt(s.c_str());
            else
                mexPrintf("%s\n", s.c_str());
        }
    }

    MxArgs::Arg MxArgs::fill_arg(
            const mxArray *mxa,
            const int arg_num,
            const char *arg_name,
            const char *expected_type,
            const long expected_rows,
            const long expected_cols,
            const Expectation row_expectation,
            const Expectation col_expectation,
            const char *method_name,
            const bool is_numeric_scalar,
            const bool halt_on_any_bad_input_arg)  {
        Arg arg;
        arg.rows = mxGetM(mxa);
        arg.cols = mxGetN(mxa);
        arg.data = mxGetPr(mxa);
        arg.name = arg_name;
        arg.num = arg_num;
        arg.type = mxGetClassName(mxa);
        if (expected_type != nullptr && !mxIsClass(mxa, expected_type)) {
            bool translated = false;
            if (strcmp("bool", expected_type) == 0 && strcmp(arg.type, ARG_BOOL) == 0)
                translated = true;
            else if (strcmp("float", expected_type) == 0 && strcmp(arg.type, ARG_FLOAT) == 0)
                translated = true;
            else if (strcmp("short", expected_type) == 0 && strcmp(arg.type, ARG_UINT16) == 0)
                translated = true;
            else if (strcmp("int", expected_type) == 0 && strcmp(arg.type, ARG_INT) == 0)
                translated = true;
            else if (strcmp("long", expected_type) == 0 && strcmp(arg.type, ARG_INT64) == 0)
                translated = true;
            else if (strcmp("size_t", expected_type) == 0 && strcmp(arg.type, ARG_SIZE_T) == 0)
                translated = true;
            else if (!is_numeric_scalar || is_non_numeric_arg(arg.type)) {
                // no complaint if empty double  and  expecting function
                if (strcmp(expected_type, ARG_FUNCTION)!=0 ||
                        strcmp(arg.type, ARG_DOUBLE)!=0
                        || arg.rows>0
                        || arg.cols>0) {
                    std::string s = complain(arg.num, expected_type, arg_name);
                    s += "NOT be argued as a ";
                    s += arg.type;
                    handle_bad_arg(method_name, s.c_str(), halt_on_any_bad_input_arg);
                }
                arg.cols = 0;
                arg.rows = 0;
                arg.data = nullptr;
                arg.num = -1;
                return arg;
            }
        }
        if (!check_size(method_name, arg, true,
                        expected_rows, row_expectation, halt_on_any_bad_input_arg)
            || !check_size(method_name, arg, false,
                           expected_cols, col_expectation, halt_on_any_bad_input_arg)) {
            arg.data = nullptr;
            arg.cols = 0;
            arg.rows = 0;
            arg.num = -1;
            return arg;
        }
        if (strcmp(ARG_CHAR, arg.type) == 0)
            arg.data = mxArrayToString(mxa);
        return arg;
    }

    void MxArgs::handle_bad_arg(const char *method_name, const char *msg, bool halt_mex_function_immediately) {
        std::string s=method_name;
        s+=" ";
        s+= (msg== nullptr?"":msg);
        s+= " ...sigh";
        if (!halt_mex_function_immediately)
            mexPrintf("%s\n", s.c_str());
        else
            mexErrMsgTxt(s.c_str());
    }



//    mxArray *MxArgs::set(const int num, const int *in, const size_t rows, const size_t cols, bool from_row_wise){}
//    mxArray* MxArgs::set(const int num, cont double *in, const size_t rows, const size_t cols, bool from_row_wise){}
//    mxArray* MxArgs::set(const int num, const size_t *in, const size_t rows, const size_t cols, bool from_row_wise){}

    mxArray *MxArgs::New(const bool *in, const size_t rows, const size_t cols, bool from_row_wise) {
        OutIndexer mvi(rows, cols, from_row_wise);
        mxArray *p = mxCreateLogicalMatrix(rows, cols);
        mxLogical *to = (mxLogical *) mxGetPr(p);
        mxLogical *toto = mxGetLogicals(p);
        for (int c = 0; c < cols; c++) {
            for (int r = 0; r < rows; r++) {
                *to++ = in[mvi.toInd(r, c)];
            }
        }
        return p;
    }

    mxArray *MxArgs::New(const int *in, const size_t rows, const size_t cols, bool from_row_wise) {
        OutIndexer mvi(rows, cols, from_row_wise);
        mxArray *p = mxCreateNumericMatrix(rows, cols, mxINT32_CLASS, mxREAL);
        int *to = (int *) mxGetPr(p);
        for (int c = 0; c < cols; c++) {
            for (int r = 0; r < rows; r++) {
                int idx = mvi.toInd(r, c);
                *to++ = in[idx];
            }
        }
        return p;
    }

    mxArray *MxArgs::New(const double *in, const size_t rows, const size_t cols, bool from_row_wise) {
        OutIndexer mvi(rows, cols, from_row_wise);
        mxArray *p = mxCreateNumericMatrix(rows, cols, mxDOUBLE_CLASS, mxREAL);
        double *to = (double *) mxGetPr(p);
        for (int c = 0; c < cols; c++) {
            for (int r = 0; r < rows; r++) {
                *to++ = in[mvi.toInd(r, c)];
            }
        }
        return p;
    }

    mxArray *MxArgs::New(const float *in, const size_t rows, const size_t cols, bool from_row_wise) {
        OutIndexer mvi(rows, cols, from_row_wise);
        mxArray *p = mxCreateNumericMatrix(rows, cols, mxSINGLE_CLASS, mxREAL);
        float *to = (float *) mxGetPr(p);
        for (int c = 0; c < cols; c++) {
            for (int r = 0; r < rows; r++) {
                *to++ = in[mvi.toInd(r, c)];
            }
        }
        return p;
    }
    mxArray *MxArgs::New(const size_t *in, const size_t rows, const size_t cols, bool from_row_wise) {
        OutIndexer mvi(rows, cols, from_row_wise);
        mxArray *p = mxCreateNumericMatrix(rows, cols, mxUINT64_CLASS, mxREAL);
        size_t *to = (size_t *) mxGetPr(p);
        for (int c = 0; c < cols; c++) {
            for (int r = 0; r < rows; r++) {
                *to++ = in[mvi.toInd(r, c)];
            }
        }
        return p;
    }

    void MxArgs::gather_named_args(const int starting_at_arg_num) {
        if (nargin - 1 <= starting_at_arg_num) {
            if (starting_at_arg_num > nargin) {
                std::string s = "# of inputs == ";
                s += nargin;
                s += " so named arguments cannot start at ";
                s += starting_at_arg_num;
                handle_bad_arg(method_name, s.c_str(), halt_on_any_bad_input_arg);
                bad_arg_cnt++;
            }
        } else
            for (int i = starting_at_arg_num; i < nargin - 1; i += 2) {
                std::string arg_name = get_string(i);
                if (!arg_name.empty()) {
                    if (has_named_arg(arg_name)) {
                        std::string s= "input #";
                        s += std::to_string(i);
                        s += " \"";
                        s += arg_name;
                        s += "\" previously used for argument #";
                        s += named_args[arg_name];
                        handle_bad_arg(method_name, s.c_str(), halt_on_any_bad_input_arg);
                        bad_arg_cnt++;
                    } else
                        named_args[arg_name] = i + 1;
                } else {
                    const Arg arg = get_input_arg(i);
                    std::string s = "input #";
                    s += std::to_string(i);
                    s += " is not a string it is a ";
                    s += arg.type;
                    s += " with rows=";
                    s += std::to_string(arg.rows);
                    s += ", cols=";
                    s += std::to_string(arg.cols);
                    bad_arg_cnt++;
                    handle_bad_arg(method_name, s.c_str(), halt_on_any_bad_input_arg);
                    break;
                }
            }
    }

    bool MxArgs::set_arg(const int arg_num, mxArray *out) {
        if (arg_num >= nargout) {
            std::string s=complain(arg_num, "", "", false);
            s += "be argument # <= ";
            s += std::to_string(nargout);
            handle_bad_arg(method_name, s.c_str(), halt_on_any_bad_output_arg);
            bad_output_cnt++;
            return false;
        }
        this->out[arg_num] = out;
        return true;
    }

     bool MxArgs::is_non_numeric_arg(const char *type){
        if (strcmp(type, ARG_CHAR)==0)
            return true;
        if (strcmp(type, ARG_CELL)==0)
            return true;
        if (strcmp(type, ARG_FUNCTION)==0)
            return true;
        if (strcmp(type, ARG_STRUCT)==0)
            return true;
        return false;
    }

    FncProgressTxt MxArgs::get_progress_callback(const char *arg_name, const bool warn_if_missing){
        if (!has_named_arg(arg_name)) {
            if (warn_if_missing) {
                std::string s = "\"";
                s += arg_name;
                s += "\" is not a named argument ";
                handle_bad_arg(method_name, s.c_str(), false);
            }
            return nullptr;
        }
        return get_progress_callback(named_args[arg_name]);
    }

    FncProgressTxt  MxArgs::get_progress_callback(const int arg_num, const char *arg_name){
        Arg arg= get_input_arg(arg_num, arg_name, MxArgs::ARG_FUNCTION);
        if (!arg) {
            return nullptr;
        }
        progress_args[0]=(mxArray *)in[arg_num];
        progress_args[1]=mxCreateNumericMatrix(1, 1, mxINT32_CLASS, mxREAL);
        progress_args[2]=mxCreateNumericMatrix(1, 1, mxINT32_CLASS, mxREAL);

        return [&](const char *txt, const int iter, const int n_iter){
            return report_progress(txt, iter, n_iter);
        };
    }

    bool MxArgs::report_progress(const char *txt, const int iteration, const int nIterations) {
        bool okToContinue=true; // okToContinue becomes false ONLY at descretion of user's callback in function_handle
        int *progress_ptr = (int *) mxGetData(progress_args[1]);
        *progress_ptr=iteration;
        progress_ptr = (int *) mxGetData(progress_args[2]);
        *progress_ptr=nIterations;
        progress_args[3] = mxCreateString(txt);
        mxArray *plhs[1];
        plhs[0]= nullptr;
        const int nlhs = SIZE_1D(plhs);
        const int nrhs = SIZE_1D(progress_args);

       if (mxFUNCTION_CLASS != mxGetClassID(progress_args[0])) {
            std::string s= "mxArray given feval is not \"function_handle\", it is \"";
           s+= mxGetClassName(progress_args[0]);
           s+= "\"";
           mexPrintf("%s\n", s.c_str());
        } else {
            mxArray *err = nullptr;
            err = mexCallMATLABWithTrap(nlhs, plhs, nrhs, progress_args, "feval");
            if (err == nullptr) { // function handle had no uncaught exceptions ... process boolean return value
                const int *continuing = (int *) mxGetPr(plhs[0]);
                okToContinue= continuing[0] == 1;
            } else {// function handle had an uncaught exception
                mxArray *msg;
                mexCallMATLAB(1, &msg, 1, &err, "getReport");
                char buf[3000];
                mxGetString(msg, buf, sizeof(buf)-2);
                std::string s="Continuing despite uncaught exception in feval call:  ";
                s+=buf;
                mexPrintf("%s\n", s.c_str());
            }
        }
        mxDestroyArray(progress_args[3]);
        return okToContinue; // do continue if
    }

    std::string MxArgs::get_string(const int arg_num, const char *arg_name, const strs*allowed){
         char *p= (char *)get_c_str(arg_num,arg_name,allowed);
        std::string result;
        if (p) {
            result = p;
            mxFree(p);
        }
        return result;
    }

    const char *MxArgs::get_c_str(const int arg_num, const char *arg_name, const strs*allowed){
        Arg arg= get_input_arg(arg_num, arg_name, MxArgs::ARG_CHAR);
        if (!arg)
            return nullptr;
        const char *str = (const char *) arg.data;
        if (allowed) {
            const suh::strs &a = *allowed;
            const int N = a.size();
            bool ok = false;
            for (int i = 0; i < N && !ok; i++)
                ok=a[i] == str;
            if (!ok) {
                std::string s = complain(arg_num, MxArgs::ARG_CHAR, arg_name);
                s += " not be \"";
                s += "\" ... but instead 1 of the following:  ";
                s += to_string(a);
                handle_bad_arg(method_name, s.c_str(), halt_on_any_bad_input_arg);
                return nullptr;
            }
        }
        return str;
    }

    std::string MxArgs::get_string(
            const char *arg_name,
            const char* default_value,
            const strs*allowed){
        char *p= (char *)get_c_str(arg_name, default_value, allowed);
        std::string result;
        if (p) {
            result = p;
            //mxFree(p);
        } else
            result=default_value;
        return result;
    }

    const char *MxArgs::get_c_str(const char *arg_name, const char* default_value, const strs*allowed){
        if (!has_named_arg(arg_name)) {
            if (default_value == nullptr) {
                std::string s= "\""; 
                s+= arg_name;
                s += "\" is not a named argument ";
                handle_bad_arg(method_name, s.c_str(), halt_on_any_bad_input_arg);
            }
            return default_value;
        }
        Arg arg= get_input_arg(named_args[arg_name], arg_name, MxArgs::ARG_CHAR);
        if (!arg)
            return default_value;
        const char *str = (const char *) arg.data;
        if (allowed) {
            const suh::strs &a = *allowed;
            const int N = a.size();
            bool ok = false;
            for (int i = 0; i < N && !ok; i++)
                ok=a[i] == str;
            if (!ok) {
                std::string s=complain( 0, MxArgs::ARG_CHAR, arg_name);
                s += " not be \"";
                s += str;
                s += "\" ... but instead 1 of the following:  ";
                s += to_string(a);
                if (default_value != nullptr) {
                    s += "\nUsing default \"";
                    s += default_value;
                    s += "\" ";
                }
                handle_bad_arg(method_name, s.c_str(), halt_on_any_bad_input_arg);
                return default_value;
            }
        }
        return str;
    }
    void MxArgs::invokeMexMan(FncMexC fncMex, const int start_of_in_args, const int start_of_out_args){
        if (start_of_in_args>=nargin) {
            std::string s = "Can't start in args at ";
            s += std::to_string(nargin);
            s += "... there are only ";
            s += std::to_string(nargin);
            s += " argument(s)";
            mexPrintf("%s\n", s.c_str());
        } else if (start_of_out_args>=nargout) {
            std::string s = "Can't start out args at ";
            s += std::to_string(nargin);
            s += "... there are only ";
            s += std::to_string(nargin);
            s += " argument(s)";
            mexPrintf("%s\n", s.c_str());
        } else
            (fncMex)(nargout, &out[start_of_out_args], nargin, &in[start_of_in_args]);
    }
}

