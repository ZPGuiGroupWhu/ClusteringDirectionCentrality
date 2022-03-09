#ifndef _EPP_MODAL_H
#define _EPP_MODAL_H 1

#include <algorithm>
#include <iostream>

#include "constants.h"
#include "boundary.h"

namespace EPP
{
	typedef unsigned int booleans;
	const int max_booleans = sizeof(booleans) * 8; // max clusters or edges in dual graph
	typedef ColoredGraph<booleans> DualGraph;

	typedef ColoredBoundary<short, short, booleans> ClusterBoundary;
	typedef ColoredMap<short, short> ClusterMap;
	typedef ColoredEdge<short, short> ClusterEdge;
	typedef std::vector<ColoredEdge<short, bool>> ClusterSeparatrix;
	typedef ColoredPoint<short> ClusterPoint;

	class ModalClustering
	{
		unsigned int clusters;
		int bad_random = 0; // so it's deterministic

		// everything is inline because we want the compiler
		// to pare down the inner loop as much as possible

		// accessors with +/-1 slop to avoid bounds checks
		short _cluster[(N + 3) * (N + 3)];
		inline short &cluster(const short int &i, const short int &j) noexcept
		{
			return _cluster[(i + 1) * (N + 3) + (j + 1)];
		};

		bool _contiguous[(N + 3) * (N + 3)];
		inline bool &contiguous(const short int &i, const short int &j) noexcept
		{
			return _contiguous[(i + 1) * (N + 3) + (j + 1)];
		};

		inline void visit(
			int &result,
			const short int &i,
			const short int &j) noexcept
		{
			// if this point has been assigned to a cluster
			if (cluster(i, j) > 0)
				// and our starting point is unassigned
				if (result < 0)
					// assign it to our cluster
					result = cluster(i, j);
				else if (result != cluster(i, j))
					// if we found something different it's a boundary point
					result = 0;
		};

		struct grid_vertex
		{
			float f;
			short i, j;

			const bool operator<(
				const grid_vertex &other) const noexcept
			{ // smaller f is better so sense inverted
				return f > other.f;
			};
		} vertex[(N + 1) * (N + 1)], *pv;

	public:
		int findClusters(const float *density, int pass, Parameters parameters) noexcept;

		void getBoundary(const float *density, ClusterBoundary &boundary) noexcept;

		ModalClustering() noexcept;
		~ModalClustering();
	};

	ModalClustering::ModalClustering() noexcept = default;

	ModalClustering::~ModalClustering() = default;

