package edu.stanford.facs.swing;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStreamWriter;
import java.util.Map;

import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.parsers.ParserConfigurationException;
import javax.xml.transform.OutputKeys;
import javax.xml.transform.Transformer;
import javax.xml.transform.TransformerException;
import javax.xml.transform.TransformerFactory;
import javax.xml.transform.dom.DOMSource;
import javax.xml.transform.stream.StreamResult;

import org.w3c.dom.Document;
import org.w3c.dom.Element;

public class EppGatingML {

	String parameters[];

	public EppGatingML() {

	}

	public EppGatingML(String parameters[]) {
		this.parameters = parameters;
	}

	Document document;

	public Element getRoot() {
		DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
		factory.setNamespaceAware(true);

		DocumentBuilder loader = null;
		try {
			loader = factory.newDocumentBuilder();
		} catch (ParserConfigurationException e) {
			e.printStackTrace();
			return null;
		}
		document = loader.newDocument();

		Element root = document.createElementNS("http://www.isac-net.org/std/Gating-ML/v2.0/gating",
				"gating:Gating-ML");
		root.setAttribute("xmlns:xsi", "http://www.w3.org/2001/XMLSchema-instance");
		root.setAttribute("xmlns:transforms", "http://www.isac-net.org/std/Gating-ML/v2.0/transformations");
		root.setAttribute("xmlns:data-type", "http://www.isac-net.org/std/Gating-ML/v2.0/datatypes");
		document.appendChild(root);
		return root;
	}

	public Element addPolygon(Element parentElement, String id, String paramX, String paramY,
			Map<Double, Double> vertexValues, Element root) {
		Element element = document.createElementNS("http://www.isac-net.org/std/Gating-ML/v2.0/gating",
				"gating:PolygonGate");
		element.setAttributeNS("http://www.isac-net.org/std/Gating-ML/v2.0/gating", "gating:id", id);
		if (parentElement != root && parentElement != null && parentElement.getAttribute("id") != null) {
			String idValue = parentElement.getAttributeNodeNS(
					"http://www.isac-net.org/std/Gating-ML/v2.0/gating", "id").getNodeValue();
			element.setAttributeNS("http://www.isac-net.org/std/Gating-ML/v2.0/gating", "gating:parent_id",
					idValue);
		}
		Element dimension1 = document.createElementNS("http://www.isac-net.org/std/Gating-ML/v2.0/gating",
				"gating:dimension");
		Element dataTypeX = document.createElementNS("http://www.isac-net.org/std/Gating-ML/v2.0/datatypes",
				"data-type:fcs-dimension");
		Element dimension2 = document.createElementNS("http://www.isac-net.org/std/Gating-ML/v2.0/gating",
				"gating:dimension");
		Element dataTypeY = document.createElementNS("http://www.isac-net.org/std/Gating-ML/v2.0/datatypes",
				"data-type:fcs-dimension");
		
		if (parameters != null && parameters.length > 0) {
			int parX = Integer.parseInt(paramX);
			int parY = Integer.parseInt(paramY);
			if (parameters.length >= parX) {
				dataTypeX.setAttributeNS("http://www.isac-net.org/std/Gating-ML/v2.0/datatypes", "data-type:name",
						parameters[parX-1]);
			}
			else {
				dataTypeX.setAttributeNS("http://www.isac-net.org/std/Gating-ML/v2.0/datatypes", "data-type:name", paramX);
			}
			if (parameters.length >= parY) {
				dataTypeY.setAttributeNS("http://www.isac-net.org/std/Gating-ML/v2.0/datatypes", "data-type:name",
						parameters[parY-1]);
			}
			else {
				dataTypeY.setAttributeNS("http://www.isac-net.org/std/Gating-ML/v2.0/datatypes", "data-type:name", paramY);
			}
		} else {
			dataTypeX.setAttributeNS("http://www.isac-net.org/std/Gating-ML/v2.0/datatypes", "data-type:name", paramX);
			dataTypeY.setAttributeNS("http://www.isac-net.org/std/Gating-ML/v2.0/datatypes", "data-type:name", paramY);
		}

		dimension1.appendChild(dataTypeX);
		dimension2.appendChild(dataTypeY);
		element.appendChild(dimension1);
		element.appendChild(dimension2);

		for (Map.Entry<Double, Double> v : vertexValues.entrySet()) {
			element.appendChild(getVertex(v.getKey(), v.getValue()));
		}
		root.appendChild(element);
		return element;

	}

	private Element getVertex(Double x, Double y) {
		Element vertex = document.createElementNS("http://www.isac-net.org/std/Gating-ML/v2.0/gating", "gating:vertex");
		vertex.appendChild(getCoordinate(x));
		vertex.appendChild(getCoordinate(y));
		return vertex;
	}

	private Element getCoordinate(Double value) {
		Element coordinate = document.createElementNS("http://www.isac-net.org/std/Gating-ML/v2.0/gating",
				"gating:coordinate");
		coordinate.setAttributeNS("http://www.isac-net.org/std/Gating-ML/v2.0/datatypes", "data-type:value",
				String.valueOf(value));
		return coordinate;
	}

	public void createGatingMLfile(Element element, File file) {
		FileOutputStream fileOutputStream = null;
		OutputStreamWriter outputStreamWriter = null;
		try {
			fileOutputStream = new FileOutputStream(file);
			outputStreamWriter = new OutputStreamWriter(fileOutputStream, "UTF-8");
			outputStreamWriter.write(getGatingMLString(element));
		} catch (Exception e) {
			e.printStackTrace();
		}
	}

	public void writeGatingML(Element element, File file) {
		String s = null;
		try {
			Transformer tr = TransformerFactory.newInstance().newTransformer();
			tr.setOutputProperty(OutputKeys.INDENT, "yes");
			tr.setOutputProperty(OutputKeys.METHOD, "xml");
			tr.setOutputProperty(OutputKeys.ENCODING, "UTF-8");
			tr.setOutputProperty("{http://xml.apache.org/xslt}indent-amount", "4");

			FileOutputStream o = new FileOutputStream(file);
			tr.transform(new DOMSource(element), new StreamResult(o));
			o.close();
		} catch (TransformerException te) {
			System.err.println(te.getMessage());
		} 
		catch (IOException ioe) {
			System.err.println(ioe.getMessage());
		}
	}
	
	public String getGatingMLString(Element element) {
		String s = null;
		try {
			Transformer tr = TransformerFactory.newInstance().newTransformer();
			tr.setOutputProperty(OutputKeys.INDENT, "yes");
			tr.setOutputProperty(OutputKeys.METHOD, "xml");
			tr.setOutputProperty(OutputKeys.ENCODING, "UTF-8");
			tr.setOutputProperty("{http://xml.apache.org/xslt}indent-amount", "4");

			/*FileOutputStream o = new FileOutputStream(
					System.getProperty("user.home") + File.separator + "Output.xml");*/
			ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
			tr.transform(new DOMSource(element), new StreamResult(outputStream));
			s = new String(outputStream.toByteArray());

			//o.close();
		} catch (TransformerException te) {
			System.err.println(te.getMessage());
		} 
		/*catch (IOException ioe) {
			System.err.println(ioe.getMessage());
		}*/
		return s;
	}
}
