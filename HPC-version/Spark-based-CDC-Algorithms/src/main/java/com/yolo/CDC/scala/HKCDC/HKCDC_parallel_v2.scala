package com.yolo.CDC.scala.HKCDC

import com.yolo.CDC.java.`type`.{FileDataSplitter, GridType}
import com.yolo.CDC.java.knnsearch.index.{IndexBase, IndexKMeans, SearchParamsBase}
import com.yolo.CDC.java.knnsearch.metric.{Metric, MetricEuclideanSquared}
import com.yolo.CDC.java.rdd.{CDCPoint, PointRDD}
import com.yolo.CDC.java.serde.SedonaKryoRegistrator
import com.yolo.CDC.java.utils.Evaluation._
import com.yolo.CDC.java.utils.SortUtils
import org.apache.hadoop.fs.{FileSystem, Path}
import org.apache.log4j.{Level, Logger}
import org.apache.spark.broadcast.Broadcast
import org.apache.spark.rdd.RDD
import org.apache.spark.serializer.KryoSerializer
import org.apache.spark.storage.StorageLevel
import org.apache.spark.{SparkConf, SparkContext, TaskContext}
import org.jfree.chart.annotations.XYShapeAnnotation
import org.jfree.chart.axis.{NumberAxis, ValueAxis}
import org.jfree.chart.plot.{PlotOrientation, XYPlot}
import org.jfree.chart.renderer.xy.XYLineAndShapeRenderer
import org.jfree.chart.ui.Layer
import org.jfree.chart.{ChartFactory, ChartUtils, JFreeChart}
import org.jfree.data.xy.DefaultXYDataset
import org.locationtech.jts.geom.{Envelope, Point}

import java.awt.geom.Rectangle2D
import java.awt.{BasicStroke, Color}
import java.io.{File, FileOutputStream, FileWriter, PrintWriter}
import java.text.DecimalFormat
import scala.collection.JavaConverters._
import scala.collection.mutable
import scala.collection.mutable.{ArrayBuffer, ListBuffer}
import scala.util.control.Breaks


object HKCDC_parallel_v2 {
  var sc: SparkContext = null

  val resourceFolder: String = System.getProperty("user.dir")

  var txtDataInputLocation: String = null

  var csvDataInputLocation: String = null

  var spatialPartitionedRDDOutputLocation: String = null

  var clusterResultOutputLocation: String = null

  var clusterResultOutPutTxt: String = null

  var clusterResultOutPutTxt2: String = null

  var partitionResultOutputLocation: String = null

  var clusterAndPartitionResultOutputLocation: String = null

  var clusterEvaluationOutPutLocation: String = null

  var timeEvaluationOutPutLocation: String = null

  var dataFileName: String = null

  var dataFileType: String = null

  var PointRDDNumPartitions: Int = 0

  var PointRDDSplitter: FileDataSplitter = null

  var PointRDDIndexType: String = null

  var PointRDDGridType: GridType = null

  var objectRDD: PointRDD = null

  //(Default: 30, Recommended: 10~50)
  var k: Int = 31
  //% Levine_UMAP: k_num = 60; Tdcm = 0.08;
  //% Samusik_UMAP: k_num = 35; Tdcm = 0.033;
  var dcmThreshold: Double = 0.1
  //(Default: 0.1, Recommended: 0.05~0.25)
  var dcmRatio: Double = 0.1

  def main(args: Array[String]): Unit = {
    //配置环境与序列化
    val sparkConf: SparkConf = new SparkConf().setMaster("local[*]").setAppName("CDCTest05")
    sparkConf.set("spark.serializer", classOf[KryoSerializer].getName)
    sparkConf.set("spark.kryo.registrator", classOf[SedonaKryoRegistrator].getName)
    sparkConf.set("spark.kryoserializer.buffer.max", "512M")
    sc = new SparkContext(sparkConf)

    Logger.getLogger("org").setLevel(Level.FATAL)
    Logger.getLogger("akka").setLevel(Level.WARN)

    //设置分区参数
    PointRDDGridType = GridType.Hilbert
    PointRDDNumPartitions = 80

    //设置近邻搜索参数
    PointRDDIndexType = "Kmeans"

    //设置io参数
    dataFileType = "TXT"

    //聚类
    dataFileType match {
      case "CSV" => {
        testCsv1()
        //        testCsv2()
      }
      case "TXT" =>
//        testTxt1()
        testTxt2()
    }
    sc.stop()
  }

  def pointToCDCPoint(rdd: RDD[Point]): RDD[(Int, CDCPoint)] = {
    rdd.zipWithIndex().map((pointIndex: (Point, Long)) => {
      val cdcPoint: CDCPoint = new CDCPoint(pointIndex._1.getX, pointIndex._1.getY, k)
      cdcPoint.setGridID(TaskContext.get.partitionId)
      cdcPoint.setIndexID(pointIndex._2.toInt)
      (cdcPoint.getIndexID, cdcPoint)
    })
  }

  def persistRDD(rdd: RDD[(Int, CDCPoint)]) = {
    rdd.cache()
    rdd.checkpoint()
  }

  def deleteExistingDir(directory: String): AnyVal = {
    //获取文件系统
    val filePath: Path = new org.apache.hadoop.fs.Path(directory)
    val fileSystem: FileSystem = filePath.getFileSystem(sc.hadoopConfiguration)
    // 判断路径是否存在，存在删除目录
    if (fileSystem.exists(filePath)) {
      fileSystem.delete(filePath)
    }
  }

  def createFile(path: String) = {
    val file = new File(path)
    if (!file.getParentFile.exists) file.getParentFile.mkdirs
  }

  def createBroadcastIndex(data: Array[Array[Double]]): Broadcast[IndexBase] = {
    val metric: Metric = new MetricEuclideanSquared()
    val buildParams: IndexKMeans.BuildParams = new IndexKMeans.BuildParams()
    val indexKMeans: IndexBase = new IndexKMeans(metric, data, buildParams)
    indexKMeans.buildIndex()
    //    println((indexKMeans.objectsIndices).size())
    sc.broadcast(indexKMeans)
  }

  def calculateDCM(dataArray: Array[Array[Double]], point: (Int, CDCPoint), indices: Array[Int]): Double = {
    val angleArray: Array[Double] = point._2.getAngleArray
    //计算角度
    for (j <- 0 until k) {
      val deltaX: Double = dataArray(indices(j))(0) - point._2.getX
      val deltaY: Double = dataArray(indices(j))(1) - point._2.getY
      if (deltaX == 0) {
        if (deltaY == 0) {
          angleArray(j) = 0
        } else if (deltaY > 0) {
          angleArray(j) = math.Pi / 2
        } else {
          angleArray(j) = 3 * math.Pi / 2
        }
      } else if (deltaX > 0) {
        if (math.atan(deltaY / deltaX) >= 0) {
          angleArray(j) = math.atan(deltaY / deltaX)
        } else {
          angleArray(j) = 2 * math.Pi + math.atan(deltaY / deltaX)
        }
      } else {
        angleArray(j) = math.Pi + math.atan(deltaY / deltaX)
      }
    }

    //计算标准化DCM
    val angleOrder: Array[Double] = angleArray.sorted
    point._2.setAngleArray(angleOrder)
    var dcmValue: Double = 0
    for (j <- 1 until k - 1) {
      dcmValue += math.pow(angleOrder(j + 1) - angleOrder(j) - 2 * math.Pi / (k - 1), 2)
    }
    dcmValue += math.pow(angleOrder(1) - angleOrder(k - 1) + 2 * math.Pi - 2 * math.Pi / (k - 1), 2)
    dcmValue /= ((k - 2) * 4 * math.pow(math.Pi, 2) / (k - 1))
    point._2.setDcmValue(dcmValue)
    dcmValue
  }

  class PartitionIterator(iter: Iterator[(Int, CDCPoint)], dataArray: Array[Array[Double]], index: Broadcast[IndexBase], searchParams: SearchParamsBase) extends Iterator[(Int, CDCPoint)] {
    override def hasNext: Boolean = {
      iter.hasNext
    }

    override def next(): (Int, CDCPoint) = {
      val point: (Int, CDCPoint) = iter.next()
      val indices: Array[Int] = point._2.getNeighborsIndexID
      val distances: Array[Double] = point._2.getNeighborsDistance
      //近邻搜索
      index.value.knnSearch(point._2.getCoordinates, indices, distances, searchParams)
      point._2.setNeighborsIndexID(indices)
      point._2.setNeighborsDistance(distances)
      //计算DCM值
      calculateDCM(dataArray, point, indices)
      //划分内部点与边界点
      if (point._2.getDcmValue < dcmThreshold) {
        point._2.setFlag(CDCPoint.Flag.Inner)
      } else {
        point._2.setFlag(CDCPoint.Flag.Border)
      }
      point
    }
  }

