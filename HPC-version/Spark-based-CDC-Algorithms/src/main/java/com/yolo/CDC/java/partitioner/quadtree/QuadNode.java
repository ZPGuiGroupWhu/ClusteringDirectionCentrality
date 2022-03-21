package com.yolo.CDC.java.partitioner.quadtree;

import java.io.Serializable;

public class QuadNode<T>
        implements Serializable
{
    QuadRectangle r;
    T element;

    QuadNode(QuadRectangle r, T element)
    {
        this.r = r;
        this.element = element;
    }

    @Override
    public String toString()
    {
        return r.toString();
    }
}
