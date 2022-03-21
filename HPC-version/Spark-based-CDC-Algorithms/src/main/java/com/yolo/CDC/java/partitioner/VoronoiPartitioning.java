package com.yolo.CDC.java.partitioner;


import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.Envelope;
import org.locationtech.jts.geom.Geometry;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.MultiPoint;
import org.locationtech.jts.geom.Point;
import org.locationtech.jts.geom.Polygon;
import org.locationtech.jts.triangulate.VoronoiDiagramBuilder;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.List;

// TODO: Auto-generated Javadoc

/**
 * The Class VoronoiPartitioning.
 */
public class VoronoiPartitioning
        implements Serializable
{

    /**
     * The grids.
     */
    List<Envelope> grids = new ArrayList<Envelope>();

    /**
     * Instantiates a new voronoi partitioning.
     *
     * @param samples the sample list
     * @param partitions the partitions
     * @throws Exception the exception
     */
    public VoronoiPartitioning(List<Envelope> samples, int partitions)
            throws Exception
    {
        GeometryFactory fact = new GeometryFactory();
        ArrayList<Point> subSampleList = new ArrayList<Point>();
        MultiPoint mp;

        //Take a subsample accoring to the partitions
        for (int i = 0; i < samples.size(); i = i + samples.size() / partitions) {
            Envelope envelope = samples.get(i);
            Coordinate coordinate = new Coordinate((envelope.getMinX() + envelope.getMaxX()) / 2.0, (envelope.getMinY() + envelope.getMaxY()) / 2.0);
            subSampleList.add(fact.createPoint(coordinate));
        }

        mp = fact.createMultiPoint(subSampleList.toArray(new Point[subSampleList.size()]));
        VoronoiDiagramBuilder voronoiBuilder = new VoronoiDiagramBuilder();
        voronoiBuilder.setSites(mp);
        Geometry voronoiDiagram = voronoiBuilder.getDiagram(fact);
        for (int i = 0; i < voronoiDiagram.getNumGeometries(); i++) {
            Polygon poly = (Polygon) voronoiDiagram.getGeometryN(i);
            grids.add(poly.getEnvelopeInternal());
        }
        //grids.add(new EnvelopeWithGrid(boundary,grids.size()));
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
}
