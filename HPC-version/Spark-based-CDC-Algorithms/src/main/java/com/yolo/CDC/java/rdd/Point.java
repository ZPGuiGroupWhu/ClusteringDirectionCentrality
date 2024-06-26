package com.yolo.CDC.java.rdd;

import org.locationtech.jts.geom.*;
import org.locationtech.jts.util.Assert;

/**
 * Represents a single point.
 *
 * A <code>Point</code> is topologically valid if and only if:
 * <ul>
 * <li>the coordinate which defines it (if any) is a valid coordinate
 * (i.e. does not have an <code>NaN</code> X or Y ordinate)
 * </ul>
 *
 *@version 1.7
 */
public class Point
	extends Geometry
	implements Puntal
{
  private static final long serialVersionUID = 4902022702746614570L;
  /**
   *  The <code>Coordinate</code> wrapped by this <code>Point</code>.
   */
  private CoordinateSequence coordinates;

  /**
   *  Constructs a <code>Point</code> with the given coordinate.
   *
   *@param  coordinate      the coordinate on which to base this <code>Point</code>
   *      , or <code>null</code> to create the empty geometry.
   *@param  precisionModel  the specification of the grid of allowable points
   *      for this <code>Point</code>
   *@param  SRID            the ID of the Spatial Reference System used by this
   *      <code>Point</code>
   * @deprecated Use GeometryFactory instead
   */
  public Point(Coordinate coordinate, PrecisionModel precisionModel, int SRID) {
    super(new GeometryFactory(precisionModel, SRID));
    init(getFactory().getCoordinateSequenceFactory().create(
          coordinate != null ? new Coordinate[]{coordinate} : new Coordinate[]{}));
  }

  /**
   *@param  coordinates      contains the single coordinate on which to base this <code>Point</code>
   *      , or <code>null</code> to create the empty geometry.
   */
  public Point(CoordinateSequence coordinates, GeometryFactory factory) {
    super(factory);
    init(coordinates);
  }

  private void init(CoordinateSequence coordinates)
  {
    if (coordinates == null) {
      coordinates = getFactory().getCoordinateSequenceFactory().create(new Coordinate[]{});
    }
    Assert.isTrue(coordinates.size() <= 1);
    this.coordinates = coordinates;
  }

  @Override
  public Coordinate[] getCoordinates() {
    return isEmpty() ? new Coordinate[]{} : new Coordinate[]{
        getCoordinate()
        };
  }

  @Override
  public int getNumPoints() {
    return isEmpty() ? 0 : 1;
  }

  @Override
  public boolean isEmpty() {
    return coordinates.size() == 0;
  }

  @Override
  public boolean isSimple() {
    return true;
  }

  @Override
  public int getDimension() {
    return 0;
  }

  @Override
  public int getBoundaryDimension() {
    return Dimension.FALSE;
  }

  public double getX() {
    if (getCoordinate() == null) {
      throw new IllegalStateException("getX called on empty Point");
    }
    return getCoordinate().x;
  }

  public double getY() {
    if (getCoordinate() == null) {
      throw new IllegalStateException("getY called on empty Point");
    }
    return getCoordinate().y;
  }

  @Override
  public Coordinate getCoordinate() {
    return coordinates.size() != 0 ? coordinates.getCoordinate(0): null;
  }

  @Override
  public String getGeometryType() {
    return Geometry.TYPENAME_POINT;
  }

  /**
   * Gets the boundary of this geometry.
   * Zero-dimensional geometries have no boundary by definition,
   * so an empty GeometryCollection is returned.
   *
   * @return an empty GeometryCollection
   * @see Geometry#getBoundary
   */
  @Override
  public Geometry getBoundary() {
    return getFactory().createGeometryCollection();
  }

  @Override
  protected Envelope computeEnvelopeInternal() {
    if (isEmpty()) {
      return new Envelope();
    }
    Envelope env = new Envelope();
    env.expandToInclude(coordinates.getX(0), coordinates.getY(0));
    return env;
  }

  @Override
  public boolean equalsExact(Geometry other, double tolerance) {
    if (!isEquivalentClass(other)) {
      return false;
    }
    if (isEmpty() && other.isEmpty()) {
      return true;
    }
    if (isEmpty() != other.isEmpty()) {
      return false;
    }
    return equal(((Point) other).getCoordinate(), this.getCoordinate(), tolerance);
  }

  @Override
  public void apply(CoordinateFilter filter) {
	    if (isEmpty()) { return; }
	    filter.filter(getCoordinate());
	  }

  @Override
  public void apply(CoordinateSequenceFilter filter)
  {
	    if (isEmpty()) {
          return;
        }
	    filter.filter(coordinates, 0);
      if (filter.isGeometryChanged()) {
        geometryChanged();
      }
	  }

  @Override
  public void apply(GeometryFilter filter) {
    filter.filter(this);
  }

  @Override
  public void apply(GeometryComponentFilter filter) {
    filter.filter(this);
  }

  /**
   * Creates and returns a full copy of this {@link Point} object.
   * (including all coordinates contained by it).
   *
   * @return a clone of this instance
   * @deprecated
   */
  @Override
  public Object clone() {
    return copy();
  }

  @Override
  protected Point copyInternal() {
    return new Point(coordinates.copy(), factory);
  }

  @Override
  public Point reverse() {
    return (Point) super.reverse();
  }

  @Override
  protected Geometry reverseInternal() {
    return null;
  }

//  @Override
//  protected Point reverseInternal()
//  {
//    return getFactory().createPoint(coordinates.copy());
//  }

  @Override
  public void normalize()
  {
    // a Point is always in normalized form
  }

  @Override
  protected int compareToSameClass(Object other) {
    Point point = (Point) other;
    return getCoordinate().compareTo(point.getCoordinate());
  }

  @Override
  protected int compareToSameClass(Object other, CoordinateSequenceComparator comp)
  {
    Point point = (Point) other;
    return comp.compare(this.coordinates, point.coordinates);
  }
  
  @Override
  protected int getTypeCode() {
    return Geometry.TYPECODE_POINT;
  }

  public CoordinateSequence getCoordinateSequence() {
    return coordinates;
  }
}