  def dividePoint(rdd: RDD[(Int, CDCPoint)], dataArray: Array[Array[Double]], index: Broadcast[IndexBase], searchParams: SearchParamsBase): RDD[(Int, CDCPoint)] = {
    //    rdd.mapPartitionsWithIndex(
    //      (partitionIndex, partition) => {
    //        val pointList: ArrayBuffer[(Int, CDCPoint)] = new ArrayBuffer[(Int, CDCPoint)]()
    //        while (partition.hasNext) {
    //          val point: (Int, CDCPoint) = partition.next()
    //          val indices: Array[Int] = point._2.getNeighborsIndexID
    //          val distances: Array[Double] = point._2.getNeighborsDistance
    //          //近邻搜索
    //          index.value.knnSearch(point._2.getCoordinates, indices, distances, searchParams)
    //          point._2.setNeighborsIndexID(indices)
    //          point._2.setNeighborsDistance(distances)
    //          //计算DCM值
    //          calculateDCM(dataArray, point, indices, searchParams.maxNeighbors)
    //          //划分内部点与边界点
    //          if (point._2.getDcmValue < dcmThreshold) {
    //            point._2.setFlag(CDCPoint.Flag.Inner)
    //          } else {
    //            point._2.setFlag(CDCPoint.Flag.Border)
    //          }
    //          pointList.append(point)
    //        }
    //        println("partition" + partitionIndex + ":" + pointList.length)
    //        pointList.iterator
    //      }
    //    )
    rdd.mapPartitions(iter => new PartitionIterator(iter, dataArray, index, searchParams))
  }

  class PartitionIterator_(iter: Iterator[(Int, CDCPoint)], flagArray: Array[CDCPoint.Flag], index1: Broadcast[IndexBase], index2: Broadcast[IndexBase]) extends Iterator[(Int, CDCPoint)] {
    override def hasNext: Boolean = {
      iter.hasNext
    }

    override def next(): (Int, CDCPoint) = {
      val point: (Int, CDCPoint) = iter.next()
      val indices: Array[Int] = new Array[Int](1)
      val distances: Array[Double] = new Array[Double](1)
      if (point._2.getFlag == CDCPoint.Flag.Inner) {
        var count: Int = 0
        val loop: Breaks = new Breaks;
        loop.breakable {
          for (i <- point._2.getNeighborsIndexID) {
            if (flagArray(i) == CDCPoint.Flag.Border) {
              distances(0) = point._2.getNeighborsDistance()(count)
              loop.break
            } else if (flagArray(i) == CDCPoint.Flag.Inner && count == point._2.getNeighborsNum - 1) {
              index1.value.knnSearch(point._2.getCoordinates, indices, distances)
            }
            count += 1
          }
        }
        point._2.setReachDistance(distances(0))
      } else {
        var count: Int = 0
        val loop: Breaks = new Breaks;
        loop.breakable {
          for (i <- point._2.getNeighborsIndexID) {
            if (flagArray(i) == CDCPoint.Flag.Inner) {
              point._2.setClusterID(i)
              loop.break
            } else if (flagArray(i) == CDCPoint.Flag.Border && count == point._2.getNeighborsNum - 1) {
              index2.value.knnSearch(point._2.getCoordinates, indices, distances)
              point._2.setClusterID(indices(0))
            }
            count += 1
          }
        }
      }
      point
    }
  }

  def calculateReachDistance(rdd: RDD[(Int, CDCPoint)], flagArray: Array[CDCPoint.Flag], index1: Broadcast[IndexBase], index2: Broadcast[IndexBase]): RDD[(Int, CDCPoint)] = {
    //    rdd.mapPartitions((partition: Iterator[(Int, CDCPoint)]) => {
    //      val pointList: ArrayBuffer[(Int, CDCPoint)] = new ArrayBuffer[(Int, CDCPoint)]()
    //      while (partition.hasNext) {
    //        val point: (Int, CDCPoint) = partition.next()
    //        val indices: Array[Int] = new Array[Int](1)
    //        val distances: Array[Double] = new Array[Double](1)
    //        if (point._2.getFlag == CDCPoint.Flag.Inner) {
    //          var count: Int = 0
    //          val loop: Breaks = new Breaks;
    //          loop.breakable {
    //            for (i <- point._2.getNeighborsIndexID) {
    //              if (flagArray(i) == CDCPoint.Flag.Border) {
    //                distances(0) = point._2.getNeighborsDistance()(count)
    //                loop.break
    //              } else if (flagArray(i) == CDCPoint.Flag.Inner && count == point._2.getNeighborsNum - 1) {
    //                index1.value.knnSearch(point._2.getCoordinates, indices, distances)
    //              }
    //              count += 1
    //            }
    //          }
    //          point._2.setReachDistance(distances(0))
    //        } else {
    //          var count: Int = 0
    //          val loop: Breaks = new Breaks;
    //          loop.breakable {
    //            for (i <- point._2.getNeighborsIndexID) {
    //              if (flagArray(i) == CDCPoint.Flag.Inner) {
    //                point._2.setClusterID(i)
    //                loop.break
    //              } else if (flagArray(i) == CDCPoint.Flag.Border && count == point._2.getNeighborsNum - 1) {
    //                index2.value.knnSearch(point._2.getCoordinates, indices, distances)
    //                point._2.setClusterID(indices(0))
    //              }
    //              count += 1
    //            }
    //          }
    //        }
    //        pointList.append(point)
    //      }
    //      pointList.iterator
    //    })
    rdd.mapPartitions(iter => new PartitionIterator_(iter, flagArray, index1, index2))
  }

  def connectInnerPointInPartition(rdd: RDD[(Int, CDCPoint)]): RDD[(Int, ListBuffer[CDCPoint])] = {
    rdd.mapPartitions((partition: Iterator[(Int, CDCPoint)]) => {
      val pointList: List[(Int, CDCPoint)] = partition.toList.sortBy(point => point._2.getReachDistance).reverse
      val clusterPointList: List[(Int, ListBuffer[CDCPoint])] = pointList.map((point: (Int, CDCPoint)) => {
        if (point._2.getFlag == CDCPoint.Flag.Inner && (!point._2.isVisited)) {
          val reachPoint: Iterable[(Int, CDCPoint)] = pointList.view.filter(other => {
            math.sqrt(point._2.getDistanceSquared(other._2)) <= math.sqrt(point._2.getReachDistance) + math.sqrt(other._2.getReachDistance)
          })
          val clusterID: Int = point._2.getIndexID
          point._2.setClusterID(clusterID)
          val allReachPoint: mutable.Queue[Iterable[(Int, CDCPoint)]] = mutable.Queue(reachPoint)
          while (allReachPoint.nonEmpty) {
            // 返回队列的第一个元素 并且删除
            allReachPoint.dequeue().foreach((point: (Int, CDCPoint)) => {
              if (point._2.getFlag == CDCPoint.Flag.Inner && (!point._2.isVisited)) { //如果点没有访问过
                point._2.setVisited(true)
                point._2.setClusterID(clusterID)
                val moreReachPoint: Iterable[(Int, CDCPoint)] = pointList.view.filter(other => {
                  math.sqrt(point._2.getDistanceSquared(other._2)) <= math.sqrt(point._2.getReachDistance) + math.sqrt(other._2.getReachDistance)
                })
                allReachPoint.enqueue(moreReachPoint)
              }
            })
          }
        }
        (point._2.getClusterID, ListBuffer(point._2))
      })
      clusterPointList.iterator
    })
  }

