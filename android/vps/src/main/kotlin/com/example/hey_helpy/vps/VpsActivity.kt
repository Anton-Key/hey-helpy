package com.example.hey_helpy.vps

import android.Manifest
import android.app.AlertDialog
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.ConnectivityManager
import android.os.Bundle
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.activity.ComponentActivity
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.lifecycleScope
import com.google.ar.core.ArCoreApk
import com.google.ar.core.Config
import com.google.ar.core.Frame
import com.google.ar.core.Plane
import com.google.ar.core.Point
import com.google.ar.core.Pose
import com.nianticspatial.nsdk.NSDKSession
import com.nianticspatial.nsdk.NsdkSessionDataSource
import com.nianticspatial.nsdk.Orientation
import com.nianticspatial.nsdk.Vps2Config
import com.nianticspatial.nsdk.helpers.createLiveDataSource
import com.nianticspatial.nsdk.vps2.Vps2LocalizationRequestStatus
import com.nianticspatial.nsdk.vps2.Vps2Session
import io.github.sceneview.ar.ARSceneView
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.asCoroutineDispatcher
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Шаг 28: «Метки VPS (эксперимент)» — Niantic Spatial NSDK 4, VPS2.
 *
 * Сценарий: «Найти место» → локализация по anchor payload помещения
 * (vps_sites, 0025) → индикатор «Ищу… / Примерно / Точно ✓» → когда «Точно»,
 * над оборудованием висят таблички (vps_marks: поза относительно якоря).
 * Касание таблички → «Карточка оборудования» (экран закрывается, Flutter
 * открывает карточку). Менеджер: «Поставить метку» → касание по стене / полу
 * (hit-test ARCore) → выбор оборудования → метка сохраняется относительно якоря.
 *
 * Сделано по мотивам сцены VPS2 из github.com/nianticspatial/nsdk-samples-kotlin
 * (тот же порядок: NSDKSession + live data source из кадров ARCore →
 * Vps2Session.trackAnchor(payload) → anchorUpdates), код написан заново.
 * Таблички — обычные Android-View поверх камеры, спроецированные из 3D-точки
 * (PoseMath.project): держатся на месте при ходьбе, без 3D-материалов.
 */
class VpsActivity : ComponentActivity() {
    private companion object {
        const val TAG = "HeyHelpyVps"
        const val REQ_PERMS = 41
        const val MESSAGE_COOLDOWN_MS = 5000L
    }

    private lateinit var texts: Map<String, String>
    private lateinit var assets: List<VpsContract.AssetLabel>
    private var api: VpsApi? = null
    private var canEdit = false

    private var site: VpsApi.Site? = null
    private val marks = mutableListOf<VpsApi.Mark>()

    // NSDK
    private var nsdk: NSDKSession? = null
    private var vps2: Vps2Session? = null
    private var dataSource: NsdkSessionDataSource? = null
    private val updateExecutor = Executors.newSingleThreadExecutor { r ->
        Thread(r, "HeyHelpy-NSDK-Update").apply { isDaemon = true }
    }
    private val updateDispatcher = updateExecutor.asCoroutineDispatcher()
    private val updateInFlight = AtomicBoolean(false)
    private var trackingJobs = mutableListOf<Job>()

    @Volatile
    private var arFrame: Frame? = null
    private var anchorId: ByteArray? = null
    private var anchorPose: RigidPose? = null
    private var anchorState: String? = null
    private var localizationState: String? = null
    private var started = false
    private var everPrecise = false
    private var placing = false
    private val lastMessageAt = HashMap<String, Long>()

    // Views
    private lateinit var root: FrameLayout
    private var arView: ARSceneView? = null
    private lateinit var labelsLayer: FrameLayout
    private lateinit var status: TextView
    private lateinit var hint: TextView
    private lateinit var message: TextView
    private lateinit var findButton: Button
    private lateinit var placeButton: Button
    private val labelViews = HashMap<String, View>()

