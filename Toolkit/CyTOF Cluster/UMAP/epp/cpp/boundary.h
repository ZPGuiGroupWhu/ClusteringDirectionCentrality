#ifndef _EPP_BOUNDARY_H
#define _EPP_BOUNDARY_H 1

#include <vector>
#include <algorithm>
#include <memory>
#include <cassert>

namespace EPP
{
    /*
     * Utilities for Colored Maps
     * 
     * The map is composed of directed edges that are color labeled on each side.
     * Primary design goal is speed of the lookup function. Secondary but still
     * important, speed of pulling out a point list of the graph edges. Includes
     * support for weighing the various graph edges for EPP
     */

    // four orientations of the edge within a grid square
    // order is important in colorAt() and initializing index and edge_color
    enum ColoredSlope
    {
        ColoredHorizontal,
        ColoredRight,
        ColoredLeft,
        ColoredVertical
    };

    // points are given a raster order so we can search them quickly
    template <typename coordinate>
    class ColoredPoint
    {
    public:
        coordinate i;
        coordinate j;

        inline bool operator<(const ColoredPoint<coordinate> &cp) const noexcept
        {
            if (i < cp.i)
                return true;
            if (i > cp.i)
                return false;
            return j < cp.j;
        };

        inline bool operator>(const ColoredPoint<coordinate> &cp) const noexcept
        {
            if (i > cp.i)
                return true;
            if (i < cp.i)
                return false;
            return j > cp.j;
        };

        inline bool operator==(const ColoredPoint<coordinate> &cp) const noexcept
        {
            return i == cp.i && j == cp.j;
        };

        inline bool adjacent(const ColoredPoint<coordinate> cp) const noexcept
        {
            return abs(i - cp.i) <= 1 && abs(j - cp.j) <= 1;
        };

        inline ColoredPoint<coordinate>(
            coordinate i,
            coordinate j) noexcept
            : i(i), j(j){};

        inline ColoredPoint<coordinate>() = default;
    };

    /**
     * a segment is a directed edge with the two sides labeled by color.
     * each segment represents one grid square. for efficiency of lookup 
     * always stored by the lower left coordinate of the square.
     */
    template <typename coordinate, typename color>
    class ColoredSegment
    {
    public:
        float weight;
        coordinate i;
        coordinate j;
        color clockwise;
        color widdershins;
        ColoredSlope slope;

        // to save space, compute the head and tail
        inline ColoredPoint<coordinate> tail() const noexcept
        {
            switch (slope)
            {
            case ColoredLeft:
                return ColoredPoint<coordinate>(i + 1, j);
            case ColoredRight:
                return ColoredPoint<coordinate>(i, j);
            case ColoredHorizontal:
                return ColoredPoint<coordinate>(i, j);
            case ColoredVertical:
                return ColoredPoint<coordinate>(i, j);
            }
            assert(("shouldn't happen", false));
            return ColoredPoint<coordinate>(0, 0);
        }

        inline ColoredPoint<coordinate> head() const noexcept
        {
            switch (slope)
            {
            case ColoredLeft:
                return ColoredPoint<coordinate>(i, j + 1);
            case ColoredRight:
                return ColoredPoint<coordinate>(i + 1, j + 1);
            case ColoredHorizontal:
                return ColoredPoint<coordinate>(i + 1, j);
            case ColoredVertical:
                return ColoredPoint<coordinate>(i, j + 1);
            }
            assert(("shouldn't happen", false));
            return ColoredPoint<coordinate>(0, 0);
        }

        // the head of one edge connects to the tail of the other
        bool adjacent(ColoredSegment<coordinate, color> ce) const noexcept
        {
            return head() == ce.head() || head() == ce.tail() || tail() == ce.tail() || tail() == ce.head();
        };

        // the point is the head or tail of the edge
        bool adjacent(ColoredPoint<coordinate> cp) const noexcept
        {
            return head() == cp || tail() == cp;
        };

        // segments are sorted for fast access
        inline bool operator<(const ColoredSegment &cs) const noexcept
        {
            if (i < cs.i)
                return true;
            if (i > cs.i)
                return false;
            if (j < cs.j)
                return true;
            if (j > cs.j)
                return false;
            return slope < cs.slope;
        };

        inline bool operator>(const ColoredSegment &cs) const noexcept
        {
            if (i > cs.i)
                return true;
            if (i < cs.i)
                return false;
            if (j > cs.j)
                return true;
            if (j < cs.j)
                return false;
            return slope > cs.slope;
        };