  def connectInnerPointBetweenPartition(rdd: RDD[(Int, ListBuffer[CDCPoint])]): Array[(Int, ListBuffer[CDCPoint])] = {
    val clusterInnerPointListRDD: RDD[(Int, ListBuffer[CDCPoint])] = rdd.reduceByKey((point1, point2) => point1 ++ point2)
    val clusterInnerPointArray: Array[(Int, ListBuffer[CDCPoint])] = clusterInnerPointListRDD.collect()
    clusterInnerPointArray.foldLeft(-1)((cluster: Int, pointList: (Int, ListBuffer[CDCPoint])) => {
      if (pointList._2.last.getClusterID >= 0) {
        val point1: CDCPoint = pointList._2.sortBy((point: CDCPoint) => point.getReachDistance).last
        for (point <- pointList._2) {
          point.setClusterID(cluster)
        }
        val reachPointList: Iterable[(Int, ListBuffer[CDCPoint])] = clusterInnerPointArray.view.filter(other => {
          val otherPoint: CDCPoint = other._2.sortBy((point: CDCPoint) => point.getReachDistance).last
          math.sqrt(point1.getDistanceSquared(otherPoint)) <= math.sqrt(point1.getReachDistance) + math.sqrt(otherPoint.getReachDistance)
        })
        val allReachPointList: mutable.Queue[Iterable[(Int, ListBuffer[CDCPoint])]] = mutable.Queue(reachPointList)
        while (allReachPointList.nonEmpty) {
          // 返回队列的第一个元素 并且删除
          allReachPointList.dequeue().foreach((pointList: (Int, ListBuffer[CDCPoint])) => {
            if (pointList._2.last.getClusterID >= 0) { //如果点没有访问过
              val point2: CDCPoint = pointList._2.sortBy((point: CDCPoint) => point.getReachDistance).last
              for (point <- pointList._2) {
                point.setClusterID(cluster)
              }
              val morePointList: Iterable[(Int, ListBuffer[CDCPoint])] = clusterInnerPointArray.view.filter(other => {
                val otherPoint: CDCPoint = other._2.sortBy((point: CDCPoint) => point.getReachDistance).last
                math.sqrt(point2.getDistanceSquared(otherPoint)) <= math.sqrt(point2.getReachDistance) + math.sqrt(otherPoint.getReachDistance)
              })
              allReachPointList.enqueue(morePointList)
            }
          })
        }
        cluster - 1
      } else {
        cluster
      }
    })
    clusterInnerPointArray
  }

  def paintClusterResult(list: List[CDCPoint], outputPath: String) = {
    val xydataset: DefaultXYDataset = new DefaultXYDataset
    val xydatasetbc: Broadcast[DefaultXYDataset] = sc.broadcast(xydataset)
    list.map(point => (point.getClusterID, point.getX, point.getY)).groupBy(_._1).foreach(list => {
      val points: Array[Array[Double]] = new Array[Array[Double]](2)
      points(0) = list._2.unzip3._2.toArray
      points(1) = list._2.unzip3._3.toArray
      xydatasetbc.value.addSeries("Cluster" + list._1, points)
    })
    val chart: JFreeChart = ChartFactory.createScatterPlot("HKCDC(k="+k+",tDCM="+(new DecimalFormat("0.00").format(dcmThreshold))+",ratio="+dcmRatio+")", "X", "Y", xydatasetbc.value, PlotOrientation.VERTICAL, true, false, false)
    chart.setBackgroundPaint(Color.white)
    chart.setBorderPaint(Color.GREEN)
    chart.setBorderStroke(new BasicStroke(1.5f))
    chart.removeLegend()
    val xyplot: XYPlot = chart.getPlot.asInstanceOf[XYPlot]

    xyplot.setBackgroundPaint(new Color(255, 253, 246))
    val vaaxis: ValueAxis = xyplot.getDomainAxis
    vaaxis.setAxisLineStroke(new BasicStroke(1.5f))

    val va: ValueAxis = xyplot.getDomainAxis(0)

    va.setAxisLineStroke(new BasicStroke(1.5f)) // 坐标轴粗细

    va.setAxisLinePaint(new Color(215, 215, 215)) // 坐标轴颜色

    xyplot.setOutlineStroke(new BasicStroke(1.5f)) // 边框粗细

    va.setLabelPaint(new Color(10, 10, 10)) // 坐标轴标题颜色

    va.setTickLabelPaint(new Color(102, 102, 102)) // 坐标轴标尺值颜色

    val axis: ValueAxis = xyplot.getRangeAxis
    axis.setAxisLineStroke(new BasicStroke(1.5f))
    val xylineandshaperenderer: XYLineAndShapeRenderer = xyplot.getRenderer.asInstanceOf[XYLineAndShapeRenderer]
    xylineandshaperenderer.setSeriesOutlinePaint(0, Color.WHITE)
    xylineandshaperenderer.setUseOutlinePaint(true)
    val numberaxis: NumberAxis = xyplot.getDomainAxis.asInstanceOf[NumberAxis]
    numberaxis.setAutoRangeIncludesZero(false)
    numberaxis.setTickMarkInsideLength(2.0F)
    numberaxis.setTickMarkOutsideLength(0.0F)
    numberaxis.setAxisLineStroke(new BasicStroke(1.5f))
    createFile(outputPath)
    val os_png: FileOutputStream = new FileOutputStream(outputPath)
    ChartUtils.writeChartAsPNG(os_png, chart, 1000, 1000)
  }

  def paintClusterAndPartitionResult(list: List[CDCPoint], grids: List[Envelope], outputPath: String) = {
    val xydataset: DefaultXYDataset = new DefaultXYDataset
    val xydatasetbc: Broadcast[DefaultXYDataset] = sc.broadcast(xydataset)
    list.map(point => (point.getClusterID, point.getX, point.getY)).groupBy(_._1).foreach(list => {
      val points: Array[Array[Double]] = new Array[Array[Double]](2)
      points(0) = list._2.unzip3._2.toArray
      points(1) = list._2.unzip3._3.toArray
      xydatasetbc.value.addSeries("Cluster" + list._1, points)
    })
    val chart: JFreeChart = ChartFactory.createScatterPlot("HKCDC(k="+k+",partition="+PointRDDGridType+",num="+PointRDDNumPartitions+")", "X", "Y", xydatasetbc.value, PlotOrientation.VERTICAL, true, false, false)
    chart.setBackgroundPaint(Color.white)
    chart.setBorderPaint(Color.GREEN)
    chart.setBorderStroke(new BasicStroke(1.5f))
    chart.removeLegend()
    val xyplot: XYPlot = chart.getPlot.asInstanceOf[XYPlot]

    xyplot.setBackgroundPaint(new Color(255, 253, 246))
    val vaaxis: ValueAxis = xyplot.getDomainAxis
    vaaxis.setAxisLineStroke(new BasicStroke(1.5f))

    val va: ValueAxis = xyplot.getDomainAxis(0)

    va.setAxisLineStroke(new BasicStroke(1.5f)) // 坐标轴粗细

    va.setAxisLinePaint(new Color(215, 215, 215)) // 坐标轴颜色

    xyplot.setOutlineStroke(new BasicStroke(1.5f)) // 边框粗细

    va.setLabelPaint(new Color(10, 10, 10)) // 坐标轴标题颜色

    va.setTickLabelPaint(new Color(102, 102, 102)) // 坐标轴标尺值颜色

    val axis: ValueAxis = xyplot.getRangeAxis
    axis.setAxisLineStroke(new BasicStroke(1.5f))
    val xylineandshaperenderer: XYLineAndShapeRenderer = xyplot.getRenderer.asInstanceOf[XYLineAndShapeRenderer]
    xylineandshaperenderer.setSeriesOutlinePaint(0, Color.WHITE)
    xylineandshaperenderer.setUseOutlinePaint(true)
    grids.foreach(grid => {
      xylineandshaperenderer.addAnnotation(new XYShapeAnnotation(
        new Rectangle2D.Double(grid.getMinX, grid.getMinY, grid.getMaxX - grid.getMinX, grid.getMaxY - grid.getMinY), new BasicStroke(2.0f), Color.RED), Layer.FOREGROUND)
    })
    val numberaxis: NumberAxis = xyplot.getDomainAxis.asInstanceOf[NumberAxis]
    numberaxis.setAutoRangeIncludesZero(false)
    numberaxis.setTickMarkInsideLength(2.0F)
    numberaxis.setTickMarkOutsideLength(0.0F)
    numberaxis.setAxisLineStroke(new BasicStroke(1.5f))
    createFile(outputPath)
    val os_png: FileOutputStream = new FileOutputStream(outputPath)
    ChartUtils.writeChartAsPNG(os_png, chart, 1000, 1000)
  }