    private fun t(key: String) = texts[key] ?: key

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        texts = VpsContract.parseTexts(intent.getStringExtra(VpsContract.TEXTS))
        assets = VpsContract.parseAssets(intent.getStringExtra(VpsContract.ASSETS))
        canEdit = intent.getBooleanExtra(VpsContract.CAN_EDIT, false)
        val url = intent.getStringExtra(VpsContract.URL).orEmpty()
        val anon = intent.getStringExtra(VpsContract.ANON_KEY).orEmpty()
        val jwt = intent.getStringExtra(VpsContract.JWT).orEmpty()
        if (url.isNotBlank() && jwt.isNotBlank()) api = VpsApi(url, anon, jwt)
        buildUi()

        // До камеры — то, что можно сказать сразу.
        when (VpsToken.state(BuildConfig.NIANTIC_TOKEN, System.currentTimeMillis() / 1000)) {
            VpsToken.State.MISSING -> return blocked("vpsTokenMissing")
            VpsToken.State.EXPIRED -> return blocked("vpsTokenExpired")
            VpsToken.State.OK -> {}
        }
        val arcore = try {
            ArCoreApk.getInstance().checkAvailability(this)
        } catch (_: Exception) {
            null
        }
        if (arcore != null && !arcore.isSupported && !arcore.isTransient) return blocked("vpsNoArcore")
        if (!online()) showMessage("vpsNoNetwork")

