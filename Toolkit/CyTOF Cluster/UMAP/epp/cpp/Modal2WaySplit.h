//
// Created by Stephen Meehan on 6/29/21.
//
#ifndef _EPP_MODAL2WAYSPLIT_H
#define _EPP_MODAL2WAYSPLIT_H
#include <ostream>
#include <iostream>
#include <fstream>
#include <sstream>
#include <map>
#include <chrono>
#include <limits>
#include "constants.h"
#include "client.h"


namespace  EPP {
    extern Point bottomLeftCorner, topLeftCorner, bottomRightCorner, topRightCorner;
    void testMex(const float *const data, const long events, const int measurements,
                 const int threads=-1, const int polygons=1,
                 const double KLD_normal_1D=0.16,
                 const double KLD_normal_2D=.16,
                 const char *service="split");
    void testMexPolygon();
    class Modal2WaySplit {
    public:
        enum class Side {LEFT, TOP, RIGHT, BOTTOM, NONE};
        std::vector<Candidate> candidates;
    private:
        std::vector<unsigned short int>qualified;
        Parameters params;
        static EPP::MATLAB_Pursuer *pursuer;

        int getMinOffset(const int column) const noexcept;
        int getMaxOffset(const int column) const noexcept;
        const float *const data;
        const char *failure = "not run";
        std::vector<EPP::Point> separatrix;
        static Side getSide(EPP::Point point)  noexcept;
        std::vector<EPP::Point> convertSeparatrixToPolygon(
                std::vector<EPP::Point>&sptx, const int X,
                const int Y, const bool part1) const noexcept;
        static void updatePoint(
                std::vector<EPP::Point>&sptx, const int idx,
                const int minX, const int minY,
                const int maxX, const int maxY) noexcept;
        static bool appendForPolygonPart1(
                std::vector<EPP::Point> &points,
                const int minX_offset=0, const int minY_offset=0,
                const int maxX_offset=0, const int maxY_offset=0)   noexcept;
        static bool appendForPolygonPart2(
                std::vector<EPP::Point> &points,
                const int minX_offset=0, const int minY_offset=0,
                const int maxX_offset=0, const int maxY_offset=0)   noexcept;

        const int finalists;
        const bool qualify_only;
        void print_best() const;

        inline float get_word(
                const unsigned short measurement,
                const unsigned long event) const noexcept {
            return data[events * measurement + event];
        }

        inline float min(const unsigned short measurement) const noexcept{
            float mx=std::numeric_limits<float>::max();
            float mn=std::numeric_limits<float>::min();
            for (int i=0;i<events;i++){
                if (get_word(measurement,i)<mx)
                    mx = get_word(measurement,i);
            }
            return mx;
        }

        inline float max(const unsigned short measurement) const noexcept{
            float mn=std::numeric_limits<float>::min();
            for (int i=0;i<events;i++){
                if (get_word(measurement,i)>mn)
                    mn = get_word(measurement,i);
            }
            return mn;
        }

        std::ostream  &print(const int idx, std::ostream &os=std::cout) const;
        int projections;
    public:
        int copyPoints(std::vector<EPP::Point>&polygon, double *const polygon_out,
                  const bool columnWise= true, const bool print= false, std::ostream& os= std::cout);
        std::vector<EPP::Point> getPolygon(const int idx, int &X, int &Y,
                  const bool simplify, std::vector<EPP::Point> *part2= nullptr) noexcept;
        std::vector<EPP::Point> getInPolygon(const int idx, int &X, int &Y)  noexcept;
        const unsigned long events;
        const unsigned short measurements;
        std::chrono::milliseconds durationMilliSecs;
        int X = -1, Y = -1;
        std::ostream & print(std::ostream &os=std::cout);
        size_t size() noexcept;
        Modal2WaySplit(
                const float *const data,
                const unsigned long events,
                const unsigned short measurements,
                const int finalists=1,
                int threads = -1,
                const int verbose_flags = 0,
                const bool balanced=true,
                const double W=-1,
                const double sigma=-1,
                const double KLD_normal_1D=-1,
                const double KLD_normal_2D=-1,
                const double KLD_exponential_1D=-1,
                const int max_clusters=-1,
                const bool qualify_only=false);
        int copyPolygon(int *const xy, bool columnWise=true);

        operator bool (){return separatrix.size()>0;}
    };


};
#endif //WEIGHINGMORE_MODALSPLIT_H
