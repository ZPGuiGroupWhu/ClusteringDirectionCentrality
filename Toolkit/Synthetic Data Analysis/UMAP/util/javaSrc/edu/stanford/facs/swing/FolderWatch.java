/***  
 * Author: Stephen Meehan, swmeehan@stanford.edu
 * 
 * Provided by the Herzenberg Lab at Stanford University
 * 
 * License: BSD 3 clause
 */

package edu.stanford.facs.swing;
import static java.nio.file.LinkOption.NOFOLLOW_LINKS;
import static java.nio.file.StandardWatchEventKinds.ENTRY_CREATE;
import static java.nio.file.StandardWatchEventKinds.ENTRY_DELETE;
import static java.nio.file.StandardWatchEventKinds.ENTRY_MODIFY;
import static java.nio.file.StandardWatchEventKinds.OVERFLOW;

import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.io.File;
import java.io.IOException;
import java.nio.file.FileSystem;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.WatchEvent;
import java.nio.file.WatchEvent.Kind;
import java.nio.file.WatchKey;
import java.nio.file.WatchService;
import java.util.ArrayList;

import javax.swing.JButton;
import javax.swing.SwingUtilities;

import com.sun.nio.file.SensitivityWatchEventModifier;

public class FolderWatch {
	private boolean alive=true;
	private final boolean logToStdOut;
	public final String folder;
	WatchKey key = null;
	public boolean isAlive() {
		return alive;
	}
	
	public void close() {
		alive=false;
		if (key !=null) {
			try {
				if (logToStdOut) {
					System.out.println(
							"Closed ALL watches on \""
							+ folder + "\"");
				}
				key.cancel();
			} catch (RuntimeException re) {
				re.printStackTrace();
			}
		}
	}
	public FolderWatch(
			final String folder, 
			final boolean logToStdOut) {
		this.folder=folder;
		this.logToStdOut=logToStdOut;
	}
	public FolderWatch(
			final String folder, 
			final boolean created, 
			final boolean modified, 
			final boolean deleted,
			final JButton click, 
			final boolean logToStdOut,
			final String priority) {
		this(folder, logToStdOut);
		Thread t=new Thread(new Runnable() {
			public void run() {
				watch(click, created,modified,deleted, priority);
			}
		});
		t.start();
	}

	@SuppressWarnings("unchecked")
	public void watch(
			final JButton click,
			final boolean created, 
			final boolean modified, 
			final boolean deleted,
			final String priority) {
		Path path =new File(folder).toPath();
		try {
			final Boolean isFolder = (Boolean) Files.getAttribute(path,
					"basic:isDirectory", NOFOLLOW_LINKS);
			if (!isFolder) {
				throw new IllegalArgumentException("Path: " + path
						+ " is not a folder");
			}
		} catch (IOException ioe) {
			// Folder does not exist
			ioe.printStackTrace();
		}
		if (logToStdOut) {
			System.out.print("Watching path: " + path + " with ");
		}
		final FileSystem fs = path.getFileSystem();

		try (
			final WatchService service = fs.newWatchService()) {
			final SensitivityWatchEventModifier modifier;
			if (priority.equalsIgnoreCase("low")) {
				modifier=SensitivityWatchEventModifier.LOW;
				if (logToStdOut) System.out.print("low");
			} else if (priority.equals("medium")){
				modifier=SensitivityWatchEventModifier.MEDIUM;
				if (logToStdOut) System.out.print("medium");
			} else {
				modifier=SensitivityWatchEventModifier.HIGH;
				if (logToStdOut) System.out.print("high");
			}
			if (logToStdOut) System.out.println(" priority ("
			+modifier.sensitivityValueInSeconds() + " second sensitity )" );
			final ArrayList<WatchEvent.Kind> c=new ArrayList<>(3);
			if (deleted)c.add(ENTRY_DELETE);
			if (created)c.add(ENTRY_CREATE);
			if (modified)c.add(ENTRY_MODIFY);
			final WatchEvent.Kind []kinds=c.toArray(
					new WatchEvent.Kind[c.size()]);
			path.register(service, kinds, modifier	);
			String eventType=null;
			Path newPath=null;
			
			while (alive) {
				key = service.take();
				Kind<?> kind = null;
				for (WatchEvent<?> watchEvent : key.pollEvents()) {
					if (!alive) {
						System.out.println("Watch has been closed!!!");
						break;
					}
					kind = watchEvent.kind();
					if (OVERFLOW == kind) {
						continue; 
					} else if (ENTRY_DELETE == kind) {
						newPath = ((WatchEvent<Path>) watchEvent)
								.context();
						eventType="Deleted";
					}else if (ENTRY_CREATE == kind) {
						newPath = ((WatchEvent<Path>) watchEvent)
								.context();
						eventType="Created";
					} else if (ENTRY_MODIFY == kind) {
						newPath = ((WatchEvent<Path>) watchEvent)
								.context();
						eventType="Modified" ;
					}
					// Output
					final String actionCommand=eventType + ": " + newPath;
					if (click != null) {
						notify(click, actionCommand, logToStdOut);
					} else if (logToStdOut) {
						System.out.println(actionCommand);
					} else {
						System.err.println(actionCommand);
					}
				}
				if (!key.reset()) {
					break; // loop
				}
				if (!alive) {
					break;
				}
			}
		} catch (final IOException ioe) {
			ioe.printStackTrace();
		} catch (final InterruptedException ie) {
			ie.printStackTrace();
		}
		if (logToStdOut) {
			System.out.println("Exiting watch on \""
					+ folder + "\"");
		}

	}

	static void notify(
			final JButton click, 
			final String actionCommand, 
			final boolean logToStdOut) {
		SwingUtilities.invokeLater(new Runnable() {
			public void run() {
				click.setActionCommand(actionCommand);
				click.doClick();
				if (logToStdOut) {
					System.out.println("Clicked button labeled \"" 
							+ click.getText() +", with action \""
							+ actionCommand + "\"");
				}
			}
		});
	}
	
	public static void main(final String[] args)
					throws IOException, InterruptedException {
		final String dir = "/Users/swmeehan/Downloads";
		final JButton btn=new JButton();
		final FolderWatch wf=new FolderWatch(dir, true, true,
				true, btn, false, "medium");
		btn.addActionListener(new ActionListener() {
			public void actionPerformed(final ActionEvent e) {
				final String ac=btn.getActionCommand();
				System.out.println("test button actionPerformed(): \""+ac +"\"");
				if (ac.equals("Deleted: duh.txt")) {
					System.out.println("STOPPING folder watch");
					wf.close();
				}
			}
		});
	}
}