/***
 * Author: Stephen Meehan, swmeehan@stanford.edu
 * 
 * Provided by the Herzenberg Lab at Stanford University
 * 
 * License: BSD 3 clause
 * 
 * Provides chatty alternative to MatLab's mute websave command.  MatLab code can invoke
 * this service via the wrappers found In WebDownload.m.
 */

package edu.stanford.facs.swing;

import java.awt.BorderLayout;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.io.BufferedInputStream;
import java.io.BufferedOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.InetAddress;
import java.net.InetSocketAddress;
import java.net.MalformedURLException;
import java.net.Socket;
import java.net.SocketAddress;
import java.net.SocketTimeoutException;
import java.net.URL;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Iterator;
import java.util.Map;
import java.util.Properties;
import java.util.Set;

import javax.swing.BorderFactory;
import javax.swing.JButton;
import javax.swing.JDialog;
import javax.swing.JLabel;
import javax.swing.JPanel;
import javax.swing.JProgressBar;
import javax.swing.SwingUtilities;

public class WebDownload {
	private static String DefaultGoogleDirUrl="https://drive.google.com/file/d/1r_ByRnrq7SWvfLa2uGdwE31IY1ClXVdy/view?usp=sharing";
	
	public static String SetDefaultGoogleDirUrl(final String url) {
		final String prior=DefaultGoogleDirUrl;
		DefaultGoogleDirUrl=url;
		return prior;
	}

	public static String SetDefaultGoogleDirFile(final String localFile, final Collection<String>problems) {
		final String prior=GoogleDriveDir.DefaultGoogleDirLocalFile;
		GoogleDriveDir.DefaultGoogleDirLocalFile=localFile;
		GoogleDriveDir.props=null;
		GoogleDriveDir.DownloadProps(null, problems);
		return prior;
	}

	public static String GetDefaultGoogleDirFile() {
		return GoogleDriveDir.DefaultGoogleDirLocalFile;
	}
	
	public String googleDirUrl=null; // if NULL then use default

	public static void main(final String[] args) {
    	Test.main(args);
    }
	
