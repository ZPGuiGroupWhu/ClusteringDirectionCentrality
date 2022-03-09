//
// Created by Stephen Meehan on 8/19/21.
//
/*
AUTHORS
    Wayne Moore <wmoore@stanford.edu>
    Stephen Meehan <swmeehan@stanford.edu>

 This smoothens a curve using the Ramer–Douglas–Peucker algorithm  described at
 https://en.wikipedia.org/wiki/Ramer%E2%80%93Douglas%E2%80%93Peucker_algorithm

 This is mostly the same as the simplify methods in the Candidate class.  It has been  decoupled to be fully
 independent of EPP::Candidate.

Provided by suh ( Stanford University's Herzenberg Lab)
License: BSD 3 clause
*/

#ifndef WEIGHINGMORE_CURVESIMPLIFIER_H
#define WEIGHINGMORE_CURVESIMPLIFIER_H

#include "client.h"

namespace EPP {
    class CurveSimplifier {
        const std::vector<Point> &line;
        const double tolerance;

        CurveSimplifier(const std::vector<Point> line, const double startingTolerance)
                : line(line), tolerance(startingTolerance) {
        }

        // Ramer–Douglas–Peucker algorithm
        void simplify(
                std::vector<Point> &simplified,
                const unsigned short int lo,
                const unsigned short int hi) {
            if (lo + 1 == hi)
                return;

            double x = line[hi].i - line[lo].i;
            double y = line[hi].j - line[lo].j;
            double theta = atan2(y, x);
            double c = cos(theta);
            double s = sin(theta);
            double max = 0;
            unsigned short int keep;
            for (int mid = lo + 1; mid < hi; mid++) { // distance of mid from the line from lo to hi
                double d = abs(c * (line[mid].j - line[lo].j) - s * (line[mid].i - line[lo].i));
                if (d > max) {
                    keep = mid;
                    max = d;
                }
            }
            if (max > tolerance) // significant, so something we must keep in here
            {
                simplify(simplified, lo, keep);
                simplified.push_back(line[keep]);
                simplify(simplified, keep, hi);
            }
            // but if not, we don't need any of the points between lo and hi
        }

        std::vector<Point> simplify() {
            std::vector<Point> polygon;
            polygon.reserve(line.size());

            polygon.push_back(line[0]);
            simplify( polygon, 0, line.size() - 1);
            polygon.push_back(line[line.size() - 1]);

            return polygon;
        }

    public:
        static   void printAsJava(const std::vector<Point>line){
            const int N=line.size();
            const int newLineEvery=12;
            std::cout << std::endl << "final int [][]testLine =new int[][]{" << std::endl;
            for (int i=0;i<N;i++){
                if( ((i+1)% newLineEvery)==0)
                    std::cout<<std::endl;
                std::cout <<"{" << line[i].j << ", " << line[i].i <<"}";
                if (i<N-1)
                    std::cout<<",";
            }
            std::cout<<std::endl<<"};"<<std::endl;
        }

        static std::vector<Point> Run(std::vector<Point> line, const double densityW, const int M) {
            CurveSimplifier ls(line, densityW*M);
            return ls.simplify();
        }
    };
}
#endif //WEIGHINGMORE_CURVESIMPLIFIER_H