	int ModalClustering::findClusters(const float *density, int pass, Parameters parameters) noexcept
	{
		clusters = 0;
		// contiguous set starts empty
		std::fill(_contiguous, _contiguous + (N + 3) * (N + 3), false);
		// points start undefined
		std::fill(_cluster, _cluster + (N + 3) * (N + 3), -1);

		// collect all the grid points
		pv = vertex;
		for (short i = 0; i <= N; i++)
			for (short j = 0; j <= N; j++)
			{
				pv->f = density[i + (N + 1) * j];
				pv->i = i;
				pv->j = j;
				pv++;
			}

		// get all comparisons out of the way early and efficiently
		std::sort(vertex, vertex + (N + 1) * (N + 1));

		// choose the threshold
		int A = (int)(pi * 4 * parameters.W * parameters.W * N * N * pass * pass + .5); // spot radius 2*W*pass
		if (A < 8)
			A = 8;
		double threshold = parameters.sigma * parameters.sigma * 4 * N * N;
		double count = 0;
		int i = (N + 1) * (N + 1);
		for (int a = 0; a < A; a++)
			count += vertex[--i].f;
		int j = (N + 1) * (N + 1);
		while (count < threshold && i > 0) // count is less than sigma standard deviations away from zero
		{
			count += vertex[--i].f;
			count -= vertex[--j].f;
		}
		count /= 4 * N * N; // approximate with filter unnormalized
		if (i == 0)
			return 0;

		// find all the significant clusters
		for (pv = vertex; pv < vertex + i; pv++)
		{
			// visit the neighbors to see what clusters they belong to
			int result = -1;
			visit(result, pv->i + 1, pv->j);
			visit(result, pv->i - 1, pv->j);
			visit(result, pv->i, pv->j + 1);
			visit(result, pv->i, pv->j - 1);
			// if we didn't find one this is a new mode
			if (result < 0)
				result = ++clusters;
			if (clusters > parameters.max_clusters) // no need to waste any more time
				return clusters;

			cluster(pv->i, pv->j) = result;
			// if this point belongs to a cluster mark the neighbors as being contiguous
			if (result > 0)
			{
				contiguous(pv->i - 1, pv->j) = true;
				contiguous(pv->i + 1, pv->j) = true;
				contiguous(pv->i, pv->j - 1) = true;
				contiguous(pv->i, pv->j + 1) = true;
				// the diagonals are sqrt(2) long so we take them
				// with probability approximately 1/sqrt(2) to compensate
				int two_bits = bad_random++ & 3;
				if (two_bits != 0)
					contiguous(pv->i + 1, pv->j + 1);
				if (two_bits != 1)
					contiguous(pv->i + 1, pv->j - 1);
				if (two_bits != 2)
					contiguous(pv->i - 1, pv->j + 1);
				if (two_bits != 3)
					contiguous(pv->i - 1, pv->j - 1);
			}
		}
		// postpone filling it out in case we fail the KLD test and it's not needed

		return clusters;
	}

