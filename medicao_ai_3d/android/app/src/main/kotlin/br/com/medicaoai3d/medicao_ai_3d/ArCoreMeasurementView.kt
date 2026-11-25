package br.com.medicaoai3d.medicao_ai_3d

import android.app.Activity
import android.content.Context
import android.opengl.GLES11Ext
import android.opengl.GLES20
import android.opengl.GLSurfaceView
import android.os.Handler
import android.os.Looper
import android.view.MotionEvent
import android.view.Surface
import android.view.View
import android.view.WindowManager
import com.google.ar.core.Anchor
import com.google.ar.core.Config
import com.google.ar.core.Frame
import com.google.ar.core.Plane
import com.google.ar.core.Point
import com.google.ar.core.Session
import com.google.ar.core.TrackingState
import com.google.ar.core.exceptions.NotYetAvailableException
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import java.util.concurrent.atomic.AtomicReference
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10
import kotlin.math.abs
import kotlin.math.sqrt

class ArCoreViewFactory(
    private val activity: Activity,
    private val messenger: BinaryMessenger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return ArCoreMeasurementPlatformView(activity, messenger, viewId)
    }
}

private class ArCoreMeasurementPlatformView(
    private val activity: Activity,
    messenger: BinaryMessenger,
    viewId: Int,
) : PlatformView, GLSurfaceView.Renderer, MethodChannel.MethodCallHandler {

    private val glSurfaceView = GLSurfaceView(activity)
    private val methodChannel = MethodChannel(messenger, "br.com.medicaoai3d/arcore_view_$viewId")
    private val mainHandler = Handler(Looper.getMainLooper())

    private var session: Session? = null
    private var depthSupported = false
    private var cameraTextureId = -1
    private var viewportWidth = 1
    private var viewportHeight = 1
    private var displayRotationChanged = false

    private val anchors = mutableListOf<Anchor>()
    private val pendingTap = AtomicReference<Pair<Float, Float>?>(null)
    private var pendingDepthProbe = false
    private var frameCounter = 0

    // OpenGL ES camera background shader program
    private var bgProgram = 0
    private var bgPositionHandle = 0
    private var bgTexCoordHandle = 0
    private val quadCoords: FloatBuffer = ByteBuffer.allocateDirect(8 * 4)
        .order(ByteOrder.nativeOrder())
        .asFloatBuffer()
        .put(floatArrayOf(-1f, -1f, 1f, -1f, -1f, 1f, 1f, 1f))
        .apply { position(0) }
    private val quadTexCoordsTransformed: FloatBuffer = ByteBuffer.allocateDirect(8 * 4)
        .order(ByteOrder.nativeOrder())
        .asFloatBuffer()

    init {
        methodChannel.setMethodCallHandler(this)
        glSurfaceView.preserveEGLContextOnPause = true
        glSurfaceView.setEGLContextClientVersion(2)
        glSurfaceView.setEGLConfigChooser(8, 8, 8, 8, 16, 0)
        glSurfaceView.setRenderer(this)
        glSurfaceView.renderMode = GLSurfaceView.RENDERMODE_CONTINUOUSLY

        glSurfaceView.setOnTouchListener { _, event ->
            if (event.action == MotionEvent.ACTION_UP) {
                pendingTap.set(Pair(event.x, event.y))
            }
            true
        }

        initArSession()
    }

    private fun initArSession() {
        try {
            val newSession = Session(activity)
            val config = Config(newSession)
            config.planeFindingMode = Config.PlaneFindingMode.HORIZONTAL_AND_VERTICAL
            config.updateMode = Config.UpdateMode.LATEST_CAMERA_IMAGE
            depthSupported = newSession.isDepthModeSupported(Config.DepthMode.AUTOMATIC)
            config.depthMode = if (depthSupported) {
                Config.DepthMode.AUTOMATIC
            } else {
                Config.DepthMode.DISABLED
            }
            newSession.configure(config)
            newSession.resume()
            session = newSession
            notifyStatus("TRACKING_INITIALIZING", null)
        } catch (e: Throwable) {
            notifyError("Falha ao iniciar sessão ARCore: ${e.message}")
        }
    }

    override fun getView(): View = glSurfaceView

    override fun dispose() {
        methodChannel.setMethodCallHandler(null)
        glSurfaceView.onPause()
        anchors.forEach { runCatching { it.detach() } }
        anchors.clear()
        runCatching {
            session?.pause()
            session?.close()
        }
        session = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "placeCenterPoint" -> {
                pendingTap.set(Pair(viewportWidth / 2f, viewportHeight / 2f))
                result.success(null)
            }

            "clearPoints" -> {
                anchors.forEach { runCatching { it.detach() } }
                anchors.clear()
                emitMeasurementState(trackingState = "CLEARED", centerDepthMm = null)
                result.success(null)
            }

            "measureCenterDepth" -> {
                pendingDepthProbe = true
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        GLES20.glClearColor(0.05f, 0.08f, 0.12f, 1.0f)
        val textures = IntArray(1)
        GLES20.glGenTextures(1, textures, 0)
        cameraTextureId = textures[0]
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, cameraTextureId)
        GLES20.glTexParameteri(
            GLES11Ext.GL_TEXTURE_EXTERNAL_OES,
            GLES20.GL_TEXTURE_MIN_FILTER,
            GLES20.GL_LINEAR,
        )
        GLES20.glTexParameteri(
            GLES11Ext.GL_TEXTURE_EXTERNAL_OES,
            GLES20.GL_TEXTURE_MAG_FILTER,
            GLES20.GL_LINEAR,
        )
        bgProgram = createBackgroundProgram()
        bgPositionHandle = GLES20.glGetAttribLocation(bgProgram, "a_Position")
        bgTexCoordHandle = GLES20.glGetAttribLocation(bgProgram, "a_TexCoord")
    }

    override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
        viewportWidth = width.coerceAtLeast(1)
        viewportHeight = height.coerceAtLeast(1)
        GLES20.glViewport(0, 0, viewportWidth, viewportHeight)
        displayRotationChanged = true
    }

    override fun onDrawFrame(gl: GL10?) {
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT or GLES20.GL_DEPTH_BUFFER_BIT)
        val activeSession = session ?: return

        if (displayRotationChanged) {
            val windowManager = activity.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            @Suppress("DEPRECATION")
            val rotation = windowManager.defaultDisplay?.rotation ?: Surface.ROTATION_0
            activeSession.setDisplayGeometry(rotation, viewportWidth, viewportHeight)
            displayRotationChanged = false
        }

        try {
            if (cameraTextureId >= 0) {
                activeSession.setCameraTextureName(cameraTextureId)
            }
            val frame = activeSession.update()
            drawCameraBackground(frame)

            val tap = pendingTap.getAndSet(null)
            if (tap != null && frame.camera.trackingState == TrackingState.TRACKING) {
                handleHitTest(frame, tap.first, tap.second)
            }

            var centerDepthMm: Double? = null
            if (pendingDepthProbe) {
                pendingDepthProbe = false
                centerDepthMm = readCenterDepthMillimeters(frame)
                emitMeasurementState(
                    trackingState = frame.camera.trackingState.name,
                    centerDepthMm = centerDepthMm,
                )
            } else if (frameCounter % 20 == 0) {
                emitMeasurementState(
                    trackingState = frame.camera.trackingState.name,
                    centerDepthMm = null,
                )
            }
            frameCounter++
        } catch (_: Throwable) {
            // Frame skipped during lifecycle transition
        }
    }

    private fun handleHitTest(frame: Frame, x: Float, y: Float) {
        val hits = frame.hitTest(x, y)
        for (hit in hits) {
            val trackable = hit.trackable
            val validPlane = trackable is Plane && trackable.isPoseInPolygon(hit.hitPose)
            val validPoint = trackable is Point &&
                trackable.orientationMode == Point.OrientationMode.ESTIMATED_SURFACE_NORMAL
            if (validPlane || validPoint) {
                if (anchors.size >= 2) {
                    anchors.forEach { runCatching { it.detach() } }
                    anchors.clear()
                }
                anchors.add(hit.createAnchor())
                emitMeasurementState(
                    trackingState = frame.camera.trackingState.name,
                    centerDepthMm = readCenterDepthMillimeters(frame),
                )
                break
            }
        }
    }

    private fun readCenterDepthMillimeters(frame: Frame): Double? {
        if (!depthSupported) return null
        return try {
            frame.acquireDepthImage16Bits().use { depthImage ->
                val plane = depthImage.planes[0]
                val cx = depthImage.width / 2
                val cy = depthImage.height / 2
                val offset = cy * plane.rowStride + cx * plane.pixelStride
                val buffer = plane.buffer.order(ByteOrder.LITTLE_ENDIAN)
                val rawDepth = buffer.getShort(offset).toInt() and 0xFFFF
                if (rawDepth in 100..8000) rawDepth.toDouble() else null
            }
        } catch (_: NotYetAvailableException) {
            null
        } catch (_: Throwable) {
            null
        }
    }

    private fun emitMeasurementState(trackingState: String, centerDepthMm: Double?) {
        var distanceMeters: Double? = null
        var horizontalMeters: Double? = null
        var verticalMeters: Double? = null

        if (anchors.size >= 2) {
            val p1 = anchors[0].pose
            val p2 = anchors[1].pose
            val dx = (p2.tx() - p1.tx()).toDouble()
            val dy = (p2.ty() - p1.ty()).toDouble()
            val dz = (p2.tz() - p1.tz()).toDouble()
            distanceMeters = sqrt(dx * dx + dy * dy + dz * dz)
            horizontalMeters = sqrt(dx * dx + dz * dz)
            verticalMeters = abs(dy)
        }

        val payload = mapOf(
            "trackingState" to trackingState,
            "anchorCount" to anchors.size,
            "depthSupported" to depthSupported,
            "distanceMeters" to distanceMeters,
            "horizontalMeters" to horizontalMeters,
            "verticalMeters" to verticalMeters,
            "centerDepthMm" to centerDepthMm,
        )
        mainHandler.post {
            methodChannel.invokeMethod("onMeasurementUpdate", payload)
        }
    }

    private fun notifyStatus(state: String, message: String?) {
        mainHandler.post {
            methodChannel.invokeMethod(
                "onStatus",
                mapOf("state" to state, "message" to message),
            )
        }
    }

    private fun notifyError(message: String) {
        mainHandler.post {
            methodChannel.invokeMethod("onError", mapOf("message" to message))
        }
    }

    private fun drawCameraBackground(frame: Frame) {
        if (bgProgram == 0) return
        val rawTexCoords = FloatArray(8) { i ->
            when (i) {
                0, 1, 3, 4 -> 0f
                else -> 1f
            }
        }
        // Standard normalized display UVs: (0,1), (1,1), (0,0), (1,0)
        val inputCoords = ByteBuffer.allocateDirect(8 * 4)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()
            .put(floatArrayOf(0f, 1f, 1f, 1f, 0f, 0f, 1f, 0f))
            .apply { position(0) }

        quadTexCoordsTransformed.position(0)
        @Suppress("DEPRECATION")
        frame.transformDisplayUvCoords(inputCoords, quadTexCoordsTransformed)
        quadTexCoordsTransformed.position(0)

        GLES20.glDisable(GLES20.GL_DEPTH_TEST)
        GLES20.glDepthMask(false)
        GLES20.glUseProgram(bgProgram)
        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES11Ext.GL_TEXTURE_EXTERNAL_OES, cameraTextureId)

        GLES20.glVertexAttribPointer(bgPositionHandle, 2, GLES20.GL_FLOAT, false, 0, quadCoords)
        GLES20.glVertexAttribPointer(
            bgTexCoordHandle,
            2,
            GLES20.GL_FLOAT,
            false,
            0,
            quadTexCoordsTransformed,
        )
        GLES20.glEnableVertexAttribArray(bgPositionHandle)
        GLES20.glEnableVertexAttribArray(bgTexCoordHandle)
        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
        GLES20.glDisableVertexAttribArray(bgPositionHandle)
        GLES20.glDisableVertexAttribArray(bgTexCoordHandle)
        GLES20.glDepthMask(true)
        GLES20.glEnable(GLES20.GL_DEPTH_TEST)
        rawTexCoords.hashCode()
    }

    private fun createBackgroundProgram(): Int {
        val vertexSrc = """
            attribute vec4 a_Position;
            attribute vec2 a_TexCoord;
            varying vec2 v_TexCoord;
            void main() {
                gl_Position = a_Position;
                v_TexCoord = a_TexCoord;
            }
        """.trimIndent()
        val fragmentSrc = """
            #extension GL_OES_EGL_image_external : require
            precision mediump float;
            varying vec2 v_TexCoord;
            uniform samplerExternalOES s_Texture;
            void main() {
                gl_FragColor = texture2D(s_Texture, v_TexCoord);
            }
        """.trimIndent()

        val vShader = compileShader(GLES20.GL_VERTEX_SHADER, vertexSrc)
        val fShader = compileShader(GLES20.GL_FRAGMENT_SHADER, fragmentSrc)
        val program = GLES20.glCreateProgram()
        GLES20.glAttachShader(program, vShader)
        GLES20.glAttachShader(program, fShader)
        GLES20.glLinkProgram(program)
        return program
    }

    private fun compileShader(type: Int, src: String): Int {
        val shader = GLES20.glCreateShader(type)
        GLES20.glShaderSource(shader, src)
        GLES20.glCompileShader(shader)
        return shader
    }
}
