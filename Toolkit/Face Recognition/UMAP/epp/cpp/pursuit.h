#include <stack>
#include <queue>
#include <cassert>
#include <thread>
#include <mutex>
#include <condition_variable>

#include <iostream>
#include <fstream>

#include <fftw3.h>

#include "constants.h"
#include "client.h"
#include "boundary.h"
#include "transform.h"
#include "modal.h"

namespace EPP
{
    static std::recursive_mutex mutex;
    // static std::condition_variable_any work_available;
    static std::condition_variable_any work_completed;
    static int work_outstanding;

    std::shared_ptr<Result> _result;

    // abstract class representing a unit of work to be done
    // virtual functions let subclasses specialize tasks
    // handles work_completed and work_outstanding
    // static std::vector<unsigned short int> qualified_measurements;

    template <class ClientSample>
    class Work
    {
    public:
        const ClientSample sample;
        const Parameters parameters;

        // many threads can execute this in parallel
        virtual void parallel() noexcept
        {
            assert(("unimplemented", false));
        };
        // then only one thread at a time can run
        virtual void serial() noexcept
        {
            assert(("unimplemented", false));
        };

        ~Work()
        {
            std::unique_lock<std::recursive_mutex> lock(EPP::mutex);
            if (--work_outstanding == 0)
                work_completed.notify_all();
        };

    protected:
        explicit Work(
            const ClientSample &sample,
            const Parameters parameters) noexcept
            : sample(sample), parameters(parameters)
        {
            std::unique_lock<std::recursive_mutex> lock(EPP::mutex);
            ++work_outstanding;
        };
    };

    // a generic worker thread. looks for work, does it, deletes it
    // virtual functions in the work object do all the real work
    template <class ClientSample>
    class Worker
    {
    public:
        static std::queue<Work<ClientSample> *> work_list;
        static std::condition_variable_any work_available;
        volatile static bool kiss_of_death;

        static void enqueue(
            Work<ClientSample> *work) noexcept
        {
            std::unique_lock<std::recursive_mutex> lock(mutex);
            work_list.push(work);
            work_available.notify_one();
        }

        static void kiss()
        {
            std::unique_lock<std::recursive_mutex> lock(mutex);
            kiss_of_death = true;
            work_available.notify_all();
        }

        static void revive()
        {
            work_list.clear();
            kiss_of_death = false;
        }

        Worker() noexcept
        {
            std::unique_lock<std::recursive_mutex> lock(mutex);
            while (!Worker<ClientSample>::kiss_of_death)
                if (work_list.empty())
                    work_available.wait(lock);
                else
                {
                    Work<ClientSample> *work = work_list.front();
                    work_list.pop();
                    lock.unlock();
                    work->parallel();
                    lock.lock();
                    work->serial();
                    delete work;
                }
        };
    };

    template <class ClientSample>
    volatile bool Worker<ClientSample>::kiss_of_death = false;

    template <class ClientSample>
    std::condition_variable_any Worker<ClientSample>::work_available;

    template <class ClientSample>
    std::queue<Work<ClientSample> *> Worker<ClientSample>::work_list;

    static Transform transform;

    // pursue a particular X, Y pair
    template <class ClientSample>
    class PursueProjection : public Work<ClientSample>
    {
    public:
        Candidate candidate;

        // this is filtering with a progressively wider Gaussian kernel
        void applyKernel(FFTData &cosine, FFTData &filtered, int pass) noexcept
        {
            double k[N + 1];
            double width = this->parameters.W * pass;
            for (int i = 0; i <= N; i++)
                k[i] = exp(-i * i * width * width * pi * pi * 2);

            float *data = *cosine;
            float *smooth = *filtered;
            for (int i = 0; i <= N; i++)
            {
                for (int j = 0; j < i; j++)
                {
                    smooth[i + (N + 1) * j] = (float)(data[i + (N + 1) * j] * k[i] * k[j]);
                    smooth[j + (N + 1) * i] = (float)(data[j + (N + 1) * i] * k[j] * k[i]);
                }
                smooth[i + (N + 1) * i] = (float)(data[i + (N + 1) * i] * k[i] * k[i]);
            }
        }

        PursueProjection(
            const ClientSample sample,
            const Parameters parameters,
            const int X,
            const int Y) noexcept
            : Work<ClientSample>(sample, parameters), candidate(X, Y){};

        ~PursueProjection() = default;

        virtual void parallel() noexcept;

        virtual void serial() noexcept;
    };

