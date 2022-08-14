package com.yolo.CDC.scala.HKCDC

import com.yolo.CDC.java.`type`.{FileDataSplitter, GridType}
import com.yolo.CDC.java.knnsearch.index.{IndexBase, IndexKMeans, SearchParamsBase}
import com.yolo.CDC.java.knnsearch.metric.{Metric, MetricEuclideanSquared}
import com.yolo.CDC.java.rdd.{CDCPoint, PointRDD}
import com.yolo.CDC.java.serde.SedonaKryoRegistrator
import com.yolo.CDC.java.utils.Evaluation._
import com.yolo.CDC.java.utils.SortUtils
import com.yolo.CDC.java.utils.WriteArray.writeArrayToExcel
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


object HKCDC_parallel_v3 {
  var sc: SparkContext = null

    val resourceFolder: String = System.getProperty("user.dir")
  //  val resourceFolder: String = "file:///vda/cdc"
//  val inputResourceFolder: String ="hdfs://master:9000/cdc"
//  val outputResourceFolder: String ="spark/data/cdc"

  var dataInputLocation: String = null

  var spatialPartitionedRDDOutputLocation: String = null

  var clusterResultOutputLocation: String = null

  var clusterResultOutPutTxt: String = null

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
  var dcmThreshold: Double = 0.1
  //(Default: 0.1, Recommended: 0.05~0.25)
  var dcmRatio: Double = 0.1

  def main(args: Array[String]): Unit = {
    //配置环境与序列化
//    val sparkConf: SparkConf = new SparkConf().setMaster("spark://master:7077").setAppName("HKCDC")
    val sparkConf: SparkConf = new SparkConf().setMaster("local[*]").setAppName("HKCDC")
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
    dataFileType = "CSV"

    //聚类
    dataFileType match {
      case "CSV" => {
        testCsv()
      }
      case "TXT" =>
        testTxt()
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
      searchParams.maxNeighbors=k
      //近邻搜索
      index.value.knnSearch(point._2.getCoordinates, indices, distances, searchParams)
      point._2.setNeighborsIndexID(indices)
      point._2.setNeighborsDistance(distances)
      //计算DCM值
      calculateDCM(dataArray, point, indices)
      point
    }
  }

  def calculateDCMs(rdd: RDD[(Int, CDCPoint)], dataArray: Array[Array[Double]], index: Broadcast[IndexBase], searchParams: SearchParamsBase): RDD[(Int, CDCPoint)] = {
    rdd.mapPartitions(iter => new PartitionIterator(iter, dataArray, index, searchParams))
  }

  class PartitionIterator2(iter: Iterator[(Int, CDCPoint)],dcmThreshold:Broadcast[Double]) extends Iterator[(Int, CDCPoint)] {
    override def hasNext: Boolean = {
      iter.hasNext
    }

    override def next(): (Int, CDCPoint) = {
      val point: (Int, CDCPoint) = iter.next()
      //划分内部点与边界点
      if (point._2.getDcmValue < dcmThreshold.value) {
        point._2.setFlag(CDCPoint.Flag.Inner)
      } else {
        point._2.setFlag(CDCPoint.Flag.Border)
      }
      point
    }
  }

  class PartitionIterator3(iter: Iterator[(Int, CDCPoint)], flagArray: Array[CDCPoint.Flag], index1: Broadcast[IndexBase], index2: Broadcast[IndexBase]) extends Iterator[(Int, CDCPoint)] {
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
    rdd.mapPartitions(iter => new PartitionIterator3(iter, flagArray, index1, index2))
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

