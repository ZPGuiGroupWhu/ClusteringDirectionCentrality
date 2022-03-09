#include "Modal2WaySplit.h"
#include <suh.h>
//#include "CurveSimplifier.h"
namespace EPP {

    int verbose_flags = 1 + 4 + 8;
    MATLAB_Pursuer *Modal2WaySplit::pursuer = nullptr;
    std::ostream &Modal2WaySplit::print(const int idx, std::ostream &os) const {
        const EPP::Candidate c=candidates[idx];
        if (c.separatrix.empty()) {
            os << "#" << (idx + 1) << "  X=" << c.X
               << ", Y=" << c.Y << " has not split!" << std::endl;
            return os;
        }
        EPP::Point start = c.separatrix[0];
        EPP::Point end = c.separatrix[c.separatrix.size() - 1];
        os  << "#" << (idx+1) << "  X=" << c.X << ", Y=" << c.Y
                << " using " << c.separatrix.size() << " points from "
                << start.i << "/" << start.j << " thru " << end.i << "/" << end.j << ", score="
                << c.score << std::endl;
        return os;
    }

    void Modal2WaySplit::print_best() const {
        const int n = finalists > candidates.size() ?
                      candidates.size() : finalists;
        std::cout<<"Top " << n << " score(s)" << std::endl;
        for (int i = 0; i < n; i++)
            print(i);
    }

    Modal2WaySplit::Modal2WaySplit(
            const float *const data,// MATLAB column wise expected
            const unsigned long events,
            const unsigned short measurements,
            const int finalists,
            int threads,
            const int verbose_flags,
            const bool balanced,
            const double W,
            const double sigma,
            const double KLD_normal_1D,
            const double KLD_normal_2D,
            const double KLD_exponential_1D,
            const int max_clusters,
            const bool qualify_only)
            : data(data),
              events(events),
              measurements(measurements),
              finalists(finalists), qualify_only(qualify_only) {
        EPP::Parameters parameters = EPP::Default; // this is the default
        parameters.finalists = finalists;
        if (W==-1)parameters.W = .006;             // works well on Eliver and Cytek
        else parameters.W=W;
        if (sigma==-1)parameters.sigma = 3.0;          // 3 to 5 maybe 6 are reasonable
        else parameters.sigma=sigma;
        if (balanced) parameters.goal=Parameters::Goal::best_balance;
        else parameters.goal=Parameters::Goal::best_separation;
        if (KLD_exponential_1D>-1) parameters.kld.Exponential1D=KLD_exponential_1D;
        if (KLD_normal_1D>-1) parameters.kld.Normal1D=KLD_normal_1D;
        if (KLD_normal_2D>-1) parameters.kld.Normal2D=KLD_normal_2D;
        if (max_clusters>-1) parameters.max_clusters=max_clusters;
        // less than three probably very noisy
        parameters.shuffle = true;       // should make border grow more uniform
        parameters.deterministic = true; // if we need reproducible tests
        parameters.kld_only = qualify_only;
        EPP::verbose_flags = verbose_flags;
        params=parameters;

        //EPP::Score::scores.clear();
        try {
            if (threads < 0 || threads > std::thread::hardware_concurrency())
                threads = std::thread::hardware_concurrency();

// initial subset is everything in range
            // there is no bounds checking in the algorithm

            std::vector<bool> start(events);
            for (long i = 0; i < events; i++) {
                bool in_range = true;
                for (int j = 0; j < measurements; j++) {
                    float value = data[i + events * j];
                    if (value < 0)
                        in_range = false;
                    if (value > 1)
                        in_range = false;
                }
                start[i] = in_range;
            }

            // start parallel projection pursuit

            if (pursuer==nullptr)
                pursuer=new MATLAB_Pursuer(threads);
            else if( pursuer->getThreads() != threads){
                delete pursuer;
                pursuer=new MATLAB_Pursuer(threads);
            }
            EPP::MATLAB_Sample sample(measurements, events, data);
            pursuer->start(sample, parameters);
            if (!pursuer->finished()) // optional, used when you want to do something else while it runs
                pursuer->wait();
            std::shared_ptr<EPP::Result> result = pursuer->result();
            durationMilliSecs = result->milliseconds;
            projections=result->projections;
            candidates = result->candidates;
            EPP::Candidate winner(-1,-1);
            if (!result->candidates.empty())
                winner= result->winner();
            else
                winner.outcome=Status::EPP_no_cluster;
            if ((verbose_flags & 8) == 8) {
                const int points = winner.separatrix.size();
                std::cout << points << " separatrix coordinates" << std::endl;
                for (int i = 0; i < points; i++) {
                    std::cout << winner.separatrix[i].i << " "
                              << winner.separatrix[i].j << "   ";
                    if ((i + 1) % 10 == 0) {
                        std::cout << std::endl;
                    }
                }
                std::cout << std::endl;
            }
            qualified=result->qualified;
            // presumably report back to the dispatcher
            // only go around once for now
            switch (winner.outcome) {
                case Status::EPP_success:
                    failure = "none";
                    separatrix = winner.separatrix;
                    X = winner.X;
                    Y = winner.Y;
                    break;
                case Status::EPP_no_cluster:
                    failure = "no cluster";
                    break;
                case Status::EPP_error:
                    failure = "EPP error";
                    break;
                case Status::EPP_no_qualified:
                    failure = "no qualified";
                    break;
                case Status::EPP_not_interesting:
                    failure = "Not interesting";
                    break;
            }
            if ((verbose_flags & 1) == 1)
                print();
        }
        catch (std::runtime_error e) {
            std::cout << e.what() << std::endl;
            this->failure = "runtime error";
        }
    }

