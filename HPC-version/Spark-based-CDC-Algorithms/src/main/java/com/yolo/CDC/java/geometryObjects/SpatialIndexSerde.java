package com.yolo.CDC.java.geometryObjects;

import com.esotericsoftware.kryo.Kryo;
import com.esotericsoftware.kryo.Serializer;
import com.esotericsoftware.kryo.io.Input;
import com.esotericsoftware.kryo.io.Output;
import org.apache.log4j.Logger;
import org.locationtech.jts.index.quadtree.IndexSerde;
import org.locationtech.jts.index.quadtree.Quadtree;
import org.locationtech.jts.index.strtree.STRtree;

/**
 * Provides methods to efficiently serialize and deserialize spatialIndex types.
 * <p>
 * Support Quadtree, STRtree types
 * <p>
 * trees are serialized recursively.
 */
public class SpatialIndexSerde
        extends Serializer
{

    private static final Logger log = Logger.getLogger(SpatialIndexSerde.class);

    private final GeometrySerde geometrySerde;

    public SpatialIndexSerde()
    {
        super();
        geometrySerde = new GeometrySerde();
    }

    public SpatialIndexSerde(GeometrySerde geometrySerde)
    {
        super();
        this.geometrySerde = geometrySerde;
    }

    @Override
    public void write(Kryo kryo, Output output, Object o)
    {
        if (o instanceof Quadtree) {
            // serialize quadtree index
            writeType(output, Type.QUADTREE);
            Quadtree tree = (Quadtree) o;
            IndexSerde indexSerde = new IndexSerde();
            indexSerde.write(kryo, output, tree);
        }
        else if (o instanceof STRtree) {
            //serialize rtree index
            writeType(output, Type.RTREE);
            STRtree tree = (STRtree) o;
            org.locationtech.jts.index.strtree.IndexSerde indexSerde
                    = new org.locationtech.jts.index.strtree.IndexSerde();
            indexSerde.write(kryo, output, tree);
        }
        else {
            throw new UnsupportedOperationException(" index type not supported ");
        }
    }

    @Override
    public Object read(Kryo kryo, Input input, Class aClass)
    {
        byte typeID = input.readByte();
        Type indexType = Type.fromId(typeID);
        switch (indexType) {
            case QUADTREE: {
                IndexSerde indexSerde = new IndexSerde();
                return indexSerde.read(kryo, input);
            }
            case RTREE: {
                org.locationtech.jts.index.strtree.IndexSerde indexSerde =
                        new org.locationtech.jts.index.strtree.IndexSerde();
                return indexSerde.read(kryo, input);
            }
            default: {
                throw new UnsupportedOperationException("can't deserialize spatial index of type" + indexType);
            }
        }
    }

    private void writeType(Output output, Type type)
    {
        output.writeByte((byte) type.id);
    }

    private enum Type
    {

        QUADTREE(0),
        RTREE(1);

        private final int id;

        Type(int id)
        {
            this.id = id;
        }

        public static Type fromId(int id)
        {
            for (Type type : values()) {
                if (type.id == id) {
                    return type;
                }
            }

            return null;
        }
    }
}
