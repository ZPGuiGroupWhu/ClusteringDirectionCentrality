//
// Created by Stephen Meehan on 6/29/21.
//

#include <iostream>
#include <fstream>
#include <sstream>
#include "Modal2WaySplit.h"
#include "MxArgs.h"
using namespace suh;

extern void mexFunction(int nlhs, mxArray *plhs[],
                        int nrhs, const mxArray *prhs[]);

namespace EPP {
    void testMexPolygon() {
        float xyData[9][2] = {
                {.11,   .21},
                {.1,    .2},
                {.15,   .42},
                {.41,   .32},
                {.21,   .12},
                {.31,   .92},
                {.81,   .72},
                {.8551, .742},
                {.331,  .82}
        };
        double xyPolygon[3][2] = {
                {0, 0},
                {1, 0},
                {1, 1}
        };
        const mxArray *prhs[] = {
                MxArgs::New(&xyData[0][0], 9, 2),
                mxCreateString("polygon"),
                MxArgs::New(&xyPolygon[0][0], 3, 2),
                mxCreateString("service"),
                mxCreateString("inpolygon")
        };
        const size_t nrhs = SIZE_1D(prhs);
        size_t nlhs = 1;
        mxArray **plhs = new mxArray *[nlhs];

        MX_ARGS("MxArgs::Test::inpolygon");
        mx_args.invokeMexMan(mexFunction);
        MxData<bool> inside = mx_args.get_output_data<bool>(0, 9, 1, "bool");
        C<bool> answers=inside.get_C();
        for (int i=0;i<9;i++){
            std::cout << xyData[i][0] << "/" << xyData[i][1] << "==" << answers[i] <<std::endl;
        }
    }

    void testMex(const float *const data, const long events,
                 const int measurements, const int threads,
                 const int polygons, const double KLD_normal_1D,
                 const double KLD_normal_2D, const char *service) {
        int verbose_flags = 1+2+4;
        bool simplify=polygons>0;
        bool balanced=true;
        double W=.01;
        double sigma=3.0;
        std::chrono::time_point<std::chrono::steady_clock> begin, end;
        const mxArray *prhs[] = {
                MxArgs::New(data, events, measurements, false),
                mxCreateString("service"),
                mxCreateString(service),
                mxCreateString("verbose_flags"),
                MxArgs::New(&verbose_flags),
                mxCreateString("threads"),
                MxArgs::New(&threads),
                mxCreateString("W"),
                MxArgs::New(&W),
                mxCreateString("sigma"),
                MxArgs::New(&sigma),

                mxCreateString("simplify_polygon"),
                MxArgs::New(&simplify),
                mxCreateString("KLD_exponential_1D"),
                MxArgs::New(&KLD_normal_1D),
                mxCreateString("balanced"),
                MxArgs::New(&balanced),
                mxCreateString("KLD_normal_2D"),
                MxArgs::New(&KLD_normal_2D)
        };
        const bool justKld=strcmpi(service, "kld")==0;
        const size_t nrhs = SIZE_1D(prhs);
         size_t  nlhs=0;
        if (justKld)
            nlhs = 1;
        else
            if (polygons > 1) {
                nlhs = polygons * 4;
            } else {
                nlhs=4;
            }
        mxArray **plhs= new mxArray *[nlhs];

        MX_ARGS("MxArgs::Test::case5");
        begin=std::chrono::steady_clock::now();
        mx_args.invokeMexMan(mexFunction);
        end=std::chrono::steady_clock::now();
        std::chrono::milliseconds  ms = std::chrono::duration_cast<std::chrono::milliseconds>(end - begin);
        if (justKld){
            MxData<double> pairs = mx_args.get_output_data<double>(0, -1, 2);
            std::cout << "TestMex received " << pairs.rows << "x" << pairs.cols << " pairs" << std::endl;
            for (int row = 0; row < pairs.rows; row++) {
                std::cout << "#" << (row + 1) << ": "
                          << pairs.get(row, 0)
                          << ", "
                          << pairs.get(row, 1);
                if (((row + 1) %  6) == 0 || row+1==pairs.rows)
                    std::cout << std::endl;
                else
                    std::cout << "  ";
            }
        } else {
            MxData<int> X = mx_args.get_output_data<int>(0, 1, 1, "int");
            MxData<int> Y = mx_args.get_output_data<int>(1, 1, 1, "int");
            MxData<double> sptx = mx_args.get_output_data<double>(2, -1, 2);
            //std::cout << " The sptx is "
            //          << sptx.to_string() << std::endl;
            std::cout << "TestMex received polygon with " << sptx.rows << " coordinates and best X vs Y:  "
                      << X.to_string() << " vs " << Y.to_string() << std::endl;
            std::cout << std::endl;
        }
        delete []plhs;
        std::cout << "COMPLETED ...." << ms.count()
                << "[ms] of processing time  "
                << std::endl;
    }
}