  def paintPartitionResult(array: Array[Array[CDCPoint]], grids: List[Envelope], outputPath: String) = {
    val xydataset: DefaultXYDataset = new DefaultXYDataset
    array.foreach(pointArray => {
      if (!pointArray.isEmpty) {
        val gridID: Int = pointArray(0).getGridID
        val array1: Array[(Double, Double)] = pointArray.map((point: CDCPoint) => (point.getX, point.getY))
        val points: Array[Array[Double]] = new Array[Array[Double]](2)
        points(0) = array1.unzip._1
        points(1) = array1.unzip._2
        xydataset.addSeries("Grid" + gridID, points)
      }
    })
    val chart: JFreeChart = ChartFactory.createScatterPlot("CDC Clustering", "X", "Y", xydataset, PlotOrientation.VERTICAL, true, false, false)
    chart.setBackgroundPaint(Color.white)
    chart.setBorderPaint(Color.GREEN)
    chart.setBorderStroke(new BasicStroke(1.5f))
    chart.removeLegend()
    val xyplot: XYPlot = chart.getPlot.asInstanceOf[XYPlot]

    xyplot.setBackgroundPaint(new Color(255, 253, 246))
    val vaaxis: ValueAxis = xyplot.getDomainAxis
    vaaxis.setAxisLineStroke(new BasicStroke(1.5f))

    val va: ValueAxis = xyplot.getDomainAxis(0)

    va.setAxisLineStroke(new BasicStroke(1.5f)) // 坐标轴粗细

    va.setAxisLinePaint(new Color(215, 215, 215)) // 坐标轴颜色

    xyplot.setOutlineStroke(new BasicStroke(1.5f)) // 边框粗细

    va.setLabelPaint(new Color(10, 10, 10)) // 坐标轴标题颜色

    va.setTickLabelPaint(new Color(102, 102, 102)) // 坐标轴标尺值颜色

    val axis: ValueAxis = xyplot.getRangeAxis
    axis.setAxisLineStroke(new BasicStroke(1.5f))
    val xylineandshaperenderer: XYLineAndShapeRenderer = xyplot.getRenderer.asInstanceOf[XYLineAndShapeRenderer]
    xylineandshaperenderer.setSeriesOutlinePaint(0, Color.WHITE)
    xylineandshaperenderer.setUseOutlinePaint(true)
    grids.foreach(grid => {
      xylineandshaperenderer.addAnnotation(new XYShapeAnnotation(
        new Rectangle2D.Double(grid.getMinX, grid.getMinY, grid.getMaxX - grid.getMinX, grid.getMaxY - grid.getMinY), new BasicStroke(2.0f), Color.RED), Layer.FOREGROUND)
    })
    val numberaxis: NumberAxis = xyplot.getDomainAxis.asInstanceOf[NumberAxis]
    numberaxis.setAutoRangeIncludesZero(false)
    numberaxis.setTickMarkInsideLength(2.0F)
    numberaxis.setTickMarkOutsideLength(0.0F)
    numberaxis.setAxisLineStroke(new BasicStroke(1.5f))
    createFile(outputPath)
    val os_png: FileOutputStream = new FileOutputStream(outputPath)
    ChartUtils.writeChartAsPNG(os_png, chart, 1000, 1000)
  }

  def saveToTxt(array: Array[(Double, Double, Int)], outputPath: String) = {
    val writer = new PrintWriter(new File(outputPath))
    writer.flush(); //清空文件内容
    for (i <- 0 until array.length) {

      writer.println(array(i)._1 + "\t" + array(i)._2 + "\t" + array(i)._3)
    }
    //关闭写入流
    writer.close()
  }

  def saveToTxt(labelsTrue: Array[Int], labelsPred: Array[Int], outputPath: String) = {
    val writer = new FileWriter(new File(outputPath), true)
    writer.write(PointRDDNumPartitions + "\t" + k + "\t" + dcmThreshold + "\t" + PointRDDGridType + "\t" + PointRDDIndexType + "\t" + purity(labelsTrue, labelsPred) + "\t" + FMeasure(labelsTrue, labelsPred) + "\t" + randIndex(labelsTrue, labelsPred) + "\t" + adjustedRandIndex(labelsTrue, labelsPred)
      + "\t" + jaccardIndex(labelsTrue, labelsPred) + "\t" + normalizedMutualInformation(labelsTrue, labelsPred) + "\n")
    //关闭写入流
    writer.close()
  }

  def saveToTxt(labelsTrue: Array[String], labelsPred: Array[Int], outputPath: String) = {
    val writer = new FileWriter(new File(outputPath), true)
    val filterNan: Array[(String, Int)] = labelsTrue.zip(labelsPred).filter(_._1 != "NaN")
    val labelsTrueFilter: Array[Int] = filterNan.unzip._1.map(_.toInt)
    val labelsPredFilter: Array[Int] = filterNan.unzip._2
    writer.write(PointRDDNumPartitions + "\t" + k + "\t" + dcmThreshold + "\t" + PointRDDGridType + "\t" + PointRDDIndexType + "\t" + purity(labelsTrueFilter, labelsPredFilter) + "\t" + FMeasure(labelsTrueFilter, labelsPredFilter) + "\t" + randIndex(labelsTrueFilter, labelsPredFilter) + "\t" + adjustedRandIndex(labelsTrueFilter, labelsPredFilter)
      + "\t" + jaccardIndex(labelsTrueFilter, labelsPredFilter) + "\t" + normalizedMutualInformation(labelsTrueFilter, labelsPredFilter) + "\n")
    //关闭写入流
    writer.close()
  }

  def saveToTxt(array: Array[Double], outputPath: String) = {
    val writer = new FileWriter(new File(outputPath), true)
    writer.write(PointRDDNumPartitions + "\t" + k + "\t" + dcmThreshold + "\t" + PointRDDGridType + "\t" + PointRDDIndexType + "\t")
    for (i <- array) {
      writer.write(i + "\t")
    }
    writer.write("\n")
    //关闭写入流
    writer.close()
  }

  def evaluateCluster(array: Array[CDCPoint]) = {
    val clusterData: Array[(Double, Double, Int)] = array.sortBy(point => (point.getX, point.getY)).map(point => (point.getX, point.getY, -point.getClusterID))
    val labelsPred: Array[Int] = clusterData.map(_._3)
    val rawData: Array[(Double, Double, Int)] = sc.textFile(txtDataInputLocation).map(line => {
      val lineSplit: Array[String] = line.trim.split("\\s+")
      (lineSplit(0).toDouble, lineSplit(1).toDouble, lineSplit(2).toInt)
    }).sortBy((point: (Double, Double, Int)) => (point._1, point._2)).collect()
    val labelsTrue: Array[Int] = rawData.map(_._3)
    saveToTxt(labelsTrue, labelsPred, clusterEvaluationOutPutLocation)
    println("purity：" + purity(labelsTrue, labelsPred))
    println("F值：" + FMeasure(labelsTrue, labelsPred))
    println("RI：" + randIndex(labelsTrue, labelsPred))
    println("ARI：" + adjustedRandIndex(labelsTrue, labelsPred))
    println("JI：" + jaccardIndex(labelsTrue, labelsPred))
    println("NMI：" + normalizedMutualInformation(labelsTrue, labelsPred))
  }

  def evaluateCluster_(array: Array[CDCPoint]) = {
    val clusterData: Array[(Double, Double, Int)] = array.sortBy(point => (point.getX, point.getY)).map(point => (point.getX, point.getY, -point.getClusterID))
    val labelsPred: Array[Int] = clusterData.map(_._3)
    val rawData: Array[(Double, Double, String)] = sc.textFile(txtDataInputLocation).map(line => {
      val lineSplit: Array[String] = line.trim.split("\\s+")
      (lineSplit(0).toDouble, lineSplit(1).toDouble, lineSplit(2))
    }).sortBy((point: (Double, Double, String)) => (point._1, point._2)).collect()
    val labelsTrue: Array[String] = rawData.map(_._3)
    saveToTxt(labelsTrue, labelsPred, clusterEvaluationOutPutLocation)
  }