        ColoredSegment<coordinate, color>(
            ColoredSlope slope,
            coordinate i,
            coordinate j,
            color clockwise,
            color widdershins,
            float weight) noexcept
            : slope(slope), i(i), j(j), clockwise(clockwise), widdershins(widdershins),
              weight(weight > 0 ? weight : std::numeric_limits<float>::min()){};

        ColoredSegment<coordinate, color>(
            ColoredSlope slope,
            coordinate i,
            coordinate j,
            color clockwise,
            color widdershins) noexcept
            : slope(slope), i(i), j(j), clockwise(clockwise), widdershins(widdershins),
              weight(std::numeric_limits<float>::min()){};

        ColoredSegment<coordinate, color>() = default;
    };

    // an ordered list of pointers to adjacent segments
    template <typename coordinate, typename color>
    class ColoredChain : public std::vector<ColoredSegment<coordinate, color> *>
    {
    public:
        // figure out the head and tail of the chain
        ColoredPoint<coordinate> tail() const noexcept
        {
            if (this->size() == 1)
                return this->front()->tail();
            ColoredSegment<coordinate, color> *first = this->at(0);
            ColoredSegment<coordinate, color> *second = this->at(1);
            if (first->head() == second->tail() || first->head() == second->head())
                return first->tail();
            else
                return first->head();
        };

        ColoredPoint<coordinate> head() const noexcept
        {
            if (this->size() == 1)
                return this->back()->head();
            ColoredSegment<coordinate, color> *ultimate = this->at(this->size() - 1);
            ColoredSegment<coordinate, color> *penultimate = this->at(this->size() - 2);
            if (penultimate->tail() == ultimate->tail() || penultimate->head() == ultimate->tail())
                return ultimate->head();
            else
                return ultimate->tail();
        };
    };

    /**
     * A directed and labeled edge longer than one grid square
     * always equivalent to a segment chain though
     */
    template <typename coordinate, typename color>
    class ColoredEdge
    {
    public:
        std::vector<ColoredPoint<coordinate>> points;
        float weight;
        color clockwise;
        color widdershins;

        ColoredEdge(
            std::vector<ColoredPoint<coordinate>> points,
            color clockwise,
            color widdershins,
            double weight) noexcept
            : points(points), clockwise(clockwise), widdershins(widdershins), weight((float)weight){};

        ColoredEdge(
            std::vector<ColoredPoint<coordinate>> points,
            color clockwise,
            color widdershins) noexcept
            : points(points), clockwise(clockwise), widdershins(widdershins), weight(0){};

        ColoredEdge(const ColoredEdge &that) noexcept
        {
            this->points = that.points;
            this->clockwise = that.clockwise;
            this->widdershins = that.widdershins;
            this->weight = that.weight;
        }

        ColoredEdge() = default;
        ;

        ~ColoredEdge() = default;
        ;

        ColoredEdge &operator=(const ColoredEdge &that) noexcept
        {
            this->points = that.points;
            this->clockwise = that.clockwise;
            this->widdershins = that.widdershins;
            this->weight = that.weight;
            return *this;
        }

        ColoredEdge &operator=(ColoredEdge &&that) noexcept
        {
            if (this != that)
            {
                this->points = that.points;
                this->clockwise = that.clockwise;
                this->widdershins = that.widdershins;
                this->weight = that.weight;
            }
            return *this;
        }
    };

    // utility class for rapid lookup of color by map position
    template <typename coordinate, typename color>
    class ColoredMap
    {
        int segments;
        ColoredSegment<coordinate, color> *boundary;
        ColoredSegment<coordinate, color> *index[N];
        color edge_color[N];