	void ModalClustering::getBoundary(const float *density, ClusterBoundary &bounds) noexcept
	{
		// we don't trust these small densities
		// so we switch to a border grow operation
		while (pv < vertex + (N + 1) * (N + 1))
		{ // find the current border points
			auto tranche = std::partition(pv, vertex + (N + 1) * (N + 1),
										  [this](const grid_vertex &pw)
										  { return contiguous(pw.i, pw.j); });
			if (pv==tranche)
			    pv++;
			else
			for (; pv < tranche; pv++)
			{
				// visit the neighbors and then allocate each point
				int result = -1;
				visit(result, pv->i - 1, pv->j);
				visit(result, pv->i + 1, pv->j);
				visit(result, pv->i, pv->j - 1);
				visit(result, pv->i, pv->j + 1);
				if (result < 0)
				{
					visit(result, pv->i - 1, pv->j - 1);
					visit(result, pv->i + 1, pv->j - 1);
					visit(result, pv->i - 1, pv->j + 1);
					visit(result, pv->i + 1, pv->j + 1);
				}
				if (result < 0) // bad_random bit us, fake a border point
					result = 0;
				cluster(pv->i, pv->j) = result;

				contiguous(pv->i - 1, pv->j) = true;
				contiguous(pv->i + 1, pv->j) = true;
				contiguous(pv->i, pv->j - 1) = true;
				contiguous(pv->i, pv->j + 1) = true;
				int two_bits = bad_random++ & 3;
				if (two_bits != 0)
					contiguous(pv->i + 1, pv->j + 1);
				if (two_bits != 1)
					contiguous(pv->i + 1, pv->j - 1);
				if (two_bits != 2)
					contiguous(pv->i - 1, pv->j + 1);
				if (two_bits != 3)
					contiguous(pv->i - 1, pv->j - 1);
			}

		}

		// now process the boundary points into segments and vertices
		short int neighbor[8];
		bounds.clear();
		for (pv = vertex; pv < vertex + (N + 1) * (N + 1); pv++)
			// if this is a boundary point
			if (cluster(pv->i, pv->j) == 0)
			{
				// traverse the neighborhood clockwise
				neighbor[0] = cluster(pv->i, pv->j + 1);
				neighbor[1] = cluster(pv->i + 1, pv->j + 1);
				neighbor[2] = cluster(pv->i + 1, pv->j);
				neighbor[3] = cluster(pv->i + 1, pv->j - 1);
				neighbor[4] = cluster(pv->i, pv->j - 1);
				neighbor[5] = cluster(pv->i - 1, pv->j - 1);
				neighbor[6] = cluster(pv->i - 1, pv->j);
				neighbor[7] = cluster(pv->i - 1, pv->j + 1);
				int rank = 0;
				bool on_edge = false;
				for (int i = 0; i < 8; i++)
				{
					if (neighbor[i] > 0)
						continue;
					if (neighbor[i] < 0)
					{
						on_edge = true;
						continue;
					}
					// found a border point, look to the left
					short left = neighbor[(i - 1) & 7];
					if (!(left > 0))
						continue;
					// found the cluster to the left
					int j = i;
					short right = neighbor[++j & 7];
					while (right == 0)
						right = neighbor[++j & 7];
					if (right < 0) // exterior surround point
						continue;
					if (left == right) // spurious edge
						continue;
					// found the cluster to the right
					assert(j - i < 6);
					bool square = false;
					switch (j - i)
					{
					case 1: // if there's just one boundary point, we're done
						break;
					case 2:		   // if there's two, take the closer,  i.e.,
						if (i & 1) // the one that's square on, not diagonal
							++i;
						break;
					case 3:
						if (i & 1) // if there are three in a T take the closest, i.e., middle one
						{
							++i;
							break;
						}
						// otherwise we have a square of border points where
						// it is impossible to consistently define the color
					case 4: // of the interior
					case 5:
						// it's possible to have another border point before
						// and/or after the square as well
						square = true;
						break;
					}
					float weight, center_weight = density[pv->i + (N + 1) * pv->j];
					if (!square)
					{
						switch (i & 7)
						{
						case 0:
							weight = center_weight + density[pv->i + (N + 1) * pv->j + (N + 1)];
							bounds.addSegment(ColoredVertical, pv->i, pv->j, right, left, weight);
							break;
						case 1:
							weight = center_weight + density[pv->i + 1 + (N + 1) * pv->j + (N + 1)];
							bounds.addSegment(ColoredRight, pv->i, pv->j, right, left, weight * sqrt2);
							break;
						case 2:
							weight = center_weight + density[pv->i + 1 + (N + 1) * pv->j];
							bounds.addSegment(ColoredHorizontal, pv->i, pv->j, right, left, weight);
							break;
						case 3:
							weight = center_weight + density[pv->i + 1 + (N + 1) * pv->j - (N + 1)];
							bounds.addSegment(ColoredLeft, pv->i, pv->j - 1, left, right, weight * sqrt2);
							break;
						default:
							// we are only responsible for the half plane head > tail
							break;
						}
						// but we need to look at all of them to see if we have a vertex
						++rank;
					}
					else
					{ // for the square the bounding segments will have 0 (border) as one of their colors
						switch (i & 7)
						{
						case 7:
						case 0:
							weight = center_weight + density[pv->i + (N + 1) * pv->j + (N + 1)];
							bounds.addSegment(ColoredVertical, pv->i, pv->j, 0, left, weight);
							weight = center_weight + density[pv->i + 1 + (N + 1) * pv->j];
							bounds.addSegment(ColoredHorizontal, pv->i, pv->j, right, 0, weight);
							break;

						case 1:
						case 2:
							weight = center_weight + density[pv->i + 1 + (N + 1) * pv->j];
							bounds.addSegment(ColoredHorizontal, pv->i, pv->j, 0, left, weight);
							break;

						case 5:
						case 6:
							weight = center_weight + density[pv->i + (N + 1) * pv->j + (N + 1)];
							bounds.addSegment(ColoredVertical, pv->i, pv->j, right, 0, weight);
							break;

						case 3:
						case 4:
							break;
						}
						// always accounts for two edges
						rank += 2;
					}
				}
				if (rank != 2 || on_edge)
				{
					bounds.addVertex(ColoredPoint<short>(pv->i, pv->j));
				}
			}
		bounds.setColorful(clusters + 1);
	}
}
#endif /* _EPP_MODAL_H */