    static class Test {
    	public static void main(final String []args) {
    		final String share="https://drive.google.com/file/d/1r_ByRnrq7SWvfLa2uGdwE31IY1ClXVdy/view?usp=sharing";
    		SetDefaultGoogleDirUrl(share);
    		ArrayList<String>problems=new ArrayList<>();
    		SetDefaultGoogleDirFile("/Users/swmeehan/myGoogleDir.properties", problems);
    	final Object txt=GoogleDirectDownloadLink("http://cgworkspace.cytogenie.org/GetDown2/domains/FACS/AutoGate2020a.tar");

    	final String []fileUrls, localFiles;
    	final WebDownload d=new WebDownload();
    	d.allowCancel=false;
    	d.waitWhenDone=true;
    	String link="https://drive.google.com/Samples/OMIP40Color/MC%203015036.fcs", 
    			link2="https://drive.google.com/Samples/OMIP40Color/MC%20303444.fcs";
    	SetDefaultGoogleDirUrl("https://drive.google.com/file/d/duh/view?usp=sharing");
    	final String prior=SetDefaultGoogleDirFile("/Users/swmeehan/foobar.properties", new ArrayList<String>());
    	d.go(new String[] {link2},new String[] {"/Users/swmeehan/omip40_2nd.fcs"}, true);
    	d.go(new String[] {link},new String[] {"/Users/swmeehan/omip40_1st.fcs"}, true);
    	SetDefaultGoogleDirFile(prior, new ArrayList<String>());
    	link=
    			"https://drive.google.com/uc?export=download&id=189nZplhvj804H2M4KPBz6vjU2JOTvHCk";
    	//final String link0="https://drive.google.com/run_umap/examples/s10_samusikImported_29D.csv";
    	//final String link0="https://drive.google.com/run_umap/examples/colorsByName.properties";
    	//final String link0="https://drive.google.com/run_umap/examples/sample30k.csv";
    	//d.go(new String[] {(String)GoogleDirectDownloadLink(link0)},new String[] {"/Users/swmeehan/s10.csv"}, true);
//    	final String link0="https://drive.google.com/GetDown2/domains/FACS/version2020a_mac.txt";
    	final String link0="https://drive.google.com/run_umap/examples/ust_s1_samusikImported_29D_30nn_2D.mat";
    	//final String link0="http://cgworkspace.cytogenie.org/run_umap/examples/sample30k.csv";
    	d.go(new String[] {link0},new String[] {"/Users/swmeehan/s10.csv"}, true);
    	final String link1="https://drive.google.com/file/d/189nZplhvj804H2M4KPBz6vjU2JOTvHCk/view?usp=sharing";
    	link2="https://filetransfer.io/data-package/GGamU3ZY?do=download";
    	d.connect(link1, null);
    	if (args.length<3) {
    		//final String fldr="http://cgworkspace.cytogenie.org/run_umap/examples/";
    		
    		final String fldr="http://54.39.2.45/run_umap/examples/";
    		System.out.println("Demo download from "+ fldr +"...");
    		final String home = System.getProperty("user.home");
    		final String []examples= {   
    				"s3_samusikManual_19D", 
    				"s4_samusikManual_19D",
    				"s5_samusikManual_s19D"
    		};
    		fileUrls= new String[examples.length*2];
    		final String local=home + File.separator+"Documents"+File.separator+"run_umap" 
			+ File.separator + "examples" + File.separator;
    		localFiles=new String[examples.length*2];
    		for (int i=0;i<examples.length;i++){
    			fileUrls[i]=fldr+examples[i]+".csv";
    			localFiles[i]=local+examples[i]+".csv";
    		};
    		for (int i=0;i<examples.length;i++){
    			fileUrls[examples.length+i]=fldr+examples[i]+".properties";
    			localFiles[examples.length+i]=local+examples[i]+".properties";
    		};
    	} else {
    		if (args.length%2 != 1) {
    			System.err.println("USAGE:  "+args[0]+ " 1 or more pairs of URL source and local file destintation");
    			return;
    		}
    		int N=(args.length-1)/2;
    		fileUrls=new String[N];
    		localFiles=new String[N];
    		for (int i=1;i<N;i+=2) {
    			fileUrls[i]=args[i];
    			localFiles[i]=args[i+1];
    		}
    	}
		System.out.println("Checking main arguments first");
		for (int i=0;i<fileUrls.length;i++) {
			if (!FileExists(fileUrls[i])) {
				System.out.println("Downloading looks unlikely for \""+fileUrls[i]+"\"");
			}
		}
    	d.go(fileUrls, localFiles, true);
    }
    }
    public boolean allowCancel=true, waitWhenDone=true;
    public JProgressBar progressBar;
    public final JPanel panel;
    public final JLabel north, south;
    public final JButton close, cancel;
    public JDialog dlg=null;
    final int readSize=8192;
    
    public WebDownload() {
    	googleDirUrl=DefaultGoogleDirUrl;
    	progressBar = new JProgressBar();
        progressBar.setMaximum(100000);
        panel=new JPanel(new BorderLayout(10,10));
        panel.add(progressBar, BorderLayout.CENTER);
        panel.setBorder(BorderFactory.createEmptyBorder(15, 15, 2, 20));
        north=new JLabel();
        panel.add(north, BorderLayout.NORTH);
        south=new JLabel();
        panel.add(south, BorderLayout.SOUTH);
        dlg = new JDialog();
        final JPanel main=new JPanel(new BorderLayout(10,10));
        dlg.setContentPane(main);
        main.add(panel, BorderLayout.CENTER);
        cancel=new JButton("Cancel");
        cancel.addActionListener(new ActionListener() {
			public void actionPerformed(ActionEvent e) {
				cancelled=true;
				dlg.setVisible(false);
			}
		});
        close=new JButton("Done");
        close.addActionListener(new ActionListener() {public void actionPerformed(ActionEvent e) {
				dlg.setVisible(false);
			}
		});
        close.setEnabled(false);
        final JPanel southEast=new JPanel();
        southEast.add(cancel);
        southEast.add(close);
        final JPanel buttons=new JPanel(new BorderLayout());
        buttons.add(southEast, BorderLayout.EAST);
        main.add(buttons, BorderLayout.SOUTH);
        dlg.setLocation(55, 200);
        dlg.setModal(true);
    }
    