    public:
        // this is the money shot, the innermost loop
        // everything is designed to make this fast
        inline color colorAt(
            const double x,
            const double y) const noexcept
        {
            int i = (int)(x * N);
            int j = (int)(y * N);
            double dx = x * N - i;
            double dy = y * N - j;
            // jump to the first element for this i
            ColoredSegment<coordinate, color> *segment = index[i];
            color result = edge_color[i];
            for (; segment < boundary + segments; segment++)
            {
                if (segment->i > i)
                    break; // definitely not here
                if (segment->j < j)
                    // the point is somewhere above this segment
                    switch (segment->slope)
                    {
                    case ColoredLeft:
                        result = segment->clockwise;
                        break;
                    case ColoredRight:
                    case ColoredHorizontal:
                        result = segment->widdershins;
                        break;
                    case ColoredVertical:
                    	break;
                    }
                else if (segment->j == j)
                    switch (segment->slope)
                    // we've found it so dispatch
                    {
                    case ColoredLeft:
                        if (dy > 1 - dx)
                            result = segment->clockwise;
                        else
                            result = segment->widdershins;
                        return result;
                    case ColoredRight:
                        if (dy <= dx)
                            result = segment->clockwise;
                        else
                            result = segment->widdershins;
                        return result;
                    case ColoredHorizontal:
                        result = segment->widdershins;
                        return result;
                    case ColoredVertical:
                        return result;
                    }
                else
                    break; // definitely not here
                // might be another one so go around again
            }
            return result;
        }

        explicit ColoredMap(std::vector<ColoredSegment<coordinate, color>> bounds) noexcept
        {
            segments = bounds.size();
            boundary = new ColoredSegment<coordinate, color>[segments];
            std::copy(bounds.begin(), bounds.end(), boundary);
            ColoredSegment<coordinate, color> *segment = boundary;
            color outside;
            if (segment->j == 0) // figure out the color < Point(0,0);
            {
                if (segment->slope == ColoredHorizontal)
                    outside = segment->clockwise;
                else
                    outside = segment->widdershins;
            }
            else
            {
                if (segment->slope == ColoredLeft)
                    outside = segment->widdershins;
                else
                    outside = segment->clockwise;
            }
            for (int i = 0; i < N; ++i) // for each i value find the color < Point(i,0)
            {                           // and the first segment with that coordinate if any
                if (segment < boundary + segments && segment->i == i)
                {
                    if (segment->j == 0)
                    {
                        outside = segment->clockwise; // boundary from here on is clockwise
                    }
                    else
                    {
                        if (segment->slope == ColoredLeft)
                            outside = segment->widdershins;
                        else
                            outside = segment->clockwise;
                    }
                    index[i] = segment++; // remember the first segment that applies to this i for later
                }
                else
                    index[i] = boundary + segments; // if there are no segments for this i point to the boundary end
                edge_color[i] = outside;

                for (; segment < boundary + segments; segment++)    // skip to next i
                    if (segment->i != i)
                        break;
            }
        };

        ~ColoredMap()
        {
            delete[] boundary;
        }
    };

    /*
   The dual graph exchanges vertices and faces while inverting the meaning of edges. The initial dual points
   are the original clusters. Not clear the dual graph is planar or what the dual faces mean. Each original point 
   is connected to some others by an edge. We can simplify the graph by removing one edge and merging two clusters.
   Lather rinse repeat. Eventually we get to a simple case of two populations and one edge. There's some gotcha's 
   if things get multiply connected but basically all of these operations can be efficiently implemented as 
   boolean vectors of appropriate size.
    */
    template <typename booleans>
    class ColoredGraph
    {

    public:
        struct DualEdge
        {
        public:             // bits are
            booleans left;  // clusters in the left set
            booleans right; // clusters in the right set
            booleans edge;  // edges in the boundary between

            DualEdge(
                booleans left,
                booleans right,
                booleans edge) noexcept
            {
                // order is well defined although meaningless
                // except that it makes comparisons faster
                // since the edges are not directed
                if (left < right)
                {
                    this->left = left;
                    this->right = right;
                }
                else
                {
                    this->left = right;
                    this->right = left;
                }
                this->edge = edge;
            };

            inline bool same_as(const DualEdge &de) const noexcept
            {
                return left == de.left && right == de.right;
            }

            DualEdge() = default;
        };

        std::vector<booleans> nodes;
        std::vector<DualEdge> duals;
        booleans removed;

        ColoredGraph() = default;

        // implement move semantics
        ColoredGraph(std::vector<booleans> &nodes,
                     std::vector<DualEdge> &duals,
                     booleans removed) noexcept
            : nodes(nodes), duals(duals), removed(removed){};

        ColoredGraph(ColoredGraph &&other) noexcept
            : nodes(other.nodes), duals(other.duals), removed(other.removed){};

        ColoredGraph &operator=(ColoredGraph &&other) noexcept
        {
            if (this != other)
            {
                this->nodes = other.nodes;
                this->duals = other.duals;
                this->removed = other.removed;
            }
            return *this;
        }

        // copy constructor
        ColoredGraph(const ColoredGraph &other) noexcept
            : nodes(other.nodes), duals(other.duals), removed(other.removed){};