  def evaluateCluster(array: Array[CDCPoint]) = {
    val clusterData: Array[(Double, Double, Int)] = array.sortBy(point => (point.getX, point.getY)).map(point => (point.getX, point.getY, -point.getClusterID))
    createFile(clusterResultOutPutTxt)
    val resultWriter = new FileWriter(new File(clusterResultOutPutTxt))

    dataFileType match {
      case "CSV" => {
        resultWriter.flush()
        for (i <- 0 until clusterData.length) {
          resultWriter.write(clusterData(i)._1 + "\t" + clusterData(i)._2+"\t"+ clusterData(i)._3+"\n")
        }
      }
      case "TXT" =>{
        createFile(clusterEvaluationOutPutLocation)
        val evaluateWriter = new FileWriter(new File(clusterEvaluationOutPutLocation), true)
        val rawData: Array[(Double, Double, String)] = sc.textFile(dataInputLocation).map(line => {
          val lineSplit: Array[String] = line.trim.split("\\s+")
          (lineSplit(0).toDouble, lineSplit(1).toDouble, lineSplit(2))
        }).sortBy((point: (Double, Double, String)) => (point._1, point._2)).collect()
        val labelsTrue: Array[String] = rawData.map(_._3)
        val labelsPred: Array[Int] = clusterData.map(_._3)
        resultWriter.flush()
        for (i <- 0 until clusterData.length) {
          resultWriter.write(clusterData(i)._1 + "\t" + clusterData(i)._2+"\t"+ clusterData(i)._3+"\t"+labelsTrue(i)+"\n")
        }
        val filterNan: Array[(String, Int)] = labelsTrue.zip(labelsPred).filter(_._1 != "NaN")
        val labelsTrueFilter: Array[Int] = filterNan.unzip._1.map(_.toInt)
        val labelsPredFilter: Array[Int] = filterNan.unzip._2
        var ss: Double = 0;
        var sd: Double = 0;
        var ds: Double = 0;
        var dd: Double = 0;
        for (i <- 0 until labelsTrueFilter.length) {
          for (j <- i + 1 until labelsTrueFilter.length) {
            if (labelsPredFilter(i)== labelsPredFilter(j) && labelsTrueFilter(i) == labelsTrueFilter(j)) {
              ss += 1
            } else if (labelsPredFilter(i)!= labelsPredFilter(j) && labelsTrueFilter(i) != labelsTrueFilter(j)) {
              dd += 1
            } else if (labelsPredFilter(i)!= labelsPredFilter(j) && labelsTrueFilter(i) == labelsTrueFilter(j)) {
              sd += 1
            } else if (labelsPredFilter(i)== labelsPredFilter(j) && labelsTrueFilter(i) != labelsTrueFilter(j)) {
              ds += 1
            }

          }
        }
        val ARI: Double = (2 * (ss * dd - ds * sd)) / ((2 * (ss * dd - ds * sd)) + (ds + sd) * (ss + sd + ds + dd))
        val precision: Double = ss / (ss + ds)
        val recall: Double = ss / (ss + sd)
        val RI: Double = (ss + dd) / (ss + sd + ds + dd)
        val Fscore: Double = 2 * precision * recall / (precision + recall)
        val JI: Double = ss / (ss + sd + ds)
        println("ss:"+ss+"\t"+"ss:"+sd+"\t"+"ds:"+ds+"\t"+"dd:"+dd)
        evaluateWriter.write(PointRDDNumPartitions + "\t" + k + "\t" + dcmThreshold + "\t" +
          PointRDDGridType + "\t" + PointRDDIndexType + "\t" + ARI+"\t" + precision+"\t" + recall+"\t" + RI+"\t" + Fscore+"\t" + JI+"\n")
        evaluateWriter.close()
      }
    }

    //关闭写入流
    resultWriter.close()
  }

  def saveTimeToTxt(array: Array[Double], outputPath: String) = {
    createFile(outputPath)
    val writer = new FileWriter(new File(outputPath), true)
    writer.write(PointRDDNumPartitions + "\t" + k + "\t" + dcmRatio + "\t" + PointRDDGridType + "\t" + PointRDDIndexType + "\t")
    for (i <- array) {
      writer.write(i + "\t")
    }
    writer.write("\n")
    //关闭写入流
    writer.close()
  }

