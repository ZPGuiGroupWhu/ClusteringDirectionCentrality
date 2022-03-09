package edu.stanford.facs.swing;

import java.util.ArrayList;
import java.util.List;

public class Epp {

	private String id;
	private String name;
	private String x;
	private String y;
	private List<Double> coordinates = new ArrayList<>();
	public List<Epp> children = new ArrayList<>();
	public List<Epp> boolenGates = new ArrayList<>();
	private boolean notGate = false;
	
	public boolean isNotGate() {
		return notGate;
	}

	public void setNotGate(boolean notGate) {
		this.notGate = notGate;
	}

	public void addBooleanGate(Epp epp) {
		epp.setNotGate(true);
		boolenGates.add(epp);
	}
	
	public List<Epp> getBoolenGates() {
		return boolenGates;
	}

	public void setBoolenGates(List<Epp> boolenGates) {
		this.boolenGates = boolenGates;
	}

	public void addChild(Epp epp) {
		children.add(epp);
	}
	
	public List<Epp> getBooleanChildren() {
		return boolenGates;
	}
	
	public List<Epp> getNonBooleanChildren() {
		return children;
	}
	
	public List<Epp> getChildren() {
		ArrayList<Epp> al = new ArrayList();
		al.addAll(children);
		al.addAll(boolenGates);
		return al;
	}
	public void setChildren(List<Epp> children) {
		this.children = children;
	}
	public String getId() {
		return id;
	}
	public void setId(String id) {
		this.id = id;
	}
	public String getName() {
		return name;
	}
	public void setName(String name) {
		this.name = name;
	}
	
	public List<Double> getCoordinates() {
		return coordinates;
	}
	public void setCoordinates(List<Double> coordinates) {
		this.coordinates = coordinates;
	}
	public String getX() {
		return x;
	}
	public void setX(String x) {
		this.x = x;
	}
	public String getY() {
		return y;
	}
	public void setY(String y) {
		this.y = y;
	}
	
	public void addCoordinate(Double x) {
		this.coordinates.add(x);
	}
	
}
