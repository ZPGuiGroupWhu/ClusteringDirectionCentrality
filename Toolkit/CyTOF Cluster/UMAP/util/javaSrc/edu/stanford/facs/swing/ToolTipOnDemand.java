/***
 * Author: Stephen Meehan, swmeehan@stanford.edu
 * 
 * Provided by the Herzenberg Lab at Stanford University
 * 
 * License: BSD 3 clause
 * 
 * Provides method to force tool tips to show as hints without need to hover over swing component.
 */

package edu.stanford.facs.swing;


/*
 * @(#)ToolTipManager.java	1.65 03/01/23
 *
 * Copyright 2003 Sun Microsystems, Inc. All rights reserved.
 * SUN PROPRIETARY/CONFIDENTIAL. Use is subject to license terms.
 */

import javax.swing.*;
import javax.swing.border.BevelBorder;
import javax.swing.border.Border;
import javax.swing.plaf.ToolTipUI;

import java.awt.event.*;
import java.awt.*;
import java.util.TreeMap;

public class ToolTipOnDemand
	extends MouseAdapter{
        public static boolean isEmpty(final String inputString) {

        return inputString == null ||
          inputString.trim().length() == 0;
    }
    	    
		    static Border 	BORDER_EMPTY = BorderFactory.createEmptyBorder(), 
		    		BORDER_MAJOR=new BevelBorder(
		    				BevelBorder.RAISED,
		    				Color.WHITE,
		    				Color.BLACK) {
		    	/**
								 * 
								 */
								private static final long serialVersionUID = 1L;

				public Insets getBorderInsets(Component c) {
		    		return new Insets(3, 3, 6, 6);
		    	}
		    };

    public final static JButton getButton(
  	      final String txt,
  	      final int mnemonic,
  	      final ActionListener action,
  	      final String toolTip) {
      final JButton button = new JButton(txt);
      button.setMnemonic(mnemonic);
      if (toolTip != null) {
          button.setToolTipText(toolTip);
      }
      button.addActionListener(action);        
      return button;
  }



    
     

  private Timer insideTimer;
  private JComponent insideComponent;
  private final static ToolTipOnDemand singleton=new ToolTipOnDemand();
  transient Popup tipWindow;
  /** The Window tip is being displayed in. This will be non-null if
   * the Window tip is in differs from that of insideComponent's Window.
   */
  private Window window;
  
  class MyToolTip extends JToolTip{
	  /**
	 * 
	 */
	private static final long serialVersionUID = 1L;

	public void set(ToolTipUI tu){
		  super.setUI(tu);
		  setOpaque(true);
	  }
  };

  private MyToolTip tip;
  
  public void turnOffTimer(){
	  if(insideTimer!=null &&insideTimer.isRunning())
	  insideTimer.stop();
  }
  public void turnOnTimer(){
	  if(insideTimer!=null &&!insideTimer.isRunning())
	  insideTimer.restart();
  }
  private Rectangle popupRect=null;
  private Rectangle popupFrameRect=null;

  private boolean enabled=true;
  
  private FocusListener focusChangeListener=null;

  private ToolTipOnDemand(){
	insideTimer=new Timer(4000, new stillInsideTimerAction());
	insideTimer.setRepeats(false);
  }

  /**
   * Returns true if this object is enabled.
   *
   * @return true if this object is enabled, false otherwise
   */
  public boolean isEnabled(){
	return enabled;
  }

  /**
   * Specifies the dismissal delay value.
   *
   * @param milliseconds  the number of milliseconds to delay
   *        before taking away the tooltip
   * @see #getDismissDelay
   */
  public void setDismissDelay(int milliseconds){
	insideTimer.setInitialDelay(milliseconds);
  }

  /**
   * Returns the dismissal delay value.
   *
   * @return an integer representing the dismissal delay value,
   *		in milliseconds
   * @see #setDismissDelay
   */
  public int getDismissDelay(){
	return insideTimer.getInitialDelay();
  }


    public void showLater(final JComponent component){
        showLater(component, false, null);
    }
    
    public void showLater(final JComponent component, final String temporaryTip){
        showLater(component, false, null, component.getWidth()-5,
                component.getHeight(), false, temporaryTip);
    }
    
    public void showLater(final JComponent component,final boolean hideWhenFocusLost, final Component bottomComponent){
    	showLater(component,hideWhenFocusLost, bottomComponent, 
            component.getWidth()-5,
            component.getHeight());
    }
    public void showLater(final JComponent component,final boolean hideWhenFocusLost, final Component bottomComponent, final int rightOffset, final int bottomOffset){
    	showLater(component, hideWhenFocusLost, bottomComponent, rightOffset, bottomOffset, false);
    }    
    
    public void showLater(final JComponent component,final boolean hideWhenFocusLost, final Component bottomComponent, final int rightOffset, final int bottomOffset, final boolean hideCancelAtTopRight){
    SwingUtilities.invokeLater(new Runnable(){
      public void run(){
  		final JButton b=cancel;

    	  if(hideCancelAtTopRight){
    			cancel=null;
    	  }
        show(
            component,
            hideWhenFocusLost,
            rightOffset,
            bottomOffset,
            bottomComponent,null);
        cancel=b;
      }
    });
  }

    public void showLater(final JComponent component,final boolean hideWhenFocusLost, final Component bottomComponent, final int rightOffset, final int bottomOffset, final boolean hideCancelAtTopRight, final String toolTip){
        SwingUtilities.invokeLater(new Runnable(){
          public void run(){
      		final JButton b=cancel;

        	  if(hideCancelAtTopRight){
        			cancel=null;
        	  }
            show(
                component,
                hideWhenFocusLost,
                rightOffset,
                bottomOffset,
                bottomComponent, toolTip);
            cancel=b;
          }
        });
      }

  public void show(
	  final JComponent component,
	  final boolean hideWhenFocusLost){
	show(component, hideWhenFocusLost, component.getWidth()-5, component.getHeight()-5);
  }

  public void showWithCloseButton(
      final JComponent component){
    show(component, false, component.getWidth()-5, component.getHeight()-5, true);
  }


  public void show(
      final JComponent component,
      final boolean hideWhenFocusLost,
      final int widthOffset,
      final int heightOffset){
      show(
        component,
        hideWhenFocusLost,
        widthOffset,
        heightOffset,
        false);
  }

  public void show(
		  final JComponent component,
		  final boolean hideWhenFocusLost,
		  final int widthOffset,
		  final int heightOffset,
	      final boolean userMustClose){
	  show(component, hideWhenFocusLost, widthOffset, heightOffset, userMustClose, true);
  }
  public void show(
	  final JComponent component,
	  final boolean hideWhenFocusLost,
	  final int widthOffset,
	  final int heightOffset,
      final boolean userMustClose,
      final boolean cancelAtTopRight){
	  final JButton b=cancel;
	  if (!cancelAtTopRight || userMustClose) {
		  cancel=null;
	  }
      show(
        component,
        hideWhenFocusLost,
        widthOffset,
        heightOffset,
        userMustClose ? getButton("Close", 'c', new ActionListener() {
          public void actionPerformed(final ActionEvent e) {
              hideTipWindow();
          }
      }, null):null,null);
      cancel=b;
  }
  public void setAlternateLocation(final Point p){
	  alternateLocation=p;
  }
  private Point alternateLocation=null;

  public static void popup(final JComboBox cmb){
	  cmb.setVisible(true);
	  SwingUtilities.invokeLater(new Runnable() {
		public void run() {
			SwingUtilities.invokeLater(new Runnable() {
				
				@Override
				public void run() {
					SwingUtilities.invokeLater(new Runnable() {
						public void run() {
							SwingUtilities.invokeLater(new Runnable() {
								
								@Override
								public void run() {
									cmb.setPopupVisible(true);
									
								}
							});
						}
					});			
				}
			});
		}
	});
  }
  private static Border empty=BorderFactory.createEmptyBorder(1, 0, 0, 0) ;
  public boolean left2Right=false;
  public void show(
      final JComponent component,
      final boolean hideWhenFocusLost,
      final int widthOffset,
      final int heightOffset,
      final Component anyComponentYouWant,
      String toolTipText){
	  hideOnMouseExitIfComponentIsInvisible=true;
      if (component == null || !component.isShowing() || component==insideComponent) {
          return;
      }
      close();
      if (anyComponentYouWant == null) {
          component.addMouseListener(this);
      }
      insideComponent = component;
      if(toolTipText == null) {
    	  toolTipText = component.getToolTipText();
    	  if(toolTipText == null && anyComponentYouWant==null) {
    		  return;
    	  }
      }
      final boolean emptyTxt=toolTipText.equals("<html></html>");
      
      final Point preferredLocation = new Point(widthOffset, heightOffset); // manual set
      if (enabled) {
          Window componentWindow = SwingUtilities.windowForComponent(insideComponent);

          final Rectangle sBounds = SwingUtil2.getScreen(insideComponent);
          boolean leftToRight
            = insideComponent.getComponentOrientation().isLeftToRight();

          // Just to be paranoid
          hideTipWindow();

          tip = new MyToolTip();
          
          tip.setComponent(insideComponent);
          
          tip.setTipText(toolTipText);
          
          final PopupFactory popupFactory = PopupFactory.getSharedInstance();
          final JPanel jp=new JPanel(new BorderLayout(0,0));
          if (northCentralComponent == null || cancel != null){
        	  if (toolTipText == null || !toolTipText.startsWith("<html>")){
        		  tip.setBorder(empty);
        	  }else {
            	  tip.setBorder(BORDER_EMPTY);              
              }
          } else {
        	  tip.setBorder(BORDER_EMPTY);              
          }
          if (!emptyTxt){
        	  jp.add(tip, BorderLayout.CENTER);
          }
          jp.setBackground(tip.getBackground());
            if (anyComponentYouWant != null) {
              if (westPanel != null){
                  westPanel.setBackground(tip.getBackground());
                  westPanel.setOpaque(true);
                  jp.add(westPanel, BorderLayout.EAST);
              }
              final JPanel jp2 = new JPanel(new FlowLayout(FlowLayout.LEFT,0,0));
              if (!emptyTxt){
            	  //System.out.println("extra component ...");
            	  jp2.setBorder(BorderFactory.createEmptyBorder(0,0,1,0));
              }
              if (! (anyComponentYouWant instanceof JButton)){
            	  anyComponentYouWant.setBackground(tip.getBackground());
            	  if (anyComponentYouWant instanceof JComponent){
            		  ( (JComponent)anyComponentYouWant).setOpaque(true);
            	  }
              }
              jp2.add(anyComponentYouWant);
              jp2.setBackground(tip.getBackground());
              jp2.setOpaque(true);
              if (emptyTxt){
            	  jp.add(jp2, BorderLayout.CENTER);
              }else{
            	  jp.add(jp2, BorderLayout.SOUTH);
              }
          } 
          final JPanel jp3 = new JPanel(new BorderLayout(0,0));
          jp3.setBackground(tip.getBackground());
          jp3.setOpaque(true);
          
          if (northCentralComponent != null){
        	  jp3.add(northCentralComponent);
        	  northCentralComponent.setBackground(tip.getBackground());
        	  northCentralComponent.setOpaque(true);
          }
          if (cancel != null) {
              jp3.add(cancel, BorderLayout.EAST);              
              cancel.setBackground(tip.getBackground());
              cancel.setOpaque(true);
          }
          if (northCentralComponent != null || cancel != null){
        	  if (northCentralComponent==null){
        		  jp.add(jp3, BorderLayout.NORTH);
        	  }else{
        		  final JPanel jp2 = new JPanel(new BorderLayout(0,0));
        		  jp2.setBackground(tip.getBackground());
        		  jp2.setOpaque(true);
        		  jp2.add(jp3, BorderLayout.EAST);
        		  jp.add(jp2,BorderLayout.NORTH);
        	  }
          }
		ToolTipManager.sharedInstance().setEnabled(false);
			
		Dimension size;
        Point screenLocation = insideComponent.isShowing()?insideComponent.getLocationOnScreen():alternateLocation;
        Point location = new Point();
        
		size = jp.getPreferredSize();
        
        location.x = screenLocation.x + preferredLocation.x;
        location.y = screenLocation.y + preferredLocation.y;
        if (!leftToRight || left2Right) {
            location.x -= size.width;
        }

        // we do not adjust x/y when using awt.Window tips

        if (popupRect == null) {
            popupRect = new Rectangle();
        }
        popupRect.setBounds(location.x, location.y,
                            size.width, size.height);

        int y = getPopupFitHeight(popupRect, insideComponent);
        int x = getPopupFitWidth(popupRect, insideComponent);

        if (y > 0 && heightOffset == 0) {
            location.y -= y;
        }
        if (x > 0 && widthOffset == 0) {
            // adjust
            location.x -= x;
        }

        // Fit as much of the tooltip on screen as possible
        if (location.x < sBounds.x) {
            location.x = sBounds.x;
        } else if (location.x - sBounds.x + size.width > sBounds.width) {
            location.x = sBounds.x + Math.max(0, sBounds.width - size.width);
        }
        //System.out.print(""+location.x+"/"+location.y+" w="+size.width+",h="+size.height+"; ");
        //System.out.println(""+sBounds.x+"/"+sBounds.y+" w="+sBounds.width+",h="+sBounds.height+"; ");
        //System.out.println(""+(location.y - sBounds.y + size.height)+">"+ sBounds.height);
        if (location.y < sBounds.y) {
            location.y = sBounds.y;
        } else if (location.y - sBounds.y + size.height > sBounds.height) {
            location.y = sBounds.y + Math.max(0, sBounds.height - size.height);
            //System.out.println("NEW Y="+location.y);
        }

          tipWindow = popupFactory.getPopup(insideComponent, jp,
                                            location.x,
                                            location.y);


          tipWindow.show();

          window = SwingUtilities.windowForComponent(tip);
          if (window != null && window != componentWindow) {
              if (anyComponentYouWant==null) {
                  window.addMouseListener(this);
              }
          } else {
              window = null;
          }

          insideTimer.start();
          if (anyComponentYouWant==null) {

              if (hideWhenFocusLost) {
                  // put a focuschange listener on to bring the tip down
                  if (focusChangeListener == null) {
                      focusChangeListener = createFocusChangeListener();
                  }
                  insideComponent.addFocusListener(focusChangeListener);
              }

          }
      }
  }

  public static void hideManagerWindow(){
	  if (ToolTipManager.sharedInstance()!=null){
		  ToolTipManager.sharedInstance().setEnabled(false);
		  ToolTipManager.sharedInstance().setEnabled(true);
	  }
  }
  private JButton cancel;
  private JComponent northCentralComponent;
  public void setNorthCentralComponent(final JComponent cmp){
	  this.northCentralComponent=cmp;
  }
  
  public JButton setCancel(final String icon){
	  final JButton prev=this.cancel;
      this.cancel=new ImageButton(icon, null);
      this.cancel.addActionListener(new ActionListener() {
			public void actionPerformed(final ActionEvent e) {
				ToolTipOnDemand.getSingleton().hideTipWindow();
			}});
      return prev;
  }
  
  private ActionListener closeListener=null;
  public void addOneTimeCloseListener(final ActionListener al){
	  closeListener=al;
  }
  
  public void hideTipWindow(){
	if (tipWindow != null){
	  if (window != null){
		window.removeMouseListener(this);
		window=null;
	  }
	  tipWindow.hide();
      ToolTipManager.sharedInstance().setEnabled(true);
	  tipWindow=null;
	  (tip.getUI()).uninstallUI(tip);
	  tip=null;
	  insideTimer.stop();
	}
	if (closeListener!=null){
		closeListener.actionPerformed(new ActionEvent(this,0,"close"));
		closeListener=null;
	}
  } 

  /**
   * Returns a shared <code>ToolTipDispatcher</code> instance.
   *
   * @return a shared <code>ToolTipDispatcher</code> object
   */
  public static ToolTipOnDemand getSingleton(){      
    return singleton;
  }

  // implements java.awt.event.MouseListener
  /**
   *  Called when the mouse exits the region of a component.
   *  Any tool tip showing should be hidden.
   *
   *  @param event  the event in question
   */
  public void mouseExited(MouseEvent event){
	boolean shouldHide=true;
	if (insideComponent != null){

	  if (window != null && event.getSource() == window){
		// if we get an exit and have a heavy window
		// we need to check if it if overlapping the inside component
		final Container insideComponentWindow=insideComponent.getTopLevelAncestor();
		Point location=event.getPoint();
		if (location != null && insideComponentWindow!=null){
		  SwingUtilities.convertPointToScreen(location, window);

		  location.x-=insideComponentWindow.getX();
		  location.y-=insideComponentWindow.getY();

		  location=SwingUtilities.convertPoint(null, location, insideComponent);
		  if (location.x >= 0 && location.x < insideComponent.getWidth() &&
			  location.y >= 0 && location.y < insideComponent.getHeight()){
			shouldHide=false;
		  }
		  else{
			shouldHide=true;
		  }
		}
	  }	  else if (event.getSource() == insideComponent && tipWindow != null){
		final Window win=SwingUtilities.getWindowAncestor(insideComponent);
		if (win != null){ // insideComponent may have been hidden (e.g. in a menu)
		  final Point location=SwingUtilities.convertPoint(insideComponent,
			  event.getPoint(),
			  win);
		  if (location != null){
			final Rectangle bounds=insideComponent.getTopLevelAncestor().getBounds();
			location.x+=bounds.x;
			location.y+=bounds.y;

			final Point loc=new Point(0, 0);
			SwingUtilities.convertPointToScreen(loc, tip);
			bounds.x=loc.x;
			bounds.y=loc.y;
			bounds.width=tip.getWidth();
			bounds.height=tip.getHeight();

			if (location.x >= bounds.x && location.x < (bounds.x + bounds.width) &&
				location.y >= bounds.y &&
				location.y < (bounds.y + bounds.height)){
			  shouldHide=false;
			}
			else{
			  shouldHide=true;
			}
		  }
		}
	  }
	}

	if (shouldHide && hideOnMouseExitIfComponentIsInvisible){
	  close();
	}
  }
  
  public boolean hideOnMouseExitIfComponentIsInvisible=true;

  // implements java.awt.event.MouseListener
  /**
   *  Called when the mouse is pressed.
   *  Any tool tip showing should be hidden.
   *
   *  @param event  the event in question
   */
  public void mousePressed(MouseEvent event){
	close();
  }

  public void close(){
	hideTipWindow();
	if (insideComponent != null){
	  insideComponent.removeMouseListener(ToolTipOnDemand.this);
	  insideComponent=null;
	}
  }

  protected class stillInsideTimerAction
	  implements ActionListener{
	public void actionPerformed(ActionEvent e){
	  close();
	}
  }

  static Frame frameForComponent(Component component){
	while (!(component instanceof Frame)){
	  component=component.getParent();
	}
	return (Frame) component;
  }

  private FocusListener createFocusChangeListener(){
	return new FocusAdapter(){
	  public void focusLost(FocusEvent evt){
		close();
		JComponent c=(JComponent) evt.getSource();
		c.removeFocusListener(focusChangeListener);
	  }
	};
  }

  // Returns: 0 no adjust
  //         -1 can't fit
  //         >0 adjust value by amount returned
  private int getPopupFitWidth(Rectangle popupRectInScreen, Component invoker){
	if (invoker != null){
	  Container parent;
	  for (parent=invoker.getParent(); parent != null; parent=parent.getParent()){
		// fix internal frame size bug: 4139087 - 4159012
		if (parent instanceof JFrame || parent instanceof JDialog ||
			parent instanceof JWindow){ // no check for awt.Frame since we use Heavy tips
		  return getWidthAdjust(parent.getBounds(), popupRectInScreen);
		}
		else if (parent instanceof JApplet || parent instanceof JInternalFrame){
		  if (popupFrameRect == null){
			popupFrameRect=new Rectangle();
		  }
		  Point p=parent.getLocationOnScreen();
		  popupFrameRect.setBounds(p.x, p.y,
								   parent.getBounds().width,
								   parent.getBounds().height);
		  return getWidthAdjust(popupFrameRect, popupRectInScreen);
		}
	  }
	}
	return 0;
  }

  // Returns:  0 no adjust
  //          >0 adjust by value return
  private int getPopupFitHeight(Rectangle popupRectInScreen, Component invoker){
	if (invoker != null){
	  Container parent;
	  for (parent=invoker.getParent(); parent != null; parent=parent.getParent()){
		if (parent instanceof JFrame || parent instanceof JDialog ||
			parent instanceof JWindow){
		  return getHeightAdjust(parent.getBounds(), popupRectInScreen);
		}
		else if (parent instanceof JApplet || parent instanceof JInternalFrame){
		  if (popupFrameRect == null){
			popupFrameRect=new Rectangle();
		  }
		  Point p=parent.getLocationOnScreen();
		  popupFrameRect.setBounds(p.x, p.y,
								   parent.getBounds().width,
								   parent.getBounds().height);
		  return getHeightAdjust(popupFrameRect, popupRectInScreen);
		}
	  }
	}
	return 0;
  }

  private int getHeightAdjust(Rectangle a, Rectangle b){
	if (b.y >= a.y && (b.y + b.height) <= (a.y + a.height)){
	  return 0;
	}
	else{
	  return (((b.y + b.height) - (a.y + a.height)) + 5);
	}
  }

  // Return the number of pixels over the edge we are extending.
  // If we are over the edge the ToolTipDispatcher can adjust.
  // REMIND: what if the Tooltip is just too big to fit at all - we currently will just clip
  private int getWidthAdjust(Rectangle a, Rectangle b){
	//    System.out.println("width b.x/b.width: " + b.x + "/" + b.width +
	//		       "a.x/a.width: " + a.x + "/" + a.width);
	if (b.x >= a.x && (b.x + b.width) <= (a.x + a.width)){
	  return 0;
	}
	else{
	  return (((b.x + b.width) - (a.x + a.width)) + 5);
	}
  }

  private static JPanel westPanel;

  public static void setWestPanel(final JComponent westLabel){
      westPanel=new JPanel();
      westPanel.add(westLabel);
      westPanel.setBorder(BorderFactory.createEmptyBorder(1,1,0,0));

  }

  private class ShowOnEntry extends MouseAdapter {
		
		private final JComponent c;

		private ShowOnEntry(final JComponent c) {
			this.c = c;
		}

		public void mouseExited(final MouseEvent e) {
			if (!isEmpty(c.getToolTipText())) {
				hideTipWindow();				
			}
		}

		public void mouseEntered(final MouseEvent e) {
			if (!isEmpty(c.getToolTipText())) {
				showWithoutCancelButton(c, true, c.getWidth(), c.getHeight());
			}
		}
	}

	public static void doNotShowOnEntry(final MenuElement[] items) {
		for (final MenuElement item : items) {
			final Component c = item.getComponent();
			final MouseListener[] ml = c.getMouseListeners();
			for (final MouseListener m : ml) {
				if (m instanceof ToolTipOnDemand.ShowOnEntry) {
					c.removeMouseListener(m);
				}
			}
			doNotShowOnEntry(item.getSubElements());
		}
	}

	public void showOnEntry(final MenuElement[] items) {
		for (final MenuElement item : items) {
			if (item.getComponent() instanceof JComponent) {
				final JComponent c = (JComponent) item.getComponent();
				c.addMouseListener(new ShowOnEntry(c));
			}
			showOnEntry(item.getSubElements());
		}
	}

	public boolean isMouseOver() {
		if (window != null) {
			final Point p = window.getMousePosition();
			return p != null;
		}
		return false;
	}
	
	public void showWithoutCancelButton(final JComponent c, final boolean hideWhenFocusLost, final int x, final int y){		
		final JButton b=cancel;
		cancel=null;
		show(c, hideWhenFocusLost, x, y);
		cancel=b;
	}
	
	public void shutOffCloseTimer(){
		insideTimer.stop();
	}
}