  def csvCDCCluster(searchParams: SearchParamsBase) = {
    deleteExistingDir("CheckPointDir")
    sc.setCheckpointDir("CheckPointDir")
    PointRDDSplitter = FileDataSplitter.COMMA

    //读取数据
    println("读取数据开始----------")
    val readDataStart: Long = System.currentTimeMillis()
    objectRDD = new PointRDD(sc, dataInputLocation, 0, PointRDDSplitter, true, PointRDDNumPartitions, StorageLevel.MEMORY_ONLY)
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
    val calculateDCMRDD: RDD[(Int, CDCPoint)] = calculateDCMs(spatialPartitionedRDD, dataArray, indexKMeansBc, searchParams)
    persistRDD(calculateDCMRDD)
    val dcmArray: Array[Double] = calculateDCMRDD.map(point => point._2.getDcmValue).collect()
    dcmThreshold = SortUtils.findKthLargest(dcmArray, (dcmArray.length * dcmRatio).toInt)
    val dcmThresholdBc: Broadcast[Double] = sc.broadcast(dcmThreshold)
    println("dcmThreshold:" + dcmThreshold)
    val dividePointRDD: RDD[(Int, CDCPoint)] = calculateDCMRDD.mapPartitions(iter => new PartitionIterator2(iter,dcmThresholdBc))
    persistRDD(dividePointRDD)
    val divideEnd: Long = System.currentTimeMillis()
    println("划分结束----------")
    println("时间：" + (divideEnd - divideStart) / 1000.0 + "秒")

    //获得划分结果数组
    val flagArray: Array[CDCPoint.Flag] = dividePointRDD.sortBy(point => point._2.getIndexID).map(point => point._2.getFlag).collect()

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
    //    paintClusterResult(clusterArray.toList, clusterResultOutputLocation)
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
    //    timeArray.append(readDataStart, readDataEnd, partitionStart, partitionEnd, indexStart, indexEnd, divideStart, divideEnd,
    //      reachDistanceStart, reachDistanceEnd, connectInnerPointStart, connectInnerPointEnd, connectInnerPointBStart, connectInnerPointBEnd, labelBoderPointStart, labelBoderPointEnd)
    timeArray.append((readDataEnd - readDataStart) / 1000.0, (partitionEnd - partitionStart) / 1000.0, (indexStart - partitionEnd) / 1000.0, (indexEnd - indexStart) / 1000.0, (divideEnd - divideStart) / 1000.0, (reachIndexStart - divideEnd) / 1000.0, (reachIndexEnd - reachIndexStart) / 1000.0,
      (reachDistanceEnd - reachDistanceStart) / 1000.0, (connectInnerPointEnd - connectInnerPointStart) / 1000.0, (connectInnerPointBEnd - connectInnerPointBStart) / 1000.0, (labelBoderPointEnd - labelBoderPointStart) / 1000.0, (labelBoderPointEnd - partitionStart) / 1000.0)
    saveTimeToTxt(timeArray.toArray, timeEvaluationOutPutLocation)
  }

  def txtCDCCluster(searchParams: SearchParamsBase) = {
    deleteExistingDir("CheckPointDir")
    sc.setCheckpointDir("CheckPointDir")
    PointRDDSplitter = FileDataSplitter.TAB

    //读取数据
    println("读取数据开始----------")
    val readDataStart: Long = System.currentTimeMillis()
    objectRDD = new PointRDD(sc, dataInputLocation, 0, PointRDDSplitter, true, PointRDDNumPartitions, StorageLevel.MEMORY_ONLY)
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
    val calculateDCMRDD: RDD[(Int, CDCPoint)] = calculateDCMs(spatialPartitionedRDD, dataArray, indexKMeansBc, searchParams)
    persistRDD(calculateDCMRDD)
    val dcmArray: Array[Double] = calculateDCMRDD.map(point => point._2.getDcmValue).collect()
    dcmThreshold = SortUtils.findKthLargest(dcmArray, (dcmArray.length * dcmRatio).toInt)
    val dcmThresholdBc: Broadcast[Double] = sc.broadcast(dcmThreshold)
    println("dcmThreshold:" + dcmThreshold)
    val dividePointRDD: RDD[(Int, CDCPoint)] = calculateDCMRDD.mapPartitions(iter => new PartitionIterator2(iter,dcmThresholdBc))
    persistRDD(dividePointRDD)
    val divideEnd: Long = System.currentTimeMillis()
    println("划分结束----------")
    println("时间：" + (divideEnd - divideStart) / 1000.0 + "秒")

    //获得划分结果数组
    val flagArray: Array[CDCPoint.Flag] = dividePointRDD.sortBy(point => point._2.getIndexID).map(point => point._2.getFlag).collect()

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
//    paintClusterResult(clusterArray.toList, clusterResultOutputLocation)
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
    saveTimeToTxt(timeArray.toArray, timeEvaluationOutPutLocation)
  }

