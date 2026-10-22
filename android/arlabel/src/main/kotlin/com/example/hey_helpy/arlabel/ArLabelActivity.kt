package com.example.hey_helpy.arlabel

import android.Manifest
import android.app.Activity
import android.app.AlertDialog
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.net.ConnectivityManager
import android.opengl.GLES20
import android.opengl.GLSurfaceView
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Base64
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.Surface
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import com.example.hey_helpy.arcommon.ArTexts
import com.example.hey_helpy.arcommon.LabelCard
import com.example.hey_helpy.arcommon.PoseMath
import com.example.hey_helpy.arcommon.SupabaseRest
import com.example.hey_helpy.arcommon.Vec3
import com.google.ar.core.Anchor
import com.google.ar.core.ArCoreApk
import com.google.ar.core.CameraConfigFilter
import com.google.ar.core.Config
import com.google.ar.core.Coordinates2d
import com.google.ar.core.DepthPoint
import com.google.ar.core.Frame
import com.google.ar.core.HitResult
import com.google.ar.core.Plane
import com.google.ar.core.Point
import com.google.ar.core.Session
import com.google.ar.core.TrackingState
import org.json.JSONObject
import java.io.File
import java.io.IOException
import java.util.UUID
import java.util.concurrent.ConcurrentLinkedQueue
import java.util.concurrent.Executors
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10

/**
 * Шаг 31: «AR-метки» — V0 своей технологии позиционирования (без Niantic и без
 * чужих серверов).
 *
 * Человек наводит прицел на оборудование → «Что это?» → в этот момент:
 *  1) hit-test ARCore в точке прицела (стены, пол, точки глубины) — временный якорь;
 *  2) кадр камеры ARCore → JPEG ≤ 1280 px → наша Edge Function photo-identify
 *     (тот же запрос, что у «Камеры-помощника»: locale, objectId, floorId,
 *     locationId; JWT пользователя; плюс box: true — рамка оборудования, блок 2);
 *  3) один уверенный кандидат → табличка над якорем; несколько — «Что это?»
 *     со списком («Это он»); нет оборудования / ошибка — понятный текст, якорь
 *     убирается. Есть рамка от ИИ — якорь переносится в её центр (луч из позы
 *     камеры в момент снимка, Frame.hitTest(origin, direction)).
 * Таблички — обычные View поверх камеры, держатся на месте при ходьбе (якорь
 * ARCore). После закрытия экрана меток нет — это V1.
 *
 * ARCore — только на телефоне: Cloud Anchors, Geospatial, Instant Placement
 * выключены явно. Снимок не сохраняется (только память; файл в cache — лишь
 * если человек сам нажал «Создать заявку», Flutter его удаляет).
 */
class ArLabelActivity : Activity(), GLSurfaceView.Renderer {
    private companion object {
        const val TAG = "HeyHelpyAr"
        const val REQ_CAMERA = 31
        const val IDENTIFY_TIMEOUT_MS = 20_000
        const val MESSAGE_COOLDOWN_MS = 3000L
    }

    /** Табличка: оборудование, якорь и то, что нужно для «Создать заявку». */
    private class Mark(
        val assetId: String,
        @Volatile var anchor: Anchor,
        val name: String,
        val line: String,
        val color: Int,
        val reply: IdentifyReply,
        val jpeg: ByteArray,
        val takenAt: Long,
        val journalId: String?,
    )

    /** Снимок «Что это?»: якорь прицела и как пересчитать рамку ИИ в экран. */
    private class Shot(
        val anchor: Anchor,
        val frame: CameraJpeg.Nv21,
        val ref: FloatArray,
        val invViewProj: FloatArray?,
        val width: Int,
        val height: Int,
        val takenAt: Long,
    )

    private class Pos(val id: String, val x: Float, val y: Float, val scale: Float)

