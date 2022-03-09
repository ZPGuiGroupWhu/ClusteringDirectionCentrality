#ifndef _EPP_CLIENT_H
#define _EPP_CLIENT_H 1

#include <ios>
#include <sstream>
#include <algorithm>
#include <vector>
#include <queue>
#include <chrono>
#include <thread>
#include <mutex>
#include <condition_variable>

#include <math.h>

namespace EPP
{
    typedef uint32_t epp_word;
    typedef unsigned char epp_hash[32];

    /**
     * These classes define the client interface to EPP and the necessary data structures
     * 
     */

    class Sample
    {
    public:
        std::vector<bool> subset;
        const unsigned long int events;
        const unsigned short int measurements;

        Sample(unsigned short int measurements,
               unsigned long int events,
               std::vector<bool> subset) noexcept
            : measurements(measurements), events(events), subset(subset){};

        Sample(unsigned short int measurements,
               unsigned long int events) noexcept
            : measurements(measurements), events(events), subset(events)
        {
            std::fill(subset.begin(), subset.end(), true);
        };

    private:
        // these are virtual because our friend stream won't know which variant it will be
        virtual epp_word get_word(unsigned short int measurement, unsigned long event) const noexcept
        {
            return (epp_word)0;
        }
        virtual void put_word(unsigned short measurement, long event, epp_word data) noexcept {};
        friend class SampleStream;
    };

    template <typename _float>
    class DefaultSample : public Sample
    {
    public:
        inline double operator()(unsigned long int event, unsigned short int measurement) const noexcept
        {
            return (double)data[measurements * event + measurement];
        };

        DefaultSample(const unsigned short int measurements,
                      const unsigned long int events,
                      const _float *const data) noexcept
            : Sample(measurements, events), data(data)
        {
            for (long int event = 0; event < events; event++)
                for (unsigned short int measurement = 0; measurement < measurements; measurement++)
                    if (data[measurements * event + measurement] < 0 || data[measurements * event + measurement] > 1)
                        subset[event] = false;
        };

        DefaultSample(const unsigned short int measurements,
                      const unsigned long int events,
                      const _float *const data,
                      std::vector<bool> subset) noexcept
            : Sample(measurements, events, subset), data(data){};

    protected:
        epp_word get_word(unsigned short int measurement, unsigned long int event) const noexcept
        {
            float f = data[measurements * event + measurement];
            return *(epp_word *)&f;
        };

        void put_word(unsigned short int measurement, unsigned long int event, epp_word value) noexcept
        {
            float f = *(float *)&value;
            data[measurements * event + measurement] = (_float)f;
        };

    private:
        const _float *const data;
    };

    template <typename _float>
    class TransposeSample : public Sample
    {
    public:
        inline double operator()(unsigned long int event, unsigned short int measurement) const noexcept
        {
            return (double)data[events * measurement + event];
        };

        TransposeSample(const unsigned short int measurements,
                        const unsigned long int events,
                        const _float *const data) noexcept
            : Sample(measurements, events), data(data)
        {
            for (unsigned long int event = 0; event < events; event++)
                for (unsigned short int measurement = 0; measurement < measurements; measurement++)
                    if (data[events * measurement + event] < 0 || data[events * measurement + event] > 1)
                        subset[event] = false;
        };

        TransposeSample(const unsigned short int measurements,
                        const unsigned long int events,
                        const _float *const data,
                        std::vector<bool> subset) noexcept
            : Sample(measurements, events, subset), data(data){};

    protected:
        epp_word get_word(unsigned short int measurement, unsigned long int event) const noexcept
        {
            float f = data[events * measurement + event];
            return *(epp_word *)&f;
        };

        void put_word(unsigned short int measurement, unsigned long int event, epp_word value) noexcept
        {
            float f = *(float *)&value;
            data[events * measurement + event] = (_float)f;
        };

    private:
        const _float *const data;
    };

    template <typename _float>
    class PointerSample : public Sample
    {
    public:
        inline double operator()(unsigned long int event, unsigned short int measurement) const noexcept
        {
            return (double)data[measurement][event];
        };