        public boolean cancelled=false, done=false;
    public int bad=0;
    public Map<String, ArrayList<Con>>tooBigLocalFolderByRemoteFile=new HashMap<>();
    public Map<String, HashSet<String>>tooBigLocalFolderByRemoteFolder=new HashMap<>();
    public Collection<String>tooBigFiles=new ArrayList<>();
    public final Collection<String> problems=new ArrayList<>();
    public String getProblemHtml() { 
    	return "<html><h3>Download problems encountered:</h3>"
    			+HtmlList(problems)+"</html>";
    }
    void whine(final String problem) {
    	Whine(problems, problem);
    }
    
    static void Whine(final Collection<String> problems, 
    		final String prefix, final Exception ex) {
    	Whine(problems, prefix+":  "+ex.getMessage());
    }
    
    static void Whine(final Collection<String> problems, final String problem) {
    	System.err.println(problem);
    	if (problems != null) {
    		problems.add(problem);
    	}
    }
    
    public boolean go(final String []fileUrls, 
    		final String []localFiles, 
    		final boolean showDialog) {
    	problems.clear();
    	cancelled=false;
    	done=false;
    	bad=0;
    	final int N=fileUrls.length;
    	if (N==0) {
    		whine("No file urls provided!");
    		return false;
    	}
    	if (N != localFiles.length) {
    		whine(N+ " file urls BUT "+localFiles.length+" local files?");
    		return false;
    	}
    	close.setEnabled(false);

    	final String []fn=new String[N];
    	for (int i=0;i<N;i++) {
    		final int lastIndex=fileUrls[i].lastIndexOf('/');
    		if (lastIndex>0)
    			fn[i]=fileUrls[i].substring(lastIndex+1);
    		else
    			fn[i]=fileUrls[i];
    	}
    	final String howMany;
    	if (N>1) {
    		howMany=N+" files";
    	} else {
    		howMany="1 file";
    	}
    	int max=0, maxI=0;
    	for (int i=0;i<N;i++) {
    		if (fn[i].length()>max) {
    			max=fn[i].length();
    			maxI=i;
    		}
    	}
    	north.setText("<html><b>Downloading " + (maxI+1) + "/" 
    			+ N +": <font color='#008866['><i>"
    			+fn[maxI]+"</i></font></b></html>");
    	final Runnable downloader= new Runnable() {
    		
    		public void run() {
    			long sz=0l;
				final byte[] data = new byte[readSize];

				final Con []cons=new Con[N];
				for (int i=0;i<N;i++) {
					final String localFile=localFiles[i];
					final File fl=new File(localFile);
					final File parent=fl.getParentFile();
					if (parent != null && !parent.getAbsoluteFile().exists()) {
						final String yikes="Local folder does not exist \"" 
								+ fl.getParentFile().getPath()+"\"";
						whine(yikes);
						cancelled=true;
						SwingUtilities.invokeLater(new Runnable() {
							public void run() {
								south.setText("<html><font color='red'>"
										+yikes+"</font></htmnl>");
								if (showDialog)
									dlg.pack();
							}
						});
						return;
					} else {
						cons[i]=connect(fileUrls[i], problems);
						if (cons[i].http !=null){
							sz += cons[i].size;
							cons[i].disconnect();
						}
					}
				}
				final long totalBytes=sz;
				SwingUtilities.invokeLater(new Runnable() {
					public void run() {
						south.setText(howMany+", "+Numeric.encodeMb(totalBytes));
						if (showDialog)
							dlg.pack();
					}
				});
				boolean needToRefreshGoogleDir=false;
				long bytesSoFar = 0;
				for (int i=0;i<N;i++) {
					if (cons[i].http==null) 
						continue;
					final Con con=connect(fileUrls[i], problems);
					if (con.http==null) {
						cons[i].http=null;
						continue;
					}
					final String localFile=localFiles[i];
					boolean completed=true;
					int got=0;
					
					try {
						final int idx=i;
						SwingUtilities.invokeLater(new Runnable() {
							public void run() {
								if (N==1)
									north.setText("<html><b>Downloading"  
											+": <font color='#008866['><i>"
											+fn[idx].replace("%20", " ")+"</i></font></b></html>");
								else
									north.setText("<html><b>Downloading " + (idx+1) + "/" 
											+ N +": <font color='#008866['><i>"
											+fn[idx].replace("%20", " ")+"</i></font></b></html>");
							}
						});
						final long needToGet=con.size;
						final InputStream in = con.http.getInputStream();
						try {
							final FileOutputStream fos= 
									new FileOutputStream(localFile);
							final BufferedOutputStream bout = new BufferedOutputStream(
									fos, readSize);
							int x = 0;
							while ((x = in.read(data)) >= 0) {
								bytesSoFar += x;
								// calculate progress
								final int currentProgress = 
										(int) ((((double)bytesSoFar) / 
												((double)totalBytes)) * 100000d);
								// update progress bar
								SwingUtilities.invokeLater(new Runnable() {
									public void run() {
										progressBar.setValue(currentProgress);
									}
								});
								if (cancelled) {
									completed=false;
									break;
								}
								bout.write(data, 0, x);
								got+=x;
							}
							if (got!=needToGet && con.size>0) {
								if (con.url.startsWith(GoogleDriveDir.drive))
									needToRefreshGoogleDir=true;
									if (got<10000l && con.size > 98l*1024l) {
										if (fileUrls[i].startsWith(GoogleDriveDir.drive)) {
											final String localFolder=new File(localFile).getParent();
											{
												ArrayList<Con>l=tooBigLocalFolderByRemoteFile.get(localFolder);
												if (l==null) {
													l=new ArrayList<>();
													tooBigLocalFolderByRemoteFile.put(localFolder, l);
												}
												l.add(con);
											}
											if (con.folderUrl!=null) {
												HashSet<String>l2=tooBigLocalFolderByRemoteFolder.get(localFolder);
												if (l2==null) {
													l2=new HashSet<>();
													tooBigLocalFolderByRemoteFolder.put(localFolder, l2);
												}
												l2.add(con.folderUrl);
											}
											tooBigFiles.add(localFile);
										}
									}
									System.err.println(""+got+" of "+needToGet+" bytes downloaded!");
								//completed=false;
							}
							bout.close();
						} catch (final Exception e) {
							con.disconnect();
							cons[i].http=null;
							completed=false;
							whine("File output stream exception \"" 
									+ e.getMessage()+"\"");
						}
						in.close();
					}
					catch (final FileNotFoundException e) {
						whine("File not found: \"" 
								+ e.getMessage()+"\"");
						con.disconnect();
						cons[i].http=null;
						completed=false;
					} catch (final IOException e) {
						whine("IO exception \"" + e.getMessage()+"\"");
						con.disconnect();
						cons[i].http=null;
						completed=false;
					}
					if (!completed) {
						final File fl=new File(localFile);
						if (fl.exists()) {
							fl.delete();
							System.err.println("Download incomplete, removed \""
								+fl.getAbsolutePath()+"\"");
						}
						cons[i].http=null;
					}else {
						System.out.println("Download complete \""
								+localFile+"\" "+Numeric.encodeK(got)+" bytes");
					}
					if (cons[i]!=null) {
						con.disconnect();
						if (cancelled) {
							break;
						}
					}
				}
				SwingUtilities.invokeLater(new Runnable() {
					public void run() {
						if (!cancelled)
							done=true;
						int badI=0;
						for (int i=0;i<N;i++) {
							if (cons[i].http==null) {
								bad++;
								badI=i;
							}
						}
						if (bad>0) {
							if (bad==1)
								south.setText("<html><font color='red'>"+
										"Did <i><u>not</u></i> download \"<b>"+
										fn[badI]+"</b>\"</font>  ...</html>");
							else
								south.setText("<html><font color='red'>"+
										"Could <i><u>not</u></i> download <b>"+ 
										bad + " files</b></font> ...</html>");
							north.setText(
									"<html><b>Downloaded</b>: " 
									+"<font color='#FF0088'><b>only "+(N-bad)
									+"</b></font>/"+ N +" file(s)!</html>");
							if (showDialog) {
					    		dlg.pack();
							}
							final String tip=getProblemHtml();
							north.setToolTipText(tip);
							progressBar.setToolTipText(tip);
							south.setToolTipText(tip);
							close.setToolTipText(tip);
						} else {
							if (N==1)
								north.setText(
										"<html><b>Downloaded</b>: <font color='blue'>"
										+fn[0]+"</font>!</html>");
							else
								north.setText(
										"<html><b>Downloaded</b>: <font color='blue'>"
										+howMany+"</font>!</html>");

						}
						close.setEnabled(true);
						cancel.setEnabled(false);
						cancel.setVisible(false);
						if (showDialog) {
							dlg.getRootPane().setDefaultButton(close);
							if (!waitWhenDone)
								close.doClick(900);
						}
					}
				});
				if (needToRefreshGoogleDir) {
					GoogleDriveDir.DownloadProps(googleDirUrl, problems);
				}
    		}
    	};
    	final Thread thread=new Thread(downloader);
    	thread.start();
    	if (showDialog) {
    		cancel.setVisible(allowCancel);
    		dlg.pack();
    		dlg.setVisible(true);
    		System.out.println("All done");
        	return !cancelled;
    	} else {
    		try {
				thread.join();
			} catch (InterruptedException e) {
				e.printStackTrace();
			}
    		return true;
    	}
    }
    