        inline bool isSimple() const noexcept
        {
            return duals.size() == 1;
        }

        inline booleans left() const noexcept
        {
            return duals[0].left;
        }

        inline booleans right() const noexcept
        {
            return duals[0].right;
        }

        inline booleans edge() const noexcept
        {
            return duals[0].edge;
        }

        std::vector<ColoredGraph> simplify() const noexcept
        {
            std::vector<booleans> nodes;
            nodes.reserve(this->nodes.size() - 1);
            std::vector<DualEdge> duals;
            duals.reserve(this->duals.size() - 1);
            std::vector<ColoredGraph> graphs;
            graphs.reserve(this->duals.size());

            for (unsigned int i = 0; i < this->duals.size(); i++)
            {
                DualEdge remove = this->duals[i];
                // we don't care in what order the edges are removed as long as
                // some order is tried for every instance. This will not eliminate
                // all duplicates because the details of the graph may only allow a
                // partial ordering but it drastically reduces the combinitoric explosion
                if (remove.edge < this->removed)
                    continue; // someone else will handle this
                nodes.clear();
                duals.clear();
                // construct a simpler graph by removing the indicated edge
                // since left and right are disjoint this is pretty easy for the nodes
                booleans new_node = remove.left | remove.right; // the merged result
                for (auto np : this->nodes)
                    if (!(np & new_node)) // skip the two we're merging
                        nodes.push_back(np);
                nodes.push_back(new_node); // add the merged node

                // for the edges we have to see if two or more edges collapsed into one
                for (unsigned int j = 0; j < this->duals.size(); j++)
                {
                    // skip the one we're removing
                    if (i == j)
                        continue;
                    DualEdge de = this->duals[j];
                    unsigned int k;
                    // this is a rapid test for the interesting cases. because of the disjunction of the
                    // nodes this is equivalent to (de.left == remove.left || de.left == remove.right)
                    if (de.left & new_node)
                    { // look to see if this edge already exists
                        if (!(de.right & new_node))
                        {
                            DualEdge nde{de.right, new_node, de.edge};
                            for (k = 0; k < duals.size(); ++k)
                                if (nde.same_as(duals[k]))
                                {
                                    duals[k].edge |= nde.edge; // found it OR it in
                                    break;
                                }
                            if (k == duals.size())
                                duals.push_back(nde); // new edge
                        }
                    }
                    else if (de.right & new_node) // same for the right
                    {
                        DualEdge nde{de.left, new_node, de.edge};
                        for (k = 0; k < duals.size(); ++k)
                            if (nde.same_as(duals[k]))
                            {
                                duals[k].edge |= nde.edge;
                                break;
                            }
                        if (k == duals.size())
                            duals.push_back(nde);
                    }
                    else
                    { // nothing to see here copy it forward
                        duals.push_back(de);
                    }
                }
                graphs.push_back(ColoredGraph(nodes, duals, this->removed | remove.edge));
            }
            return graphs;
        };
    };

    template <typename coordinate, typename color, typename booleans>
    class ColoredBoundary
    {
        std::vector<ColoredSegment<coordinate, color>> boundary;
        std::vector<ColoredEdge<coordinate, color>> edges;
        std::vector<ColoredPoint<coordinate>> vertices;
        friend class ColoredMap<coordinate, color>;
        color colorful;

    public:
        void setColorful(const int colors) noexcept
        {
            this->colorful = colors;
            std::sort(vertices.begin(), vertices.end());
            std::sort(boundary.begin(), boundary.end());
        }

        color getColorful() const noexcept
        {
            return colorful;
        };

        inline void addSegment(ColoredSegment<coordinate, color> segment)
        {
            boundary.push_back(segment);
        };

        void addSegment(
            ColoredSlope slope,
            int i,
            int j,
            color clockwise,
            color widdershins,
            double weight) noexcept
        {
            addSegment(ColoredSegment<coordinate, color>(slope, (coordinate)i, (coordinate)j, clockwise, widdershins, (float)weight));
        }

        void addSegment(
            ColoredSlope slope,
            int i,
            int j,
            color clockwise,
            color widdershins) noexcept
        {
            addSegment(ColoredSegment<coordinate, color>(slope, (coordinate)i, (coordinate)j, clockwise, widdershins, 0));
        }