        PointerSample(const unsigned short int measurements,
                      const unsigned long int events,
                      const _float *const *const data) noexcept
            : Sample(measurements, events), data(data)
        {
            for (unsigned long int event = 0; event < events; event++)
                for (unsigned short int measurement = 0; measurement < measurements; measurement++)
                    if (data[measurement][event] < 0 || data[measurement][event] > 1)
                        subset[event] = false;
        };

        PointerSample(const unsigned short int measurements,
                      const unsigned long int events,
                      const _float *const *const data,
                      std::vector<bool> subset) noexcept
            : Sample(measurements, events, subset), data(data){};

    protected:
        epp_word get_word(unsigned short int measurement, unsigned long int event) const noexcept
        {
            float f = data[measurement][event];
            return *(epp_word *)&f;
        };

        void put_word(unsigned short int measurement, unsigned long int event, epp_word value) noexcept
        {
            float f = *(float *)&value;
            data[measurement][event] = (_float)f;
        };

    private:
        const _float *const *const data;
    };

    class Subset : public std::vector<bool>
    {
    public:
        explicit Subset(Sample &sample);
        Sample *sample;

    private:
        friend class SubsetStream;
    };

    struct Parameters
    {
        // N = 256 gives points and features a precision of roughly two significant figures

        static const unsigned short N = 1 << 8; // resolution of points and boundaries
                                                // optimized when there are lots of small factors

        double W = 1 / (double)N; // standard deviation of kernel,
                                  // this is the highest achievable resolution, in practice a higher
                                  // value might be used for application reasons or just performance

        double sigma = 5; // controls the density threshold for starting a new cluster

        enum Goal
        {                    // which objective function
            best_separation, // lowest edge weight
            best_balance     // edge weight biased towards more even splits
        } goal = best_balance;

        int finalists = 1; // remember this many of the best candidates

        struct KLD // KLD threshold for informative cases
        {
            double Normal2D = .16;      // is this population worth splitting?
            double Normal1D = .16;      // is the measurement just normal
            double Exponential1D = .16; // is this an exponential tail (CyToF)

            KLD(
                double Normal2D = .16,
                double Normal1D = .16,
                double Exponential1D = .16) noexcept
                : Normal2D(Normal2D), Normal1D(Normal1D), Exponential1D(Exponential1D){};
        };

        const static KLD KLD_Default;
        KLD kld = KLD_Default;

        std::vector<bool> censor; // omit measurements from consideration

        // algorithm tweaks

        int max_clusters = 12; // most clusters the graph logic should handle

        bool shuffle = false;        // shuffle the boundary points for uniformity
        bool deterministic = false;  // do it with a fixed seed for testing
        bool supress_in_out = false; // don't bother with in and out sets
        bool kld_only = false;
        Parameters(
            Goal goal = best_balance,
            KLD kld = {.16, .16, .16},
            double sigma = 5,
            double W = 1 / (double)N)
            : goal(goal), kld(kld), W(W), sigma(sigma),
              censor(0), finalists(1), max_clusters(12),
              shuffle(false), deterministic(false), supress_in_out(false){};
    };

    const Parameters Default;

    struct Point
    {
        short i, j;

        inline double x() const noexcept { return (double)i / (double)Parameters::N; };
        inline double y() const noexcept { return (double)j / (double)Parameters::N; };

        inline bool operator==(const Point &other)
        {
            return i == other.i && j == other.j;
        }

        inline bool operator!=(const Point &other)
        {
            return !(*this == other);
        }

        Point(short i, short j) noexcept : i(i), j(j){};
    };

    enum Status
    {
        EPP_success,
        EPP_no_qualified,
        EPP_no_cluster,
        EPP_not_interesting,
        EPP_error
    };

    struct Candidate
    {
        std::vector<Point> separatrix;
        std::vector<bool> in, out;
        double score, edge_weight, balance_factor;
        unsigned long int in_events, out_events;
        unsigned int pass, clusters, graphs;
        unsigned short int X, Y;
        enum Status outcome;

