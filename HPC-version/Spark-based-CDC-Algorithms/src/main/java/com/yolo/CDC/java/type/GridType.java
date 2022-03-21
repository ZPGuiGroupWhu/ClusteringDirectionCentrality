
package com.yolo.CDC.java.type;

import org.apache.log4j.Logger;

import java.io.Serializable;

// TODO: Auto-generated Javadoc

/**
 * The Enum GridType.
 */
public enum GridType
        implements Serializable {

    /**
     * The Equal partitioning.
     */
    Equal,
    /**
     * The Quad-Tree partitioning.
     */
    QUADTREE,

    /**
     * K-D-B-tree partitioning (k-dimensional B-tree)
     */
    KDBTREE,
    /**
     * STR-tree partitioning (R-tree)
     */
    STRTREE,
    /**
     * Hilbert
     **/
    Hilbert,
    /**
     * The Voronoi partitioning.
     */
    Voronoi,

    None;

    /**
     * Gets the grid type.
     *
     * @param str the str
     * @return the grid type
     */
    public static GridType getGridType(String str) {
        final Logger logger = Logger.getLogger(GridType.class);
        for (GridType me : GridType.values()) {
            if (me.name().equalsIgnoreCase(str)) {
                return me;
            }
        }
        logger.error("This grid type is not supported: " + str);
        return null;
    }
}