    public Con connect(final String in, final Collection<String>problems) {
    	return GoogleDriveDir.Connect(in, googleDirUrl, problems);
    }
    
    public static HttpURLConnection GetConnection(
    		final String fileUrl, final Collection<String>problems ) {
    	HttpURLConnection http=null;
    	int response = HttpURLConnection.HTTP_NOT_FOUND;
		
    	try {
    		final URL url=new URL(fileUrl);
			if (CanReachHost(url, problems)) {
				try {
					http = (HttpURLConnection) (url.openConnection());
					http.setDoInput(true);
					http.setDoOutput(false);
					http.setUseCaches(false);
					http.setConnectTimeout(7000);
					http.setReadTimeout(7000);
					response=http.getResponseCode();
				} catch (final IOException e) {
					http=null;
					Whine(problems, "IO exception: \""+e.getMessage()+"\"");
				}
			}
		} catch (final MalformedURLException e) {
			Whine(problems, "Badly formed URL: \""+fileUrl +"\"");
		}
    	if (response != HttpURLConnection.HTTP_OK) {
    		if (problems!=null) {
    			problems.add("Http response code "+response+" received!");
    		}
    		http=null;
    	}
    	return http;
    }
    
    public static boolean FileExists(final String fileUrl) {
    	return FileExists(fileUrl, null);
    }
    public static boolean FileExists(final String fileUrl, final Collection<String>problems) {
    	boolean yes=false;
    	final HttpURLConnection http=GetConnection(fileUrl, problems);
    	if (http != null) {
    		try {
    			final BufferedInputStream in = 
    					new BufferedInputStream(http.getInputStream());
    			in.close();
    			yes=true;
    		} catch (final FileNotFoundException e) {
    			Whine(problems, "File not found: \""+e.getMessage()+"\"");
    		} catch (final IOException e) {
    			Whine(problems, "IO exception: \""+e.getMessage()+"\"");
    		}
    		http.disconnect();
    	}
     	return yes;
    }
    
