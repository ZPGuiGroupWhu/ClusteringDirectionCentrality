package com.yolo.CDC.java.partitioner.quadtree;

import com.yolo.CDC.java.partitioner.SpatialPartitioner;
import com.yolo.CDC.java.type.GridType;
import com.yolo.CDC.java.partitioner.DedupParams;
import com.yolo.CDC.java.utils.HalfOpenRectangle;
import org.locationtech.jts.geom.Envelope;
import org.locationtech.jts.geom.Geometry;
import org.locationtech.jts.geom.Point;
import scala.Tuple2;

import javax.annotation.Nullable;
import java.util.*;

public class QuadTreePartitioner
        extends SpatialPartitioner
{
    private final StandardQuadTree<? extends Geometry> quadTree;

    public QuadTreePartitioner(StandardQuadTree<? extends Geometry> quadTree)
    {
        super(GridType.QUADTREE, getLeafGrids(quadTree));
        this.quadTree = quadTree;

        // Make sure not to broadcast all the samples used to build the Quad
        // tree to all nodes which are doing partitioning
        this.quadTree.dropElements();
    }

    private static List<Envelope> getLeafGrids(StandardQuadTree<? extends Geometry> quadTree)
    {
        Objects.requireNonNull(quadTree, "quadTree");

        final List<QuadRectangle> zones = quadTree.getLeafZones();
        final List<Envelope> grids = new ArrayList<>();
        for (QuadRectangle zone : zones) {
            grids.add(zone.getEnvelope());
        }

        return grids;
    }

    @Override
    public <T extends Geometry> Iterator<Tuple2<Integer, T>> placeObject(T spatialObject)
            throws Exception
    {
        Objects.requireNonNull(spatialObject, "spatialObject");

        final Envelope envelope = spatialObject.getEnvelopeInternal();

        final List<QuadRectangle> matchedPartitions = quadTree.findZones(new QuadRectangle(envelope));

        final Point point = spatialObject instanceof Point ? (Point) spatialObject : null;

        final Set<Tuple2<Integer, T>> result = new HashSet<>();
        for (QuadRectangle rectangle : matchedPartitions) {
            // For points, make sure to return only one partition
            if (point != null && !(new HalfOpenRectangle(rectangle.getEnvelope())).contains(point)) {
                continue;
            }

            result.add(new Tuple2(rectangle.partitionId, spatialObject));
        }

        return result.iterator();
    }

    @Nullable
    @Override
    public DedupParams getDedupParams()
    {
        return new DedupParams(grids);
    }

    @Override
    public int numPartitions()
    {
        return grids.size();
    }

    @Override
    public boolean equals(Object o)
    {
        if (o == null || !(o instanceof QuadTreePartitioner)) {
            return false;
        }

        final QuadTreePartitioner other = (QuadTreePartitioner) o;
        return other.quadTree.equals(this.quadTree);
    }
}
