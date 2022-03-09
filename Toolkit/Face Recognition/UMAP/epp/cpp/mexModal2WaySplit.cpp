#include <iostream>
#include <fstream>
#include <sstream>
#include "Modal2WaySplit.h"
#include "MxArgs.h"
#include "Polygon.h"

using namespace suh;

void mexFunction(int nlhs, mxArray *plhs[],
                 int nrhs, const mxArray *prhs[]) {
    MX_ARGS("mexModal2WaySplit");
    const int nargout = mx_args.nargout;
    if (nargout <1){
        mexErrMsgTxt("You must provide output arguments to get the answers...");
        return;
    }
    MX_ARG_MATRIX2(float, data, 0);
    mx_args.gather_named_args(1);
    MX_NAMED_ARG_SCALAR(int, verbose_flags, 0);
    MX_NAMED_ARG_SCALAR(int, threads, -1);
    MX_NAMED_ARG_SCALAR(bool, simplify_polygon, false);
    MX_NAMED_ARG_SCALAR(bool, balanced, true);
    MX_NAMED_ARG_SCALAR(double, W, -1);
    MX_NAMED_ARG_SCALAR(double, sigma, -1);
    MX_NAMED_ARG_SCALAR(double, KLD_normal_1D, -1);
    MX_NAMED_ARG_SCALAR(double, KLD_normal_2D, -1);
    MX_NAMED_ARG_SCALAR(double, KLD_exponential_1D, -1);
    MX_NAMED_ARG_SCALAR(int, max_clusters, -1);
    strs allowed_services({"split", "inpolygon", "kld"});
    std::string service = mx_args.get_string(
            "service", "split", &allowed_services);
    mx_args.handle_bad_args(true); // halt if not a float
    if (strcmpi(service, "inpolygon")==0) {
        MX_NAMED_ARG_MATRIX2(double, polygon);
        if (polygon.data == nullptr) {
            bool nothing=false;
            mx_args.set(0, &nothing, 0, 1);
            mexErrMsgTxt("You need to provide a polygon in an argument named polygon");
        } else{
            int N = data.rows;
            Polygon polygon_(polygon.get_column_ptr(0) , polygon.get_column_ptr(1), polygon.rows);
            bool *inside = new bool[N];
            polygon_.inPoly(data.get_column_ptr(0), data.get_column_ptr(1), data.rows, inside);
            mx_args.set(0, inside, N, 1);
            delete []inside;
        }
        return;
    }
    int nPolygons = nargout / 4;
    bool keepHistory = nPolygons > 1;
    const bool justKld=strcmpi(service, "kld")==0;
    if (justKld) {
        if (nargout != 1) {
            mexErrMsgTxt("1 putput argument for KLD service: paris of KLD qualified input columns ");
            return;
        }
    } else { // split service
        if (nargout != 4) {
            if ((nargout % 4) != 0) {
                mexErrMsgTxt("Output args for top polygons must be in groups of 4 "
                             "[X, Y, polygonPart1 polygonPart2]");
                return;
            }
        }
        if (nargout < 3) {// halt mex if not getting output
            mexErrMsgTxt("You need at least 3 output args [X, Y, polygon]");
            return;
        }
    }
    EPP::Modal2WaySplit split(
            data.data, data.rows, data.cols, nPolygons, threads, verbose_flags,
            balanced, W, sigma, KLD_normal_1D, KLD_normal_2D, KLD_exponential_1D,
            max_clusters, justKld);
    bool printSptx = (verbose_flags & 16) == 16;
    if (strcmpi(service, "kld")==0) {
        const std::vector<EPP::Candidate> &candidates=split.candidates;
        const int N=candidates.size();
        double *out = mx_args.setDouble(0, N, 2);
        for (int i=0;i<N;i++){
            out[i] = static_cast<double>(candidates[i].X +1);
            out[i + N] = static_cast<double>(candidates[i].Y + 1) ;
        }
    } else if (nargout < 6) {
        int X, Y;
        std::vector<EPP::Point> polygon, part2;
        polygon = split.getPolygon(0, X, Y, simplify_polygon, &part2);
        mx_args.set(0, X + 1);
        mx_args.set(1, Y + 1);
        double *polygon_out = mx_args.setDouble(2, polygon.size(), 2);
        split.copyPoints(polygon, polygon_out, true, printSptx);
            double *polygon2_out = mx_args.setDouble(3, part2.size(), 2);
        split.copyPoints(part2, polygon2_out, true, printSptx);
    } else if (nPolygons > 0) {
        int X, Y;
        std::vector<EPP::Point> polygon;
        for (int i = 0; i < nPolygons; i++) {
            std::vector<EPP::Point> part2;
            const int argoutX = (i * 4);
            polygon = split.getPolygon(i, X, Y, simplify_polygon, &part2);
            mx_args.set(argoutX, X + 1);
            mx_args.set(argoutX + 1, Y + 1);
            double *polygon_out = mx_args.setDouble(argoutX + 2, polygon.size(), 2);
            split.copyPoints(polygon, polygon_out, true, printSptx);
            double *polygon2_out = mx_args.setDouble(argoutX + 3, part2.size(), 2);
            split.copyPoints(part2, polygon2_out, true, printSptx);
        }
    }
    if ((verbose_flags & 1) == 1) {
        std::cout << "Done ..." << std::endl;
    }
}