  def csvCDCCluster(searchParams: SearchParamsBase) = {
    deleteExistingDir("CheckPointDir")
    sc.setCheckpointDir("CheckPointDir")
    PointRDDSplitter = FileDataSplitter.COMMA

    //读取数据
    println("读取数据开始----------")
    val readDataStart: Long = System.currentTimeMillis()
    objectRDD = new PointRDD(sc, csvDataInputLocation, 0, PointRDDSplitter, true, PointRDDNumPartitions, StorageLevel.MEMORY_ONLY, "epsg:4326", "epsg:3857")
    val readDataEnd: Long = System.currentTimeMillis()
    println("读取数据结束----------")
    println("时间：" + (readDataEnd - readDataStart) / 1000.0 + "秒")

    //空间分区
    println("空间分区开始----------")
    val partitionStart: Long = System.currentTimeMillis()
    objectRDD.spatialPartitioning(PointRDDGridType, PointRDDNumPartitions)
    val partitionEnd: Long = System.currentTimeMillis()
    println("空间分区结束----------")
    println("时间：" + (partitionEnd - partitionStart) / 1000.0 + "秒")

    //转换数据结构，并标记index
    val spatialPartitionedRDD: RDD[(Int, CDCPoint)] = pointToCDCPoint(objectRDD.spatialPartitionedRDD)
    //性能优化——数据持久化
    persistRDD(spatialPartitionedRDD)
    //    deleteExistingDir(spatialPartitionedRDDOutputLocation)
    //    spatialPartitionedRDD.saveAsTextFile(spatialPartitionedRDDOutputLocation)
    // 获得数组数据，用于构建索引
    val dataArray: Array[Array[Double]] = spatialPartitionedRDD.sortBy((point: (Int, CDCPoint)) => point._2.getIndexID).map(point => point._2.getCoordinates).collect()

    //构建全局索引并广播
    println("构建索引开始----------")
    val indexStart: Long = System.currentTimeMillis()
    val indexKMeansBc: Broadcast[IndexBase] = createBroadcastIndex(dataArray)
    val indexEnd: Long = System.currentTimeMillis()
    println("构建索引结束----------")
    println("时间：" + (indexEnd - indexStart) / 1000.0 + "秒")

    //对分区中每个数据进行近邻搜索并计算其DCM值，根据DCM阈值划分边界点与内部点
    println("划分开始----------")
    val divideStart: Long = System.currentTimeMillis()
    val dividePointRDD: RDD[(Int, CDCPoint)] = dividePoint(spatialPartitionedRDD, dataArray, indexKMeansBc, searchParams)
    persistRDD(dividePointRDD)
    val divideEnd: Long = System.currentTimeMillis()
    println("划分结束----------")
    println("时间：" + (divideEnd - divideStart) / 1000.0 + "秒")

    //获得划分结果数组
    val flagArray: Array[CDCPoint.Flag] = dividePointRDD.sortBy(point => point._2.getIndexID).map(point => point._2.getFlag).collect()
    val dcmArray: Array[Double] = dividePointRDD.map(point => point._2.getDcmValue).collect()
    dcmThreshold = SortUtils.findKthLargest(dcmArray, (dcmArray.length * dcmRatio).toInt)
    println("dcmThreshold:" + dcmThreshold)
    println("构建索引开始----------")
    val reachIndexStart: Long = System.currentTimeMillis()
    //构建边界点索引，用于内部点寻找最近的边界点
    val borderPointArray: Array[Array[Double]] = dividePointRDD.filter(point => point._2.getFlag == CDCPoint.Flag.Border).map(point => point._2.getCoordinates).collect()
    val borderIndexKMeansBc: Broadcast[IndexBase] = createBroadcastIndex(borderPointArray)

    //构建内部点索引，用于边界点寻找最近的内部点
    val innerPointArray: Array[Array[Double]] = dividePointRDD.filter(point => point._2.getFlag == CDCPoint.Flag.Inner).map(point => point._2.getCoordinates).collect()
    val innerIndexKMeansBc: Broadcast[IndexBase] = createBroadcastIndex(innerPointArray)
    val reachIndexEnd: Long = System.currentTimeMillis()
    println("构建索引结束----------")
    println("时间：" + (reachIndexEnd - reachIndexStart) / 1000.0 + "秒")

    //计算内部点的可达距离
    println("计算可达距离开始----------")
    val reachDistanceStart: Long = System.currentTimeMillis()
    val reachPartitionedRDD: RDD[(Int, CDCPoint)] = calculateReachDistance(dividePointRDD, flagArray, borderIndexKMeansBc, innerIndexKMeansBc)
    persistRDD(reachPartitionedRDD)
    val reachDistanceEnd: Long = System.currentTimeMillis()
    println("计算可达距离结束----------")
    println("时间：" + (reachDistanceEnd - reachDistanceStart) / 1000.0 + "秒")

    //根据距离可达原则在分区内连接内部点
    println("分区内连接内部点开始----------")
    val connectInnerPointStart: Long = System.currentTimeMillis()
    val clusterInnerPointRDD: RDD[(Int, ListBuffer[CDCPoint])] = connectInnerPointInPartition(reachPartitionedRDD.filter((point: (Int, CDCPoint)) => point._2.getFlag == CDCPoint.Flag.Inner))
    val connectInnerPointEnd: Long = System.currentTimeMillis()
    println("分区内连接内部点结束----------")
    println("时间：" + (connectInnerPointEnd - connectInnerPointStart) / 1000.0 + "秒")

    println("分区间连接内部点开始----------")
    val connectInnerPointBStart: Long = System.currentTimeMillis()
    val clusterInnerPointArray: Array[(Int, ListBuffer[CDCPoint])] = connectInnerPointBetweenPartition(clusterInnerPointRDD)
    val connectInnerPointBEnd: Long = System.currentTimeMillis()
    println("分区间连接内部点结束----------")
    println("时间：" + (connectInnerPointBEnd - connectInnerPointBStart) / 1000.0 + "秒")

    println("标记边界点开始----------")
    val labelBoderPointStart: Long = System.currentTimeMillis()
    val clusterInnerPoint: Array[CDCPoint] = clusterInnerPointArray.flatMap(_._2)
    val borderPoint: Array[CDCPoint] = reachPartitionedRDD.filter((point: (Int, CDCPoint)) => point._2.getFlag == CDCPoint.Flag.Border).map(_._2).collect()
    val clusterArray: Array[CDCPoint] = (clusterInnerPoint ++ borderPoint).sortBy(point => point.getIndexID)
    clusterArray.foreach((point: CDCPoint) => {
      if (point.getFlag == CDCPoint.Flag.Border) {
        point.setClusterID(clusterArray(point.getClusterID).getClusterID)
      }
    })
    val labelBoderPointEnd: Long = System.currentTimeMillis()
    println("标记边界点结束----------")
    println("时间：" + (labelBoderPointEnd - labelBoderPointStart) / 1000.0 + "秒")

    //画出聚类结果图
    println("画图开始----------")
    var t1: Long = System.currentTimeMillis()
    //    val grids: List[Envelope] = objectRDD.getPartitioner.getGrids.asScala.toList
    //    println("partitionSize:" + objectRDD.spatialPartitionedRDD.partitions.size())
    paintClusterResult(clusterArray.toList, clusterResultOutputLocation)
    //    paintClusterAndPartitionResult(clusterArray.toList, grids, clusterAndPartitionResultOutputLocation)
    //    val partitionPoints: Array[Array[CDCPoint]] = spatialPartitionedRDD.map(_._2).glom().collect()
    //    paintPartitionResult(partitionPoints, grids, partitionResultOutputLocation)
    var t2: Long = System.currentTimeMillis()
    println("画图结束----------")
    println("时间：" + (t2 - t1) / 1000.0 + "秒")


    println("分区时间：" + (partitionEnd - partitionStart) / 1000.0 + "秒")
    println("本地聚类时间：" + (connectInnerPointEnd - partitionStart) / 1000.0 + "秒")
    println("聚类合并和重标记：" + (labelBoderPointEnd - connectInnerPointBStart) / 1000.0 + "秒")
    println("聚类时间：" + (labelBoderPointEnd - partitionStart) / 1000.0 + "秒")
    val timeArray: ArrayBuffer[Double] = new ArrayBuffer[Double]()
    //    timeArray.append(readDataStart, readDataEnd, partitionStart, partitionEnd, indexStart, indexEnd, divideStart, divideEnd,
    //      reachDistanceStart, reachDistanceEnd, connectInnerPointStart, connectInnerPointEnd, connectInnerPointBStart, connectInnerPointBEnd, labelBoderPointStart, labelBoderPointEnd)
    timeArray.append((readDataEnd - readDataStart) / 1000.0, (partitionEnd - partitionStart) / 1000.0, (indexStart - partitionEnd) / 1000.0, (indexEnd - indexStart) / 1000.0, (divideEnd - divideStart) / 1000.0, (reachIndexStart - divideEnd) / 1000.0, (reachIndexEnd - reachIndexStart) / 1000.0,
      (reachDistanceEnd - reachDistanceStart) / 1000.0, (connectInnerPointEnd - connectInnerPointStart) / 1000.0, (connectInnerPointBEnd - connectInnerPointBStart) / 1000.0, (labelBoderPointEnd - labelBoderPointStart) / 1000.0, (labelBoderPointEnd - partitionStart) / 1000.0)
    saveToTxt(timeArray.toArray, timeEvaluationOutPutLocation)
  }

