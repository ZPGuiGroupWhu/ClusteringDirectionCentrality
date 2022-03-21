package com.yolo.CDC.java.index.HilbertCurve;

/**
 * @ClassName:HilbertUtil
 * @Description:二维坐标与希尔伯特值的互相转化
 * @Author:yolo
 * @Date:2022/2/1511:47
 * @Version:1.0
 */
public class HilbertUtil {

    /**
     * 将XY的编号转化为希尔伯特值
     *
     * @param x    X的编号
     * @param y    Y的编号
     * @param rank 希尔伯特曲线的阶数
     */
    public static int XYToHilbertCode1(int x, int y, int rank) {
        return XYToHilbertCode2(x, y, 1 << rank);
    }

    /**
     * 将XY的编号转化为希尔伯特值
     *
     * @param x      X的编号
     * @param y      Y的编号
     * @param @param grid 格网的宽度或高度，必须是2的幂次方
     */
    public static int XYToHilbertCode2(int x, int y, int grid) {
        int n = grid;
        int rx, ry, s, d = 0;
        boolean rxb;
        boolean ryb;
        for (s = n >> 1; s > 0; s >>= 1) {
            rxb = (x & s) > 0;
            ryb = (y & s) > 0;
            rx = rxb ? 1 : 0;
            ry = ryb ? 1 : 0;
            d += s * s * ((3 * rx) ^ ry);
            int[] xy = rot(s, x, y, rxb, ryb);
            x = xy[0];
            y = xy[1];
        }
        return d;
    }

    private static int[] rot(int n, int x, int y, boolean rxb, boolean ryb) {
        if (!ryb) {
            if (rxb) {
                x = n - 1 - x;
                y = n - 1 - y;
            }
            return new int[]{y, x};
        }
        return new int[]{x, y};
    }

    /**
     * @param code hilbert编码值
     * @param rank hilbert曲线的阶数
     * @return
     */
    public static int[] hilbertCodeToXY1(int code, int rank) {
        return hilbertCodeToXY2(code, 1 << rank);
    }

    /**
     * @param code hilbert编码值
     * @param grid 格网的宽度或高度，必须是2的幂次方
     * @return
     */
    public static int[] hilbertCodeToXY2(int code, int grid) {
        int n = grid, rx, ry, s, t = code, x = 0, y = 0;
        boolean rxb;
        boolean ryb;
        for (s = 1; s < n; s *= 2) {
            rx = 1 & (t >> 1);
//            rx = 1 & (t / 2);
            ry = 1 & (t ^ rx);
            rxb = rx != 0 ? true : false;
            ryb = ry != 0 ? true : false;
            int[] xy = rot(s, x, y, rxb, ryb);
            x = xy[0];
            y = xy[1];
            x += s * rx;
            y += s * ry;
            t >>= 2;
//            t /= 4;
        }
        return new int[]{x, y};
    }
}