    private:
        void close_clockwise(
            std::vector<Point> &polygon)
        {
            Point tail = polygon.front();
            Point head = polygon.back();
            int edge;
            if (head.j == 0)
                edge = 0;
            if (head.i == 0)
                edge = 1;
            if (head.j == Parameters::N)
                edge = 2;
            if (head.i == Parameters::N)
                edge = 3;
            while (!(head == tail))
            {
                switch (edge++ & 3)
                {
                case 0:
                    if (tail.j == 0 && tail.i < head.i)
                        head = tail;
                    else
                        head = Point(Parameters::N, 0);
                    break;
                case 1:
                    if (tail.i == 0 && tail.j > head.j)
                        head = tail;
                    else
                        head = Point(0, 0);
                    break;
                case 2:
                    if (tail.j == Parameters::N && tail.i > head.i)
                        head = tail;
                    else
                        head = Point(0, Parameters::N);
                    break;
                case 3:
                    if (tail.i == Parameters::N && tail.j < head.j)
                        head = tail;
                    else
                        head = Point(Parameters::N, Parameters::N);
                    break;
                }
                polygon.push_back(head);
            }
        }

        // Ramer–Douglas–Peucker algorithm
        void simplify(
            const double tolerance,
            std::vector<Point> &simplified,
            const unsigned short int lo,
            const unsigned short int hi)
        {
            if (lo + 1 == hi)
                return;

            double x = separatrix[hi].i - separatrix[lo].i;
            double y = separatrix[hi].j - separatrix[lo].j;
            double theta = atan2(y, x);
            double c = cos(theta);
            double s = sin(theta);
            double max = 0;
            unsigned short int keep;
            for (int mid = lo + 1; mid < hi; mid++)
            { // distance of mid from the line from lo to hi
                double d = abs(c * (separatrix[mid].j - separatrix[lo].j) - s * (separatrix[mid].i - separatrix[lo].i));
                if (d > max)
                {
                    keep = mid;
                    max = d;
                }
            }
            if (max > tolerance) // significant, so something we must keep in here
            {
                simplify(tolerance, simplified, lo, keep);
                simplified.push_back(separatrix[keep]);
                simplify(tolerance, simplified, keep, hi);
            }
            // but if not, we don't need any of the points between lo and hi
        }

    public:
        bool operator<(const Candidate &other) const noexcept
        {
            if (score < other.score)
                return true;
            if (score > other.score)
                return false;
            return outcome < other.outcome;
        }

        std::vector<Point> simplify(
            const double tolerance)
        {
            std::vector<Point> polygon;
            polygon.reserve(separatrix.size());

            polygon.push_back(separatrix[0]);
            simplify(tolerance * Parameters::N, polygon, 0, separatrix.size() - 1);
            polygon.push_back(separatrix[separatrix.size() - 1]);

            return polygon;
        }

        std::vector<Point> in_polygon()
        {
            std::vector<Point> polygon;
            polygon.reserve(separatrix.size() + 4);

            for (auto point = separatrix.begin(); point != separatrix.end(); point++)
                polygon.push_back(*point);

            close_clockwise(polygon);
            return polygon;
        }

        std::vector<Point> in_polygon(
            double tolerance)
        {
            std::vector<Point> polygon;
            polygon.reserve(separatrix.size() + 4);

            polygon.push_back(separatrix[0]);
            simplify(tolerance * Parameters::N, polygon, 0, separatrix.size() - 1);
            polygon.push_back(separatrix[separatrix.size() - 1]);

            close_clockwise(polygon);
            return polygon;
        }

        std::vector<Point> out_polygon()
        {
            std::vector<Point> polygon;
            polygon.reserve(separatrix.size() + 4);

            for (auto point = separatrix.rbegin(); point != separatrix.rend(); point++)
                polygon.push_back(*point);

            close_clockwise(polygon);
            return polygon;
        }

        std::vector<Point> out_polygon(
            double tolerance)
        {
            std::vector<Point> polygon;
            polygon.reserve(separatrix.size() + 4);

            polygon.push_back(separatrix[0]);
            simplify(tolerance * Parameters::N, polygon, 0, separatrix.size() - 1);
            polygon.push_back(separatrix[separatrix.size() - 1]);
            std::reverse(polygon.begin(), polygon.end());

            close_clockwise(polygon);
            return polygon;
        }

        Candidate(
            unsigned short int X,
            unsigned short int Y)
            : X(X < Y ? X : Y), Y(X < Y ? Y : X),
              outcome(Status::EPP_error),
              score(std::numeric_limits<double>::infinity()),
              pass(0), clusters(0), graphs(0){};
    };