  def txtCDCCluster(searchParams: SearchParamsBase) = {
    deleteExistingDir("CheckPointDir")
    sc.setCheckpointDir("CheckPointDir")
    PointRDDSplitter = FileDataSplitter.TAB

    //读取数据
    println("读取数据开始----------")
    val readDataStart: Long = System.currentTimeMillis()
    objectRDD = new PointRDD(sc, txtDataInputLocation, 0, PointRDDSplitter, true, PointRDDNumPartitions, StorageLevel.MEMORY_ONLY)
    val readDataEnd: Long = System.currentTimeMillis()
    println("读取数据结束----------")
    println("时间：" + (readDataEnd - readDataStart) / 1000.0 + "秒")

    //空间分区
    println("空间分区开始----------")
    val partitionStart: Long = System.currentTimeMillis()
    objectRDD.spatialPartitioning(PointRDDGridType, PointRDDNumPartitions)
    val partitionEnd: Long = System.currentTimeMillis()
    println("空间分区结束----------")
    println("时间：" + (partitionEnd - partitionStart) / 1000.0 + "秒")

    //转换数据结构，并标记index
    val spatialPartitionedRDD: RDD[(Int, CDCPoint)] = pointToCDCPoint(objectRDD.spatialPartitionedRDD)
    //性能优化——数据持久化
    persistRDD(spatialPartitionedRDD)
    //    deleteExistingDir(spatialPartitionedRDDOutputLocation)
    //    spatialPartitionedRDD.saveAsTextFile(spatialPartitionedRDDOutputLocation)
    // 获得数组数据，用于构建索引
    val dataArray: Array[Array[Double]] = spatialPartitionedRDD.sortBy((point: (Int, CDCPoint)) => point._2.getIndexID).map(point => point._2.getCoordinates).collect()

    //构建全局索引并广播
    println("构建索引开始----------")
    val indexStart: Long = System.currentTimeMillis()
    val indexKMeansBc: Broadcast[IndexBase] = createBroadcastIndex(dataArray)
    val indexEnd: Long = System.currentTimeMillis()
    println("构建索引结束----------")
    println("时间：" + (indexEnd - indexStart) / 1000.0 + "秒")

    //对分区中每个数据进行近邻搜索并计算其DCM值，根据DCM阈值划分边界点与内部点
    println("划分开始----------")
    val divideStart: Long = System.currentTimeMillis()
    val dividePointRDD: RDD[(Int, CDCPoint)] = dividePoint(spatialPartitionedRDD, dataArray, indexKMeansBc, searchParams)
    persistRDD(dividePointRDD)
    val divideEnd: Long = System.currentTimeMillis()
    println("划分结束----------")
    println("时间：" + (divideEnd - divideStart) / 1000.0 + "秒")

    //获得划分结果数组
    val flagArray: Array[CDCPoint.Flag] = dividePointRDD.sortBy(point => point._2.getIndexID).map(point => point._2.getFlag).collect()
    val dcmArray: Array[Double] = dividePointRDD.map(point => point._2.getDcmValue).collect()
    dcmThreshold = SortUtils.findKthLargest(dcmArray, (dcmArray.length * dcmRatio).toInt)
    println("dcmThreshold:" + dcmThreshold)
    println("构建索引开始----------")
    val reachIndexStart: Long = System.currentTimeMillis()
    //构建边界点索引，用于内部点寻找最近的边界点
    val borderPointArray: Array[Array[Double]] = dividePointRDD.filter(point => point._2.getFlag == CDCPoint.Flag.Border).map(point => point._2.getCoordinates).collect()
    val borderIndexKMeansBc: Broadcast[IndexBase] = createBroadcastIndex(borderPointArray)

    //构建内部点索引，用于边界点寻找最近的内部点
    val innerPointArray: Array[Array[Double]] = dividePointRDD.filter(point => point._2.getFlag == CDCPoint.Flag.Inner).map(point => point._2.getCoordinates).collect()
    val innerIndexKMeansBc: Broadcast[IndexBase] = createBroadcastIndex(innerPointArray)
    val reachIndexEnd: Long = System.currentTimeMillis()
    println("构建索引结束----------")
    println("时间：" + (reachIndexEnd - reachIndexStart) / 1000.0 + "秒")

    //计算内部点的可达距离
    println("计算可达距离开始----------")
    val reachDistanceStart: Long = System.currentTimeMillis()
    val reachPartitionedRDD: RDD[(Int, CDCPoint)] = calculateReachDistance(dividePointRDD, flagArray, borderIndexKMeansBc, innerIndexKMeansBc)
    persistRDD(reachPartitionedRDD)
    val reachDistanceEnd: Long = System.currentTimeMillis()
    println("计算可达距离结束----------")
    println("时间：" + (reachDistanceEnd - reachDistanceStart) / 1000.0 + "秒")

    //根据距离可达原则在分区内连接内部点
    println("分区内连接内部点开始----------")
    val connectInnerPointStart: Long = System.currentTimeMillis()
    val clusterInnerPointRDD: RDD[(Int, ListBuffer[CDCPoint])] = connectInnerPointInPartition(reachPartitionedRDD.filter((point: (Int, CDCPoint)) => point._2.getFlag == CDCPoint.Flag.Inner))
    val connectInnerPointEnd: Long = System.currentTimeMillis()
    println("分区内连接内部点结束----------")
    println("时间：" + (connectInnerPointEnd - connectInnerPointStart) / 1000.0 + "秒")

    println("分区间连接内部点开始----------")
    val connectInnerPointBStart: Long = System.currentTimeMillis()
    val clusterInnerPointArray: Array[(Int, ListBuffer[CDCPoint])] = connectInnerPointBetweenPartition(clusterInnerPointRDD)
    val connectInnerPointBEnd: Long = System.currentTimeMillis()
    println("分区间连接内部点结束----------")
    println("时间：" + (connectInnerPointBEnd - connectInnerPointBStart) / 1000.0 + "秒")

    println("标记边界点开始----------")
    val labelBoderPointStart: Long = System.currentTimeMillis()
    val clusterInnerPoint: Array[CDCPoint] = clusterInnerPointArray.flatMap(_._2)
    val borderPoint: Array[CDCPoint] = reachPartitionedRDD.filter((point: (Int, CDCPoint)) => point._2.getFlag == CDCPoint.Flag.Border).map(_._2).collect()
    val clusterArray: Array[CDCPoint] = (clusterInnerPoint ++ borderPoint).sortBy(point => point.getIndexID)
    clusterArray.foreach((point: CDCPoint) => {
      if (point.getFlag == CDCPoint.Flag.Border) {
        point.setClusterID(clusterArray(point.getClusterID).getClusterID)
      }
    })
    val labelBoderPointEnd: Long = System.currentTimeMillis()
    println("标记边界点结束----------")
    println("时间：" + (labelBoderPointEnd - labelBoderPointStart) / 1000.0 + "秒")

    //画出聚类结果图
    println("画图开始----------")
    var t1: Long = System.currentTimeMillis()
    //    val grids: List[Envelope] = objectRDD.getPartitioner.getGrids.asScala.toList
    //    println("partitionSize:" + objectRDD.spatialPartitionedRDD.partitions.size())
    paintClusterResult(clusterArray.toList, clusterResultOutputLocation)
    //    paintClusterAndPartitionResult(clusterArray.toList, grids, clusterAndPartitionResultOutputLocation)
    //    val partitionPoints: Array[Array[CDCPoint]] = spatialPartitionedRDD.map(_._2).glom().collect()
    //    paintPartitionResult(partitionPoints, grids, partitionResultOutputLocation)
    var t2: Long = System.currentTimeMillis()
    println("画图结束----------")
    println("时间：" + (t2 - t1) / 1000.0 + "秒")

    //评价聚类结果
    println("评价开始----------")
    t1 = System.currentTimeMillis()
    evaluateCluster(clusterArray)
    t2 = System.currentTimeMillis()
    println("评价结束----------")
    println("评价时间：" + (t2 - t1) / 1000.0 + "秒")

    println("分区时间：" + (partitionEnd - partitionStart) / 1000.0 + "秒")
    println("本地聚类时间：" + (connectInnerPointEnd - partitionStart) / 1000.0 + "秒")
    println("聚类合并和重标记：" + (labelBoderPointEnd - connectInnerPointBStart) / 1000.0 + "秒")
    println("聚类时间：" + (labelBoderPointEnd - partitionStart) / 1000.0 + "秒")
    val timeArray: ArrayBuffer[Double] = new ArrayBuffer[Double]()
    timeArray.append((readDataEnd - readDataStart) / 1000.0, (partitionEnd - partitionStart) / 1000.0, (indexStart - partitionEnd) / 1000.0, (indexEnd - indexStart) / 1000.0, (divideEnd - divideStart) / 1000.0, (reachIndexStart - divideEnd) / 1000.0, (reachIndexEnd - reachIndexStart) / 1000.0,
      (reachDistanceEnd - reachDistanceStart) / 1000.0, (connectInnerPointEnd - connectInnerPointStart) / 1000.0, (connectInnerPointBEnd - connectInnerPointBStart) / 1000.0, (labelBoderPointEnd - labelBoderPointStart) / 1000.0, (labelBoderPointEnd - partitionStart) / 1000.0)
    saveToTxt(timeArray.toArray, timeEvaluationOutPutLocation)
  }

