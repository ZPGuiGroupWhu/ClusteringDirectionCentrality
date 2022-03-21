package com.yolo.CDC.java.partitioner;

import com.yolo.CDC.java.type.GridType;
import com.yolo.CDC.java.utils.SortUtils;
import org.locationtech.jts.geom.Envelope;
import org.locationtech.jts.geom.Geometry;
import scala.Tuple2;

import javax.annotation.Nullable;
import java.util.*;

public class FlatGridPartitioner
        extends SpatialPartitioner {
    protected final HashMap<Integer, Integer> gridCounts = new HashMap<>();

    public FlatGridPartitioner(GridType gridType, List<Envelope> grids) {
        super(gridType, grids);
    }

    // For backwards compatibility (see SpatialRDD.spatialPartitioning(otherGrids))
    public FlatGridPartitioner(List<Envelope> grids) {
        super(null, grids);
        for (int i = 0; i < grids.size(); i++) {
            this.gridCounts.put(i, 0);
        }
    }

    @Override
    public <T extends Geometry> Iterator<Tuple2<Integer, T>> placeObject(T spatialObject)
            throws Exception {
        Objects.requireNonNull(spatialObject, "spatialObject");

        // Some grid types (RTree and Voronoi) don't provide full coverage of the RDD extent and
        // require an overflow container.
        final int overflowContainerID = grids.size();


        final Envelope envelope = spatialObject.getEnvelopeInternal();
        Set<Tuple2<Integer, T>> result = new HashSet();
        boolean containFlag = false;
        //依次判断元素数量少的分区，若包含该元素，添加后不再重复添加该元素
        //TODO 并行 该方法无效
        List<Map.Entry<Integer, Integer>> list = SortUtils.sortMap(gridCounts);
        for (int i = 0; i < grids.size(); i++) {
            int key = list.get(i).getKey();
            int value = list.get(i).getValue();
            final Envelope grid = grids.get(key);
//            final Envelope grid = grids.get(i);
            if (grid.covers(envelope)) {
//                result.add(new Tuple2(i, spatialObject));
//                containFlag = true;
                result.add(new Tuple2(key, spatialObject));
                containFlag = true;
                value += 1;
                gridCounts.put(key, value);
                //如果已经包含在该分区内，不再重复添加空间对象
                break;
            } else if (grid.intersects(envelope) || envelope.covers(grid)) {
                result.add(new Tuple2<>(i, spatialObject));
            }
        }

        if (!containFlag) {

            result.add(new Tuple2<>(overflowContainerID, spatialObject));
        }
        return result.iterator();
    }

    @Override
    @Nullable
    public DedupParams getDedupParams() {
        /**
         * Equal and Hilbert partitioning methods have necessary properties to support de-dup.
         * These methods provide non-overlapping partition extents and not require overflow
         * partition as they cover full extent of the RDD. However, legacy
         * SpatialRDD.spatialPartitioning(otherGrids) method doesn't preserve the grid type
         * making it impossible to reliably detect whether partitioning allows efficient de-dup or not.
         *
         * TODO Figure out how to remove SpatialRDD.spatialPartitioning(otherGrids) API. Perhaps,
         * make the implementation no-op and fold the logic into JoinQuery, RangeQuery and KNNQuery APIs.
         */

        return null;
    }

    @Override
    public int numPartitions() {
//        if (this.overflow) {
            /* overflow partition */
            return grids.size() + 1;
//        } else {
//            return grids.size();
//        }
    }

    @Override
    public boolean equals(Object o) {
        if (o == null || !(o instanceof FlatGridPartitioner)) {
            return false;
        }

        final FlatGridPartitioner other = (FlatGridPartitioner) o;

        // For backwards compatibility (see SpatialRDD.spatialPartitioning(otherGrids))
        if (this.gridType == null || other.gridType == null) {
            return other.grids.equals(this.grids);
        }

        return other.gridType.equals(this.gridType) && other.grids.equals(this.grids);
    }

}