    public static boolean CanReachHost(final URL url, final Collection<String>problems) {
    	final boolean ok;
    	final String host=url.getHost();
		if (host==null || host.trim().length()==0) {
			ok=false;
			Whine(problems, "Can not parse host name from \""+ url.toExternalForm()+"\"");
		} else {
			ok=CanReachHost(host, url.getPort(), 4500, problems);
		}
		return ok;
    }
    
    	    
    public static Exception lastReachableException=null;
    public static boolean CanReachHost(
    		final String host, int port,  
    		int timeout, final Collection<String>problems) {
    	if (port<0) {
    		port=80;
    	}
  		lastReachableException=null;
  		Socket socket = new Socket();
  		boolean online = true;
  		if (timeout==0){
  			timeout=9000; // Connect with 9 s timeout
  		}
  		final String complaint="Can not reach host \""+host +":" +port+"  because \"";
  		try {
  			InetAddress byn=InetAddress.getByName(host);
  			final SocketAddress sockaddr = new InetSocketAddress(host, port);  	  		
  			socket.connect(sockaddr, timeout);
  		} catch (final SocketTimeoutException e) {
  			// treating timeout errors separately from other io exceptions
  			// may make sense
  			online=false;
  			lastReachableException=e;
  			Whine(problems, complaint, e);
  		} catch (final IOException e) {
  			online = false;
  			lastReachableException=e;
  			Whine(problems, complaint, e);
  		} catch(final RuntimeException e){
  			online=false;
  			lastReachableException=e;
  			Whine(problems, complaint, e);
  		}finally {
  			// As the close() operation can also throw an IOException
  			// it must caught here
  			try {
  				socket.close();
  			} catch (final IOException e) {
  				Whine(problems, complaint, e);
  			}
  		}
  		return online;
  	}
    