  def testCsv(): Unit = {
    for (i <- List("hubei-1")) {
      dataFileName = i + "0000"
      for (j <- List(16)) {
        PointRDDNumPartitions = j
        for (m <- Range(30, 51, 10)) {
          k = m
          for (n <- Range(5, 31, 5)) {
            dcmRatio = n / 100.0
            println("文件名:" + dataFileName + "\t文件类型:" + dataFileType + "\t分区数:" + PointRDDNumPartitions + "\t邻居数:" + k + "\tDCM阈值比例:" + dcmRatio)
            val searchParams: SearchParamsBase = new IndexKMeans.SearchParams()
            searchParams.maxNeighbors = k
//            csvDataInputLocation = inputResourceFolder + "/Points/" + dataFileName + ".csv"
//            clusterResultOutPutTxt = outputResourceFolder + "/ResultData/clusterResult/HKCDC/" + dataFileName + "/" + PointRDDGridType + "_" + PointRDDIndexType + "_" + PointRDDNumPartitions + "_" + k + "_" + dcmRatio + ".txt"
//            clusterResultOutputLocation = outputResourceFolder + "/ResultData/clusterResult/HKCDC/" + dataFileName + "/" + PointRDDGridType + "_" + PointRDDIndexType + "_" + PointRDDNumPartitions + "_" + k + "_" + dcmRatio + ".png"
//            clusterAndPartitionResultOutputLocation = outputResourceFolder + "/ResultData/cpResult/HKCDC/" + dataFileName + "/" + PointRDDGridType + "_" + PointRDDIndexType + "_" + PointRDDNumPartitions + "_" + k + "_" + dcmRatio + ".png"
//            timeEvaluationOutPutLocation = outputResourceFolder + "/ResultData/timeEvaluation/" + dataFileName + ".txt"
            dataInputLocation = resourceFolder + "/GeoDataSets/0.37 Million Enterprise Registration Data in Hubei Province/Points/" + dataFileName + ".csv"
            clusterResultOutputLocation = resourceFolder + "/ResultData/clusterResult/test/" + dataFileName + "/" + PointRDDGridType + "_" + PointRDDIndexType + "_" + PointRDDNumPartitions + "_" + k + "_" + dcmRatio + ".png"
//            clusterAndPartitionResultOutputLocation = resourceFolder + "/ResultData/cpResult/HKCDC/" + dataFileName + "/" + PointRDDGridType + "_" + PointRDDIndexType + "_" + PointRDDNumPartitions + "_" + k + "_" + dcmRatio + ".png"
            clusterResultOutPutTxt = resourceFolder + "/ResultData/clusterResult/test/" + dataFileName + "/" + PointRDDGridType + "_" + PointRDDIndexType + "_" + PointRDDNumPartitions + "_" + k + "_" + dcmRatio + ".txt"
            timeEvaluationOutPutLocation = resourceFolder + "/ResultData/timeEvaluation/test/" + dataFileName + ".txt"
            csvCDCCluster(searchParams)
          }
        }
      }
    }
  }
  def testTxt(): Unit = {
    for (i <- Range(1, 7)) {
      dataFileName = "DS" + i
      for (j <- Range(4, 33, 4)) {
        PointRDDNumPartitions = j
        for (m <- Range(3, 52, 1)) {
          k = m
          for (n <- Range(5, 31, 5)) {
            dcmRatio = n / 100.0
            println("文件名:" + dataFileName + "\t文件类型:" + dataFileType + "\t分区数:" + PointRDDNumPartitions + "\t邻居数:" + k + "\tDCM阈值:" + dcmRatio)
            val searchParams: SearchParamsBase = new IndexKMeans.SearchParams()
            searchParams.maxNeighbors = k
            dataInputLocation = resourceFolder + "/SyntheticDatasets/" + dataFileName + ".txt"
//            clusterResultOutputLocation = resourceFolder + "/ResultData/clusterResult/test/" + dataFileName + "/" + PointRDDGridType + "/" + PointRDDIndexType + "/" + PointRDDNumPartitions + "_" + k + "_" + dcmRatio + ".png"
//            clusterAndPartitionResultOutputLocation = resourceFolder + "/ResultData/cpResult/" + dataFileName + "/" + PointRDDGridType + "/" + PointRDDIndexType + "/" + PointRDDNumPartitions + "_" + k + "_" + dcmRatio + ".png"
            clusterResultOutPutTxt= resourceFolder + "/ResultData/clusterResult/test/" + dataFileName + "/" + PointRDDGridType + "_" + PointRDDIndexType + "_" + PointRDDNumPartitions + "_" + k + "_" + dcmRatio + ".txt"
            clusterEvaluationOutPutLocation = resourceFolder + "/ResultData/clusterEvaluation/test/" + dataFileName + ".txt"
            timeEvaluationOutPutLocation = resourceFolder + "/ResultData/timeEvaluation/test/" + dataFileName + ".txt"
            txtCDCCluster(searchParams)
          }
        }
      }
    }
  }

}
