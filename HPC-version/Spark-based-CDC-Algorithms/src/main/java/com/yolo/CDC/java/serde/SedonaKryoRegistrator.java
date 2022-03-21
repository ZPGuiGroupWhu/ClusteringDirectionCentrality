package com.yolo.CDC.java.serde;

import com.esotericsoftware.kryo.Kryo;
import com.yolo.CDC.java.knnsearch.index.IndexBase;
import org.apache.log4j.Logger;
import com.yolo.CDC.java.geometryObjects.Circle;
import com.yolo.CDC.java.geometryObjects.GeometrySerde;
import com.yolo.CDC.java.geometryObjects.SpatialIndexSerde;
import org.apache.spark.serializer.KryoRegistrator;
import org.locationtech.jts.geom.*;
import org.locationtech.jts.index.quadtree.Quadtree;
import org.locationtech.jts.index.strtree.STRtree;

public class SedonaKryoRegistrator
        implements KryoRegistrator
{

    final static Logger log = Logger.getLogger(SedonaKryoRegistrator.class);

    @Override
    public void registerClasses(Kryo kryo)
    {
        GeometrySerde serializer = new GeometrySerde();
        SpatialIndexSerde indexSerializer = new SpatialIndexSerde(serializer);

        log.info("Registering custom serializers for geometry types");

        kryo.register(Point.class, serializer);
        kryo.register(LineString.class, serializer);
        kryo.register(Polygon.class, serializer);
        kryo.register(MultiPoint.class, serializer);
        kryo.register(MultiLineString.class, serializer);
        kryo.register(MultiPolygon.class, serializer);
        kryo.register(GeometryCollection.class, serializer);
        kryo.register(Circle.class, serializer);
        kryo.register(Envelope.class, serializer);
        // TODO: Replace the default serializer with default spatial index serializer
        kryo.register(Quadtree.class, indexSerializer);
        kryo.register(STRtree.class, indexSerializer);
    }
}
