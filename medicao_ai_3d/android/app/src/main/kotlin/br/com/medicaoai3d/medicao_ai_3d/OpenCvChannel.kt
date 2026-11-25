package br.com.medicaoai3d.medicao_ai_3d

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.opencv.android.OpenCVLoader
import org.opencv.core.Core
import org.opencv.core.Mat
import org.opencv.core.MatOfDouble
import org.opencv.core.MatOfPoint
import org.opencv.core.MatOfPoint2f
import org.opencv.core.Point
import org.opencv.core.Scalar
import org.opencv.core.Size
import org.opencv.imgcodecs.Imgcodecs
import org.opencv.imgproc.Imgproc
import java.io.File
import java.util.concurrent.Executors
import kotlin.math.PI
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

class OpenCvChannel(
    private val context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, "br.com.medicaoai3d/opencv")
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())
    private var openCvInitialized = false

    init {
        channel.setMethodCallHandler(this)
        try {
            openCvInitialized = OpenCVLoader.initLocal()
        } catch (_: Throwable) {
            openCvInitialized = false
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> {
                if (!openCvInitialized) {
                    try {
                        openCvInitialized = OpenCVLoader.initLocal()
                    } catch (_: Throwable) {
                        openCvInitialized = false
                    }
                }
                result.success(openCvInitialized)
            }

            "analyzeContours" -> {
                val imagePath = call.argument<String>("imagePath")
                val cannyLow = call.argument<Double>("cannyLow") ?: 55.0
                val cannyHigh = call.argument<Double>("cannyHigh") ?: 155.0
                val minAreaRatio = call.argument<Double>("minAreaRatio") ?: 0.008

                if (imagePath.isNullOrBlank()) {
                    result.error("INVALID_ARGS", "Caminho da imagem não informado.", null)
                    return
                }

                executor.execute {
                    try {
                        val payload = processImage(
                            imagePath = imagePath,
                            cannyLow = cannyLow,
                            cannyHigh = cannyHigh,
                            minAreaRatio = minAreaRatio,
                        )
                        mainHandler.post { result.success(payload) }
                    } catch (e: Throwable) {
                        mainHandler.post {
                            result.error(
                                "OPENCV_ERROR",
                                "Falha ao processar imagem com OpenCV: ${e.message}",
                                null,
                            )
                        }
                    }
                }
            }

            "analyzeMaterialSurface" -> {
                val imagePath = call.argument<String>("imagePath")
                val roiLeft = call.argument<Double>("roiLeft") ?: 0.20
                val roiTop = call.argument<Double>("roiTop") ?: 0.20
                val roiWidth = call.argument<Double>("roiWidth") ?: 0.60
                val roiHeight = call.argument<Double>("roiHeight") ?: 0.60

                if (imagePath.isNullOrBlank()) {
                    result.error("INVALID_ARGS", "Caminho da imagem não informado.", null)
                    return
                }

                executor.execute {
                    try {
                        val payload = extractMaterialSurface(
                            imagePath = imagePath,
                            roiLeft = roiLeft,
                            roiTop = roiTop,
                            roiWidth = roiWidth,
                            roiHeight = roiHeight,
                        )
                        mainHandler.post { result.success(payload) }
                    } catch (e: Throwable) {
                        mainHandler.post {
                            result.error(
                                "OPENCV_MATERIAL_ERROR",
                                "Falha na análise de superfície com OpenCV: ${e.message}",
                                null,
                            )
                        }
                    }
                }
            }

            else -> result.notImplemented()
        }
    }

    private fun processImage(
        imagePath: String,
        cannyLow: Double,
        cannyHigh: Double,
        minAreaRatio: Double,
    ): Map<String, Any?> {
        if (!openCvInitialized) {
            openCvInitialized = OpenCVLoader.initLocal()
        }
        if (!openCvInitialized) {
            throw IllegalStateException("Biblioteca nativa OpenCV não pôde ser inicializada.")
        }

        val source = Imgcodecs.imread(imagePath)
        if (source.empty()) {
            throw IllegalArgumentException("Não foi possível decodificar a imagem em $imagePath")
        }

        val originalWidth = source.cols()
        val originalHeight = source.rows()
        val maxSide = max(originalWidth, originalHeight)
        val workingScale = if (maxSide > 1280) 1280.0 / maxSide.toDouble() else 1.0

        val working = Mat()
        if (workingScale < 1.0) {
            Imgproc.resize(
                source,
                working,
                Size(
                    (originalWidth * workingScale).roundToInt().toDouble(),
                    (originalHeight * workingScale).roundToInt().toDouble(),
                ),
                0.0,
                0.0,
                Imgproc.INTER_AREA,
            )
        } else {
            source.copyTo(working)
        }

        val gray = Mat()
        Imgproc.cvtColor(working, gray, Imgproc.COLOR_BGR2GRAY)

        // Real sharpness & contrast telemetry using Laplacian variance and stddev
        val laplacian = Mat()
        Imgproc.Laplacian(gray, laplacian, org.opencv.core.CvType.CV_64F)
        val lapMean = MatOfDouble()
        val lapStd = MatOfDouble()
        Core.meanStdDev(laplacian, lapMean, lapStd)
        val lapVariance = lapStd.toArray().firstOrNull()?.let { it * it } ?: 0.0

        val grayMean = MatOfDouble()
        val grayStd = MatOfDouble()
        Core.meanStdDev(gray, grayMean, grayStd)
        val contrastStd = grayStd.toArray().firstOrNull() ?: 0.0

        val blurred = Mat()
        Imgproc.GaussianBlur(gray, blurred, Size(5.0, 5.0), 0.0)

        val edges = Mat()
        Imgproc.Canny(blurred, edges, cannyLow, cannyHigh)

        val kernel = Imgproc.getStructuringElement(Imgproc.MORPH_RECT, Size(3.0, 3.0))
        val closed = Mat()
        Imgproc.morphologyEx(edges, closed, Imgproc.MORPH_CLOSE, kernel)

        val contours = ArrayList<MatOfPoint>()
        val hierarchy = Mat()
        Imgproc.findContours(
            closed,
            contours,
            hierarchy,
            Imgproc.RETR_EXTERNAL,
            Imgproc.CHAIN_APPROX_SIMPLE,
        )

        val overlay = working.clone()
        val workingArea = working.rows().toDouble() * working.cols().toDouble()
        val invScale = 1.0 / workingScale

        val detectedContours = mutableListOf<Map<String, Any>>()

        val sortedContours = contours
            .map { contour -> contour to Imgproc.contourArea(contour) }
            .filter { (_, area) -> area >= workingArea * minAreaRatio && area < workingArea * 0.96 }
            .sortedByDescending { it.second }
            .take(12)

        for ((index, pair) in sortedContours.withIndex()) {
            val contour = pair.first
            val area = pair.second
            val contour2f = MatOfPoint2f(*contour.toArray())
            val perimeter = Imgproc.arcLength(contour2f, true)
            val rect = Imgproc.minAreaRect(contour2f)
            val boxPoints = Array(4) { Point() }
            rect.points(boxPoints)

            val majorPx = max(rect.size.width, rect.size.height) * invScale
            val minorPx = min(rect.size.width, rect.size.height) * invScale
            val circularity = if (perimeter > 1e-6) {
                (4.0 * PI * area) / (perimeter * perimeter)
            } else {
                0.0
            }

            val approx = MatOfPoint2f()
            Imgproc.approxPolyDP(contour2f, approx, 0.03 * perimeter, true)
            val vertexCount = approx.rows()

            val shapeHint = when {
                circularity >= 0.78 -> "cylindrical"
                vertexCount in 4..6 && circularity >= 0.45 -> "rectangular"
                else -> "irregular"
            }

            val color = when (shapeHint) {
                "cylindrical" -> Scalar(212.0, 188.0, 0.0) // Cyan-BGR
                "rectangular" -> Scalar(0.0, 179.0, 255.0) // Amber-BGR
                else -> Scalar(154.0, 166.0, 38.0) // Teal-BGR
            }

            Imgproc.drawContours(overlay, listOf(contour), 0, color, 2)
            for (i in 0 until 4) {
                Imgproc.line(overlay, boxPoints[i], boxPoints[(i + 1) % 4], color, 2)
            }

            val mappedBox = boxPoints.map { pt ->
                mapOf(
                    "x" to pt.x * invScale,
                    "y" to pt.y * invScale,
                )
            }

            detectedContours.add(
                mapOf(
                    "id" to "c_${index + 1}",
                    "majorPx" to majorPx,
                    "minorPx" to minorPx,
                    "areaPx2" to (area * invScale * invScale),
                    "perimeterPx" to (perimeter * invScale),
                    "circularity" to circularity.coerceIn(0.0, 1.0),
                    "vertexCount" to vertexCount,
                    "angleDeg" to rect.angle,
                    "centerX" to (rect.center.x * invScale),
                    "centerY" to (rect.center.y * invScale),
                    "shapeHint" to shapeHint,
                    "boxPoints" to mappedBox,
                ),
            )

            contour2f.release()
            approx.release()
        }

        // HoughCircles detection for cylindrical bores / shafts / washers
        val circles = Mat()
        Imgproc.HoughCircles(
            blurred,
            circles,
            Imgproc.HOUGH_GRADIENT,
            1.2,
            max(24.0, min(working.rows(), working.cols()) * 0.08),
            120.0,
            42.0,
            max(8, (min(working.rows(), working.cols()) * 0.03).toInt()),
            (min(working.rows(), working.cols()) * 0.45).toInt(),
        )

        val detectedCircles = mutableListOf<Map<String, Any>>()
        for (i in 0 until min(circles.cols(), 8)) {
            val data = circles.get(0, i) ?: continue
            val cx = data[0]
            val cy = data[1]
            val r = data[2]
            Imgproc.circle(overlay, Point(cx, cy), r.roundToInt(), Scalar(255.0, 200.0, 0.0), 2)
            Imgproc.circle(overlay, Point(cx, cy), 4, Scalar(255.0, 200.0, 0.0), -1)

            detectedCircles.add(
                mapOf(
                    "centerX" to (cx * invScale),
                    "centerY" to (cy * invScale),
                    "diameterPx" to (2.0 * r * invScale),
                ),
            )
        }

        val overlayFile = File(
            context.cacheDir,
            "opencv_overlay_${System.currentTimeMillis()}.png",
        )
        Imgcodecs.imwrite(overlayFile.absolutePath, overlay)

        // Cleanup native Mats
        source.release()
        working.release()
        gray.release()
        laplacian.release()
        lapMean.release()
        lapStd.release()
        grayMean.release()
        grayStd.release()
        blurred.release()
        edges.release()
        kernel.release()
        closed.release()
        hierarchy.release()
        circles.release()
        overlay.release()
        for (c in contours) {
            c.release()
        }

        return mapOf(
            "engine" to "opencv_native_4_12",
            "imageWidth" to originalWidth,
            "imageHeight" to originalHeight,
            "overlayPath" to overlayFile.absolutePath,
            "sharpnessVariance" to lapVariance,
            "contrastStdDev" to contrastStd,
            "contours" to detectedContours,
            "circles" to detectedCircles,
        )
    }

    private fun extractMaterialSurface(
        imagePath: String,
        roiLeft: Double,
        roiTop: Double,
        roiWidth: Double,
        roiHeight: Double,
    ): Map<String, Any> {
        if (!openCvInitialized) {
            openCvInitialized = OpenCVLoader.initLocal()
        }
        if (!openCvInitialized) {
            throw IllegalStateException("Biblioteca nativa OpenCV não pôde ser inicializada.")
        }

        val source = Imgcodecs.imread(imagePath)
        if (source.empty()) {
            throw IllegalArgumentException("Não foi possível decodificar a imagem em $imagePath")
        }

        val x = (roiLeft.coerceIn(0.0, 0.9) * source.cols()).roundToInt().coerceIn(0, source.cols() - 2)
        val y = (roiTop.coerceIn(0.0, 0.9) * source.rows()).roundToInt().coerceIn(0, source.rows() - 2)
        val w = (roiWidth.coerceIn(0.1, 1.0) * source.cols()).roundToInt().coerceIn(2, source.cols() - x)
        val h = (roiHeight.coerceIn(0.1, 1.0) * source.rows()).roundToInt().coerceIn(2, source.rows() - y)

        val roiMat = Mat(source, org.opencv.core.Rect(x, y, w, h))
        val resized = Mat()
        val scale = if (max(w, h) > 360) 360.0 / max(w, h).toDouble() else 1.0
        if (scale < 1.0) {
            Imgproc.resize(
                roiMat,
                resized,
                Size(
                    max(16.0, (w * scale).roundToInt().toDouble()),
                    max(16.0, (h * scale).roundToInt().toDouble()),
                ),
                0.0,
                0.0,
                Imgproc.INTER_AREA,
            )
        } else {
            roiMat.copyTo(resized)
        }

        val hsv = Mat()
        Imgproc.cvtColor(resized, hsv, Imgproc.COLOR_BGR2HSV)

        val gray = Mat()
        Imgproc.cvtColor(resized, gray, Imgproc.COLOR_BGR2GRAY)

        val lap = Mat()
        Imgproc.Laplacian(gray, lap, org.opencv.core.CvType.CV_64F)
        val lapMean = MatOfDouble()
        val lapStd = MatOfDouble()
        Core.meanStdDev(lap, lapMean, lapStd)
        val sharpnessVariance = lapStd.toArray().firstOrNull()?.let { it * it } ?: 0.0

        val gx = Mat()
        val gy = Mat()
        Imgproc.Sobel(gray, gx, org.opencv.core.CvType.CV_64F, 1, 0, 3)
        Imgproc.Sobel(gray, gy, org.opencv.core.CvType.CV_64F, 0, 1, 3)
        Core.absdiff(gx, Scalar.all(0.0), gx)
        Core.absdiff(gy, Scalar.all(0.0), gy)
        val meanGx = Core.mean(gx).`val`[0]
        val meanGy = Core.mean(gy).`val`[0]
        val textureEnergy = (meanGx + meanGy) / 2.0
        val anisotropyRatio = max(meanGx, meanGy) / max(min(meanGx, meanGy), 0.5)

        val rows = hsv.rows()
        val cols = hsv.cols()
        val totalPixels = max(1, rows * cols)
        var sumHueDeg = 0.0
        var sumSat = 0.0
        var sumVal = 0.0
        var specularCount = 0
        var warmMetalCount = 0
        var darkMatteCount = 0
        var redOrWarmSaturationCount = 0

        for (r in 0 until rows) {
            for (c in 0 until cols) {
                val px = hsv.get(r, c) ?: continue
                val hDeg = px[0] * 2.0 // OpenCV Hue is 0..180
                val s = px[1] // 0..255
                val v = px[2] // 0..255
                sumHueDeg += hDeg
                sumSat += s
                sumVal += v

                if (v >= 220.0 && s <= 50.0) {
                    specularCount++
                }
                if (hDeg in 8.0..48.0 && s in 45.0..235.0 && v >= 60.0) {
                    warmMetalCount++
                }
                if (v <= 85.0 && s <= 55.0) {
                    darkMatteCount++
                }
                if (s >= 65.0) {
                    redOrWarmSaturationCount++
                }
            }
        }

        val meanHue = sumHueDeg / totalPixels
        val meanSaturation = sumSat / totalPixels
        val meanValue = sumVal / totalPixels

        source.release()
        roiMat.release()
        resized.release()
        hsv.release()
        gray.release()
        lap.release()
        lapMean.release()
        lapStd.release()
        gx.release()
        gy.release()

        return mapOf(
            "engine" to "opencv_native_4_12",
            "meanHue" to meanHue,
            "meanSaturation" to meanSaturation,
            "meanValue" to meanValue,
            "specularRatio" to (specularCount.toDouble() / totalPixels),
            "warmMetalRatio" to (warmMetalCount.toDouble() / totalPixels),
            "darkMatteRatio" to (darkMatteCount.toDouble() / totalPixels),
            "chromaticRatio" to (redOrWarmSaturationCount.toDouble() / totalPixels),
            "textureEnergy" to textureEnergy,
            "anisotropyRatio" to anisotropyRatio,
            "sharpnessVariance" to sharpnessVariance,
        )
    }
}