    struct Result
    {
        std::vector<Candidate> candidates;
        std::vector<unsigned short int> qualified;
        std::chrono::milliseconds milliseconds;
        int projections, passes, clusters, graphs;

        Candidate winner() const noexcept
        {
            return candidates[0];
        }

        enum Status outcome() const noexcept
        {
            return winner().outcome;
        };

    protected:
        std::chrono::time_point<std::chrono::steady_clock> begin, end;
        friend class MATLAB_Pursuer;
    };

    class Request
    {
        static std::condition_variable_any completed;
        volatile unsigned int outstanding = 0;

        void finish ()
        {
            --outstanding;
        }

        bool finished ()
        {
            return outstanding == 0;
        };

        void wait ()
        {
            while (outstanding > 0)
                ;
        };

        Result *result ()
        {
            return nullptr;
        }
    };

    template <class ClientSample>
    class Pursuer
    {
    public:
        void start(
            const ClientSample sample,
            const Parameters parameters) noexcept;
        void start(
            const ClientSample sample) noexcept;
        bool finished() noexcept;
        void wait() noexcept;
        std::shared_ptr<Result> result() noexcept;
        std::shared_ptr<Result> pursue(
            const ClientSample sample,
            const Parameters parameters) noexcept;
        std::shared_ptr<Result> pursue(
            const ClientSample sample) noexcept;

    protected:
        Pursuer() noexcept = default;
        ~Pursuer() = default;
    };

    typedef TransposeSample<float> MATLAB_Sample;

    class MATLAB_Pursuer : public Pursuer<MATLAB_Sample>
    {
        int threads;
        std::thread *workers;

    public:
        int getThreads() const noexcept {return threads;}
        void start(
            const MATLAB_Sample sample,
            const Parameters parameters) noexcept;
        void start(
            const MATLAB_Sample sample) noexcept;
        void start(
            const unsigned short int measurements,
            const unsigned long int events,
            const float *const data,
            std::vector<bool> &subset) noexcept;
        void start(
            const unsigned short int measurements,
            const unsigned long int events,
            const float *const data) noexcept;
        bool finished() noexcept;
        void wait() noexcept;
        std::shared_ptr<Result> result() noexcept;
        std::shared_ptr<Result> pursue(
            const MATLAB_Sample sample,
            const Parameters parameters) noexcept;
        std::shared_ptr<Result> pursue(
            const MATLAB_Sample sample) noexcept;
        std::shared_ptr<Result> pursue(
            const unsigned short int measurements,
            const unsigned long int events,
            const float *const data,
            std::vector<bool> &subset) noexcept;
        std::shared_ptr<Result> pursue(
            const unsigned short int measurements,
            const unsigned long int events,
            const float *const data) noexcept;
        MATLAB_Pursuer() noexcept;
        MATLAB_Pursuer(int threads) noexcept;
        ~MATLAB_Pursuer();
    };

    /**
     * utility classes for serializing sample and subset as streams
     */

    class SampleStream : public std::iostream
    {
    protected:
        class sample_buffer : public std::streambuf
        {

        public:
            explicit sample_buffer(Sample &sample);
            virtual ~sample_buffer();

        protected:
            virtual std::streambuf::int_type underflow();
            virtual std::streambuf::int_type overflow(std::streambuf::int_type value);
            virtual std::streambuf::int_type sync();

        private:
            Sample *sample;
            epp_word *buffer;
            long next_event;
        };

    public:
        explicit SampleStream(Sample &sample);
    };

    class SubsetStream : public std::iostream
    {
    protected:
        class subset_buffer : public std::streambuf
        {
        public:
            explicit subset_buffer(Subset &subset);
            virtual ~subset_buffer();
            virtual std::streambuf::int_type underflow();
            virtual std::streambuf::int_type overflow(std::streambuf::int_type value);
            virtual std::streambuf::int_type sync();

        private:
            Subset *subset;
            uint8_t *buffer;
            long next_event;
            friend class SubsetStream;
        };

    public:
        explicit SubsetStream(Subset &subset);
    };
}
#endif /* _EPP_CLIENT_H */