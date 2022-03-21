package com.yolo.CDC.java.partitioner;

import com.yolo.CDC.java.type.GridType;
import com.yolo.CDC.java.partitioner.DedupParams;
import com.yolo.CDC.java.utils.HalfOpenRectangle;
import org.locationtech.jts.geom.Envelope;
import org.locationtech.jts.geom.Geometry;
import org.locationtech.jts.geom.Point;
import scala.Tuple2;

import javax.annotation.Nullable;
import java.util.*;

public class KDBTreePartitioner
        extends SpatialPartitioner
{
    private final KDBTree tree;

    public KDBTreePartitioner(KDBTree tree)
    {
        super(GridType.KDBTREE, getLeafZones(tree));
        this.tree = tree;
        this.tree.dropElements();
    }

    private static List<Envelope> getLeafZones(KDBTree tree)
    {
        final List<Envelope> leafs = new ArrayList<>();
        tree.traverse(new KDBTree.Visitor()
        {
            @Override
            public boolean visit(KDBTree tree)
            {
                if (tree.isLeaf()) {
                    leafs.add(tree.getExtent());
                }
                return true;
            }
        });

        return leafs;
    }

    @Override
    public int numPartitions()
    {
        return grids.size();
    }

    @Override
    public <T extends Geometry> Iterator<Tuple2<Integer, T>> placeObject(T spatialObject)
            throws Exception
    {
        // 判断对象是否为空
        Objects.requireNonNull(spatialObject, "spatialObject");
        // 获得对象范围
        final Envelope envelope = spatialObject.getEnvelopeInternal();
        // 找到范围对应叶子节点分区
        final List<KDBTree> matchedPartitions = tree.findLeafNodes(envelope);
        //若为点转->换
        final Point point = spatialObject instanceof Point ? (Point) spatialObject : null;

        final Set<Tuple2<Integer, T>> result = new HashSet<>();
        for (KDBTree leaf : matchedPartitions) {
            // For points, make sure to return only one partition
            if (point != null && !(new HalfOpenRectangle(leaf.getExtent())).contains(point)) {
                continue;
            }

            result.add(new Tuple2(leaf.getLeafId(), spatialObject));
        }

        return result.iterator();
    }

    @Nullable
    @Override
    public DedupParams getDedupParams()
    {
        return new DedupParams(grids);
    }
}