        loadSite()
        if (hasPermissions()) startAr() else requestPermissions(
            arrayOf(Manifest.permission.CAMERA, Manifest.permission.ACCESS_FINE_LOCATION),
            REQ_PERMS,
        )
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
        setTextColor(if (primary) 0xFF062B23.toInt() else Color.WHITE)
        background = pill(if (primary) 0xFF2DB89A.toInt() else 0xCC1C1C1E.toInt(), 24)
        setPadding(dp(18), dp(10), dp(18), dp(10))
        setOnClickListener { onClick() }
    }

    private fun buildUi() {
        root = FrameLayout(this).apply { setBackgroundColor(Color.BLACK) }
        labelsLayer = FrameLayout(this)
        root.addView(labelsLayer, FrameLayout.LayoutParams(MATCH, MATCH))

        status = TextView(this).apply {
            setTextColor(Color.WHITE)
            textSize = 15f
            typeface = Typeface.DEFAULT_BOLD
            setPadding(dp(14), dp(8), dp(14), dp(8))
            background = pill(0xCC1C1C1E.toInt())
            visibility = View.GONE
        }
        root.addView(status, FrameLayout.LayoutParams(WRAP, WRAP, Gravity.TOP or Gravity.CENTER_HORIZONTAL)
            .apply { topMargin = dp(40) })

        hint = TextView(this).apply {
            setTextColor(Color.WHITE)
            textSize = 14f
            gravity = Gravity.CENTER
            setPadding(dp(14), dp(8), dp(14), dp(8))
            background = pill(0x99000000.toInt())
            visibility = View.GONE
        }
        root.addView(hint, FrameLayout.LayoutParams(WRAP, WRAP, Gravity.TOP or Gravity.CENTER_HORIZONTAL)
            .apply { topMargin = dp(88); leftMargin = dp(16); rightMargin = dp(16) })

        message = TextView(this).apply {
            setTextColor(Color.WHITE)
            textSize = 14f
            gravity = Gravity.CENTER
            setPadding(dp(16), dp(10), dp(16), dp(10))
            background = pill(0xE6B3261E.toInt(), 14)
            visibility = View.GONE
        }
        root.addView(message, FrameLayout.LayoutParams(MATCH, WRAP, Gravity.BOTTOM)
            .apply { bottomMargin = dp(96); leftMargin = dp(16); rightMargin = dp(16) })

        val bar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }
        findButton = button(t("vpsFindPlace"), true) { startTracking() }
        placeButton = button(t("vpsPlaceMark"), true) { togglePlacing() }.apply { visibility = View.GONE }
        val close = button(t("vpsClose"), false) { finish() }
        val lp = LinearLayout.LayoutParams(WRAP, WRAP).apply { marginStart = dp(6); marginEnd = dp(6) }
        bar.addView(findButton, lp)
        bar.addView(placeButton, lp)
        bar.addView(close, lp)
        root.addView(bar, FrameLayout.LayoutParams(MATCH, WRAP, Gravity.BOTTOM)
            .apply { bottomMargin = dp(32) })
        setContentView(root)
    }

    private fun blocked(key: String) {
        findButton.visibility = View.GONE
        placeButton.visibility = View.GONE
        message.text = t(key)
        message.visibility = View.VISIBLE
    }

    private fun showMessage(key: String, error: Boolean = true) {
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

    private fun renderStatus() {
        val ind = VpsState.indicator(started, localizationState, anchorState)
        if (ind == Indicator.PRECISE) everPrecise = true
        if (ind == Indicator.IDLE) {
            status.visibility = View.GONE
            return
        }
        status.visibility = View.VISIBLE
        val (dot, key) = when (ind) {
            Indicator.SEARCHING -> 0xFFE5484D.toInt() to "vpsSearching"
            Indicator.COARSE -> 0xFFF5B000.toInt() to "vpsCoarse"
            else -> 0xFF2DB89A.toInt() to "vpsPrecise"
        }
        status.text = "●  ${t(key)}"
        status.setTextColor(Color.WHITE)
        status.compoundDrawablePadding = dp(6)
        status.text = android.text.SpannableString(status.text).apply {
            setSpan(android.text.style.ForegroundColorSpan(dot), 0, 1, 0)
        }
        placeButton.visibility = if (canEdit && started) View.VISIBLE else View.GONE
    }

    // ----------------------------------------------------- права и сеть

    private fun hasPermissions() =
        checkSelfPermission(Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, results: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, results)
        if (requestCode != REQ_PERMS) return
        if (hasPermissions()) startAr() else blocked("vpsNoCamera")
    }

    private fun online(): Boolean {
        val cm = getSystemService(ConnectivityManager::class.java) ?: return true
        return cm.activeNetwork != null
    }

    // ------------------------------------------------------------ данные

    private fun loadSite() {
        val api = api ?: return blocked("vpsSessionExpired")
        val locationId = intent.getStringExtra(VpsContract.LOCATION_ID) ?: return blocked("vpsFailed")
        lifecycleScope.launch {
            try {
                val s = api.site(locationId)
                if (s == null) {
                    blocked("vpsNoSite")
                    return@launch
                }
                site = s
                marks.clear()
                marks.addAll(api.marks(s.id))
            } catch (e: VpsApi.HttpError) {
                blocked(VpsState.httpErrorKey(e.code))
            } catch (e: Exception) {
                Log.w(TAG, "load site: ${e.javaClass.simpleName}")
                blocked(VpsState.httpErrorKey(null))
            }
        }
    }

    // ---------------------------------------------------------- AR + NSDK

    private fun startAr() {
        if (arView != null) return
        try {
            val session = NSDKSession(BuildConfig.NIANTIC_TOKEN, false)
            nsdk = session
            val ds = createLiveDataSource(this, { arFrame }, { Orientation.PORTRAIT })
            dataSource = ds
            session.dataSource = ds
            (ds as? DefaultLifecycleObserver)?.let { lifecycle.addObserver(it) }
        } catch (e: Exception) {
            Log.w(TAG, "nsdk init: ${e.javaClass.simpleName}")
            return blocked("vpsFailed")
        }

        val view = ARSceneView(this, sharedActivity = this, sharedLifecycle = lifecycle)
        view.planeRenderer.isEnabled = false
        view.configureSession { session, config ->
            config.depthMode = if (session.isDepthModeSupported(Config.DepthMode.AUTOMATIC)) {
                Config.DepthMode.AUTOMATIC
            } else {
                Config.DepthMode.DISABLED
            }
            config.planeFindingMode = Config.PlaneFindingMode.HORIZONTAL_AND_VERTICAL
            config.focusMode = Config.FocusMode.AUTO
            config.updateMode = Config.UpdateMode.LATEST_CAMERA_IMAGE
        }
        view.onSessionFailed = { e ->
            Log.w(TAG, "arcore: ${e.javaClass.simpleName}")
            blocked("vpsNoArcore")
        }
        view.onSessionUpdated = { _, frame -> onFrame(frame) }
        view.setOnTouchListener { _, e ->
            if (placing && e.action == MotionEvent.ACTION_UP) {
                onPlaceTap(e.x, e.y)
                true
            } else {
                false
            }
        }
        root.addView(view, 0, FrameLayout.LayoutParams(MATCH, MATCH))
        arView = view
    }

    private fun onFrame(frame: Frame) {
        arFrame = frame
        // Кадр → NSDK: снимок кадра здесь (кадр действителен до следующего),
        // тяжёлое update() — в отдельном потоке; не успели — кадр пропускаем.
        val ds = dataSource
        val session = nsdk
        if (ds != null && session != null && updateInFlight.compareAndSet(false, true)) {
            lifecycleScope.launch {
                try {
                    if (ds.prepareFrame()) withContext(updateDispatcher) { session.update() }
                } catch (e: Throwable) {
                    Log.w(TAG, "frame: ${e.javaClass.simpleName}")
                } finally {
                    updateInFlight.set(false)
                }
            }
        }
        // Якорь свежий — берём позу прямо из сессии (без ожидания потока).
        val id = anchorId
        val v = vps2
        if (id != null && v != null) {
            runCatching { v.getAnchorUpdate(id) }.getOrNull()?.let { u ->
                anchorState = u.trackingState.name
                anchorPose = if (u.trackingState.name == "NOT_TRACKED") null else u.anchorToLocalTrackingTransform.toRigid()
            }
        }
        renderStatus()
        renderLabels(frame)
    }

    private fun startTracking() {
        val s = site ?: return showMessage("vpsNoSite")
        val session = nsdk ?: return
        if (started) return
        try {
            val v = vps2 ?: session.vps2.acquire().also { vps2 = it }
            v.configure(
                Vps2Config(
                    enableUniversalLocalization = true,
                    universalLocalizationRequestsPerSecond = 1.0f,
                    enableVpsMapLocalization = true,
                    initialVpsRequestsPerSecond = 1.0f,
                    continuousVpsRequestsPerSecond = 0.2f,
                ),
            )
            v.start()
            anchorId = v.trackAnchor(s.payload)
            started = true
            findButton.visibility = View.GONE
            trackingJobs += lifecycleScope.launch {
                v.localizationUpdates.catch { Log.w(TAG, "loc flow") }.collect { l ->
                    localizationState = l.trackingState.name
                }
            }
            trackingJobs += lifecycleScope.launch {
                v.localizationRequestRecords.catch { Log.w(TAG, "rec flow") }.collect { r ->
                    if (r.status == Vps2LocalizationRequestStatus.FAILED ||
                        r.status == Vps2LocalizationRequestStatus.FRAME_REJECTED
                    ) {
                        VpsState.errorKey(r.error.name)?.let { showMessage(it) }
                    }
                }
            }
            renderStatus()
        } catch (e: Exception) {
            Log.w(TAG, "track: ${e.javaClass.simpleName}")
            stopTracking()
            showMessage(if (e.javaClass.simpleName.contains("InvalidArgument")) "vpsNoMap" else "vpsFailed")
        }
    }

    private fun stopTracking() {
        trackingJobs.forEach { it.cancel() }
        trackingJobs.clear()
        val v = vps2
        anchorId?.let { id -> runCatching { v?.removeAnchor(id) } }
        anchorId = null
        runCatching { v?.stop() }
        started = false
        anchorPose = null
        anchorState = null
        localizationState = null
    }

    // ------------------------------------------------------------ таблички

    private fun renderLabels(frame: Frame) {
        val anchor = anchorPose
        val w = labelsLayer.width
        val h = labelsLayer.height
        if (anchor == null || w == 0 || !VpsState.marksVisible(everPrecise, anchorState)) {
            labelViews.values.forEach { it.visibility = View.GONE }
            return
        }
        val view = FloatArray(16)
        val proj = FloatArray(16)
        frame.camera.getViewMatrix(view, 0)
        frame.camera.getProjectionMatrix(proj, 0, 0.05f, 100f)
        val viewProj = PoseMath.multiply(proj, view)
        val cam = frame.camera.pose
        val camPos = Vec3(cam.tx().toDouble(), cam.ty().toDouble(), cam.tz().toDouble())
        val shown = HashSet<String>()
        for (m in marks) {
            val world = PoseMath.toWorld(anchor, m.pose).p + Vec3(0.0, PoseMath.LABEL_LIFT_M, 0.0)
            val dist = (world - camPos).length()
            val screen = if (dist <= PoseMath.MAX_VISIBLE_M) PoseMath.project(viewProj, world, w, h) else null
            val label = labelViews.getOrPut(m.id) { makeLabel(m) }
            if (screen == null) {
                label.visibility = View.GONE
                continue
            }
            shown += m.id
            val s = VpsState.labelScale(dist)
            label.scaleX = s
            label.scaleY = s
            label.translationX = screen.first - label.width / 2f
            label.translationY = screen.second - label.height
            label.visibility = View.VISIBLE
        }
        labelViews.filterKeys { it !in shown }.values.forEach { it.visibility = View.GONE }
    }

    private fun makeLabel(m: VpsApi.Mark): View {
        val a = assets.firstOrNull { it.id == m.assetId }
        val box = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(12), dp(8), dp(12), dp(8))
            background = GradientDrawable().apply {
                setColor(0xF2FFFFFF.toInt())
                cornerRadius = dp(12).toFloat()
                setStroke(dp(3), a?.color ?: 0xFF2DB89A.toInt())
            }
            elevation = dp(4).toFloat()
            setOnClickListener { onLabelTap(m) }
            visibility = View.GONE
        }
        box.addView(TextView(this).apply {
            text = a?.name ?: "—"
            setTextColor(0xFF111111.toInt())
            textSize = 15f
            typeface = Typeface.DEFAULT_BOLD
        })
        if (!a?.line.isNullOrBlank()) {
            box.addView(TextView(this).apply {
                text = a!!.line
                setTextColor(0xFF3A3A3C.toInt())
                textSize = 13f
            })
        }
        labelsLayer.addView(box, FrameLayout.LayoutParams(WRAP, WRAP))
        return box
    }

    private fun onLabelTap(m: VpsApi.Mark) {
        if (placing) return
        val a = assets.firstOrNull { it.id == m.assetId }
        val items = mutableListOf(t("vpsOpenAsset"))
        if (canEdit) items += t("vpsDeleteMark")
        AlertDialog.Builder(this)
            .setTitle(a?.name ?: "")
            .setItems(items.toTypedArray()) { _, which ->
                when (which) {
                    0 -> {
                        setResult(RESULT_OK, Intent().putExtra(VpsContract.RESULT_ASSET, m.assetId))
                        finish()
                    }
                    1 -> deleteMark(m)
                }
            }
            .setNegativeButton(t("commonCancel"), null)
            .show()
    }

    private fun deleteMark(m: VpsApi.Mark) {
        val api = api ?: return
        lifecycleScope.launch {
            try {
                api.deleteMark(m.id)
                marks.removeAll { it.id == m.id }
                labelViews.remove(m.id)?.let { labelsLayer.removeView(it) }
                showMessage("vpsMarkDeleted", error = false)
            } catch (e: VpsApi.HttpError) {
                showMessage(VpsState.httpErrorKey(e.code))
            } catch (_: Exception) {
                showMessage(VpsState.httpErrorKey(null))
            }
        }
    }

    // ------------------------------------------------- «Поставить метку»

    private fun togglePlacing() {
        if (!placing && !everPrecise) return showMessage("vpsNeedPrecise")
        if (!placing && assets.isEmpty()) return showMessage("vpsNoAssets")
        placing = !placing
        hint.text = t("vpsPlaceHint")
        hint.visibility = if (placing) View.VISIBLE else View.GONE
        placeButton.text = if (placing) t("commonCancel") else t("vpsPlaceMark")
    }

    private fun onPlaceTap(x: Float, y: Float) {
        val frame = arFrame ?: return
        val anchor = anchorPose ?: return showMessage("vpsNeedPrecise")
        val hit = try {
            frame.hitTest(x, y).firstOrNull { r ->
                when (val tr = r.trackable) {
                    is Plane -> tr.isPoseInPolygon(r.hitPose)
                    is Point -> tr.orientationMode == Point.OrientationMode.ESTIMATED_SURFACE_NORMAL
                    else -> true // точка глубины
                }
            }
        } catch (_: Exception) {
            null
        } ?: return showMessage("vpsNoHit")
        val rel = PoseMath.relativeTo(anchor, hit.hitPose.toRigid())
        if (!PoseMath.isValidRelative(rel)) return showMessage("vpsNoHit")
        val names = assets.map { a ->
            if (marks.any { it.assetId == a.id }) "${a.name} ✓" else a.name
        }
        AlertDialog.Builder(this)
            .setTitle(t("vpsPickAsset"))
            .setItems(names.toTypedArray()) { _, which -> saveMark(assets[which].id, rel) }
            .setNegativeButton(t("commonCancel"), null)
            .show()
    }

    private fun saveMark(assetId: String, rel: RigidPose) {
        val api = api ?: return
        val s = site ?: return
        lifecycleScope.launch {
            try {
                val saved = api.saveMark(s.id, assetId, rel)
                marks.removeAll { it.assetId == assetId }
                labelViews.keys.filter { id -> marks.none { it.id == id } }.forEach { id ->
                    labelViews.remove(id)?.let { labelsLayer.removeView(it) }
                }
                marks += saved
                showMessage("vpsMarkSaved", error = false)
                if (placing) togglePlacing()
            } catch (e: VpsApi.HttpError) {
                showMessage(VpsState.httpErrorKey(e.code))
            } catch (_: Exception) {
                showMessage(VpsState.httpErrorKey(null))
            }
        }
    }

    // ------------------------------------------------------------ жизнь

    override fun onPause() {
        super.onPause()
        // Камера и запросы VPS — только пока экран на виду (кредиты Niantic).
        if (started) {
            stopTracking()
            findButton.visibility = if (site != null) View.VISIBLE else View.GONE
            renderStatus()
        }
    }

    override fun onDestroy() {
        stopTracking()
        runCatching { vps2?.close() }
        (dataSource as? DefaultLifecycleObserver)?.let { lifecycle.removeObserver(it) }
        updateExecutor.shutdown()
        // Ждём идущий update(): иначе нативный код читает уже закрытый кадр.
        runCatching { updateExecutor.awaitTermination(2, java.util.concurrent.TimeUnit.SECONDS) }
        runCatching { arView?.destroy() }
        runCatching { nsdk?.close() }
        super.onDestroy()
    }
}

private const val MATCH = ViewGroup.LayoutParams.MATCH_PARENT
private const val WRAP = ViewGroup.LayoutParams.WRAP_CONTENT

private fun Pose.toRigid() = RigidPose(
    Vec3(tx().toDouble(), ty().toDouble(), tz().toDouble()),
    Quat(qx().toDouble(), qy().toDouble(), qz().toDouble(), qw().toDouble()),
)
