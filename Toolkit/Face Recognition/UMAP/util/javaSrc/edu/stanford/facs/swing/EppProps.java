package edu.stanford.facs.swing;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.FileReader;
import java.io.IOException;
import java.io.OutputStream;
import java.io.OutputStreamWriter;
import java.net.URL;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.Map.Entry;
import java.util.Properties;
import java.util.TreeMap;

import org.w3c.dom.Element;

public class EppProps {

	private static final String BOOLEAN_GATE_SUFFIX = ".B";
	private static final String GATE_NAME_SUFFIX = ".name";
	private static Properties props = new Properties();
	
	public EppProps(File file) {
		try {
			props.load(new FileReader(file));
		} catch (IOException e) {
			e.printStackTrace();
		}
	}
	
	private static Element addEpp(EppGatingML gml, Element parent, Epp epp, Element root) {
		List<Double> coordinates = epp.getCoordinates();
		Map<Double, Double> vertexValues = new TreeMap<>();
		if (coordinates != null && coordinates.size() > 0) {
			int mid = coordinates.size()/2;
			int count = 0;
			while (count < mid) {
				vertexValues.put(coordinates.get(count), coordinates.get(mid+count));
				count++;
			}
		}
		return gml.addPolygon(parent, epp.getName(), epp.getX(), epp.getY(), vertexValues, root );
	}
	
	private static void addEppGateHierarchy(EppGatingML gml, Element parent, Epp epp, Element root) {
		Element parent2 = addEpp(gml, parent, epp, root);
		for (Epp child: epp.getChildren()) {
			addEppGateHierarchy(gml, parent2, child, root);
		}
	}
	
	public void getGatingML(Epp eppRoot, String parameters[], File file) {
		EppGatingML gml = new EppGatingML(parameters);
		Element root = gml.getRoot();
		for (Epp child: eppRoot.getChildren()) {
			addEppGateHierarchy(gml, root, child, root);
		}
		//addEppGateHierarchy(gml, root, eppRoot, root);
		//String res = gml.getGatingMLString(root);
		gml.writeGatingML(root, file);
		
	}
	
	/*public String getGatingMLFlat(List<AutoGateEpp> epps, String parameters[]) {
		logger.log(Level.INFO, ">>>getGatingML");
		GatingML gml = new GatingML(parameters);
		Element root = gml.getRoot();
		//gml.addGatingMLDefaultNamespaceAttributes(root);
		for (AutoGateEpp epp: epps) {
			List<Double> coordinates = epp.getCoordinates();
			Map<Double, Double> vertexValues = new TreeMap<>();
			if (coordinates != null && coordinates.size() > 0) {
				int mid = coordinates.size()/2;
				int count = 0;
				while (count < mid) {
					vertexValues.put(coordinates.get(count), coordinates.get(mid+count));
					count++;
				}
			}
			gml.addPolygon(root, epp.getHierarchy(), epp.getX(), epp.getY(), vertexValues, root );
		}
		String res = gml.getGatingMLString(root);
		logger.log(Level.INFO, "<<<getGatingML");
		return res;
		
	}*/
	
	public Epp getAutoGateRoot(List<Epp> epps) {
		Iterator<Epp> it = epps.iterator();
		Epp root = null;
		while (it.hasNext()) {
			Epp epp = it.next();
			if (epp.getId().trim().equals("0")) {
				root = epp;
				it.remove();
				break;
			}
		}
		sortEppObjects("01", root, epps);
		return root;
	}
	
	private void sortEppObjects(String searchId, Epp currParent, List<Epp> epps) {
		//int sorted= 0;
		//int length=epps.size();
		//while (sorted<length) {
			boolean found = false;
			Iterator<Epp> it = epps.iterator();
			while(it.hasNext()) {
				Epp epp = it.next();
				String key = epp.getId();
				
				/*if (key.equalsIgnoreCase(searchId+GATE_NAME_SUFFIX)) {
					currParent.addBooleanGate(epp);
				}*/
				if (key.equalsIgnoreCase(searchId+BOOLEAN_GATE_SUFFIX)) {
					currParent.addBooleanGate(epp);
				}
				else if (key.equals(searchId)) {
					found = true;
					//sorted++;
					currParent.addChild(epp);
					//break;
				}
			}
			if (found) {
				int lastDigit = Integer.parseInt(String.valueOf(searchId.charAt(searchId.length()-1)));
				lastDigit++;
				String substr = searchId.substring(0,searchId.length()-1);
				sortEppObjects(substr+lastDigit, currParent, epps);
			}
			else {
				for (Epp epp: currParent.getChildren()) {
					sortEppObjects(epp.getId()+"1", epp, epps);
				}
			}
		//}
	}
	