    size_t Modal2WaySplit::size() noexcept {
        return separatrix.size();
    }

    int Modal2WaySplit::copyPolygon(int *const xy, bool columnWise) {
        const int sz = size();
        const std::vector<Point> &sptx = separatrix;
        if (columnWise) {
            for (int i = 0; i < sz; i++) {
                xy[i] = sptx[i].i;
                xy[i + sz] = sptx[i].j;
            }
        } else {
            for (int i = 0, ii = 0; i < sz; i++, ii += 2) {
                xy[ii] = sptx[i].i;
                xy[ii + 1] = sptx[i].j;
            }
        }
        return sz;
    }

    Modal2WaySplit::Side Modal2WaySplit::getSide(EPP::Point point)  noexcept {
        if (point.i == 0) {
            return Side::LEFT;
        }
        if (point.j == EPP::N) {
            return Side::TOP;
        }
        if (point.j == 0) {
            return Side::BOTTOM;
        } else if (point.i==EPP::N){
            return Side::RIGHT;
        }
        return Side::NONE;
    }

    void Modal2WaySplit::updatePoint(
            std::vector<EPP::Point> &sptx, const int idx,
            const int minX, const int minY,
            const int maxX, const int maxY) noexcept {
        if (minX == 0 && minY == 0
            && maxX == EPP::N
            && maxY == EPP::N) {
            return;
        }
        Point &p = sptx[idx];
        if (minX < 0 && p.i == 0)
            p.i = minX;
        else if (maxX > EPP::N && p.i == EPP::N)
            p.i = maxX;
        if (minY < 0 && p.j == 0)
            p.j = minY;
        else if (maxY > EPP::N && p.j == EPP::N)
            p.j = maxY;
        else // nothing changed
            return;
        sptx[idx] = p;
    }


    int Modal2WaySplit::getMaxOffset(const int column) const noexcept {
        const float max = this->max(column);
        if (max > 1) {
            int mx = std::ceil((max - 1) * EPP::N);
            return mx;
        }
        return 0;
    }