    template <class ClientSample>
    class QualifyMeasurement : public Work<ClientSample>
    {
    public:
        const unsigned short int X;
        double KLDn = 0;
        double KLDe = 0;
        bool qualified = false;

        QualifyMeasurement(
            const ClientSample sample,
            const Parameters parameters,
            const int X)
            : Work<ClientSample>(sample, parameters), X(X){};

        virtual void parallel() noexcept;

        virtual void serial() noexcept;
    };

    // pursue a particular X, Y pair
    template <class ClientSample>
    void PursueProjection<ClientSample>::parallel() noexcept
    {
        thread_local FFTData weights;
        // compute the weights and sample statistics from the data for this subset
        unsigned long int n = 0;
        weights.zero();
        double Sx = 0, Sy = 0, Sxx = 0, Sxy = 0, Syy = 0;
        for (unsigned long int event = 0; event < this->sample.events; event++)
            if (this->sample.subset[event])
            {
                ++n;
                double x = this->sample(event, candidate.X);
                double y = this->sample(event, candidate.Y);

                int i = (int)(x * N);
                int j = (int)(y * N);
                double dx = x * N - i;
                double dy = y * N - j;
                weights[i + (N + 1) * j] += (float)((1 - dx) * (1 - dy));
                weights[i + 1 + (N + 1) * j] += (float)(dx * (1 - dy));
                weights[i + (N + 1) * j + (N + 1)] += (float)((1 - dx) * dy);
                weights[i + 1 + (N + 1) * j + (N + 1)] += (float)(dx * dy);

                Sx += x;
                Sy += y;
                Sxx += x * x;
                Sxy += x * y;
                Syy += y * y;
            }
        double Mx = Sx / (double)n; // means
        double My = Sy / (double)n;
        double Cxx = (Sxx - Sx * Mx) / (double)(n - 1); // covariance
        double Cxy = (Sxy - Sx * My) / (double)(n - 1);
        double Cyy = (Syy - Sy * My) / (double)(n - 1);

        // discrete cosine transform (FFT of real even function)
        thread_local FFTData cosine;
        transform.forward(weights, cosine);

        double KLD = 0;
        thread_local FFTData filtered;
        thread_local FFTData density;
        thread_local ModalClustering modal;
        thread_local ClusterBoundary cluster_bounds;
        std::vector<ClusterEdge> edges;
        do
        {
            do
            {
                // apply kernel to cosine transform
                applyKernel(cosine, filtered, ++candidate.pass);
                // inverse discrete cosine transform
                // gives a smoothed density estimator
                transform.reverse(filtered, density);
                // modal clustering
                candidate.clusters = modal.findClusters(*density, candidate.pass, this->parameters);
                if (this->parameters.kld_only)
                    break;
            } while (candidate.clusters > this->parameters.max_clusters);
            if (candidate.clusters < 2)
            {
                candidate.outcome = Status::EPP_no_cluster;
                return;
            }

            // Kullback-Leibler Divergence
            if (KLD == 0)
            { // if it was complex enough to go around this is unlikely to be relevant the second time
                double NQ = 0;
                double NP = 0;
                for (int i = 0; i <= N; i++)
                    for (int j = 0; j <= N; j++)
                    {
                        double p = density[i + (N + 1) * j]; // density is *not* normalized
                        NP += p;
                        if (p <= 0)
                            continue;
                        double x = i / (double)N - Mx;
                        double y = j / (double)N - My;
                        // Mahalanobis distance squared over 2 is unnormalized - ln Q
                        double MD2 = (x * x / Cxx - 2 * x * y * Cxy / Cxx / Cyy + y * y / Cyy) / (1 - Cxy * Cxy / Cxx / Cyy) / 2;
                        NQ += exp(-MD2);
                        // unnormalized P ln(P/Q) = P * (ln P - ln Q) where P is density and Q is bivariant normal
                        KLD += p * (log(p) + MD2);
                    }

                // Normalize the density
                KLD /= NP;
                // subtract off normalization constants factored out of the sum above
                KLD -= log(NP / NQ);
                if (KLD < this->parameters.kld.Normal2D)
                {
                    candidate.outcome = Status::EPP_not_interesting;
                    return;
                } else if (this->parameters.kld_only){
                    candidate.outcome = Status::EPP_success;
                    return;
                }

            }
            modal.getBoundary(*density, cluster_bounds);
            // get the edges, which have their own weights
            edges = cluster_bounds.getEdges();
            // smooth some more if graph is too complex to process
        } while (edges.size() > max_booleans);

        // compute the cluster weights
        auto cluster_map = cluster_bounds.getMap();
        unsigned long int *cluster_weight = new unsigned long int[candidate.clusters + 1];
        std::fill(cluster_weight, cluster_weight + candidate.clusters + 1, 0);
        for (unsigned long int event = 0; event < Work<ClientSample>::sample.events; event++)
            if (Work<ClientSample>::sample.subset[event])
            {
                double x = this->sample(event, candidate.X);
                double y = this->sample(event, candidate.Y);
                short cluster = cluster_map->colorAt(x, y);
                ++cluster_weight[cluster];
            }

        // get the dual graph of the map
        auto graph = cluster_bounds.getDualGraph();

        // pile of graphs to consider
        std::stack<DualGraph> pile;
        pile.push(*graph);

        // find and score simple sub graphs
        double best_score = std::numeric_limits<double>::infinity();
        booleans best_edges;
        booleans best_clusters;
        double best_balance_factor;
        double best_edge_weight;
        unsigned long int best_left, best_right;
        while (!pile.empty())
        {
            ++candidate.graphs;
            DualGraph graph = pile.top();
            pile.pop();
            if (graph.isSimple())
            { // one edge, i.e., two populations
                booleans left_clusters = graph.left();
                unsigned long int left_weight = 0;
                for (unsigned int i = 1; i <= candidate.clusters; i++)
                {
                    if (left_clusters & (1 << (i - 1)))
                        left_weight += cluster_weight[i];
                }
                if (left_weight == 0 || left_weight == n) // empty cluster!
                {
                    // std::cout << "empty cluster" << std::endl;
                    continue;
                }

                booleans dual_edges = graph.edge();
                double edge_weight = 0;
                for (unsigned int i = 0; i < edges.size(); i++)
                {
                    if (dual_edges & (1 << i))
                        edge_weight += edges[i].weight;
                }
                double P = (double)left_weight / (double)n;
                double balanced_factor = 4 * P * (1 - P);

                edge_weight /= 8 * N * N; // approximates number of events within +/-W of the border
                double score = edge_weight;
                if (this->parameters.goal == Parameters::Goal::best_balance)
                    score /= balanced_factor;
                assert(score > 0);
                // score this separatrix
                if (score < best_score)
                {
                    best_score = score;
                    best_edges = dual_edges;
                    best_clusters = left_clusters;
                    best_left = left_weight;
                    best_right = n - left_weight;
                    best_balance_factor = balanced_factor;
                    best_edge_weight = edge_weight;
                }
            }
            else
            { // not simple so simplify it some, i.e., remove one dual edge at a time
                // and merge two adjacent subsets. that makes a bunch more graphs to look at
                std::vector<DualGraph> simplified = graph.simplify();
                for (const auto &graph : simplified)
                    pile.push(graph);
            }
        }
        delete[] cluster_weight;
        if (best_score == std::numeric_limits<double>::infinity())
        {
            candidate.outcome = Status::EPP_no_cluster;
            return;
        }

        thread_local ColoredBoundary<short, bool, booleans> subset_boundary;
        subset_boundary.clear();
        for (unsigned int i = 0; i < edges.size(); i++)
        {
            if (best_edges & (1 << i))
            {
                ColoredEdge<short, short> edge = edges[i];
                bool lefty = best_clusters & (1 << (edge.widdershins - 1));
                subset_boundary.addEdge(edge.points, lefty, !lefty);
                // end points on the boundaries of data space are vertices
                ColoredPoint<short> point = edge.points[0];
                if (point.i == 0 || point.i == N || point.j == 0 || point.j == N)
                    subset_boundary.addVertex(point);
                point = edge.points[edge.points.size() - 1];
                if (point.i == 0 || point.i == N || point.j == 0 || point.j == N)
                    subset_boundary.addVertex(point);
            }
        }
        subset_boundary.setColorful(2);

        candidate.outcome = Status::EPP_success;

        ColoredEdge<short, bool> separatrix = subset_boundary.getEdges().at(0);
        candidate.separatrix.clear();
        candidate.separatrix.reserve(separatrix.points.size());
        for (ColoredPoint<short> cp : separatrix.points)
            candidate.separatrix.push_back(Point(cp.i, cp.j));
        if (separatrix.widdershins)
            std::reverse(candidate.separatrix.begin(), candidate.separatrix.end());

        if (!this->parameters.supress_in_out)
        { // don't waste the time if they're not wanted
            // create in/out subsets
            auto subset_map = subset_boundary.getMap();
            candidate.in.resize(this->sample.events);
            candidate.in.clear();
            candidate.in_events = 0;
            candidate.out.resize(this->sample.events);
            candidate.out.clear();
            candidate.out_events = 0;
            for (unsigned long int event = 0; event < this->sample.events; event++)
                if (Work<ClientSample>::sample.subset[event])
                {
                    double x = this->sample(event, candidate.X);
                    double y = this->sample(event, candidate.Y);
                    bool member = subset_map->colorAt(x, y);
                    if (member)
                    {
                        ++candidate.in_events;
                        candidate.in[event] = true;
                    }
                    else
                    {
                        ++candidate.out_events;
                        candidate.out[event] = true;
                    }
                }
            assert(best_right == candidate.in_events && best_left == candidate.out_events);
        }else
        {
            candidate.in_events = best_right;
            candidate.out_events = best_left;
        }

        candidate.score = best_score;
        candidate.edge_weight = best_edge_weight;
        candidate.balance_factor = best_balance_factor;
    }

