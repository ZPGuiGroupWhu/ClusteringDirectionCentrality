package com.yolo.CDC.java.utils;

import org.locationtech.jts.geom.CoordinateSequence;
import org.locationtech.jts.geom.CoordinateSequenceFilter;
import org.locationtech.jts.geom.Geometry;

import java.util.Objects;

public class GeomUtils
{
    public static String printGeom(Geometry geom) {
        if(geom.getUserData()!=null) return geom.toText() + "\t" + geom.getUserData();
        else return geom.toText();
    }

    public static String printGeom(Object geom) {
        Geometry g = (Geometry) geom;
        return printGeom(g);
    }

    public static int hashCode(Geometry geom) {
        return geom.getUserData()==null? geom.hashCode():geom.hashCode()*31 + geom.getUserData().hashCode();
    }
    public static boolean equalsTopoGeom(Geometry geom1, Geometry geom2) {
        if (Objects.equals(geom1.getUserData(), geom2.getUserData())) return geom1.equals(geom2);
        return false;
    }

    public static boolean equalsExactGeom(Geometry geom1, Object geom2) {
        if (! (geom2 instanceof Geometry)) return false;
        Geometry g = (Geometry) geom2;
        if (Objects.equals(geom1.getUserData(), g.getUserData())) return geom1.equalsExact(g);
        else return false;
    }

    /**
     * Swaps the XY coordinates of a geometry.
     */
    public static void flipCoordinates(Geometry g) {
        g.apply(new CoordinateSequenceFilter() {

            @Override
            public void filter(CoordinateSequence seq, int i) {
                double oldX = seq.getCoordinate(i).x;
                double oldY = seq.getCoordinateCopy(i).y;
                seq.getCoordinate(i).setX(oldY);
                seq.getCoordinate(i).setY(oldX);
            }

            @Override
            public boolean isGeometryChanged() {
                return true;
            }

            @Override
            public boolean isDone() {
                return false;
            }
        });
    }
}
