package com.yolo.CDC.java.type;

import java.io.Serializable;

// TODO: Auto-generated Javadoc

/**
 * The Enum FileDataSplitter.
 */
public enum FileDataSplitter
        implements Serializable
{

    /**
     * The csv.
     */
    CSV(","),

    /**
     * The tsv.
     */
    TSV("\t"),

    /**
     * The geojson.
     */
    GEOJSON(""),

    /**
     * The wkt.
     */
    WKT("\t"),

    /**
     * The wkb.
     */
    WKB("\t"),

    COMMA(","),

    TAB("\t"),

    QUESTIONMARK("?"),

    SINGLEQUOTE("\'"),

    QUOTE("\""),

    UNDERSCORE("_"),

    DASH("-"),

    PERCENT("%"),

    TILDE("~"),

    PIPE("|"),

    SEMICOLON(";");

    /**
     * The splitter.
     */
    private final String splitter;

    /**
     * Instantiates a new file data splitter.
     *
     * @param splitter the splitter
     */
    FileDataSplitter(String splitter)
    {
        this.splitter = splitter;
    }

    /**
     * Gets the file data splitter.
     *
     * @param str the str
     * @return the file data splitter
     */
    public static FileDataSplitter getFileDataSplitter(String str)
    {
        for (FileDataSplitter me : FileDataSplitter.values()) {
            if (me.getDelimiter().equalsIgnoreCase(str) || me.name().equalsIgnoreCase(str)) { return me; }
        }
        throw new IllegalArgumentException("[" + FileDataSplitter.class + "] Unsupported FileDataSplitter:" + str);
    }

    /**
     * Gets the delimiter.
     *
     * @return the delimiter
     */
    public String getDelimiter()
    {
        return this.splitter;
    }
}

