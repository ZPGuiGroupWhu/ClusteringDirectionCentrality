package com.yolo.CDC.java.partitioner;

import org.locationtech.jts.geom.Envelope;
import org.locationtech.jts.index.strtree.AbstractNode;
import org.locationtech.jts.index.strtree.Boundable;
import org.locationtech.jts.index.strtree.STRtree;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.List;

// TODO: Auto-generated Javadoc

/**
 * The Class RtreePartitioning.
 */
public class RtreePartitioning
        implements Serializable
{

    /**
     * The grids.
     */
    final List<Envelope> grids = new ArrayList<>();

    /**
     * Instantiates a new rtree partitioning.
     *
     * @param samples the sample list
     * @param partitions the partitions
     * @throws Exception the exception
     */
    public RtreePartitioning(List<Envelope> samples, int partitions)
            throws Exception
    {
        STRtree strtree = new STRtree(samples.size() / partitions);
        for (Envelope sample : samples) {
            strtree.insert(sample, sample);
        }
        List<Envelope> envelopes = findLeafBounds(strtree);
        for (Envelope envelope : envelopes) {
            grids.add(envelope);
        }
    }

    /**
     * Gets the grids.
     *
     * @return the grids
     */
    public List<Envelope> getGrids()
    {

        return this.grids;
    }

    /**
     * This function traverses the boundaries of all leaf nodes.
     * This function should be called after all insertions.
     * @param stRtree
     * @return The list of leaf nodes boundaries
     */
    private List findLeafBounds(STRtree stRtree){
        stRtree.build();
        List boundaries = new ArrayList();
        if (stRtree.isEmpty()) {
            //Assert.isTrue(root.getBounds() == null);
            //If the root is empty, we stop traversing. This should not happen.
            return boundaries;
        }
        findLeafBounds(stRtree.getRoot(), boundaries);
        return boundaries;
    }

    private void findLeafBounds(AbstractNode node, List boundaries) {
        List childBoundables = node.getChildBoundables();
        boolean flagLeafnode=true;
        for (Object boundable : childBoundables) {
            Boundable childBoundable = (Boundable) boundable;
            if (childBoundable instanceof AbstractNode) {
                //We find this is not a leaf node.
                flagLeafnode = false;
                break;
            }
        }
        if(flagLeafnode)
        {
            boundaries.add(node.getBounds());
        }
        else
        {
            for (Object boundable : childBoundables) {
                Boundable childBoundable = (Boundable) boundable;
                if (childBoundable instanceof AbstractNode) {
                    findLeafBounds((AbstractNode) childBoundable, boundaries);
                }
            }
        }
    }
}