  def txtCDCCluster_(searchParams: SearchParamsBase) = {
    deleteExistingDir("CheckPointDir")
    sc.setCheckpointDir("CheckPointDir")
    PointRDDSplitter = FileDataSplitter.TAB

    //读取数据
    println("读取数据开始----------")
    val readDataStart: Long = System.currentTimeMillis()
    objectRDD = new PointRDD(sc, txtDataInputLocation, 0, PointRDDSplitter, true, PointRDDNumPartitions, StorageLevel.MEMORY_ONLY)
    val readDataEnd: Long = System.currentTimeMillis()
    println("读取数据结束----------")
    println("时间：" + (readDataEnd - readDataStart) / 1000.0 + "秒")

    //空间分区
    println("空间分区开始----------")
    val partitionStart: Long = System.currentTimeMillis()
    objectRDD.spatialPartitioning(PointRDDGridType, PointRDDNumPartitions)
    val partitionEnd: Long = System.currentTimeMillis()
    println("空间分区结束----------")
    println("时间：" + (partitionEnd - partitionStart) / 1000.0 + "秒")

    //转换数据结构，并标记index
    val spatialPartitionedRDD: RDD[(Int, CDCPoint)] = pointToCDCPoint(objectRDD.spatialPartitionedRDD)
    //性能优化——数据持久化
    persistRDD(spatialPartitionedRDD)
    //    deleteExistingDir(spatialPartitionedRDDOutputLocation)
    //    spatialPartitionedRDD.saveAsTextFile(spatialPartitionedRDDOutputLocation)
    // 获得数组数据，用于构建索引
    val dataArray: Array[Array[Double]] = spatialPartitionedRDD.sortBy((point: (Int, CDCPoint)) => point._2.getIndexID).map(point => point._2.getCoordinates).collect()

    //构建全局索引并广播
    println("构建索引开始----------")
    val indexStart: Long = System.currentTimeMillis()
    val indexKMeansBc: Broadcast[IndexBase] = createBroadcastIndex(dataArray)
    val indexEnd: Long = System.currentTimeMillis()
    println("构建索引结束----------")
    println("时间：" + (indexEnd - indexStart) / 1000.0 + "秒")

    //对分区中每个数据进行近邻搜索并计算其DCM值，根据DCM阈值划分边界点与内部点
    println("划分开始----------")
    val divideStart: Long = System.currentTimeMillis()
    val dividePointRDD: RDD[(Int, CDCPoint)] = dividePoint(spatialPartitionedRDD, dataArray, indexKMeansBc, searchParams)
    persistRDD(dividePointRDD)
    val divideEnd: Long = System.currentTimeMillis()
    println("划分结束----------")
    println("时间：" + (divideEnd - divideStart) / 1000.0 + "秒")

    //获得划分结果数组
    val flagArray: Array[CDCPoint.Flag] = dividePointRDD.sortBy(point => point._2.getIndexID).map(point => point._2.getFlag).collect()
    val dcmArray: Array[Double] = dividePointRDD.map(point => point._2.getDcmValue).collect()
    dcmThreshold = SortUtils.findKthLargest(dcmArray, (dcmArray.length * dcmRatio).toInt)
    println("dcmThreshold:" + dcmThreshold)
    println("构建索引开始----------")
    val reachIndexStart: Long = System.currentTimeMillis()
    //构建边界点索引，用于内部点寻找最近的边界点
    val borderPointArray: Array[Array[Double]] = dividePointRDD.filter(point => point._2.getFlag == CDCPoint.Flag.Border).map(point => point._2.getCoordinates).collect()
    val borderIndexKMeansBc: Broadcast[IndexBase] = createBroadcastIndex(borderPointArray)

    //构建内部点索引，用于边界点寻找最近的内部点
    val innerPointArray: Array[Array[Double]] = dividePointRDD.filter(point => point._2.getFlag == CDCPoint.Flag.Inner).map(point => point._2.getCoordinates).collect()
    val innerIndexKMeansBc: Broadcast[IndexBase] = createBroadcastIndex(innerPointArray)
    val reachIndexEnd: Long = System.currentTimeMillis()
    println("构建索引结束----------")
    println("时间：" + (reachIndexEnd - reachIndexStart) / 1000.0 + "秒")

    //计算内部点的可达距离
    println("计算可达距离开始----------")
    val reachDistanceStart: Long = System.currentTimeMillis()
    val reachPartitionedRDD: RDD[(Int, CDCPoint)] = calculateReachDistance(dividePointRDD, flagArray, borderIndexKMeansBc, innerIndexKMeansBc)
    persistRDD(reachPartitionedRDD)
    val reachDistanceEnd: Long = System.currentTimeMillis()
    println("计算可达距离结束----------")
    println("时间：" + (reachDistanceEnd - reachDistanceStart) / 1000.0 + "秒")

    //根据距离可达原则在分区内连接内部点
    println("分区内连接内部点开始----------")
    val connectInnerPointStart: Long = System.currentTimeMillis()
    val clusterInnerPointRDD: RDD[(Int, ListBuffer[CDCPoint])] = connectInnerPointInPartition(reachPartitionedRDD.filter((point: (Int, CDCPoint)) => point._2.getFlag == CDCPoint.Flag.Inner))
    val connectInnerPointEnd: Long = System.currentTimeMillis()
    println("分区内连接内部点结束----------")
    println("时间：" + (connectInnerPointEnd - connectInnerPointStart) / 1000.0 + "秒")

    println("分区间连接内部点开始----------")
    val connectInnerPointBStart: Long = System.currentTimeMillis()
    val clusterInnerPointArray: Array[(Int, ListBuffer[CDCPoint])] = connectInnerPointBetweenPartition(clusterInnerPointRDD)
    val connectInnerPointBEnd: Long = System.currentTimeMillis()
    println("分区间连接内部点结束----------")
    println("时间：" + (connectInnerPointBEnd - connectInnerPointBStart) / 1000.0 + "秒")

    println("标记边界点开始----------")
    val labelBoderPointStart: Long = System.currentTimeMillis()
    val clusterInnerPoint: Array[CDCPoint] = clusterInnerPointArray.flatMap(_._2)
    val borderPoint: Array[CDCPoint] = reachPartitionedRDD.filter((point: (Int, CDCPoint)) => point._2.getFlag == CDCPoint.Flag.Border).map(_._2).collect()
    val clusterArray: Array[CDCPoint] = (clusterInnerPoint ++ borderPoint).sortBy(point => point.getIndexID)
    clusterArray.foreach((point: CDCPoint) => {
      if (point.getFlag == CDCPoint.Flag.Border) {
        point.setClusterID(clusterArray(point.getClusterID).getClusterID)
      }
    })
    val labelBoderPointEnd: Long = System.currentTimeMillis()
    println("标记边界点结束----------")
    println("时间：" + (labelBoderPointEnd - labelBoderPointStart) / 1000.0 + "秒")

    //画出聚类结果图
    println("画图开始----------")
    var t1: Long = System.currentTimeMillis()
    //    val grids: List[Envelope] = objectRDD.getPartitioner.getGrids.asScala.toList
    //    println("partitionSize:" + objectRDD.spatialPartitionedRDD.partitions.size())
    paintClusterResult(clusterArray.toList, clusterResultOutputLocation)
    //    paintClusterAndPartitionResult(clusterArray.toList, grids, clusterAndPartitionResultOutputLocation)
    //    val partitionPoints: Array[Array[CDCPoint]] = spatialPartitionedRDD.map(_._2).glom().collect()
    //    paintPartitionResult(partitionPoints, grids, partitionResultOutputLocation)
    var t2: Long = System.currentTimeMillis()
    println("画图结束----------")
    println("时间：" + (t2 - t1) / 1000.0 + "秒")

    //评价聚类结果
    println("评价开始----------")
    t1 = System.currentTimeMillis()
    evaluateCluster_(clusterArray)
    t2 = System.currentTimeMillis()
    println("评价结束----------")
    println("评价时间：" + (t2 - t1) / 1000.0 + "秒")

    println("分区时间：" + (partitionEnd - partitionStart) / 1000.0 + "秒")
    println("本地聚类时间：" + (connectInnerPointEnd - partitionStart) / 1000.0 + "秒")
    println("聚类合并和重标记：" + (labelBoderPointEnd - connectInnerPointBStart) / 1000.0 + "秒")
    println("聚类时间：" + (labelBoderPointEnd - partitionStart) / 1000.0 + "秒")
    val timeArray: ArrayBuffer[Double] = new ArrayBuffer[Double]()
    timeArray.append((readDataEnd - readDataStart) / 1000.0, (partitionEnd - partitionStart) / 1000.0, (indexStart - partitionEnd) / 1000.0, (indexEnd - indexStart) / 1000.0, (divideEnd - divideStart) / 1000.0, (reachIndexStart - divideEnd) / 1000.0, (reachIndexEnd - reachIndexStart) / 1000.0,
      (reachDistanceEnd - reachDistanceStart) / 1000.0, (connectInnerPointEnd - connectInnerPointStart) / 1000.0, (connectInnerPointBEnd - connectInnerPointBStart) / 1000.0, (labelBoderPointEnd - labelBoderPointStart) / 1000.0, (labelBoderPointEnd - partitionStart) / 1000.0)
    saveToTxt(timeArray.toArray, timeEvaluationOutPutLocation)
  }