    template <class ClientSample>
    void PursueProjection<ClientSample>::serial() noexcept
    {
        // std::cout << "pass " << pass << " clusters " << clusters << " graphs considered " << graph_count << std::endl;
        // std::cout << "pursuit completed " << X << " vs " << Y << "  ";

        if (this->parameters.kld_only){
            if (candidate.outcome==EPP_success)
                _result->candidates.push_back(candidate);
        } else {
            // keep the finalists in order, even failures get inserted so we return some error message
            int i = _result->candidates.size();
            if (i < this->parameters.finalists)
                _result->candidates.push_back(candidate);
            else
                --i;
            if (candidate.score <= _result->candidates[i].score) {
                for (; i > 0 && candidate < _result->candidates[i - 1]; i--)
                    _result->candidates[i] = _result->candidates[i - 1];
                _result->candidates[i] = candidate;
            }
        }
        _result->projections++;
        _result->passes += candidate.pass;
        _result->clusters += candidate.clusters;
        _result->graphs += candidate.graphs;
    }

    template <class ClientSample>
    void QualifyMeasurement<ClientSample>::parallel() noexcept
    {
        thread_local struct Scratch
        {
            float *data;
            unsigned long int size;
        } scratch = {nullptr, 0};
        if (scratch.size < this->sample.events + 1)
        {
            delete[] scratch.data;
            scratch.data = new float[this->sample.events + 1];
        }

        // get statistics for this measurement for this subset
        float *x = scratch.data;
        float *p = x;
        double Sx = 0, Sxx = 0;
        long n = 0;
        for (unsigned long int event = 0; event < this->sample.events; event++)
            if (Work<ClientSample>::sample.subset[event])
            {
                float value = (float)this->sample(event, X);
                ++n;
                Sx += value;
                Sxx += value * value;
                *p++ = value;
            }
        const double Mx = Sx / (double)n;
        const double sigma = sqrt((Sxx - Sx * Mx) / (double)(n - 1));

        // compute Kullback-Leibler Divergence
        std::sort(x, x + n);
        x[n] = 1;
        if (sigma > 0)
        {
            const double sqrt2 = sqrt(2);
            // normalization factors for truncated distributions
            double NQn = .5 * (erf((x[n] - Mx) / sigma / sqrt2) - erf((x[0] - Mx) / sigma / sqrt2));
            double NQe = exp(-x[0] / Mx) - exp(-x[n] / Mx);
            for (long i = 0, j; i < n; i = j)
            {
                j = i + 1;
                while ((x[j] - x[i]) < .001 && j < n)
                    j++;
                double P = (double)(j - i) / (double)n;
                double Qn = .5 * (erf((x[j] - Mx) / sigma / sqrt2) - erf((x[i] - Mx) / sigma / sqrt2)) / NQn;
                double Qe = (exp(-x[i] / Mx) - exp(-x[j] / Mx)) / NQe;
                KLDn += P * log(P / Qn);
                KLDe += P * log(P / Qe);
            }
        }
    }

    template <class ClientSample>
    void QualifyMeasurement<ClientSample>::serial() noexcept
    {
        qualified = KLDn > this->parameters.kld.Normal1D && KLDe > this->parameters.kld.Exponential1D;
        if (qualified)
        {
            // start pursuit on this measurement vs all the others found so far
            for (int Y : _result->qualified)
                Worker<ClientSample>::work_list.push(
                    new PursueProjection<ClientSample>(this->sample, this->parameters, X, Y));
            Worker<ClientSample>::work_available.notify_all();

            _result->qualified.push_back(X);
            // std::cout << "dimension qualified " << X << std::endl;
        }
        // else
        // std::cout << "dimension disqualified " << X << std::endl;
    }
}