        void addSegment(
            ColoredPoint<coordinate> tail,
            ColoredPoint<coordinate> head,
            color clockwise,
            color widdershins,
            float weight) noexcept
        {
            assert(head.adjacent(tail));

            if (head < tail)
            {
                std::swap(tail, head);
                std::swap(clockwise, widdershins);
            }

            if (tail.i == head.i)
            {
                addSegment(ColoredSegment<coordinate, color>(ColoredVertical, tail.i, tail.j, clockwise, widdershins, weight));
                return;
            }
            switch (head.j - tail.j)
            {
            case 1:
                addSegment(ColoredSegment<coordinate, color>(ColoredRight, tail.i, tail.j, clockwise, widdershins, weight));
                return;

            case 0:
                addSegment(ColoredSegment<coordinate, color>(ColoredHorizontal, tail.i, tail.j, clockwise, widdershins, weight));
                return;

            case -1:
                addSegment(ColoredSegment<coordinate, color>(ColoredLeft, tail.i, head.j, widdershins, clockwise, weight));
                return;
            }
        };

        void addSegment(
            ColoredPoint<coordinate> tail,
            ColoredPoint<coordinate> head,
            color clockwise,
            color widdershins,
            double weight) noexcept
        {
            addSegment(tail, head, clockwise, widdershins, (float)weight);
        };

        void addSegment(
            ColoredPoint<coordinate> tail,
            ColoredPoint<coordinate> head,
            color clockwise,
            color widdershins) noexcept
        {
            addSegment(tail, head, clockwise, widdershins, 0);
        };

        void addVertex(ColoredPoint<coordinate> vertex) noexcept
        {
            vertices.push_back(vertex);
        };

        std::vector<ColoredPoint<coordinate>> &getVertices() const noexcept
        {
            return vertices;
        }

        bool isVertex(ColoredPoint<coordinate> vertex) const noexcept
        {
            return std::binary_search(vertices.begin(), vertices.end(), vertex);
        };

        void addEdge(ColoredEdge<coordinate, color> &edge) noexcept
        {
            assert(edge.points.size() > 1);
            auto point = edge.points.begin();
            ColoredPoint<coordinate> head, tail = *point++;
            double weight = edge.weight / (edge.points.size() - 1);
            while (point < edge.points.end())
            {
                head = *point++;
                addSegment(tail, head, edge.clockwise, edge.widdershins, weight);
                tail = head;
            }
            edges.push_back(edge);
        };

        void addEdge(std::vector<ColoredPoint<coordinate>> points, color clockwise, color widdershins, double weight) noexcept
        {
            ColoredEdge<coordinate, color> nce(points, clockwise, widdershins, weight);
            addEdge(nce);
        };

        void addEdge(std::vector<ColoredPoint<coordinate>> points, color clockwise, color widdershins) noexcept
        {
            addEdge(points, clockwise, widdershins, 0.0);
        };

        void addEdge(ColoredChain<coordinate, color> &chain) noexcept
        {
            std::vector<ColoredPoint<coordinate>> points;
            points.reserve(chain.size() + 1);
            ColoredSegment<coordinate, color> *segment = chain.front();

            color clockwise = segment->clockwise;
            color widdershins = segment->widdershins;
            double weight = 0;

            ColoredPoint<coordinate> point = chain.tail();
            if (segment->head() == point)
                std::swap(clockwise, widdershins);
            points.push_back(point);
            for (auto csp = chain.begin(); csp < chain.end(); ++csp)
            {
                segment = *csp;
                if (point == segment->tail())
                {
                    assert(clockwise == segment->clockwise && widdershins == segment->widdershins);
                    point = segment->head();
                }
                else
                {
                    assert(clockwise == segment->widdershins && widdershins == segment->clockwise);
                    point = segment->tail();
                }
                weight += segment->weight;
                points.push_back(point);
            }
            ColoredEdge<coordinate, color> edge(points, clockwise, widdershins, weight);

            edges.push_back(edge);
        };

