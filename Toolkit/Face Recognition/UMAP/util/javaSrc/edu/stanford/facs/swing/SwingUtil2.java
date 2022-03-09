/***
 * Author: Stephen Meehan, swmeehan@stanford.edu
 * 
 * Provided by the Herzenberg Lab at Stanford University
 * 
 * License: BSD 3 clause
 * 
 * Provides static methods to support ToolTipOnDemand in umap jar
 */

package edu.stanford.facs.swing;

import java.awt.Component;
import java.awt.Dimension;
import java.awt.GraphicsConfiguration;
import java.awt.GraphicsDevice;
import java.awt.GraphicsEnvironment;
import java.awt.Rectangle;
import java.awt.Window;
import java.io.IOException;
import java.util.TreeMap;

import javax.swing.JTable;
import javax.swing.SwingUtilities;

public class SwingUtil2 {
    public static Rectangle getScreen(final Component c) {
    	final Window w=SwingUtilities.getWindowAncestor(c);
    	final Rectangle value;
    	if (w == null){
    		final Dimension d=c.getToolkit().getScreenSize();
    		value=new Rectangle(0,0,d.width,d.height);
    	} else {
    		value=getScreen(w);
    	}
    	return value;
    }
    public static Rectangle getScreen(final Window window) {
        final GraphicsEnvironment ge = GraphicsEnvironment.
                                       getLocalGraphicsEnvironment();
        final GraphicsDevice[] physicalScreens = ge.getScreenDevices();
        final TreeMap<Integer, Rectangle>m=new TreeMap<Integer, Rectangle>();
        if (physicalScreens.length > 1) {
            final Rectangle b=window.getBounds();
            
            for (int i = 0; i < physicalScreens.length; i++) {
                final GraphicsConfiguration gc = physicalScreens[i].
                                                 getDefaultConfiguration();
                final Rectangle physicalScreen = gc.getBounds();
                if (physicalScreen != null){
                	final int portion=getPortion(b, physicalScreen);
                    m.put(portion, physicalScreen);                    
                }
            }
        }
        if (m.size()>0){
        	final int key=m.lastKey();
        	final Rectangle ret=m.get(key);
        	return ret;
        }
        final Dimension d = java.awt.Toolkit.getDefaultToolkit().getScreenSize();
        return new Rectangle(0, 0, d.width, d.height);
    }

    
    private static int getPortion(final int leftStart, final int leftSize, final int rightStart, final int rightSize){
    	int portion=0;
    	int leftSpan=leftStart+leftSize, rightSpan=rightStart+rightSize;
		
    	if (leftStart<rightStart){
    		if (leftSpan>rightStart){
    			if (rightSpan>leftSpan){ // window's right side is in screen
    				portion=leftSpan-rightStart;
    			} else {
    				portion=rightSize;
    			}
    		}
    	} else {
    		if (leftStart < rightSpan){
    			if (leftSpan<rightSpan){
    				portion=leftSize;
    			} else {
    				portion=rightSpan-leftStart;
    			}
    		}
    	}
    	return portion;
    }

    
    private static int getPortion(final Rectangle w, final Rectangle s){
    	final int width=getPortion(w.x, w.width, s.x, s.width);
    	final int height=getPortion(w.y, w.height, s.y, s.height);
    	return width*height;
    }

    public static void updateTable(final JTable t, final String[][]data, 
    		final int []modelColumns, final int []modelRows) 
    				throws Exception{
    	final int R=data.length;
    	if (R!=modelRows.length){
    		throw(new Exception("Must have as many modelRows as data rows: " + R + "!"));
    	}
    	if(R!=t.getRowCount()){
    		throw(new Exception("JTable must have as many rows as data rows: " + R + "!"));	
    	}
    	final int C=modelColumns.length;
    	final int []vcs=new int[C];
    	for (int i=0;i<C;i++){
    		vcs[i]=t.convertColumnIndexToView(modelColumns[i]);
    	}
    	for (int vr=0;vr<R;vr++){
    		final int mr=modelRows[vr];
    		for (int c=0;c<C;c++){
    			final int vc=vcs[c];
    			final String value=data[mr][modelColumns[c]];
    			if (value==null){
    				t.setValueAt("", vr, vc);
    			} else {
    				t.setValueAt(value, vr, vc);
    			}
    		}
    	}
    }
}