    int Modal2WaySplit::getMinOffset(const int column) const noexcept {
        const float min = this->min(column);
        if (min < 0) {
            int mn = std::ceil((0 - min) * EPP::N);
            return 0 - mn;
        }
        return 0;
    }
    std::vector<EPP::Point> Modal2WaySplit::getInPolygon(const int idx, int &X, int &Y)   noexcept{
        if (idx <0 || idx> candidates.size()) {
            X = -1;
            Y = -1;
            std::cerr << "Modal2WaySplit::getInPolygon() idx " << idx
            << " should be >=0 and < "<<  candidates.size() << std::endl;
            std::vector<EPP::Point> polygon;
            return polygon;
        }
        X=candidates[idx].X;
        Y=candidates[idx].Y;
        return candidates[idx].in_polygon();
    }
    std::vector<EPP::Point> Modal2WaySplit::getPolygon(
            const int idx, int &X, int &Y,const bool simplify,
            std::vector<EPP::Point>  *part2 ) noexcept{
        std::vector<EPP::Point> polygon;
        if (idx < 0 || idx>= candidates.size()) {
            X = -1;
            Y = -1;
            return polygon;
        }
        if (this->X==-1 || this->Y==-1){
            X=this->X;
            Y=this->Y;
            return polygon;
        }
        Candidate &c=candidates[idx];
        if (c.outcome != Status::EPP_success){
            X=this->X;
            Y=this->Y;
            return polygon;
        }
        X=c.X;
        Y=c.Y;
        if (simplify && (EPP::verbose_flags&1)==1)
            std::cout << c.separatrix.size() << " points becomes ";
        //CurveSimplifier::printAsJava(separatrix);
        if (simplify)
            polygon = c.simplify(.0039);///params.W * 1);
        else
            polygon = c.separatrix;
        if (part2!= nullptr){
            part2->insert(part2->end(), polygon.begin(), polygon.end());
            convertSeparatrixToPolygon(polygon, X, Y, true);
            convertSeparatrixToPolygon(*part2, X, Y, false);
        } else {
            convertSeparatrixToPolygon(polygon, X, Y, true);
        }
        if (simplify && (EPP::verbose_flags&1)==1)
            std::cout << polygon.size() << " points "
                      << (simplify ? "simplified" : "unsimplified") << std::endl;
        return polygon;
    }

    std::vector<EPP::Point> Modal2WaySplit::convertSeparatrixToPolygon(
            std::vector<EPP::Point> &sptx, const int X, const int Y,
            const bool part1) const noexcept {
        if (sptx.size() > 1) {
            //std::vector<EPP::Point> copy(sptx);
            const int minX_offset = getMinOffset(X), minY_offset = getMinOffset(Y);
            const int maxX_offset = getMaxOffset(X), maxY_offset = getMaxOffset(Y);
            if (part1) {
                appendForPolygonPart1(sptx, minX_offset,
                                      minY_offset, maxX_offset, maxY_offset);
                /*addPolygonPoints(copy, getSide(copy[0]),
                        getSide(copy[copy.size() - 1]),
                        minX_offset, minY_offset, maxX_offset, maxY_offset);*/
            } else {
                appendForPolygonPart2(sptx, minX_offset,
                                      minY_offset, maxX_offset, maxY_offset);
            }
        }
        return sptx;
    }

    int Modal2WaySplit::copyPoints(
            std::vector<Point> &polygon,
            double *const polygon_out, const bool columnWise,
            const bool print, std::ostream &os) {
        const int sz = polygon.size();
        const double n = static_cast<double>(N);
        if (columnWise) {
            for (int i = 0; i < sz; i++) {
                polygon_out[i] = static_cast<double>(polygon[i].i) / n;
                polygon_out[i + sz] = static_cast<double>(polygon[i].j) / n;
            }
        } else {
            for (int i = 0, ii = 0; i < sz; i++, ii += 2) {
                polygon_out[ii] = static_cast<double>(polygon[i].i) / n;
                polygon_out[ii + 1] = static_cast<double>(polygon[i].j) / n;
            }
        }
        if (print) {
            for (int i = 0, ii = 0; i < sz; i++, ii += 2) {
                os << "#" << (i + 1) << ": " << polygon[i].i << "=";
                if (!columnWise) {
                    os << polygon_out[ii];
                } else {
                    os << polygon_out[i];
                }
                os << " and ";
                os << polygon[i].j << "=";
                if (!columnWise) {
                    os << polygon_out[ii + 1];
                } else {
                    os << polygon_out[i + sz];
                }
                os << std::endl;
            }
        }
        return sz;
    }

    std::ostream &Modal2WaySplit::print(std::ostream &os) {
        const int sz = size();
        if (sz == 0)
            os << "No successful separatrix: " << failure << std::endl;
        else
            print_best();
        os << "\t" << durationMilliSecs.count()
           << "[ms] of processing time on "
           << events << " events X " << measurements << " measurements in sample "
           << "(" << qualified.size() << " qualified measurements & " << projections << " 2D pairs)"
           << std::endl;

        return os;
    }
}

