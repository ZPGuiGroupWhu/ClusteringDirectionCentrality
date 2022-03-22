package com.yolo.CDC.scala.HKCDC

import com.yolo.CDC.java.knnsearch.index.{IndexBase, IndexKMeans}
import com.yolo.CDC.java.knnsearch.metric.{Metric, MetricEuclideanSquared}
import com.yolo.CDC.java.rdd.PointRDD
import com.yolo.CDC.java.serde.SedonaKryoRegistrator
import com.yolo.CDC.java.utils.{CRSTransform, SortUtils}
import com.yolo.CDC.java.utils.Evaluation.{FMeasure, adjustedRandIndex, jaccardIndex, normalizedMutualInformation, purity, randIndex}
import javafx.util
import org.apache.log4j.{Level, Logger}
import org.apache.spark.rdd.RDD
import org.apache.spark.{SparkConf, SparkContext}
import org.apache.spark.serializer.KryoSerializer
import org.jfree.chart.{ChartFactory, ChartUtils, JFreeChart}
import org.jfree.chart.annotations.XYShapeAnnotation
import org.jfree.chart.axis.{NumberAxis, ValueAxis}
import org.jfree.chart.plot.{PlotOrientation, XYPlot}
import org.jfree.chart.renderer.xy.XYLineAndShapeRenderer
import org.jfree.chart.ui.Layer
import org.jfree.data.xy.DefaultXYDataset
import org.locationtech.jts.geom.Envelope

import java.awt.{BasicStroke, Color}
import java.awt.geom.Rectangle2D
import java.io.{File, FileOutputStream, FileWriter}
import java.lang
import scala.collection.mutable.ArrayBuffer
import scala.util.control.Breaks

object CDC_v2 {
  var sc: SparkContext = null

  val resourceFolder: String = System.getProperty("user.dir")

  var txtDataInputLocation: String = null

  var csvDataInputLocation: String = null

  var clusterResultOutputLocation: String = null

  var clusterEvaluationOutPutLocation: String = null

  var timeEvaluationOutPutLocation: String = null

  var dataFileName: String = null

  var dataFileType: String = null

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
    sparkConf.set("spark.kryo.registrator", classOf[SedonaKryoRegistrator].getName);
    sc = new SparkContext(sparkConf)

    Logger.getLogger("org").setLevel(Level.FATAL)
    Logger.getLogger("akka").setLevel(Level.WARN)

    //设置io参数
    //    dataFileName = "1000000"
    dataFileType = "TXT"