    private lateinit var texts: Map<String, String>
    private lateinit var assets: Map<String, ArLabelContract.AssetLabel>
    private var rest: SupabaseRest? = null
    private var locale = "ru"
    private var companyId: String? = null
    private var userId: String? = null
    private var objectId: String? = null
    private var floorId: String? = null
    private var locationId: String? = null

    private val worker = Executors.newSingleThreadExecutor { r -> Thread(r, "HeyHelpy-AR").apply { isDaemon = true } }
    private val main = Handler(Looper.getMainLooper())

    // ARCore (сессия создаётся в главном потоке, кадры — в потоке GL).
    @Volatile
    private var session: Session? = null
    private var textureFor: Session? = null
    private val background = BackgroundRenderer()
    private var installRequested = false
    private var blocked = false
    private var imageRotation = 90

    @Volatile
    private var viewW = 0

    @Volatile
    private var viewH = 0

    @Volatile
    private var geometryChanged = false

    @Volatile
    private var captureRequested = false
    private val glJobs = ConcurrentLinkedQueue<(Frame) -> Unit>()

    private val lock = Any()
    private val slots = LabelSlots<Mark>()

    // Views
    private lateinit var root: FrameLayout
    private lateinit var glView: GLSurfaceView
    private lateinit var labelsLayer: FrameLayout
    private lateinit var hint: TextView
    private lateinit var message: TextView
    private lateinit var whatButton: Button
    private val labelViews = HashMap<String, LinearLayout>()
    private var busy = false
    private var tracking = false
    private val lastMessageAt = HashMap<String, Long>()

    private fun t(key: String) = texts[key] ?: key

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        texts = ArTexts.parseTexts(intent.getStringExtra(ArLabelContract.TEXTS))
        assets = ArLabelContract.parseAssets(intent.getStringExtra(ArLabelContract.ASSETS)).associateBy { it.id }
        locale = intent.getStringExtra(ArLabelContract.LOCALE) ?: "ru"
        companyId = intent.getStringExtra(ArLabelContract.COMPANY_ID)
        userId = intent.getStringExtra(ArLabelContract.USER_ID)
        objectId = intent.getStringExtra(ArLabelContract.OBJECT_ID)
        floorId = intent.getStringExtra(ArLabelContract.FLOOR_ID)
        locationId = intent.getStringExtra(ArLabelContract.LOCATION_ID)
        val url = intent.getStringExtra(ArLabelContract.URL).orEmpty()
        val anon = intent.getStringExtra(ArLabelContract.ANON_KEY).orEmpty()
        val jwt = intent.getStringExtra(ArLabelContract.JWT).orEmpty()
        if (url.isNotBlank() && jwt.isNotBlank()) rest = SupabaseRest(url, anon, jwt)
        buildUi()