	private Epp getEppObject(String key) {
		if (!epps.isEmpty()) {
			for (Epp epp: epps) {
				if (epp.getId().equals(key)) {
					return epp;
				}
			}
		}
		return null;
	}
	List<Epp> epps = new ArrayList<Epp>();
	public List<Epp> getEppObjectsOld() {
		HashMap<String, String> gateNames = new HashMap();
		List<Epp> epps = new ArrayList<Epp>();
		for(Entry<Object, Object> e : props.entrySet()) {
			try {
				Epp epp = new Epp();
				boolean isBoolGate = false;
				String key = (String)e.getKey();
				try {
					long l = Long.parseLong(key);
				}
				catch (Exception e1) {
					if (key.endsWith(GATE_NAME_SUFFIX)) {
						String gateId = key.substring(0,key.indexOf(GATE_NAME_SUFFIX));
						Epp epp1 = getEppObject(gateId);
						if (epp1 != null) {
							epp1.setName((String)e.getValue());;
						}
						else {
							gateNames.put(gateId, (String)e.getValue());
						}
					}
					else if (key.endsWith(BOOLEAN_GATE_SUFFIX)) {
						String key2 = key.substring(0,key.indexOf("."));
						try {
							long l = Long.parseLong(key2);
							isBoolGate = true;
						}
						catch (Exception e2) {
							continue;
						}
					}
					else {
						continue;
					}
				}
				epp.setId(key);
				if (gateNames.containsKey(key) ) {
					epp.setName(gateNames.get(key));
				}
				String val = (String)e.getValue();
				String tokens[] = val.split(":");
				if (tokens.length == 2) {
					String params = tokens[0];
					String paramTokens[] = params.split("/");
					if (paramTokens.length == 2) {
						String x = paramTokens[0];
						String y = paramTokens[1];
						epp.setX(x);
						epp.setY(y);
					}
					String coords = tokens[1];
					String coordinates[] = coords.split(" ");
					if (coordinates != null && coordinates.length > 0) {
						for (String coord: coordinates) {
							if (!coord.trim().equals("")) {
								epp.addCoordinate(Double.parseDouble(coord));
							}
						}
					}
					epps.add(epp);
				}
			}
			catch (Exception e2) {
				e2.printStackTrace();
			}
        }
		
		int count=1;
		for (Epp epp: epps) {
			if (epp.getName() == null || epp.getName().trim().equals("")) {
				epp.setName("ID" + count++);
			}
		}
		return epps;
	}
	
	public List<Epp> getEppObjects() {
		HashMap<String, String> gateIdnNames = new HashMap();
		List<Epp> epps = new ArrayList<Epp>();
		
		for(Entry<Object, Object> e : props.entrySet()) {
			try {
				Epp epp = new Epp();
				String key = (String)e.getKey();
				try {
					long l = Long.parseLong(key);
				}
				catch (Exception e1) {
					if (key.endsWith(GATE_NAME_SUFFIX)) {
						String gateId = key.substring(0,key.indexOf(GATE_NAME_SUFFIX));
						gateIdnNames.put(gateId, (String)e.getValue());
					}
					else if (key.endsWith(BOOLEAN_GATE_SUFFIX)) {
						String key2 = key.substring(0,key.indexOf("."));
						try {
							long l = Long.parseLong(key2);
						}
						catch (Exception e2) {
							continue;
						}
					}
					else {
						continue;
					}
				}
				epp.setId(key);
				String val = (String)e.getValue();
				String tokens[] = val.split(":");
				if (tokens.length == 2) {
					String params = tokens[0];
					String paramTokens[] = params.split("/");
					if (paramTokens.length == 2) {
						String x = paramTokens[0];
						String y = paramTokens[1];
						epp.setX(x);
						epp.setY(y);
					}
					String coords = tokens[1];
					String coordinates[] = coords.split(" ");
					if (coordinates != null && coordinates.length > 0) {
						for (String coord: coordinates) {
							if (!coord.trim().equals("")) {
								epp.addCoordinate(Double.parseDouble(coord));
							}
						}
					}
					epps.add(epp);
				}
			}
			catch (Exception e2) {
				e2.printStackTrace();
			}
        }
		
		/*for (String gateId: gateIdnNames.keySet()) {
		AutoGateEpp epp1 = getEppObject(gateId);
		if (epp1 != null) {
			epp1.setHierarchy(gateIdnNames.get(gateId));
		}
		}*/				
		for (Epp epp: epps) {
			String value = gateIdnNames.get(epp.getId());
			if (value != null) {
				epp.setName(value);
			}
			else {
				System.out.println("WARNING: No name for " + epp.getId());
			}
		}
	
		int count=1;
		for (Epp epp: epps) {
			if (epp.getName() == null || epp.getName().trim().equals("")) {
				System.out.println("WARNING: SETTING RANDOM ID For " + epp.getId());
				epp.setName("ID" + count++);
			}
		}
		return epps;
	}
	