    //聚类
    dataFileType match {
      case "CSV" => {
        testCsv1()
        //        testCsv2()
      }
      case "TXT" => testTxt2()
    }
    sc.stop()
  }

  def readTxtData(inputPath: String): (RDD[Array[Double]], Array[Int]) = {
    val dataRDD: RDD[String] = sc.textFile(inputPath)
    val labelsTrue = new ArrayBuffer[Int]()
    val mapRDD: RDD[Array[Double]] = dataRDD.map(
      line => {
        val split_data: Array[String] = line.trim.split("\\s+")
        Array(split_data(0).toDouble, split_data(1).toDouble)
      }
    )
    dataRDD.collect.foreach(line => {
      val split_data: Array[String] = line.trim.split("\\s+")
      if (split_data(2).equals("NaN")) {
        labelsTrue.append(-1)
      } else {
        labelsTrue.append(split_data(2).toInt)
      }
    })
    (mapRDD, labelsTrue.toArray)
  }

  def readCsvData(inputPath: String): RDD[Array[Double]] = {
    val dataRDD: RDD[String] = sc.textFile(inputPath)
    val mapRDD: RDD[Array[Double]] = dataRDD.map(
      line => {
        val split_data: Array[String] = line.split(",")
        val pair: util.Pair[lang.Double, lang.Double] = CRSTransform.transformTo3857(split_data(0).toDouble, split_data(1).toDouble)
        Array(pair.getKey, pair.getValue)
      }
    )
    mapRDD
  }

  def csvCDCCluster() = {
    //读取数据
    val mapRDD: RDD[Array[Double]] = readCsvData(csvDataInputLocation)
    val clusteStart: Long = System.currentTimeMillis()
    val dataArray: Array[Array[Double]] = mapRDD.collect()
    val length: Int = dataArray.length
    val metric: Metric = new MetricEuclideanSquared()

    val buildParams: IndexKMeans.BuildParams = new IndexKMeans.BuildParams()
    val indexKMeans: IndexBase = new IndexKMeans(metric, dataArray, buildParams)
    indexKMeans.buildIndex()
    val searchParams: IndexKMeans.SearchParams = new IndexKMeans.SearchParams()
    searchParams.maxNeighbors = k
    searchParams.eps = 0.0f

    val indices: Array[Array[Int]] = Array.ofDim[Int](length, k)
    val distances: Array[Array[Double]] = Array.ofDim[Double](length, k)
    indexKMeans.knnSearch(dataArray, indices, distances, searchParams)

    //计算角度
    val caculateAngleStart = System.currentTimeMillis()
    val angleArray: Array[Array[Double]] = Array.ofDim[Double](length, k)
    for (i <- 0 until length) {
      for (j <- 0 until k) {
        val deltaX: Double = dataArray(indices(i)(j))(0) - dataArray(i)(0)
        val deltaY: Double = dataArray(indices(i)(j))(1) - dataArray(i)(1)
        if (deltaX == 0) {
          if (deltaY == 0) {
            angleArray(i)(j) = 0
          } else if (deltaY > 0) {
            angleArray(i)(j) = math.Pi / 2
          } else {
            angleArray(i)(j) = 3 * math.Pi / 2
          }
        } else if (deltaX > 0) {
          if (math.atan(deltaY / deltaX) >= 0) {
            angleArray(i)(j) = math.atan(deltaY / deltaX)
          } else {
            angleArray(i)(j) = 2 * math.Pi + math.atan(deltaY / deltaX)
          }
        } else {
          angleArray(i)(j) = math.Pi + math.atan(deltaY / deltaX)
        }
      }

    }

    //计算标准化DCM
    val caculateDCMStart = System.currentTimeMillis()
    val dcmValue: Array[Double] = new Array[Double](length)
    for (i <- 0 until length) {
      val angleOrder: Array[Double] = angleArray(i).sorted
      //      println(angleOrder.mkString("Array(", ", ", ")"))
      dcmValue(i) = 0
      for (j <- 1 until k - 1) {
        dcmValue(i) += math.pow(angleOrder(j + 1) - angleOrder(j) - 2 * math.Pi / k, 2)
      }
      dcmValue(i) += math.pow(angleOrder(1) - angleOrder(k - 1) + 2 * math.Pi - 2 * math.Pi / (k - 1), 2)
      dcmValue(i) /= ((k - 2) * 4 * math.pow(math.Pi, 2) / (k - 1))
    }

    //划分内部点与边界点
    val divideStart = System.currentTimeMillis()
    val categary: Array[Int] = new Array[Int](length)
    dcmThreshold = SortUtils.findKthLargest(dcmValue, (length * dcmRatio).toInt)
    for (i <- 0 until length) {
      if (dcmValue(i) < dcmThreshold) {
        categary(i) = 1
      } else {
        categary(i) = 0
      }
    }

    //计算可达距离
    val calculateReachDistanceStart = System.currentTimeMillis()
    val reachDistance: Array[Double] = new Array[Double](length)
    val loop1: Breaks = new Breaks;
    for (i <- 0 until length) {
      //内部点
      if (categary(i) == 1) {
        loop1.breakable {
          for (j <- 1 until k) {
            if (categary(indices(i)(j)) == 0) {
              reachDistance(i) = distances(i)(j)
              //              println(reachDistance(i))
              loop1.break()
            } else if (j == k - 1 && categary(indices(i)(j)) == 1) {
              reachDistance(i) = Short.MaxValue
              var temp: Double = 0.0
              for (m <- 0 until length) {
                if (categary(m) == 0) {
                  temp = math.pow(dataArray(i)(0) - dataArray(m)(0), 2) + math.pow(dataArray(i)(1) - dataArray(m)(1), 2)
                  //                  println(temp)
                  if (temp < reachDistance(i)) {
                    reachDistance(i) = temp
                  }
                }
              }
            }
          }
        }
      } else {
        val loop2: Breaks = new Breaks;
        loop2.breakable {
          for (j <- 1 until k) {
            if (categary(indices(i)(j)) == 1) {
              reachDistance(i) = indices(i)(j)
              loop2.break()
            } else if (j == k - 1 && categary(indices(i)(j)) == 0) {
              var tempDistance: Double = Double.MaxValue
              var temp2: Double = 0.0
              for (m <- 0 until length) {
                if (categary(m) == 1) {
                  temp2 = math.pow(dataArray(i)(0) - dataArray(m)(0), 2) + math.pow(dataArray(i)(1) - dataArray(m)(1), 2)
                  if (temp2 < tempDistance) {
                    tempDistance = temp2
                    reachDistance(i) = m
                  }
                }
              }
            }
          }
        }
      }
    }

    // 连接、合并聚类
    val connectStart = System.currentTimeMillis()
    val clusterArray: Array[Int] = new Array[Int](length)
    var mark: Int = 1
    for (i <- 0 until length) {
      if (categary(i) == 1 && clusterArray(i) == 0) {
        clusterArray(i) = mark
        for (j <- 0 until length) {
          if (categary(j) == 1 && math.sqrt(math.pow(dataArray(i)(0) - dataArray(j)(0), 2) + math.pow(dataArray(i)(1) - dataArray(j)(1), 2)) <= (math.sqrt(reachDistance(i)) + math.sqrt(reachDistance(j)))) {
            if (clusterArray(j) == 0) {
              clusterArray(j) = mark
            } else {
              var tempCluster = clusterArray(j)
              for (m <- 0 until length) {
                if (clusterArray(m) == tempCluster) {
                  clusterArray(m) = mark
                }
              }
            }
          }
        }
        //        println(mark)
        mark += 1
      }
    }
    for (i <- 0 until length) {
      if (categary(i) == 0) {
        clusterArray(i) = clusterArray(reachDistance(i).toInt)
      }
    }

    //重新标记类别
    val relabelStart = System.currentTimeMillis()
    val tempArray = new Array[Int](length)
    val labelsPred = new ArrayBuffer[Int]()
    var indexMark: Int = 1
    for (i <- 0 until length) {
      if (tempArray.contains(clusterArray(i))) {
        labelsPred.append(tempArray.indexOf(clusterArray(i)))
      } else {
        tempArray(indexMark) = clusterArray(i)
        labelsPred.append(indexMark)
        indexMark += 1
      }
    }
    val clusterEnd: Long = System.currentTimeMillis()
    println("聚类结束：" + (clusterEnd - clusteStart) / 1000.0 + "秒")
    paintClusterResult(dataArray, labelsPred.toArray, clusterResultOutputLocation)
    val timeArray: ArrayBuffer[Double] = new ArrayBuffer[Double]()
    timeArray.append((caculateAngleStart - clusteStart) / 1000.0, (caculateDCMStart - caculateAngleStart) / 1000.0, (divideStart - caculateDCMStart) / 1000.0, (calculateReachDistanceStart - divideStart) / 1000.0, (connectStart - calculateReachDistanceStart) / 1000.0, (relabelStart - connectStart) / 1000.0, (clusterEnd - relabelStart) / 1000.0, (clusterEnd - clusteStart) / 1000.0)
    evaluateTime(timeArray.toArray, timeEvaluationOutPutLocation)
  }

  def txtCDCCluster() = {
    //读取数据
    val txtData = readTxtData(txtDataInputLocation)
    val mapRDD = txtData._1
    val labelsTrue = txtData._2
    val clusteStart: Long = System.currentTimeMillis()
    val dataArray: Array[Array[Double]] = mapRDD.collect()
    val length: Int = dataArray.length
    val metric: Metric = new MetricEuclideanSquared()

    val buildParams: IndexKMeans.BuildParams = new IndexKMeans.BuildParams()
    val indexKMeans: IndexBase = new IndexKMeans(metric, dataArray, buildParams)
    indexKMeans.buildIndex()
    val searchParams: IndexKMeans.SearchParams = new IndexKMeans.SearchParams()
    searchParams.maxNeighbors = k
    searchParams.eps = 0.0f

    val indices: Array[Array[Int]] = Array.ofDim[Int](length, k)
    val distances: Array[Array[Double]] = Array.ofDim[Double](length, k)
    indexKMeans.knnSearch(dataArray, indices, distances, searchParams)

    //计算角度
    val caculateAngleStart = System.currentTimeMillis()
    val angleArray: Array[Array[Double]] = Array.ofDim[Double](length, k)
    for (i <- 0 until length) {
      for (j <- 0 until k) {
        val deltaX: Double = dataArray(indices(i)(j))(0) - dataArray(i)(0)
        val deltaY: Double = dataArray(indices(i)(j))(1) - dataArray(i)(1)
        if (deltaX == 0) {
          if (deltaY == 0) {
            angleArray(i)(j) = 0
          } else if (deltaY > 0) {
            angleArray(i)(j) = math.Pi / 2
          } else {
            angleArray(i)(j) = 3 * math.Pi / 2
          }
        } else if (deltaX > 0) {
          if (math.atan(deltaY / deltaX) >= 0) {
            angleArray(i)(j) = math.atan(deltaY / deltaX)
          } else {
            angleArray(i)(j) = 2 * math.Pi + math.atan(deltaY / deltaX)
          }
        } else {
          angleArray(i)(j) = math.Pi + math.atan(deltaY / deltaX)
        }
      }

    }

    //计算标准化DCM
    val caculateDCMStart = System.currentTimeMillis()
    val dcmValue: Array[Double] = new Array[Double](length)
    for (i <- 0 until length) {
      val angleOrder: Array[Double] = angleArray(i).sorted
      //      println(angleOrder.mkString("Array(", ", ", ")"))
      dcmValue(i) = 0
      for (j <- 1 until k - 1) {
        dcmValue(i) += math.pow(angleOrder(j + 1) - angleOrder(j) - 2 * math.Pi / k, 2)
      }
      dcmValue(i) += math.pow(angleOrder(1) - angleOrder(k - 1) + 2 * math.Pi - 2 * math.Pi / (k - 1), 2)
      dcmValue(i) /= ((k - 2) * 4 * math.pow(math.Pi, 2) / (k - 1))
    }

    //划分内部点与边界点
    val divideStart = System.currentTimeMillis()
    val categary: Array[Int] = new Array[Int](length)
    dcmThreshold = SortUtils.findKthLargest(dcmValue, (length * dcmRatio).toInt)
    for (i <- 0 until length) {
      if (dcmValue(i) < dcmThreshold) {
        categary(i) = 1
      } else {
        categary(i) = 0
      }
    }

    //计算可达距离
    val calculateReachDistanceStart = System.currentTimeMillis()
    val reachDistance: Array[Double] = new Array[Double](length)
    val loop1: Breaks = new Breaks;
    for (i <- 0 until length) {
      //内部点
      if (categary(i) == 1) {
        loop1.breakable {
          for (j <- 1 until k) {
            if (categary(indices(i)(j)) == 0) {
              reachDistance(i) = distances(i)(j)
              //              println(reachDistance(i))
              loop1.break()
            } else if (j == k - 1 && categary(indices(i)(j)) == 1) {
              reachDistance(i) = Short.MaxValue
              var temp: Double = 0.0
              for (m <- 0 until length) {
                if (categary(m) == 0) {
                  temp = math.pow(dataArray(i)(0) - dataArray(m)(0), 2) + math.pow(dataArray(i)(1) - dataArray(m)(1), 2)
                  //                  println(temp)
                  if (temp < reachDistance(i)) {
                    reachDistance(i) = temp
                  }
                }
              }
            }
          }
        }
      } else {
        val loop2: Breaks = new Breaks;
        loop2.breakable {
          for (j <- 1 until k) {
            if (categary(indices(i)(j)) == 1) {
              reachDistance(i) = indices(i)(j)
              loop2.break()
            } else if (j == k - 1 && categary(indices(i)(j)) == 0) {
              var tempDistance: Double = Double.MaxValue
              var temp2: Double = 0.0
              for (m <- 0 until length) {
                if (categary(m) == 1) {
                  temp2 = math.pow(dataArray(i)(0) - dataArray(m)(0), 2) + math.pow(dataArray(i)(1) - dataArray(m)(1), 2)
                  if (temp2 < tempDistance) {
                    tempDistance = temp2
                    reachDistance(i) = m
                  }
                }
              }
            }
          }
        }
      }
    }

    // 连接、合并聚类
    val connectStart = System.currentTimeMillis()
    val clusterArray: Array[Int] = new Array[Int](length)
    var mark: Int = 1
    for (i <- 0 until length) {
      if (categary(i) == 1 && clusterArray(i) == 0) {
        clusterArray(i) = mark
        for (j <- 0 until length) {
          if (categary(j) == 1 && math.sqrt(math.pow(dataArray(i)(0) - dataArray(j)(0), 2) + math.pow(dataArray(i)(1) - dataArray(j)(1), 2)) <= (math.sqrt(reachDistance(i)) + math.sqrt(reachDistance(j)))) {
            if (clusterArray(j) == 0) {
              clusterArray(j) = mark
            } else {
              var tempCluster = clusterArray(j)
              for (m <- 0 until length) {
                if (clusterArray(m) == tempCluster) {
                  clusterArray(m) = mark
                }
              }
            }
          }
        }
        //        println(mark)
        mark += 1
      }
    }
    for (i <- 0 until length) {
      if (categary(i) == 0) {
        clusterArray(i) = clusterArray(reachDistance(i).toInt)
      }
    }

    //重新标记类别
    val relabelStart = System.currentTimeMillis()
    val tempArray = new Array[Int](length)
    val labelsPred = new ArrayBuffer[Int]()
    var indexMark: Int = 1
    for (i <- 0 until length) {
      if (tempArray.contains(clusterArray(i))) {
        labelsPred.append(tempArray.indexOf(clusterArray(i)))
      } else {
        tempArray(indexMark) = clusterArray(i)
        labelsPred.append(indexMark)
        indexMark += 1
      }
    }
    val clusterEnd: Long = System.currentTimeMillis()
    println("聚类结束：" + (clusterEnd - clusteStart) / 1000.0 + "秒")
    paintClusterResult(dataArray, labelsPred.toArray, clusterResultOutputLocation)
    //    paintClusterResult(dataArray, labelsTrue, clusterResultOutputLocation)
    evaluateCluster(labelsTrue, labelsPred.toArray, clusterEvaluationOutPutLocation)
    val timeArray: ArrayBuffer[Double] = new ArrayBuffer[Double]()
    timeArray.append((caculateAngleStart - clusteStart) / 1000.0, (caculateDCMStart - caculateAngleStart) / 1000.0, (divideStart - caculateDCMStart) / 1000.0, (calculateReachDistanceStart - divideStart) / 1000.0, (connectStart - calculateReachDistanceStart) / 1000.0, (relabelStart - connectStart) / 1000.0, (clusterEnd - relabelStart) / 1000.0, (clusterEnd - clusteStart) / 1000.0)
    evaluateTime(timeArray.toArray, timeEvaluationOutPutLocation)
  }

  def evaluateCluster(labelsTrue: Array[Int], labelsPred: Array[Int], outputPath: String) = {
    createFile(outputPath)
    val filterNan = labelsTrue.zip(labelsPred).filter((filter: (Int, Int)) => filter._1 != (-1))
    val labelsTrueFilter = filterNan.unzip._1.map(_.toInt)
    val labelsPredFilter = filterNan.unzip._2
    val writer = new FileWriter(new File(outputPath), true)
    writer.write(k + "\t" + dcmThreshold + "\t" + purity(labelsTrueFilter, labelsPredFilter) + "\t" + FMeasure(labelsTrueFilter, labelsPredFilter) + "\t" + randIndex(labelsTrueFilter, labelsPredFilter) + "\t" + adjustedRandIndex(labelsTrueFilter, labelsPredFilter)
      + "\t" + jaccardIndex(labelsTrueFilter, labelsPredFilter) + "\t" + normalizedMutualInformation(labelsTrueFilter, labelsPredFilter) + "\n")
    //关闭写入流
    writer.close()
  }

  def paintClusterResult(array: Array[Array[Double]], labels: Array[Int], outputPath: String) = {
    val xydataset: DefaultXYDataset = new DefaultXYDataset
    val cluster: Map[Int, Array[(Array[Double], Int)]] = array.zip(labels).groupBy(_._2)
    cluster.foreach(group => {
      var clusterID = group._1
      var array: Array[(Double, Double)] = group._2.map(_._1).map(point => (point(0), point(1)))
      val points: Array[Array[Double]] = new Array[Array[Double]](2)
      points(0) = array.map(_._1)
      points(1) = array.map(_._2)
      xydataset.addSeries("cluster" + clusterID, points)
    })
    val chart: JFreeChart = ChartFactory.createScatterPlot("CDC(k=" + k + ",tDCM=" + dcmThreshold + ",ratio=" + dcmRatio + ")", "X", "Y", xydataset, PlotOrientation.VERTICAL, true, false, false)
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

  def createFile(path: String) = {
    val file = new File(path)
    if (!file.getParentFile.exists) file.getParentFile.mkdirs
  }

  def evaluateTime(array: Array[Double], outputPath: String) = {
    createFile(outputPath)
    val writer = new FileWriter(new File(outputPath), true)
    writer.write(k + "\t" + dcmThreshold + "\t")
    for (i <- array) {
      writer.write(i + "\t")
    }
    writer.write("\n")
    //关闭写入流
    writer.close()
  }

  def testTxt1(): Unit = {
    for (i <- Range(1, 7)) {
      dataFileName = "DS" + i
      for (m <- Range(10, 51, 5)) {
        k = m
        for (n <- Range(5, 31, 5)) {
          dcmRatio = n / 100.0
          println("文件名:" + dataFileName + "\t文件类型:" + dataFileType)
          txtDataInputLocation = resourceFolder + "/SyntheticDatasets/" + dataFileName + ".txt"
          clusterResultOutputLocation = resourceFolder + "/ResultData/clusterResult/raw/" + dataFileName + "/" + k + "_" + dcmRatio + ".png"
          clusterEvaluationOutPutLocation = resourceFolder + "/ResultData/clusterEvaluation/raw/" + dataFileName + ".txt"
          timeEvaluationOutPutLocation = resourceFolder + "/ResultData/timeEvaluation/raw/" + dataFileName + ".txt"
          txtCDCCluster()
        }
      }
    }
  }

  def testTxt2(): Unit = {
    for (i <- List("Levine", "Samusik")) {
      dataFileName = i + "_UMAP"
      for (m <- Range(30, 101, 10)) {
        k = m
        for (n <- Range(5, 31, 5)) {
          dcmRatio = n / 100.0
          println("文件名:" + dataFileName + "\t文件类型:" + dataFileType)
          txtDataInputLocation = resourceFolder + "/CyTOFDatasets/" + dataFileName + ".txt"
          clusterResultOutputLocation = resourceFolder + "/ResultData/clusterResult/raw/" + dataFileName + "/" + k + "_" + dcmRatio + ".png"
          clusterEvaluationOutPutLocation = resourceFolder + "/ResultData/clusterEvaluation/raw/" + dataFileName + ".txt"
          timeEvaluationOutPutLocation = resourceFolder + "/ResultData/timeEvaluation/raw/" + dataFileName + ".txt"
          txtCDCCluster()
        }
      }
    }
  }

  def testCsv1(): Unit = {
    for (i <- List("1", "2", "5", "10", "20", "30")) {
      dataFileName = "hubei-" + i + "0000"
      //        for (m <- Range(3, 52, 1)) {
      //          k = m
      for (n <- Range(5, 31, 5)) {
        dcmRatio = n / 100.0
        println("文件名:" + dataFileName + "\t文件类型:" + dataFileType)
        csvDataInputLocation = resourceFolder + "/GeoDataSets/0.37 Million Enterprise Registration Data in Hubei Province/Points/" + dataFileName + ".csv"
        clusterResultOutputLocation = resourceFolder + "/ResultData/clusterResult/raw/" + dataFileName + "/" + k + "_" + dcmRatio + ".png"
        timeEvaluationOutPutLocation = resourceFolder + "/ResultData/timeEvaluation/raw/" + dataFileName + ".txt"
        csvCDCCluster()
      }
    }
  }

  def testCsv2(): Unit = {
    for (i <- Range(1, 11, 1)) {
      dataFileName = i + "00000"
      //        for (m <- Range(3, 52, 1)) {
      //          k = m
      for (n <- Range(5, 31, 5)) {
        dcmRatio = n / 100.0
        println("文件名:" + dataFileName + "\t文件类型:" + dataFileType)
        csvDataInputLocation = resourceFolder + "/GeoDataSets/1 Million Amap Points of Interest in China/Points/" + dataFileName + ".csv"
        clusterResultOutputLocation = resourceFolder + "/ResultData/clusterResult/raw/" + dataFileName + "/" + k + "_" + dcmRatio + ".png"
        timeEvaluationOutPutLocation = resourceFolder + "/ResultData/timeEvaluation/raw/" + dataFileName + ".txt"
        csvCDCCluster()
      }
    }
  }
}
