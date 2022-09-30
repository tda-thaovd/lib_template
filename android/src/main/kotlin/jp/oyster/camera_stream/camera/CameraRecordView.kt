package jp.oyster.camera_stream.camera

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Rect
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.net.Uri
import android.util.Log
import android.util.Size
import android.view.LayoutInflater
import android.widget.FrameLayout
import androidx.camera.core.*
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import com.google.mlkit.common.MlKitException
import com.google.mlkit.vision.face.FaceDetectorOptions
import jp.oyster.camera_stream.R
import jp.oyster.camera_stream.databinding.ViewCameraStreamBinding
import jp.oyster.camera_stream.models.Question
import jp.oyster.camera_stream.utils.*
import kotlinx.coroutines.*
import java.io.File
import java.text.DecimalFormat
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import android.media.AudioManager
import androidx.core.graphics.drawable.toBitmap
import jp.oyster.camera_stream.models.VideoInfo

class CameraRecordView(context: Context) : FrameLayout(context), LifecycleOwner {

    private var binding: ViewCameraStreamBinding =
        ViewCameraStreamBinding.inflate(LayoutInflater.from(context), this, true)

    private var cameraExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private var needUpdateGraphicOverlayImageSourceInfo = false
    private val lensFacing = CameraSelector.LENS_FACING_FRONT

    private val faceFrameRect: Rect = Rect()

    private var imageProcessor: VisionImageProcessor? = null
    private val videoCapture: VideoCapture by lazy { createVideoCapture() }
    private val imageAnalysis: ImageAnalysis by lazy { ImageAnalysis.Builder().build() }
    private val cameraSelector: CameraSelector by lazy {
        CameraSelector.Builder().requireLensFacing(lensFacing).build()
    }

    private var scope: CoroutineScope? = null

    private var isDetected = false
    private var isRecording = false
    private var isWarmUp = false

    private var checkerLastDetectJob: Job? = null
    private var checkerDetectJob: Job? = null
    private var checkStartRecordVideo = false

    private val counterNumberFormat = DecimalFormat("##00")

    // Data store
    private var questions: MutableList<Question>?
    private val recordOutputs = ArrayList<VideoInfo>()

    // View callback
    var recordCallback: ((Boolean, ArrayList<VideoInfo>?) -> Unit)? = null
    var warmupCallback: ((Boolean, VideoInfo?) -> Unit)? = null

    private var mediaPlayer: MediaPlayer?
    private var audioManager: AudioManager? = null

    private var cameraUseCases = mutableListOf<UseCase>()

    private val lifecycleRegistry = LifecycleRegistry(this)

