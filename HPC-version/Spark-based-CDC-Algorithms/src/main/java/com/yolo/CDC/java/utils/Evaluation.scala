package com.yolo.CDC.java.utils

import com.google.common.math.{DoubleMath, IntMath}

object Evaluation {


  /**
   *
   * 检查标签
   *
   * @param labelsTrue
   * @param labelsPred
   *
   */

  private def labelChecker(labelsTrue: Array[Int], labelsPred: Array[Int]): Unit = {

    require(labelsTrue.length == labelsPred.length && labelsTrue.length >= 2, "The length must be equal!" +

      "The size of labels must be greater than 1!")

  }


  /**
   *
   * 纯度：Purity
   *
   * @param labelsTrue
   * @param labelsPred
   * @return
   *
   */

  def purity(labelsTrue: Array[Int], labelsPred: Array[Int]) = {

    labelChecker(labelsTrue, labelsPred)

    val eachCount: Map[(Int, Int), Int] = labelsTrue.zip(labelsPred).groupBy((x: (Int, Int)) => x).mapValues((_: Array[(Int, Int)]).length)

    eachCount.groupBy((_: ((Int, Int), Int))._1._1).mapValues((_: Map[(Int, Int), Int]).values.max).values.sum.toDouble / labelsTrue.length

  }


  /**
   *
   * 互信息：Mutual Information
   *
   * @param labelsTrue
   * @param labelsPred
   *
   */

  private def mutualInformation(labelsTrue: Array[Int], labelsPred: Array[Int]) = {

    labelChecker(labelsTrue, labelsPred)

    val N: Int = labelsTrue.length

    val mapTrue: Map[Int, Int] = labelsTrue.groupBy(x => x).mapValues(_.length)

    val mapPred: Map[Int, Int] = labelsPred.groupBy(x => x).mapValues(_.length)

    labelsTrue.zip(labelsPred).groupBy(x => x).mapValues(_.length).map {

      case ((x, y), z) =>

        val wk = mapTrue(x)

        val cj = mapPred(y)

        val common = z.toDouble

        common / N * DoubleMath.log2(N * common / (wk * cj))

    }.sum

  }


  /**
   *
   * 熵：Entropy
   *
   * @param labels
   * @return
   *
   */

  private def entropy(labels: Array[Int]) = {

    val N: Int = labels.length

    val array: Array[Int] = labels.groupBy(x => x).values.map(_.length).toArray

    array.map(x => -1.0 * x / N * DoubleMath.log2(1.0 * x / N)).sum

  }


  /**
   *
   * 标准化互信息：Normalized Mutual Information
   *
   * @param labelsTrue
   * @param labelsPred
   * @return
   *
   */

  def normalizedMutualInformation(labelsTrue: Array[Int], labelsPred: Array[Int]) = {

    labelChecker(labelsTrue, labelsPred)

    2 * mutualInformation(labelsTrue, labelsPred) / (entropy(labelsTrue) + entropy(labelsPred))

  }


  /**
   *
   * 混淆矩阵
   *
   * @param TP
   * @param FP
   * @param FN
   * @param TN
   *
   */

  case class Table(TP: Int, FP: Int, FN: Int, TN: Int)


  /**
   *
   * 计算混淆矩阵
   *
   * @param labelsTrue
   * @param labelsPred
   * @return
   *
   */

  private def contingencyTable(labelsTrue: Array[Int], labelsPred: Array[Int]) = {

    labelChecker(labelsTrue, labelsPred)

    def binomial(x: Int) = if (x < 2) 0 else IntMath.binomial(x, 2)

    val TPAndFP: Int = labelsPred.groupBy(x => x).values.map(x => binomial(x.length)).sum

    val tmp: Map[(Int, Int), Array[(Int, Int)]] = labelsTrue.zip(labelsPred).groupBy(x => x)

    val TP: Int = tmp.values.map(x => binomial(x.length)).sum

    val FP: Int = TPAndFP - TP

    def fun(xs: Array[Int]) = {

      val length: Int = xs.length

      val sums: Array[Int] = xs.tails.slice(1, length).toArray.map(_.sum)

      (xs.init, sums).zipped.map(_ * _).sum

    }

    val FN: Int = tmp.groupBy(_._1._1).mapValues(_.values.map(_.length).toArray).values.map(fun).sum

    val total: Int = binomial(labelsTrue.length)

    val TN: Int = total - TPAndFP - FN

    Table(TP, FP, FN, TN)

  }


  /**
   *
   * Rand Index值
   *
   * @param labelsTrue
   * @param labelsPred
   * @return
   *
   */

  def randIndex(labelsTrue: Array[Int], labelsPred: Array[Int]) = {

    labelChecker(labelsTrue, labelsPred)

    val table: Table = contingencyTable(labelsTrue, labelsPred)

    1.0 * (table.TP + table.TN) / (table.TP + table.FP + table.FN + table.TN)

  }

  /**
  * Adjusted Rand Index, ARI
  * @Param:
  * @Return:
  * @Version:1.0
  **/
  def adjustedRandIndex(labelsTrue: Array[Int], labelsPred: Array[Int])={
    labelChecker(labelsTrue, labelsPred)
    val table: Table = contingencyTable(labelsTrue, labelsPred)
    1.0 * (2.0 * (1.0*table.TP * table.TN-1.0*table.FN * table.FP)) / ((2.0 * (1.0*table.TP * table.TN-1.0*table.FN * table.FP))+1.0*(table.FN+table.FP) * (table.TP+table.TN+table.FN+table.FP))
  }
  /**
   *
   * 准确率：Precision
   *
   * @param labelsTrue
   * @param labelsPred
   * @return
   *
   */

  def precision(labelsTrue: Array[Int], labelsPred: Array[Int]) = {

    labelChecker(labelsTrue, labelsPred)

    val table: Table = contingencyTable(labelsTrue, labelsPred)

    1.0 * table.TP / (table.TP + table.FP)

  }


  /**
   *
   * 召回率：Recall
   *
   * @param labelsTrue
   * @param labelsPred
   * @return
   *
   */

  def recall(labelsTrue: Array[Int], labelsPred: Array[Int]) = {

    labelChecker(labelsTrue, labelsPred)

    val table: Table = contingencyTable(labelsTrue, labelsPred)

    1.0 * table.TP / (table.TP + table.FN)

  }


  /**
   *
   * FMeasure
   *
   * F值
   *
   * @param labelsTrue
   * @param labelsPred
   * @param beta
   * @return
   *
   */

  def FMeasure(labelsTrue: Array[Int], labelsPred: Array[Int])(implicit beta: Double = 1.0) = {

    labelChecker(labelsTrue, labelsPred)

    val precision1: Double = precision(labelsTrue, labelsPred)

    val recall1: Double = recall(labelsTrue, labelsPred)

    (math.pow(beta, 2) + 1) * precision1 * recall1 / (math.pow(beta, 2) * precision1 + recall1)

  }

  /**
   *
   * Jaccard Index
   * @param labelsTrue
   * @param labelsPred
   * @param beta
   * @return
   *
   */
  def jaccardIndex(labelsTrue: Array[Int], labelsPred: Array[Int])={
    labelChecker(labelsTrue, labelsPred)

    val table: Table = contingencyTable(labelsTrue, labelsPred)

    1.0 * table.TP/ (table.TP + table.FP + table.FN)
  }

}
