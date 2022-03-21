package com.yolo.CDC.java.utils;

import javafx.util.Pair;
import org.geotools.geometry.jts.JTS;
import org.geotools.referencing.CRS;
import org.locationtech.jts.geom.Coordinate;
import org.opengis.referencing.FactoryException;
import org.opengis.referencing.crs.CoordinateReferenceSystem;
import org.opengis.referencing.operation.MathTransform;
import org.opengis.referencing.operation.TransformException;

/**
 * @ClassName:CRSTransform
 * @Description:TODO
 * @Author:yolo
 * @Date:2022/3/189:36
 * @Version:1.0
 */
public class CRSTransform {

    private static final double PI = Math.PI;
    private static final double mercatorMax = 20037508.34;

    /**
     * 4326坐标转3857即经纬度转墨卡托
     * @param lon
     * @param lat
     */
    public static Pair<Double, Double> transformTo3857(double lat,double lon) throws FactoryException, TransformException {
//        double mercatorx = lon * mercatorMax / 180;
//        double mercatory = Math.log(Math.tan(((90+lat) * PI) / 360)) / (PI / 180);
//        mercatory = mercatory * mercatory / 180;
//        System.out.printf("经纬度坐标转墨卡托后的坐标:%f,%f",mercatorx,mercatory);
//        return new Pair(mercatorx,mercatory);
        CoordinateReferenceSystem sourceCRS = CRS.decode("epsg:4326");
        CoordinateReferenceSystem targetCRS = CRS.decode("epsg:3857");
        MathTransform transform = CRS.findMathTransform(sourceCRS, targetCRS, false);
        Coordinate coorDst=new Coordinate();
        JTS.transform(new Coordinate(lat, lon),coorDst, transform);
        return new Pair(coorDst.x,coorDst.y);
    }

    /**
     * 墨卡托坐标转3857即墨卡托转经纬度
     * @param mercatorx
     * @param mercatory
     */
    public static Pair<Double, Double> tarnsformTo4326(double mercatorx,double mercatory){
        double lon = mercatorx/mercatorMax * 180;
        double lat = mercatory/mercatorMax * 180;
        lat = (180 / PI) * (2 *Math.atan(Math.exp((lat * PI) / 180)) - PI / 2);
        return new Pair(lat,lon);
//        System.out.printf("墨卡托坐标转经纬度后的坐标:%f,%f \n",lon,lat);
    }

    public static void main(String[] args) throws FactoryException, TransformException {
        CoordinateReferenceSystem sourceCRS = CRS.decode("epsg:4326");
        CoordinateReferenceSystem targetCRS = CRS.decode("epsg:3857");
        MathTransform transform = CRS.findMathTransform(sourceCRS, targetCRS, false);
        Coordinate coorDst=new Coordinate();
        JTS.transform(new Coordinate(32, 118),coorDst, transform);
        System.out.println(coorDst);
//        transformTo3857(32.000000,118.000000);
    }
}