        // Без ИИ экрану нет смысла: без сети — сообщение и выход.
        if (!online()) {
            block("arNoNetwork")
            main.postDelayed({ finish() }, 3500)
            return
        }
        if (rest == null) return block("arSessionExpired")
        if (!hasCamera()) requestPermissions(arrayOf(Manifest.permission.CAMERA), REQ_CAMERA)
    }

    // ------------------------------------------------------------------ UI

    private fun dp(v: Int) = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics,
    ).toInt()

    private fun pill(bg: Int, radius: Int = 20) = GradientDrawable().apply {
        setColor(bg)
        cornerRadius = dp(radius).toFloat()
    }

    private fun button(label: String, primary: Boolean, onClick: () -> Unit) = Button(this).apply {
        text = label
        isAllCaps = false
        textSize = 16f
        setTextColor(if (primary) 0xFF062B23.toInt() else Color.WHITE)
        background = pill(if (primary) 0xFF2DB89A.toInt() else 0xCC1C1C1E.toInt(), 24)
        setPadding(dp(22), dp(12), dp(22), dp(12))
        setOnClickListener { onClick() }
    }

    /** Прицел в центре экрана: кольцо и точка. */
    private inner class Crosshair(context: Context) : View(context) {
        private val ring = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = dp(2).toFloat()
            color = Color.WHITE
            setShadowLayer(dp(2).toFloat(), 0f, 0f, 0x99000000.toInt())
        }
        private val dot = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0xFF2DB89A.toInt() }

        override fun onDraw(canvas: Canvas) {
            val cx = width / 2f
            val cy = height / 2f
            canvas.drawCircle(cx, cy, dp(22).toFloat(), ring)
            canvas.drawCircle(cx, cy, dp(4).toFloat(), dot)
        }
    }

    private fun buildUi() {
        root = FrameLayout(this).apply { setBackgroundColor(Color.BLACK) }
        glView = GLSurfaceView(this).apply {
            preserveEGLContextOnPause = true
            setEGLContextClientVersion(2)
            setEGLConfigChooser(8, 8, 8, 8, 16, 0)
            setRenderer(this@ArLabelActivity)
            renderMode = GLSurfaceView.RENDERMODE_CONTINUOUSLY
            setWillNotDraw(false)
        }
        root.addView(glView, FrameLayout.LayoutParams(MATCH, MATCH))
        root.addView(Crosshair(this), FrameLayout.LayoutParams(MATCH, MATCH))
        labelsLayer = FrameLayout(this)
        root.addView(labelsLayer, FrameLayout.LayoutParams(MATCH, MATCH))

        hint = TextView(this).apply {
            text = t("arHint")
            setTextColor(Color.WHITE)
            textSize = 14f
            gravity = Gravity.CENTER
            setPadding(dp(14), dp(8), dp(14), dp(8))
            background = pill(0x99000000.toInt())
        }
        root.addView(hint, FrameLayout.LayoutParams(WRAP, WRAP, Gravity.TOP or Gravity.CENTER_HORIZONTAL)
            .apply { topMargin = dp(44); leftMargin = dp(16); rightMargin = dp(16) })

        message = TextView(this).apply {
            setTextColor(Color.WHITE)
            textSize = 14f
            gravity = Gravity.CENTER
            setPadding(dp(16), dp(10), dp(16), dp(10))
            background = pill(0xE6B3261E.toInt(), 14)
            visibility = View.GONE
        }
        root.addView(message, FrameLayout.LayoutParams(MATCH, WRAP, Gravity.BOTTOM)
            .apply { bottomMargin = dp(104); leftMargin = dp(16); rightMargin = dp(16) })

        val bar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }
        whatButton = button(t("arWhatIsIt"), true) { onWhatIsIt() }
        val close = button(t("arClose"), false) { finish() }
        val lp = LinearLayout.LayoutParams(WRAP, WRAP).apply { marginStart = dp(6); marginEnd = dp(6) }
        bar.addView(whatButton, lp)
        bar.addView(close, lp)
        root.addView(bar, FrameLayout.LayoutParams(MATCH, WRAP, Gravity.BOTTOM)
            .apply { bottomMargin = dp(36) })
        setContentView(root)
    }

    private fun block(key: String) {
        blocked = true
        whatButton.visibility = View.GONE
        hint.visibility = View.GONE
        message.removeCallbacks(hideMessage)
        message.background = pill(0xE6B3261E.toInt(), 14)
        message.text = t(key)
        message.visibility = View.VISIBLE
    }

    private fun showMessage(key: String, error: Boolean = true) {
        if (blocked) return
        val now = System.currentTimeMillis()
        if (now - (lastMessageAt[key] ?: 0L) < MESSAGE_COOLDOWN_MS) return
        lastMessageAt[key] = now
        message.background = pill(if (error) 0xE6B3261E.toInt() else 0xE60B7A62.toInt(), 14)
        message.text = t(key)
        message.visibility = View.VISIBLE
        message.removeCallbacks(hideMessage)
        message.postDelayed(hideMessage, if (error) 5000 else 3000)
    }

    private val hideMessage = Runnable { message.visibility = View.GONE }

    private fun setBusy(v: Boolean) {
        busy = v
        whatButton.isEnabled = !v
        whatButton.alpha = if (v) 0.7f else 1f
        whatButton.text = if (v) t("arLooking") else t("arWhatIsIt")
    }

    private fun renderHint() {
        val show = !blocked && (!tracking || labelViews.isEmpty())
        hint.visibility = if (show) View.VISIBLE else View.GONE
    }

    // ----------------------------------------------------- права и сеть

    private fun hasCamera() = checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, results: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, results)
        if (requestCode != REQ_CAMERA) return
        if (hasCamera()) startAr() else block("arNoCamera")
    }

    private fun online(): Boolean {
        val cm = getSystemService(ConnectivityManager::class.java) ?: return true
        return cm.activeNetwork != null
    }

    // ------------------------------------------------------------ ARCore

    override fun onResume() {
        super.onResume()
        if (!blocked && hasCamera()) startAr()
    }

    private fun startAr() {
        if (blocked) return
        if (session == null) {
            try {
                // «Сервисы Google Play для AR» не стоят или устарели — Play Маркет
                // предложит поставить; вернёмся сюда же в onResume.
                if (ArCoreApk.getInstance().requestInstall(this, !installRequested) ==
                    ArCoreApk.InstallStatus.INSTALL_REQUESTED
                ) {
                    installRequested = true
                    return
                }
                val s = Session(this)
                configure(s)
                session = s
            } catch (e: Exception) {
                Log.w(TAG, "arcore: ${e.javaClass.simpleName}")
                return block("arNoArcore")
            }
        }
        try {
            session?.resume()
        } catch (e: Exception) {
            Log.w(TAG, "resume: ${e.javaClass.simpleName}")
            session = null
            return block("arNoCamera")
        }
        glView.onResume()
    }

    private fun configure(s: Session) {
        // Кадр для узнавания — самый чёткий не шире 1920 (обычный 640×480 мелковат).
        try {
            val configs = s.getSupportedCameraConfigs(
                CameraConfigFilter(s).setFacingDirection(com.google.ar.core.CameraConfig.FacingDirection.BACK),
            )
            if (configs.isNotEmpty()) {
                val i = ArLabelLogic.pickImageSize(configs.map { it.imageSize.width to it.imageSize.height })
                s.cameraConfig = configs[i]
            }
        } catch (e: Exception) {
            Log.w(TAG, "camera config: ${e.javaClass.simpleName}")
        }
        val c = Config(s)
        c.planeFindingMode = Config.PlaneFindingMode.HORIZONTAL_AND_VERTICAL
        c.depthMode = if (s.isDepthModeSupported(Config.DepthMode.AUTOMATIC)) {
            Config.DepthMode.AUTOMATIC
        } else {
            Config.DepthMode.DISABLED
        }
        c.focusMode = Config.FocusMode.AUTO
        c.updateMode = Config.UpdateMode.BLOCKING
        c.lightEstimationMode = Config.LightEstimationMode.DISABLED
        // Ничего не уходит на серверы Google: облачные якоря, Geospatial (VPS
        // Google) и Instant Placement выключены явно.
        c.cloudAnchorMode = Config.CloudAnchorMode.DISABLED
        c.geospatialMode = Config.GeospatialMode.DISABLED
        c.instantPlacementMode = Config.InstantPlacementMode.DISABLED
        s.configure(c)
        imageRotation = try {
            val cm = getSystemService(CameraManager::class.java)
            val sensor = cm.getCameraCharacteristics(s.cameraConfig.cameraId)
                .get(CameraCharacteristics.SENSOR_ORIENTATION) ?: 90
            ArLabelLogic.imageRotation(sensor, displayDegrees())
        } catch (_: Exception) {
            90
        }
    }

    @Suppress("DEPRECATION")
    private fun displayRotation(): Int =
        if (Build.VERSION.SDK_INT >= 30) display?.rotation ?: Surface.ROTATION_0 else windowManager.defaultDisplay.rotation

    private fun displayDegrees() = when (displayRotation()) {
        Surface.ROTATION_90 -> 90
        Surface.ROTATION_180 -> 180
        Surface.ROTATION_270 -> 270
        else -> 0
    }

    // ---------------------------------------------------- поток GL: кадры

    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        GLES20.glClearColor(0f, 0f, 0f, 1f)
        background.create()
        textureFor = null
    }

    override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
        GLES20.glViewport(0, 0, width, height)
        viewW = width
        viewH = height
        geometryChanged = true
    }

    override fun onDrawFrame(gl: GL10?) {
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT or GLES20.GL_DEPTH_BUFFER_BIT)
        val s = session ?: return
        if (textureFor !== s) {
            s.setCameraTextureName(background.textureId)
            textureFor = s
        }
        if (geometryChanged) {
            s.setDisplayGeometry(displayRotation(), viewW, viewH)
            geometryChanged = false
        }
        val frame = try {
            s.update()
        } catch (e: Exception) {
            Log.w(TAG, "update: ${e.javaClass.simpleName}")
            return
        }
        background.draw(frame)
        val isTracking = frame.camera.trackingState == TrackingState.TRACKING
        while (true) {
            val job = glJobs.poll() ?: break
            try {
                job(frame)
            } catch (e: Exception) {
                Log.w(TAG, "job: ${e.javaClass.simpleName}")
            }
        }
        if (captureRequested) {
            captureRequested = false
            capture(frame, isTracking)
        }
        val positions = if (isTracking) positions(frame) else emptyList()
        main.post { applyPositions(isTracking, positions) }
    }

    private fun viewProj(frame: Frame): FloatArray {
        val view = FloatArray(16)
        val proj = FloatArray(16)
        frame.camera.getViewMatrix(view, 0)
        frame.camera.getProjectionMatrix(proj, 0, 0.05f, 100f)
        return PoseMath.multiply(proj, view)
    }

    private fun goodHit(r: HitResult): Boolean {
        if (r.distance > PoseMath.MAX_VISIBLE_M) return false
        return when (val tr = r.trackable) {
            is Plane -> tr.isPoseInPolygon(r.hitPose)
            is Point -> tr.orientationMode == Point.OrientationMode.ESTIMATED_SURFACE_NORMAL
            is DepthPoint -> true
            else -> false
        }
    }

    private fun capture(frame: Frame, isTracking: Boolean) {
        if (!isTracking) return ui { showMessage("arNoHit"); setBusy(false) }
        val w = viewW
        val h = viewH
        val hit = try {
            frame.hitTest(w / 2f, h / 2f).firstOrNull { goodHit(it) }
        } catch (_: Exception) {
            null
        } ?: return ui { showMessage("arNoHit"); setBusy(false) }
        val nv = try {
            frame.acquireCameraImage().use { CameraJpeg.copy(it) }
        } catch (e: Exception) {
            Log.w(TAG, "image: ${e.javaClass.simpleName}")
            return ui { showMessage("arNoHit"); setBusy(false) }
        }
        val ref = FloatArray(6)
        try {
            frame.transformCoordinates2d(
                Coordinates2d.IMAGE_NORMALIZED, floatArrayOf(0f, 0f, 1f, 0f, 0f, 1f),
                Coordinates2d.VIEW, ref,
            )
        } catch (_: Exception) {
        }
        val shot = Shot(hit.createAnchor(), nv, ref, PoseMath.invert(viewProj(frame)), w, h, System.currentTimeMillis())
        ui { identify(shot) }
    }

    private fun positions(frame: Frame): List<Pos> {
        val vp = viewProj(frame)
        val cam = frame.camera.pose
        val camPos = Vec3(cam.tx().toDouble(), cam.ty().toDouble(), cam.tz().toDouble())
        val marks = synchronized(lock) { slots.entries() }
        val out = ArrayList<Pos>(marks.size)
        for ((id, m) in marks) {
            val a = m.anchor
            if (a.trackingState != TrackingState.TRACKING) continue
            val p = a.pose
            val world = Vec3(p.tx().toDouble(), p.ty() + ArLabelLogic.LABEL_LIFT_M, p.tz().toDouble())
            val dist = (world - camPos).length()
            if (dist > PoseMath.MAX_VISIBLE_M) continue
            val screen = PoseMath.project(vp, world, viewW, viewH) ?: continue
            out += Pos(id, screen.first, screen.second, PoseMath.labelScale(dist))
        }
        return out
    }

    private fun ui(f: () -> Unit) {
        main.post { if (!isFinishing && !isDestroyed) f() }
    }

    private fun gl(job: (Frame) -> Unit) {
        glJobs += job
    }

    private fun detach(a: Anchor) = gl { runCatching { a.detach() } }

    // --------------------------------------------------- главный поток

    private fun applyPositions(isTracking: Boolean, list: List<Pos>) {
        if (isFinishing || isDestroyed) return
        tracking = isTracking
        val shown = HashSet<String>()
        for (p in list) {
            val v = labelViews[p.id] ?: continue
            shown += p.id
            v.scaleX = p.scale
            v.scaleY = p.scale
            v.translationX = p.x - v.width / 2f
            v.translationY = p.y - v.height
            v.visibility = View.VISIBLE
        }
        for ((id, v) in labelViews) if (id !in shown) v.visibility = View.GONE
        renderHint()
    }

    private fun onWhatIsIt() {
        if (busy || blocked || session == null) return
        if (!online()) return showMessage("arNoNetwork")
        if (!tracking) return showMessage("arNoHit")
        setBusy(true)
        captureRequested = true
    }

    private fun identify(shot: Shot) {
        val api = rest ?: return fail(shot, "arSessionExpired")
        val started = System.currentTimeMillis()
        worker.execute {
            try {
                val jpeg = CameraJpeg.toJpeg(shot.frame, imageRotation)
                val body = JSONObject()
                    .put("image", Base64.encodeToString(jpeg, Base64.NO_WRAP))
                    .put("locale", if (locale == "ru") "ru" else "en")
                    .put("box", true)
                objectId?.let { body.put("objectId", it) }
                floorId?.let { body.put("floorId", it) }
                locationId?.let { body.put("locationId", it) }
                val res = api.function("photo-identify", body.toString(), IDENTIFY_TIMEOUT_MS)
                val reply = ArLabelLogic.parseReply(res)
                val ms = (System.currentTimeMillis() - started).toInt()
                ui { onReply(shot, jpeg, reply, ms) }
            } catch (e: SupabaseRest.HttpError) {
                Log.w(TAG, "identify: http ${e.code}")
                ui { fail(shot, ArLabelLogic.httpErrorKey(e.code)) }
            } catch (e: IOException) {
                Log.w(TAG, "identify: ${e.javaClass.simpleName}")
                ui { fail(shot, ArLabelLogic.httpErrorKey(null)) }
            } catch (e: Exception) {
                Log.w(TAG, "identify: ${e.javaClass.simpleName}")
                ui { fail(shot, "arFailed") }
            }
        }
    }

    private fun fail(shot: Shot, key: String) {
        setBusy(false)
        detach(shot.anchor)
        showMessage(key)
    }

    private fun onReply(shot: Shot, jpeg: ByteArray, reply: IdentifyReply?, ms: Int) {
        setBusy(false)
        if (reply == null) return fail(shot, "arFailed")
        val journalId = journalAdd(reply, ms)
        if (reply.noEquipment) return fail(shot, "arNoEquipment")
        val pick = ArLabelLogic.choose(reply.candidates)
        when (pick.kind) {
            ArLabelLogic.PickKind.NONE -> fail(shot, "arNotRecognized")
            ArLabelLogic.PickKind.CONFIDENT -> {
                place(shot, reply, pick.candidate!!, jpeg, journalId)
                journalFinish(journalId, ArLabelLogic.outcome(reply, pick.candidate.assetId), pick.candidate.assetId)
            }
            ArLabelLogic.PickKind.SEVERAL -> askWhich(shot, reply, jpeg, journalId)
        }
    }

    /** Несколько похожих — «Что это?»: выбрать из кандидатов («Это он»). */
    private fun askWhich(shot: Shot, reply: IdentifyReply, jpeg: ByteArray, journalId: String?) {
        val items = reply.candidates.map { c ->
            listOf(c.name, c.locationLabel).filter { it.isNotBlank() }.joinToString(" · ")
        }
        var decided = false
        AlertDialog.Builder(this)
            .setTitle(t("arPickAsset"))
            .setItems(items.toTypedArray()) { _, which ->
                decided = true
                val c = reply.candidates[which]
                place(shot, reply, c, jpeg, journalId)
                journalFinish(journalId, ArLabelLogic.outcome(reply, c.assetId), c.assetId)
            }
            .setNegativeButton(t("commonCancel"), null)
            .setOnDismissListener {
                if (!decided) {
                    detach(shot.anchor)
                    journalFinish(journalId, "dismissed", null)
                }
            }
            .show()
    }

    private fun place(shot: Shot, reply: IdentifyReply, c: Candidate, jpeg: ByteArray, journalId: String?) {
        val info = assets[c.assetId]
        val name = info?.name?.ifBlank { null } ?: c.name
        val line = if (info != null) {
            ArLabelLogic.factsLine(info.openCount, info.due, info.overdue, locale, texts)
        } else {
            c.locationLabel
        }
        val color = info?.color ?: ArTexts.BRAND
        val mark = Mark(c.assetId, shot.anchor, name, line, color, reply, jpeg, shot.takenAt, journalId)
        val put = synchronized(lock) { slots.put(c.assetId, mark) }
        // Повторное «Что это?» по тому же оборудованию — переставить, не дублировать.
        put.replaced?.let { detach(it.anchor) }
        put.evicted?.let { (id, m) ->
            detach(m.anchor)
            labelViews.remove(id)?.let { labelsLayer.removeView(it) }
            showMessage("arLimit", error = false)
        }
        val view = labelViews.getOrPut(c.assetId) {
            LabelCard.create(this, name, line, color) { onLabelTap(c.assetId) }.also {
                labelsLayer.addView(it, FrameLayout.LayoutParams(WRAP, WRAP))
            }
        }
        LabelCard.update(view, name, line, color)
        refineByBox(shot, reply, mark)
        renderHint()
    }

    /** Блок 2: рамка от ИИ → якорь в её центре (если там есть поверхность). */
    private fun refineByBox(shot: Shot, reply: IdentifyReply, mark: Mark) {
        val box = reply.box ?: return
        val inv = shot.invViewProj ?: return
        val p = ArLabelLogic.boxCenterOnView(box, imageRotation, shot.ref, shot.width, shot.height) ?: return
        val (origin, dir) = PoseMath.rayThrough(inv, p.first, p.second, shot.width, shot.height) ?: return
        gl { frame ->
            val hit = frame.hitTest(
                floatArrayOf(origin.x.toFloat(), origin.y.toFloat(), origin.z.toFloat()), 0,
                floatArrayOf(dir.x.toFloat(), dir.y.toFloat(), dir.z.toFloat()), 0,
            ).firstOrNull { goodHit(it) } ?: return@gl
            val fresh = hit.createAnchor()
            val current = synchronized(lock) { slots[mark.assetId] === mark }
            if (current) {
                val old = mark.anchor
                mark.anchor = fresh
                // Временный якорь прицела больше не нужен (мы уже в потоке GL).
                if (old !== fresh) runCatching { old.detach() }
            } else {
                runCatching { fresh.detach() }
            }
        }
    }

    private fun onLabelTap(assetId: String) {
        val m = synchronized(lock) { slots[assetId] } ?: return
        val items = arrayOf(t("arOpenAsset"), t("arCreateOrder"), t("arRemoveMark"))
        AlertDialog.Builder(this)
            .setTitle(m.name)
            .setItems(items) { _, which ->
                when (which) {
                    0 -> finishWith(Intent()
                        .putExtra(ArLabelContract.RESULT_ACTION, "asset")
                        .putExtra(ArLabelContract.RESULT_ASSET, m.assetId))
                    1 -> createOrder(m)
                    2 -> removeMark(m)
                }
            }
            .setNegativeButton(t("commonCancel"), null)
            .show()
    }

    private fun createOrder(m: Mark) {
        // Снимок — фото «до» новой заявки: временный файл, Flutter прочитает и удалит.
        val path = try {
            val f = File(cacheDir, "arlabel_${System.currentTimeMillis()}.jpg")
            f.writeBytes(m.jpeg)
            f.absolutePath
        } catch (_: Exception) {
            null
        }
        val data = Intent()
            .putExtra(ArLabelContract.RESULT_ACTION, "order")
            .putExtra(ArLabelContract.RESULT_ASSET, m.assetId)
            .putExtra(ArLabelContract.RESULT_IDENTIFY, m.reply.raw)
            .putExtra(ArLabelContract.RESULT_TAKEN_AT, m.takenAt)
        path?.let { data.putExtra(ArLabelContract.RESULT_PHOTO, it) }
        m.journalId?.let { data.putExtra(ArLabelContract.RESULT_JOURNAL, it) }
        finishWith(data)
    }

    private fun removeMark(m: Mark) {
        synchronized(lock) { if (slots[m.assetId] === m) slots.remove(m.assetId) }
        detach(m.anchor)
        labelViews.remove(m.assetId)?.let { labelsLayer.removeView(it) }
        // Метку убрали — для замера точности V0 считаем, что узнал неверно.
        journalFinish(m.journalId, "dismissed", null)
        renderHint()
    }

    private fun finishWith(data: Intent) {
        setResult(RESULT_OK, data)
        finish()
    }

    // ------------------------------------------- журнал узнаваний (0017)

    /** Строка журнала — как у «Камеры-помощника»; ошибка — молча (как IdentifyLog). */
    private fun journalAdd(reply: IdentifyReply, ms: Int): String? {
        val api = rest ?: return null
        val company = companyId ?: return null
        val user = userId ?: return null
        val id = UUID.randomUUID().toString()
        val row = ArLabelLogic.journalRow(id, company, user, objectId, floorId, locationId, reply, ms)
        worker.execute {
            try {
                api.rest("POST", "photo_identifications", row.toString(), "return=minimal")
            } catch (e: Exception) {
                Log.w(TAG, "journal: ${(e as? SupabaseRest.HttpError)?.code ?: e.javaClass.simpleName}")
            }
        }
        return id
    }

    private fun journalFinish(id: String?, outcome: String, chosenAssetId: String?) {
        val api = rest ?: return
        if (id == null) return
        val body = JSONObject()
            .put("outcome", outcome)
            .put("chosen_asset_id", if (outcome == "dismissed") JSONObject.NULL else chosenAssetId)
        worker.execute {
            try {
                api.rest("PATCH", "photo_identifications?id=eq.$id", body.toString(), "return=minimal")
            } catch (e: Exception) {
                Log.w(TAG, "journal outcome: ${(e as? SupabaseRest.HttpError)?.code ?: e.javaClass.simpleName}")
            }
        }
    }

    // ------------------------------------------------------------ жизнь

    override fun onPause() {
        super.onPause()
        // Камера и ARCore — только пока экран на виду.
        glView.onPause()
        session?.pause()
    }

    override fun onDestroy() {
        main.removeCallbacksAndMessages(null)
        session?.close()
        session = null
        worker.shutdown()
        super.onDestroy()
    }
}

private const val MATCH = ViewGroup.LayoutParams.MATCH_PARENT
private const val WRAP = ViewGroup.LayoutParams.WRAP_CONTENT