        std::vector<bool> *done;
        // find next segment adjacent to a point
        ColoredSegment<coordinate, color> *find_next_segment(
            ColoredPoint<coordinate> point) noexcept
        {
            // we know the next adjacent segment can't be far away
            ColoredSegment<coordinate, color> low, high;
            low.i = point.i - 1;
            low.j = point.j - 1;
            low.slope = ColoredHorizontal;
            high.i = point.i + 1;
            high.j = point.j + 2; // strict upper bound
            high.slope = ColoredHorizontal;
            // so it's contained in a small interval
            // that we can find quickly since they are sorted
            auto lower = std::lower_bound(boundary.begin(), boundary.end(), low);
            auto upper = std::upper_bound(lower, boundary.end(), high);
            // and then we use brute force
            for (auto cp = lower; cp != upper; ++cp)
            {
                ColoredSegment<coordinate, color> *peek = &(*cp);
                if (!(*done)[cp - boundary.begin()])
                {
                    ColoredSegment<coordinate, color> *candidate = &(*cp);
                    if (!candidate->adjacent(point))
                        continue;
                    (*done)[cp - boundary.begin()] = true;
                    return candidate;
                }
            }
            return nullptr;
        }

        // find any segment we haven't considered yet
        ColoredSegment<coordinate, color> *find_next_segment() noexcept
        {
            for (auto csp = boundary.begin(); csp != boundary.end(); ++csp)
                if (!(*done)[csp - boundary.begin()])
                {
                    ColoredSegment<coordinate, color> *candidate = &(*csp);
                    (*done)[csp - boundary.begin()] = true;
                    return candidate;
                }
            return nullptr;
        }

        // this is the other hard problem but uses
        // much less total time than the lookup
        std::vector<ColoredEdge<coordinate, color>> &getEdges() noexcept
        {
            done = new std::vector<bool>(boundary.size(), false);
            edges.clear();

            ColoredChain<coordinate, color> chain;
            ColoredSegment<coordinate, color> *segment;

            // look for open edges starting and ending at a vertex
            for (auto vp = vertices.begin(); vp < vertices.end();)
            {
                ColoredPoint<coordinate> vertex = *vp;
                ColoredSegment<coordinate, color> *segment = find_next_segment(vertex);
                if (!segment)
                {
                    vp++;
                    continue;
                }
                chain.clear();
                chain.push_back(segment);
                ColoredPoint<coordinate> point;
                if (segment->tail() == vertex)
                    point = segment->head();
                else
                    point = segment->tail();
                while (!isVertex(point))
                {
                    segment = find_next_segment(point);
                    if (segment == nullptr)
                        segment = find_next_segment(point);
                    if (segment == nullptr)
                        break;
                    chain.push_back(segment);
                    if (segment->tail() == point)
                        point = segment->head();
                    else
                        point = segment->tail();
                }
                addEdge(chain);
            }

            // now look for closed edges
            while ((segment = find_next_segment()))
            {
                chain.clear();
                chain.push_back(segment);
                ColoredPoint<coordinate> tail = segment->tail();
                ColoredPoint<coordinate> head = segment->head();
                while ((segment = find_next_segment(head)))
                {
                    chain.push_back(segment);
                    head = chain.head();
                    if (head == tail)
                        break;
                }
                assert(head == tail);
                addEdge(chain);
            }

            delete done;
            return edges;
        }

        std::unique_ptr<ColoredMap<coordinate, color>> getMap() noexcept
        {
            return std::unique_ptr<ColoredMap<coordinate, color>>(new ColoredMap<coordinate, color>(boundary));
        }

        std::unique_ptr<ColoredGraph<booleans>> getDualGraph() noexcept
        {
            std::vector<booleans> nodes(colorful - 1);
            std::vector<typename ColoredGraph<booleans>::DualEdge> duals;
            duals.reserve(edges.size());
            for (int i = 1; i < colorful; i++)
            {
                nodes[i - 1] = 1 << (i - 1);
            }
            for (unsigned int i = 0; i < edges.size(); i++)
            {
                typename ColoredGraph<booleans>::DualEdge dual(1 << (edges[i].widdershins - 1), 1 << (edges[i].clockwise - 1), 1 << i);
                unsigned int k;
                for (k = 0; k < duals.size(); ++k)
                    if (dual.same_as(duals[k]))
                    {
                        duals[k].edge |= dual.edge; // found it OR it in
                        break;
                    }
                if (k == duals.size())
                    duals.push_back(dual); // new edge
            }

            ColoredGraph<booleans> *graph = new ColoredGraph<booleans>(nodes, duals, 0);
            return std::unique_ptr<ColoredGraph<booleans>>(graph);
        }

        void clear() noexcept
        {
            boundary.clear();
            edges.clear();
            vertices.clear();
            colorful = (color)0;
        };

        ColoredBoundary() = default;
        ~ColoredBoundary() = default;
    };
}
#endif /* _EPP_BOUNDARY_H */