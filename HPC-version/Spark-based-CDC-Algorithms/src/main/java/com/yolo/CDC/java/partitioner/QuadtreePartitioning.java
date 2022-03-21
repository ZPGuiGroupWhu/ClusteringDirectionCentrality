package com.yolo.CDC.java.partitioner;

import com.yolo.CDC.java.partitioner.quadtree.QuadRectangle;
import com.yolo.CDC.java.partitioner.quadtree.StandardQuadTree;
import org.locationtech.jts.geom.Envelope;

import java.io.Serializable;
import java.util.List;

public class QuadtreePartitioning
        implements Serializable
{

    /**
     * The Quad-Tree.
     */
    private final StandardQuadTree<Integer> partitionTree;

    /**
     * Instantiates a new Quad-Tree partitioning.
     *
     * @param samples the sample list
     * @param boundary the boundary
     * @param partitions the partitions
     */
    public QuadtreePartitioning(List<Envelope> samples, Envelope boundary, int partitions)
            throws Exception
    {
        this(samples, boundary, partitions, -1);
    }

    public QuadtreePartitioning(List<Envelope> samples, Envelope boundary, final int partitions, int minTreeLevel)
            throws Exception
    {
        // Make sure the tree doesn't get too deep in case of data skew
        int maxLevel = partitions;
        int maxItemsPerNode = samples.size() / partitions;
        partitionTree = new StandardQuadTree(new QuadRectangle(boundary), 0,
                maxItemsPerNode, maxLevel);
        if (minTreeLevel > 0) {
            partitionTree.forceGrowUp(minTreeLevel);
        }

        for (final Envelope sample : samples) {
            partitionTree.insert(new QuadRectangle(sample), 1);
        }

        partitionTree.assignPartitionIds();
    }

    public StandardQuadTree getPartitionTree()
    {
        return this.partitionTree;
    }
}