  def testTxt1(): Unit = {
    for (i <- Range(1, 7)) {
      dataFileName = "DS" + i
      for (j <- List(4,8,16,32)) {
        PointRDDNumPartitions = j
        for (m <- Range(10, 51, 5)) {
          k = m
          for (n <- Range(5, 31, 5)) {
            dcmRatio = n / 100.0
            println("文件名:" + dataFileName + "\t文件类型:" + dataFileType + "\t分区数:" + PointRDDNumPartitions + "\t邻居数:" + k + "\tDCM阈值比例:" + dcmRatio)
            val searchParams: SearchParamsBase = new IndexKMeans.SearchParams()
            searchParams.maxNeighbors = k
            txtDataInputLocation = resourceFolder + "/SyntheticDatasets/" + dataFileName + ".txt"
            clusterResultOutputLocation = resourceFolder + "/ResultData/clusterResult/HKCDC/" + dataFileName + "/" + PointRDDGridType + "_" + PointRDDIndexType + "_" + PointRDDNumPartitions + "_" + k + "_" + dcmRatio + ".png"
            clusterAndPartitionResultOutputLocation = resourceFolder + "/ResultData/cpResult/HKCDC/" + dataFileName + "/" + PointRDDGridType + "_" + PointRDDIndexType + "_" + PointRDDNumPartitions + "_" + k + "_" + dcmRatio + ".png"
            clusterEvaluationOutPutLocation = resourceFolder + "/ResultData/clusterEvaluation/" + dataFileName + ".txt"
            timeEvaluationOutPutLocation = resourceFolder + "/ResultData/timeEvaluation/" + dataFileName + ".txt"
            txtCDCCluster(searchParams)
          }
        }
      }
    }
  }

  def testTxt2(): Unit = {
//    for (i <- List("Levine","Samusik")) {
    for (i <- List("Samusik")) {
      dataFileName = i + "_UMAP"
      for (j <- List(256,512)) {
        PointRDDNumPartitions = j
        for (m <- Range(30, 61, 10)) {
          k = m
          for (n <- Range(5, 31, 5)) {
            dcmRatio = n / 100.0
            println("文件名:" + dataFileName + "\t文件类型:" + dataFileType + "\t分区数:" + PointRDDNumPartitions + "\t邻居数:" + k + "\tDCM阈值比例:" + dcmRatio)
            val searchParams: SearchParamsBase = new IndexKMeans.SearchParams()
            searchParams.maxNeighbors = k
            txtDataInputLocation = resourceFolder + "/CyTOFDatasets/" + dataFileName + ".txt"
            clusterResultOutputLocation = resourceFolder + "/ResultData/clusterResult/HKCDC/" + dataFileName + "/" + PointRDDGridType + "_" + PointRDDIndexType + "_" + PointRDDNumPartitions + "_" + k + "_" + dcmRatio + ".png"
            clusterAndPartitionResultOutputLocation = resourceFolder + "/ResultData/cpResult/HKCDC/" + dataFileName + "/" + PointRDDGridType + "_" + PointRDDIndexType + "_" + PointRDDNumPartitions + "_" + k + "_" + dcmRatio + ".png"
            clusterEvaluationOutPutLocation = resourceFolder + "/ResultData/clusterEvaluation/" + dataFileName + ".txt"
            timeEvaluationOutPutLocation = resourceFolder + "/ResultData/timeEvaluation/" + dataFileName + ".txt"
            txtCDCCluster_(searchParams)
          }
        }
      }
    }
  }

  def testCsv1(): Unit = {
    for (i <- List("1", "2", "5", "10", "20", "30")) {
      dataFileName = "hubei-" + i + "0000"
      for (j <- List(64,128,256,512)) {
        PointRDDNumPartitions = j
        //        for (m <- Range(3, 52, 1)) {
        //          k = m
        for (n <- Range(5, 31, 5)) {
          dcmRatio = n / 100.0
          println("文件名:" + dataFileName + "\t文件类型:" + dataFileType + "\t分区数:" + PointRDDNumPartitions + "\t邻居数:" + k + "\tDCM阈值:" + dcmRatio)
          val searchParams: SearchParamsBase = new IndexKMeans.SearchParams()
          searchParams.maxNeighbors = k
          csvDataInputLocation = resourceFolder + "/GeoDataSets/0.37 Million Enterprise Registration Data in Hubei Province/Points/" + dataFileName + ".csv"
          clusterResultOutputLocation = resourceFolder + "/ResultData/clusterResult/HKCDC/" + dataFileName + "/" + PointRDDGridType + "_" + PointRDDIndexType + "_" + PointRDDNumPartitions + "_" + k + "_" + dcmRatio + ".png"
          clusterAndPartitionResultOutputLocation = resourceFolder + "/ResultData/cpResult/HKCDC/" + dataFileName + "/" + PointRDDGridType + "_" + PointRDDIndexType + "_" + PointRDDNumPartitions + "_" + k + "_" + dcmRatio + ".png"
          timeEvaluationOutPutLocation = resourceFolder + "/ResultData/timeEvaluation/" + dataFileName + ".txt"
          csvCDCCluster(searchParams)
        }
      }
    }
  }

  def testCsv2(): Unit = {
      for (i <- Range(1, 11, 1)) {
        dataFileName = i + "00000"
        for (j <- List(64,128,256,512)) {
          PointRDDNumPartitions = j
          //        for (m <- Range(3, 52, 1)) {
          //          k = m
          for (n <- Range(5, 31, 5)) {
            dcmRatio = n / 100.0
          println("文件名:" + dataFileName + "\t文件类型:" + dataFileType + "\t分区数:" + PointRDDNumPartitions + "\t邻居数:" + k + "\tDCM阈值比例:" + dcmRatio)
          val searchParams: SearchParamsBase = new IndexKMeans.SearchParams()
          searchParams.maxNeighbors = k
          csvDataInputLocation = resourceFolder + "/GeoDataSets/1 Million Amap Points of Interest in China/Points/" + dataFileName + ".csv"
          clusterResultOutputLocation = resourceFolder + "/ResultData/clusterResult/HKCDC/" + dataFileName + "/" + PointRDDGridType + "_" + PointRDDIndexType + "_" + PointRDDNumPartitions + "_" + k + "_" + dcmRatio + ".png"
          clusterAndPartitionResultOutputLocation = resourceFolder + "/ResultData/cpResult/HKCDC/" + dataFileName + "/" + PointRDDGridType + "_" + PointRDDIndexType + "_" + PointRDDNumPartitions + "_" + k + "_" + dcmRatio + ".png"
          timeEvaluationOutPutLocation = resourceFolder + "/ResultData/timeEvaluation/" + dataFileName + ".txt"
          csvCDCCluster(searchParams)
        }
        }
      }
    }
}