    init {
        scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
        questions = ArrayList<Question>()
        setupView()

        mediaPlayer = MediaPlayer().apply {
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .build()
            )
        }
        audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val volume = (audioManager?.getStreamMaxVolume(AudioManager.STREAM_MUSIC) ?: 10) / 2
        audioManager?.setStreamVolume(AudioManager.STREAM_MUSIC, volume, 0)
    }

    override fun getLifecycle(): Lifecycle {
        return lifecycleRegistry
    }

    fun startDetectAndRecord(questions: List<Question>?) {
        this.questions = questions?.toMutableList()
        this.recordOutputs.clear()

        isWarmUp = false
        if (questions?.isNotEmpty() == true) {
            getProcessCamera().unbindAll()
            cameraUseCases.clear()

            scope?.launch {
                delay(100)

                withContext(Dispatchers.Main) {
                    startPreview()
                    startDetectFace()
                }
            }
        } else {
            recordCallback?.invoke(false, null)
        }
    }

    fun startWarmUp(questions: List<Question>?) {
        this.questions = questions?.toMutableList()
        this.recordOutputs.clear()

        isWarmUp = true

        getProcessCamera().unbindAll()
        cameraUseCases.clear()

        scope?.launch {
            delay(100)

            withContext(Dispatchers.Main) {
                startPreview()
            }
        }

        binding.apply {
            faceFrame.hide()
            ivDetectNotice.gone()
            tvWarmUp.show()
            focusViewFullscreen.show()
            focusView.hide()
        }

        scope?.launch {
            repeat(3) {
                delay(1_000)
            }

            withContext(Dispatchers.Main) {
                binding.apply {
                    faceFrame.show()
                    ivDetectNotice.show()
                    tvWarmUp.gone()
                    focusViewFullscreen.hide()
                    focusView.show()
                }

                binding.faceFrame.post {
                    binding.faceFrame.getGlobalVisibleRect(faceFrameRect)
                }

                startDetectFace()
            }
        }
    }

    private fun setupView() {
        setUpFont()
        binding.counterProgressBar.apply { max = COUNTER_TIME }

        binding.counterText.apply {
            text = counterNumberFormat.format(COUNTER_TIME)
        }

        binding.faceFrame.post {
            binding.faceFrame.getGlobalVisibleRect(faceFrameRect)
            binding.focusView.focusPosition = FocusPosition(faceFrameRect)
        }

    }

    private fun setUpFont() {
        binding.tvWarmUp.typeface = getFont(context, NotoFontType.Black)
        binding.tvStartQuestion.typeface = getFont(context, NotoFontType.Black)
        binding.prepareRecord.typeface = getFont(context, NotoFontType.Black)
        binding.textQuestionState.typeface = getFont(context, NotoFontType.Bold)
        binding.questionTitle.typeface = getFont(context, NotoFontType.Bold)
        binding.counterText.typeface = getFont(context, NotoFontType.Black)
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        binding.faceFrame.post {
            binding.faceFrame.getGlobalVisibleRect(faceFrameRect)
        }

        lifecycleRegistry.currentState = Lifecycle.State.RESUMED
    }

    override fun onDetachedFromWindow() {
        super.onDetachedFromWindow()
        scope?.cancel()
        scope = null

        cameraUseCases.clear()

        mediaPlayer?.release()
        checkerLastDetectJob?.cancel()
        checkerDetectJob?.cancel()
        cameraExecutor.shutdown()
        imageProcessor?.run { this.stop() }

        lifecycleRegistry.currentState = Lifecycle.State.DESTROYED
    }

    private fun playQuestionAudio(question: Question, onDone: () -> Unit) {
        binding.viewQuestionState.apply {
            show()
            background = context.getDrawableV2(R.drawable.bg_question_playback)
        }
        binding.textQuestionState.apply {
            text = context.getString(R.string.question)
        }
        binding.ivQuestionState.apply {
            setImageResource(R.drawable.icon_speaker)
        }

        binding.counterProgressBar.progress = 0
        binding.counterText.text = counterNumberFormat.format(question.answerTime ?: COUNTER_TIME)

        mediaPlayer?.reset()
        mediaPlayer?.setDataSource(question.audioLink)
        mediaPlayer?.prepareAsync()
        mediaPlayer?.setOnPreparedListener {
            it.start()
        }
        mediaPlayer?.setOnCompletionListener {
            it.reset()
            onDone.invoke()
        }
    }

    private fun startPreparedQuestion(onDone: () -> Unit) {
        var preparedTime = 3

        binding.apply {
//            counterProgressBar.hide()
//            counterText.hide()
//            questionTitleLayout.hide()

            viewQuestionState.background = context.getDrawableV2(R.drawable.bg_question_playback)

            preparedGroup.show()
            prepareRecord.text = preparedTime.toString()

            pbQuestionCountdown.progress = 0
            pbQuestionCountdown.setBigMax(10)
            pbQuestionCountdown.animateTo(10, 100)

            focusViewFullscreen.show()
        }

        scope?.launch {
            repeat(3) {
                delay(1_000)
                withContext(Dispatchers.Main) {
                    preparedTime--
                    binding.prepareRecord.text = preparedTime.toString()
                }
            }

            withContext(Dispatchers.Main) {
                binding.apply {
                    preparedGroup.gone()
                    counterProgressBar.show()
                    counterText.show()
                    questionTitleLayout.show()
                    focusViewFullscreen.hide()
                }
                onDone.invoke()
            }
        }
    }

    private fun startDetectFace() = checkPermission { startDetect() }

    private fun startCheckerChangeUIWhenFaceDetected() {
        binding.faceFrame.show()
        binding.focusView.show()
        checkerDetectJob?.cancel()
        checkerDetectJob = scope?.launch {
            while (true) {
                withContext(Dispatchers.Main) {
                    if (isDetected) {
                        binding.faceFrame.setImageResource(R.drawable.frame_face_on)
                        binding.detectedIcon.show()
                        binding.ivDetectNotice.gone()
                        checkStartRecordVideo()
                    } else {
                        binding.faceFrame.setImageResource(R.drawable.frame_face_off)
                        binding.detectedIcon.gone()
                        binding.ivDetectNotice.show()
                    }
                }
                delay(300)
            }
        }
    }

    private fun stopCheckerChangeUIWhenFaceDetected() {
        getProcessCamera().unbind(imageAnalysis)
        cameraUseCases.remove(imageAnalysis)

        binding.faceFrame.hide()
        binding.focusView.hide()
        binding.ivDetectNotice.gone()
        checkerDetectJob?.cancel()
    }

    @SuppressLint("RestrictedApi")
    private fun startRecord(question: Question, onDone: () -> Unit) {
        val videoFile = createFile(context)
        val thumbnailFile = createFile(context, "png")
        getProcessCamera().bindToLifecycle(this, cameraSelector, videoCapture)

        cameraUseCases.add(videoCapture)

        val outputOptions = VideoCapture.OutputFileOptions.Builder(videoFile).build()

        videoCapture.startRecording(
            outputOptions,
            ContextCompat.getMainExecutor(context),
            object : VideoCapture.OnVideoSavedCallback {
                override fun onError(videoCaptureError: Int, message: String, cause: Throwable?) {
                    Log.e(TAG, "Video capture failed: $message")
                }

                override fun onVideoSaved(outputFileResults: VideoCapture.OutputFileResults) {
                    val videoFileUri = Uri.fromFile(videoFile)
                    val thumbnailUri = Uri.fromFile(thumbnailFile)
                    getThumbnailImage(context, videoFileUri, thumbnailFile) {
                        recordOutputs.add(
                            VideoInfo(
                                questionId = question.id,
                                videoDir = videoFile.absolutePath,
                                thumbnailDir = thumbnailFile.absolutePath
                            )
                        )
                        val msg = "Video capture successfully: $videoFileUri - $thumbnailUri"
                        Log.d(TAG, msg)
                        onDone.invoke()
                    }
                }
            })
    }

    @SuppressLint("RestrictedApi")
    private fun stopRecording() {
        isRecording = false
        videoCapture.stopRecording()
        getProcessCamera().unbind(videoCapture)

        cameraUseCases.remove(videoCapture)
    }

    private fun startRecordingCountTime(question: Question) {
        var videoDurationCounter = question.answerTime ?: COUNTER_TIME

        binding.counterProgressBar.max = question.answerTime ?: COUNTER_TIME
        binding.counterProgressBar.progress = 0
        binding.counterText.text = counterNumberFormat.format(videoDurationCounter)

        scope?.launch {
            repeat(question.answerTime ?: COUNTER_TIME) {
                delay(1_000)
                withContext(Dispatchers.Main) {
                    videoDurationCounter--
                    binding.counterProgressBar.progress = (question.answerTime ?: COUNTER_TIME) - videoDurationCounter
                    binding.counterText.text = counterNumberFormat.format(videoDurationCounter)
                }
            }
            delay(2_00)
            withContext(Dispatchers.Main) {
                isRecording = false
                isDetected = false
                kotlin.runCatching { questions?.removeAt(0) }
                stopRecording()

                binding.counterText.text = counterNumberFormat.format(0)
            }
        }
    }

    // TODO
    @SuppressLint("RestrictedApi")
    private fun createVideoCapture() = VideoCapture.Builder()
        .setVideoFrameRate(30)
        .setMaxResolution(Size(1280, 720))
        .setBitRate(2000 * 1024)
        .build()

    private fun startPreview() {
        checkPermission {
            val preview = Preview.Builder()
                .build()
                .also {
                    it.setSurfaceProvider(binding.previewView.surfaceProvider)
                }

            getProcessCamera().bindToLifecycle(this, cameraSelector, preview)

            cameraUseCases.add(preview)
        }
    }

    private fun startDetect() {
        imageProcessor?.stop()
        val faceDetectOptions = FaceDetectorOptions.Builder().apply { setMinFaceSize(0.5f) }.build()
        imageProcessor = FaceDetectorProcessor(context, faceDetectOptions) { faces, graphicOverlay ->
            faces.forEach { face ->
                isDetected = graphicOverlay.checkRectInsideBox(faceFrameRect, face.boundingBox)
                checkerFaceDebounced { isDetected = false }
            }
        }

        needUpdateGraphicOverlayImageSourceInfo = true

        imageAnalysis.setAnalyzer(
            // imageProcessor.processImageProxy will use another thread to run the detection underneath,
            // thus we can just runs the analyzer itself on main thread.
            cameraExecutor,
            { imageProxy: ImageProxy ->
                if (needUpdateGraphicOverlayImageSourceInfo) {
                    val isImageFlipped =
                        lensFacing == CameraSelector.LENS_FACING_FRONT
                    val rotationDegrees =
                        imageProxy.imageInfo.rotationDegrees
                    if (rotationDegrees == 0 || rotationDegrees == 180) {
                        binding.graphicOverlay.setImageSourceInfo(
                            imageProxy.width, imageProxy.height, isImageFlipped
                        )
                    } else {
                        binding.graphicOverlay.setImageSourceInfo(
                            imageProxy.height, imageProxy.width, isImageFlipped
                        )
                    }
                    needUpdateGraphicOverlayImageSourceInfo = false
                }

                try {
                    imageProcessor?.processImageProxy(imageProxy, binding.graphicOverlay)
                } catch (e: MlKitException) {
                    Log.e(TAG, "Failed to process image. Error: " + e.localizedMessage)
                    context.toast(e.localizedMessage ?: "")
                }
            }
        )

        // Bind use cases to camera
        getProcessCamera().bindToLifecycle(this, cameraSelector, imageAnalysis)

        cameraUseCases.add(imageAnalysis)

        startCheckerChangeUIWhenFaceDetected()
    }

    private fun checkStartRecordVideo() {
        if (checkStartRecordVideo) return
        checkStartRecordVideo = true
        scope?.launch {
            delay(1_000)
            withContext(Dispatchers.Main) {
                if (isDetected) {
                    startQuestion()
                }
            }
            checkStartRecordVideo = false
        }

    }

    private fun startQuestion() {
        if (questions?.isEmpty() == true) {
            binding.viewQuestionState.background = context.getDrawableV2(R.drawable.bg_question_playback)
            binding.doneImv.show()

            scope?.launch {
                delay(2000)

                withContext(Dispatchers.Main) {
                    if (isWarmUp) warmupCallback?.invoke(true, recordOutputs.first())
                    else recordCallback?.invoke(true, recordOutputs)
                }
            }
            return
        }
        val question = questions?.firstOrNull()
        question?.run {
            binding.questionTitle.text = this.name
            stopCheckerChangeUIWhenFaceDetected()
            binding.detectedIcon.gone()
            isRecording = true
            startPreparedQuestion {
                playQuestionAudio(this@run) {
                    binding.viewQuestionState.apply {
                        show()
                        background = context.getDrawableV2(R.drawable.bg_question_your_turn)
                    }
                    binding.textQuestionState.apply {
                        text = context.getString(R.string.your_turn)
                    }
                    binding.ivQuestionState.apply {
                        setImageResource(R.drawable.icon_microphone)
                    }
                    binding.questionTitle.apply {
                        text = question.name
                    }

                    startRecord (question) { startQuestion() }
                    startRecordingCountTime(question)
                }
            }
        }
    }

    private fun checkerFaceDebounced(timeDebounce: Long = 300, callBack: () -> Unit) {
        checkerLastDetectJob?.cancel()
        checkerLastDetectJob = scope?.launch {
            delay(timeDebounce)
            callBack.invoke()
        }
    }

    private fun getProcessCamera() =
        ProcessCameraProvider.getInstance(context).get()

    private fun allPermissionsGranted() = REQUIRED_PERMISSIONS.all {
        ContextCompat.checkSelfPermission(
            context, it
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun checkPermission(onAllPermissionsGranted: () -> Unit) {
        if (allPermissionsGranted()) {
            onAllPermissionsGranted.invoke()
        }
    }

    fun pausePreview() {
        getProcessCamera().unbindAll()
    }

    fun resumePreview() {
        if (lifecycle.currentState == Lifecycle.State.DESTROYED) return
        for (useCase in cameraUseCases) {
            getProcessCamera().bindToLifecycle(this, cameraSelector, useCase)
        }
    }

    companion object {
        private const val TAG = "CameraRecordView"

        // TODO: Change based on question
        private const val COUNTER_TIME = 30
        private val REQUIRED_PERMISSIONS =
            arrayOf(Manifest.permission.CAMERA, Manifest.permission.RECORD_AUDIO)

        /** Creates a [File] named with the current date and time */
        private fun createFile(context: Context, extension: String = "mp4"): File {
            val sdf = SimpleDateFormat("yyyy_MM_dd_HH_mm_ss_SSS", Locale.US)
            return File(context.filesDir, "VID_${sdf.format(Date())}.$extension")
        }
    }

}