    static String HtmlList(final Collection<String>things) {
    	final StringBuilder sb=new StringBuilder();
    	sb.append("<ol>");
    	final Iterator<String>it=things.iterator();
    	while (it.hasNext()) {
    		sb.append("<li>");
    		sb.append(it.next());
    	}
    	sb.append("</ol>");
    	return sb.toString();
    }
    
    public static class Con{
    	public HttpURLConnection http;
    	public final String url;
    	public String driveKey, sharingUrl, folderUrl;
    	public final long size; 
    	
    	Con(final String url){
    		this(url, -1);
    	}
    	
    	Con(final String url, final long size){
    		this(url, size, null);
    	}
    	Con(final String url, final long size, final Collection<String> problems){
    		this.url=url;
    		if (this.url.equals("bad")) {
    			this.size=-1;
    			return;
    		}
    		this.http=GetConnection(url, problems);
			if (this.http !=null && size<0){
				this.size=this.http.getContentLength();
			} else if (this.http!=null){
				int trySize=this.http.getContentLength();
				if (trySize>0 && trySize!=size) {
					this.size=trySize;
				} else {
					this.size=size;
				}
			} else {
				this.size=-1;
			}
    	}
    	public void disconnect() {
    		if (http !=null) {
    			http.disconnect();
    		}
    	}
    }
    
    public static class GoogleDriveDir {
    	final String url;
    	final long size; 
    	
    	GoogleDriveDir(final String url){
    		this(url, -1);
    	}
    	GoogleDriveDir(final String url, final long size){
    		this.url=url;
    		this.size=size;
    	}
    	
    	public static Properties props;
        