	private void minimizeAndTransform(File file) throws FileNotFoundException {
		for(Entry<Object, Object> e : props.entrySet()) {
			String key = (String)e.getKey();
			try {
				long l = Long.parseLong(key);
			}
			catch (Exception e1) {
				props.remove(key);
				continue;
			}
		}
		OutputStream os = new FileOutputStream(new File(System.getProperty("user.home"), 
				"minimizedEpp.properties"));
		props.save(os, "");
	}
	
	public static void createGatingML(String props, String outFile, String commaDelimitedParameters) {
		if (commaDelimitedParameters != null) {
			createGatingML(props, outFile, commaDelimitedParameters.split(","));
		}
		else {
			createGatingML(props, outFile, commaDelimitedParameters);
		}
	}
	
	public static void createGatingML(String props, String outFile, String []parameters) {
		File file = new File(props);
		if (file.exists()) {
			EppProps reader = new EppProps(file);
			List<Epp> epps = reader.getEppObjects();
			Epp root = reader.getAutoGateRoot(epps);
			//printEppGateHierarchy(0, root);
			if (parameters != null) {
				reader.getGatingML(root, parameters, new File(outFile));
			}
			else {
				String[] params = new String[] {"1","2","3","4","5","6","7","8","9",
						"10","11","12","13","14","15", "16","17","18","19","20"};
				reader.getGatingML(root, params, new File(outFile));
			}
		}
	}
	
	private void createGatingMLfile(File file, String gatingML) {
		FileOutputStream fileOutputStream = null;
		OutputStreamWriter outputStreamWriter = null;
		try {
			fileOutputStream = new FileOutputStream(file);
			outputStreamWriter = new OutputStreamWriter(fileOutputStream, "UTF-8");
			outputStreamWriter.write(gatingML);
		} catch (Exception e) {
			e.printStackTrace();
		}
	}
	
	public static void main(String a[])throws Exception {
		URL url = EppProps.class.getResource("./eppNew.properties");
		if (url != null) {
			File file = new File(url.toURI());
			EppProps reader = new EppProps(file);
			String[] parameters = new String[] {"1","2","3","4","5","6","7","8","9",
					"10","11","12","13","14","15"};
			List<Epp> epps = reader.getEppObjects();
			Epp root = reader.getAutoGateRoot(epps);
			printEppGateHierarchy(0, root);
			File outFile = new File(System.getProperty("user.home"), "Epp-gatingml.xml");
			reader.getGatingML(root, parameters, outFile);
		} 
		
	}

	private static void printEpp(int level, Epp epp) {
		for (int i=0; i<level; i++) {
			System.out.print("\t");
		}
		StringBuilder sb = new StringBuilder();
		sb.append(epp.getId()).append(",").append(epp.getX())
			.append(",").append(epp.getY()).append(",").append(epp.getCoordinates());
		System.out.println(sb.toString());//.append(",")append(epp.getHierarchy()).
	}
	
	private static void printEppGateHierarchy(int level, Epp epp) {
		printEpp(level++, epp);
		for (Epp child: epp.getChildren()) {
			//printEpp(level, child);
			printEppGateHierarchy(level, child);
		}
	}
}