    	public static boolean ReadProps() {
    		if (props==null) {
    			props=new Properties();
    		}else {
    			props.clear();
    		}
    			
        	FileInputStream fis =null;
			final String file=GetPropsFileName();
    		try {
    			fis = new FileInputStream(new File(file));
    			props.load(fis);
    			System.out.println("Loaded \""+file+"\"");
    		} catch (FileNotFoundException e1) {
    			System.err.println("Problem loading \""+file+"\"");
    			return false;
    		} catch (IOException e) {
    			System.err.println("Problem loading \""+file+"\"");
    			return false;
    		} catch (RuntimeException ex) {
    			ex.printStackTrace();
    			System.err.println("Problem loading \""+file+"\"");
    			return false;
    		} finally {
    			if (fis !=null) {
    				try {
    					fis.close();
    				} catch (final IOException e) {
    					e.printStackTrace();
    				}
    			}
    		}
    		return true;
        }
    	
    	public static String DefaultGoogleDirLocalFile=null;
        public static String GetPropsFileName() {
        	if (DefaultGoogleDirLocalFile==null) {
        		String currentUsersHomeDir = System.getProperty("user.home");
        		String s= currentUsersHomeDir + File.separator + ".googleDriveDir.properties";
        		DefaultGoogleDirLocalFile=s;
        	}
        	return DefaultGoogleDirLocalFile;
        }
        
        public static boolean DownloadProps(String googleDirUrl, 
        		final Collection<String>problems) {
        	if (googleDirUrl==null) {
        		googleDirUrl=DefaultGoogleDirUrl;
        	}
        	//final Con con=Connect(googleDirUrl, null, problems);
        	final WebDownload d=new WebDownload();
        	d.allowCancel=false;
        	d.waitWhenDone=true;
        	final boolean ok=d.go(new String[] {googleDirUrl}, new String[] {GetPropsFileName()}, false);
        	if (problems!=null) {
        		problems.addAll(d.problems);
        	}
        	if (ok) {
        		return ReadProps();
        	}
        	return false;
        }
        
        public final static String
        		export="https://drive.google.com/uc?export=download&id=",
        		drive="https://drive.google.com/",
        		sharingStart="https://drive.google.com/file/d/", 
        		sharingEnd="/view?usp=sharing";
        
        public static Con Connect(final String in, final String googleDirUrl, 
        		final Collection<String> problems) {
        	
        	/*
        	 * As described at 
        	 *    https://www.wonderplugin.com/online-tools/google-drive-direct-link-generator/
        	 *    
        	 * A shared file link like
        	 *    https://drive.google.com/file/d/189nZplhvj804H2M4KPBz6vjU2JOTvHCk/view?usp=sharing
        	 *    
        	 * BECOMES
        	 * 	  https://drive.google.com/uc?export=download&id=189nZplhvj804H2M4KPBz6vjU2JOTvHCk
        	 * 
        	 */
        	Con out=null;
        	if (in.startsWith(drive)) {
        		final int qIdx=in.indexOf('?');
        		if (qIdx<=0) {
        			final String filePath=in.substring(drive.length());
        			boolean justDownloaded=false;
        			if (props==null) {
        				if (!ReadProps()) {
        					justDownloaded=true;
        					if (!DownloadProps(googleDirUrl, problems)) {
        						System.err.println("Can not read/download "+GetPropsFileName());
        					}
        				} 
        			}
        			if (!props.containsKey(filePath)) {
        				if (!justDownloaded) {
        					justDownloaded=true;
        					DownloadProps(googleDirUrl, problems);
        				}
        			}
        			if (props.containsKey(filePath)) {
        				String v=props.getProperty(filePath).trim();
        				int idx=v.indexOf(' ');
        				if (idx<1) {
        					if (!justDownloaded) {
        						System.err.println("Redownloading corrupt-ish googleDir file");
        						DownloadProps(googleDirUrl, problems);
        					}
        				}
        				v=props.getProperty(filePath).trim();
        				idx=v.indexOf(' ');
        				if (idx>0) {
        					final String s1=v.substring(0, idx);
        					final String sharingUrl=v.substring(idx+1).trim();
        					final String s2=ConvertSharingToExportIfNecessary(sharingUrl);
        					try {
        						final long l=Long.parseLong(s1);
        						out=new Con(s2, l, problems);
        						out.sharingUrl=sharingUrl;
        						out.driveKey=in;
        						String parent=new File(filePath).getParent();
        						parent=props.getProperty(parent);
        						if (parent != null) {
        							final int idx2=parent.indexOf(' ');
        							if (idx2>0) {
        								out.folderUrl=parent.substring(idx2+1).trim();
        							}
        							
        						}
        					}catch(final Exception e) {

        					}
        				} else {
        					System.err.println("The Google Drive key\""+filePath+"\" has malformed value \""+v+"\"");
        					//System.exit(1);
        				}
        			}
        			if (out==null) {
        				out=new Con("bad", -1, problems);
        			}
        		} else {
        			out=new Con(ConvertSharingToExportIfNecessary(in), -1, problems);
        		}
        	}
        	if (out==null) {
        		out=new Con(in, -1, problems);
        	}
        	return out;
        }
    
    static int warned=0;
        public static String ConvertSharingToExportIfNecessary(final String in) {
        	if (in.startsWith(sharingStart)){
        		final int vIdx=in.indexOf(sharingEnd);
        		if (vIdx>0) {
        			final String id=in.substring(sharingStart.length(), vIdx);
        			final String result=export+id;
        			if (warned++<3) {
        				System.out.println("Changed url to internal Google Drive export format... ");
        				System.out.println("... NOTE that both file and parent folder must ALSO be shared to everyone!!");
        			}
        			return result;
        		}
        	}
        	return in;
        }
        
        public static String GetDirectDownloadLink(final String in, 
        		final String googleDirUrl) {
        	if (in.startsWith(drive)) {
        		final int qIdx=in.indexOf('?');
        		if (qIdx<=0) {
        			final String filePath=in.substring(drive.length());
        			boolean justDownloaded=false;
        			final Collection<String>  problems=null;
        			if (props==null) {
        				if (!ReadProps()) {
        					justDownloaded=true;
        					if (!DownloadProps(googleDirUrl, problems)) {
        						System.err.println("Can not read/download "+GetPropsFileName());
        					}
        				} 
        			}
        			if (!props.containsKey(filePath)) {
        				if (!justDownloaded) {
        					justDownloaded=true;
        					DownloadProps(googleDirUrl, problems);
        				}
        			}
        			if (props.containsKey(filePath)) {
        				String v=props.getProperty(filePath).trim();
        				int idx=v.indexOf(' ');
        				if (idx<1) {
        					if (!justDownloaded) {
        						System.err.println("Redownloading corrupt-ish googleDir file");
        						DownloadProps(googleDirUrl, problems);
        					}
        				}
        				v=props.getProperty(filePath).trim();
        				idx=v.indexOf(' ');
        				if (idx>0) {
        					final String s1=v.substring(0, idx);
        					return ConvertSharingToExportIfNecessary(v.substring(idx+1));
        					
        				} else {
        					System.err.println("The Google Drive key\""+filePath+"\" has malformed value \""+v+"\"");
        					//System.exit(1);
        				}
        			}
        		} 
        	}
    		return in;
        }
    }
    
    public static Object ConvertToGoogleDirectDownloadIfNecessary(final String in) {
    	return GoogleDriveDir.ConvertSharingToExportIfNecessary(in);
    }
    
    public static Object GoogleDirectDownloadLink(final String url) { 
    	return GoogleDirectDownloadLink(url, DefaultGoogleDirUrl);
	}
    
    public static Object GoogleDirectDownloadLink(final String url, 
    		final String googleDirUrl) {
    	return GoogleDriveDir.GetDirectDownloadLink(url, googleDirUrl);
    }
}