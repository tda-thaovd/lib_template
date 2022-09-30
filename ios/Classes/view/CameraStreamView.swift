//
//  CameraStreamView.swift
//  CameraModule
//
//  Created by Huy Nguyen on 25/08/2021.
//

import UIKit
import AVKit
import Vision

enum CaptureState {
        case idle, start, capturing, captured, end
}
enum UserState {
    case idle
    case prepare
    case listenQuestion
    case answer
    case processing
    case end
    case warmup
}

public struct Question: Codable {
    let id, title: String
    let questionLink: String
    let position, answerTime: Int
}

public struct VideoInfo: Codable {
  let questionId: String
  let videoDir: String
  let thumbnailDir: String?
    
  private enum CodingKeys : String, CodingKey {
    case questionId = "question_id"
    case videoDir = "video_dir"
    case thumbnailDir = "thumbnail_dir"
  }
}

public final class CameraStreamView: UIView, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    
    @IBOutlet var contentView: UIView!
    
    // MARK: - Outlets
    @IBOutlet weak var iconDone: UIImageView!
    @IBOutlet weak var imgWarning: UIImageView!
    @IBOutlet weak var imvFace: UIImageView!
    
    // View for warm up
    @IBOutlet weak var lbWarmup: UILabel!
    
    // View Count down for prepare
    @IBOutlet weak var countDownPrepare: CircularProgressBarView!
    @IBOutlet weak var lbCountDownPrepare: UILabel!
    @IBOutlet weak var containerCountDownPrepareView:UIView!
    @IBOutlet weak var lbNumberQuestion: UILabel!
    @IBOutlet weak var lbStartQuestion: UILabel!
    @IBOutlet weak var lbPrepare: UILabel!
    
    // View question or your turn
    @IBOutlet weak var containerViewQuestion: UIView!
    @IBOutlet weak var iconQuestion: UIImageView!
    @IBOutlet weak var lbTitleQuestion: UILabel!
    
    //view  Count down for listen question and anwser question
    @IBOutlet weak var countDownView: CircularProgressBarView!
    @IBOutlet weak var lbCountDownView: UILabel!
    
    @IBOutlet weak var completeContainerView: UIView!
    @IBOutlet weak var iconComplete: UIImageView!
    
    // Main view for showing camera content.
    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var containerView: UIView!
    
    // Focus view
    @IBOutlet weak var backgroundView: UIView!
    @IBOutlet weak var backgroundViewFullScreen: UIView!
    
    public typealias RecordOutputCallback = ([VideoInfo]) -> Void
    
    public typealias WarmUpOutputCallback = (VideoInfo?) -> Void
    
    //MARK: - AV
    
    // Write video
    
    var videoOutputURL: URL?
    var videoWriter: AVAssetWriter?
    var videoInput: AVAssetWriterInput?
    // Write audio
    var audioOutputURL: URL?
    var audioWriter: AVAssetWriter?
    var micAudioInput:AVAssetWriterInput?
    // Thumnail
    var videoThumbnailURL: URL?

    var isPaused = false
    var isVideoWritingFinished = false
    var isAudioWritingFinished = false
    
    var sessionStartTime: CMTime = CMTime.zero
    
    var _adpater: AVAssetWriterInputPixelBufferAdaptor?
    var _filename = ""
    var _time: Double = 0
    
    // MARK: - Variables and constant
    // data
    var recordOutputs: [String] = []
    private let timePrepare = 3;
    var output: [VideoInfo] = []
    
    // mockup data
    var questions: [Question] = []
    var timeCount = 0 ;
    var currentQuestion = 0;
    
    //AudioPlayer
    var player: AVPlayer?
   
    // Callback when record finish
    var recordVideoHandler: RecordOutputCallback?
    var warmUpHandler: WarmUpOutputCallback?
    
    // AVCapture variables to hold sequence data
    var session: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    var videoDataOutput: AVCaptureVideoDataOutput?
    var audioDataOutput: AVCaptureAudioDataOutput?
    
    var audioConnection: AVCaptureConnection?
    var videoConnection: AVCaptureConnection?
    
    var videoDataOutputQueue: DispatchQueue?
    
    var drawings: [CAShapeLayer] = []
    
    var captureDevice: AVCaptureDevice?
    var captureDeviceResolution: CGSize = CGSize()
    
    // Vision requests
    var detectionRequests: [VNDetectFaceRectanglesRequest]?
    var trackingRequests: [VNTrackObjectRequest]?
    
    lazy var sequenceRequestHandler = VNSequenceRequestHandler()
    
    var timer: Timer?
    
    var isCounting = false
    var isWarmUp = false
    
    var captureState = CaptureState.idle
    
    var currentState: UserState = .idle {
        didSet {
            switch currentState {
            case .warmup:
                imvFace.isHidden = true
                iconDone.isHidden = true
                imgWarning.isHidden = true
                lbWarmup.isHidden = false
                backgroundView.isHidden = true
                backgroundViewFullScreen.isHidden = false
                
                timer = Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(updateUICountDown), userInfo: nil, repeats: false)
            
            case .prepare:
                timeCount = timePrepare
                imvFace.isHidden = true
                iconDone.isHidden = true
                backgroundView.isHidden = true
                backgroundViewFullScreen.isHidden = false
                
                timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(updateUICountDown), userInfo: nil, repeats: true)
                
            case .listenQuestion:
                updateUIListenQuestionState()
                playQuestions()
                
            case .answer:
                timeCount = questions[currentQuestion].answerTime
                updateUIAnswerState()
                captureState = .start
                timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] _ in
                    self?.updateUICountDown()
                })
            case .processing:
                completeContainerView.isHidden = false
                resetTimer()
            case .end:
                if (isWarmUp) {
                    warmUpHandler?(output.first)
                }
                else {
                    recordVideoHandler?(output)
                }
            case .idle:
                imvFace.isHidden = false
                imgWarning.isHidden = false
                lbWarmup.isHidden = true
                backgroundView.isHidden = false
                backgroundViewFullScreen.isHidden = true
                break
            }
        }
    }
    
    var task = DispatchWorkItem(block: {})
    
    var isDetectFace: Bool = false {
        didSet {
            if captureState == .idle && currentState == .idle {
                imgWarning.isHidden = isDetectFace
                iconDone.isHidden = !isDetectFace
                imvFace.image = isDetectFace ? AssetManager.getImage("frame_face_on") : AssetManager.getImage("frame_face_off")
                
                task.cancel()
                task = DispatchWorkItem { [weak self ] in
                    if (self?.isDetectFace ?? false ){
                        self?.currentState = .prepare
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1, execute: task)
            }

        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        layoutIfNeeded()
        setUpOverlayView()
    }
    
    private func commonInit() {
        Bundle.current.loadNibNamed("CameraStreamView", owner: self, options: nil)
        addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        setUp()
        
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
        self.videoOutputURL = URL(fileURLWithPath: documentsPath.appendingPathComponent("CameraStreamTempVideo.mp4"))
        self.audioOutputURL = URL(fileURLWithPath: documentsPath.appendingPathComponent("CameraStreamTempAudio.m4a"))
        removeURLsIfNeeded()
    }
    
    public func setUp() {
        UIApplication.shared.isIdleTimerDisabled = true
        
        self.session = self.setupAVCaptureSession()
        
        self.prepareVisionRequest()
        
        self.session?.startRunning()
            
        setupView()
    }

    func reset() {
        self.session?.stopRunning()
        self.timer?.invalidate()
        self.timer = nil
        self.player?.pause()
        self.player = nil
        print("CameraStreamView Reset")
        UIApplication.shared.isIdleTimerDisabled = false
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
    }
    
    func startDetectAndRecord(questions: [Question]) {
        self.questions = questions
        self.isWarmUp = false
        self.currentState = .idle
    }
    
    func startWarmUpFlow(warmUpQuestion: Question?) {
        if let question = warmUpQuestion {
            self.questions.removeAll()
            self.questions.append(question)
            
            self.currentState = .warmup
        }
        self.isWarmUp = true
    }
    
    private func playQuestions() {
        guard let url = URL(string: questions[currentQuestion].questionLink) else { return }
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        player?.play()
        
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            self?.currentState = .answer
        }
    }
    
    @objc func updateUICountDown() {
        switch currentState {
        case .warmup:
            self.currentState = .idle
        case .prepare:
            containerCountDownPrepareView.isHidden = false
            if(!isCounting) {
                countDownPrepare.progressAnimation(duration: TimeInterval(timePrepare))
                isCounting = true
            }
            if(self.timeCount >= 0 ) {
                self.lbCountDownPrepare.text = "\(self.timeCount)"
                self.timeCount = self.timeCount - 1

            } else {
                resetTimer()
                currentState = .listenQuestion
            }
        case .answer:
            if(!isCounting) {
                countDownView.progressAnimation(duration: TimeInterval(questions[currentQuestion].answerTime))
                isCounting = true
            }
            if(self.timeCount >= 0) {
                self.lbCountDownView.text = "\(self.timeCount)"
                self.timeCount = self.timeCount - 1
               
            } else {
                resetTimer()
                captureState = .captured
            }
         default:
            break
        }
    }
    
    func resetTimer() {
        isCounting = false
        timer?.invalidate()
        timer = nil
    }
    
    
    private func updateUIListenQuestionState() {
        containerCountDownPrepareView.isHidden = true
        backgroundViewFullScreen.isHidden = true
        containerViewQuestion.isHidden = false
        lbNumberQuestion.isHidden = false
        countDownView.isHidden = false
        lbNumberQuestion.text = questions[currentQuestion].title
        iconQuestion.image  = AssetManager.getImage("icon_speaker")
        lbTitleQuestion.text = "Question"
        containerViewQuestion.backgroundColor = UIColor.black
        lbCountDownView.text = "\(questions[currentQuestion].answerTime)"
    }
  
    private func updateUIAnswerState() {
        iconQuestion.image = AssetManager.getImage("icon_microphone")
        lbTitleQuestion.text = "Your turn "
        containerViewQuestion.backgroundColor = UIColor.systemPink
        countDownView.resetCircularProgress()
        lbCountDownView.text = "\(timeCount)"
    }
    
    @IBAction func closeHandle(_ sender: UIButton) {
        removeFromSuperview()
    }
    
    private func setupView() {
        previewView.bringSubviewToFront(containerView)
        countDownPrepare.countType = .prepare
        countDownView.countType = .listenQuestion
        containerViewQuestion.layer.cornerRadius = containerViewQuestion.frame.height / 2
        completeContainerView.layer.cornerRadius = 15
        lbNumberQuestion.layer.cornerRadius = 8
        lbNumberQuestion.layer.maskedCorners = [.layerMaxXMaxYCorner, .layerMinXMaxYCorner]
        lbNumberQuestion.layer.masksToBounds = true
        
        imvFace.image = AssetManager.getImage("frame_face_off")
        iconDone.image = AssetManager.getImage("icon_done")
        imgWarning.image = AssetManager.getImage("bg_tracking_notice")
        iconComplete.image = AssetManager.getImage("icon_complete")
        
        
        lbWarmup.font = UIFont.NotoSansCJKJS(.black, size: 40)
        lbNumberQuestion.font = UIFont.NotoSansCJKJS(.bold, size: 17)
        lbTitleQuestion.font = UIFont.NotoSansCJKJS(.bold, size: 14)
        lbCountDownView.font = UIFont.NotoSansCJKJS(.black, size: 20)
        lbCountDownPrepare.font = UIFont.NotoSansCJKJS(.black, size: 20)
        lbStartQuestion.font = UIFont.NotoSansCJKJS(.black, size: 30)
        lbPrepare.font = UIFont.NotoSansCJKJS(.black, size: 100)
    }
    
    private func setUpOverlayView() {
        // Create the initial layer from the view bounds.
        let maskLayer = CAShapeLayer()
        maskLayer.frame = backgroundView.bounds
        maskLayer.fillColor = UIColor.black.cgColor

        // Create the path.
        let path = UIBezierPath(rect: backgroundView.bounds)
        maskLayer.fillRule = CAShapeLayerFillRule.evenOdd
        
        path.append(UIBezierPath(rect: imvFace.frame))
        maskLayer.path = path.cgPath

        // Set the mask of the view.
        backgroundView.layer.mask = maskLayer
    }
    
    // MARK: -  AVCapture Setup
    
    /// - Tag: CreateCaptureSession
    fileprivate func setupAVCaptureSession() -> AVCaptureSession? {
        let captureSession = AVCaptureSession()
        
        do {
            let videoDeviceInput = try self.configureFrontCamera(for: captureSession)
            let audioDeviceInput = try self.configureMicrophone(for: captureSession)
            
            self.configureVideoDataOutput(for: videoDeviceInput.device, resolution: videoDeviceInput.resolution, captureSession: captureSession)
            self.configureAudioDataOutput(for: audioDeviceInput, captureSession: captureSession)
            
            self.designatePreviewLayer(for: captureSession)
            
            return captureSession
        } catch let executionError as NSError {
            self.presentError(executionError)
        } catch {
            self.presentErrorAlert(message: "An unexpected failure has occured")
        }
        
        self.teardownAVCapture()
        
        return nil
    }
    
    /// - Tag: ConfigureDeviceResolution
    fileprivate func highestResolution420Format(for device: AVCaptureDevice) -> (format: AVCaptureDevice.Format, resolution: CGSize)? {
        var highestResolutionFormat: AVCaptureDevice.Format? = nil
        var highestResolutionDimensions = CMVideoDimensions(width: 0, height: 0)
        
        for format in device.formats {
            let deviceFormat = format as AVCaptureDevice.Format
            
            let deviceFormatDescription = deviceFormat.formatDescription
            
            if CMFormatDescriptionGetMediaSubType(deviceFormatDescription) == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange {
                let candidateDimensions = CMVideoFormatDescriptionGetDimensions(deviceFormatDescription)
                if (highestResolutionFormat == nil) || (candidateDimensions.width > highestResolutionDimensions.width) {
                    highestResolutionFormat = deviceFormat
                    highestResolutionDimensions = candidateDimensions
                }
            }
        }
        
        if highestResolutionFormat != nil {
            let resolution = CGSize(width: CGFloat(highestResolutionDimensions.width), height: CGFloat(highestResolutionDimensions.height))
            return (highestResolutionFormat!, resolution)
        }
        
        return nil
    }
    
    fileprivate func configureFrontCamera(for captureSession: AVCaptureSession) throws -> (device: AVCaptureDevice, resolution: CGSize) {
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .front)
        
        if let device = deviceDiscoverySession.devices.first {
            if let deviceInput = try? AVCaptureDeviceInput(device: device) {
                if captureSession.canAddInput(deviceInput) {
                    captureSession.addInput(deviceInput)
                }
                
                if let highestResolution =  self.highestResolution420Format(for: device) {
                    try device.lockForConfiguration()
                    device.activeFormat = highestResolution.format
                    device.unlockForConfiguration()
                    
                    return (device, highestResolution.resolution)
                }
            }
        }
        
        throw NSError(domain: "Front camera was not available", code: 1, userInfo: nil)
    }
    
    fileprivate func configureMicrophone(for captureSession: AVCaptureSession) throws -> AVCaptureDevice {
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInMicrophone],
            mediaType: .audio,
            position: .unspecified)
        if let device = deviceDiscoverySession.devices.first {
            if let deviceInput = try? AVCaptureDeviceInput(device: device) {
                if captureSession.canAddInput(deviceInput) {
                    captureSession.addInput(deviceInput)
                }
                return device
            }
        }
        
        throw NSError(domain: "Microphone was not available", code: 2, userInfo: nil)
    }
    
    /// - Tag: CreateSerialDispatchQueue
    fileprivate func configureVideoDataOutput(for inputDevice: AVCaptureDevice, resolution: CGSize, captureSession: AVCaptureSession) {
        
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        
        // Create a serial dispatch queue used for the sample buffer delegate as well as when a still image is captured.
        // A serial dispatch queue must be used to guarantee that video frames will be delivered in order.
        let videoDataOutputQueue = DispatchQueue(label: "jp.oyster.camera_stream.videoqueues")
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
        }
        
        videoDataOutput.connection(with: .video)?.isEnabled = true
        
        if let captureConnection = videoDataOutput.connection(with: AVMediaType.video) {
            if captureConnection.isCameraIntrinsicMatrixDeliverySupported {
                captureConnection.isCameraIntrinsicMatrixDeliveryEnabled = true
            }
            captureConnection.videoOrientation = .portrait
            
            self.videoConnection = captureConnection
        }
        
        self.videoDataOutput = videoDataOutput
        self.videoDataOutputQueue = videoDataOutputQueue
        
        self.captureDevice = inputDevice
        self.captureDeviceResolution = CGSize(width: 720, height: 1280)
        
        captureSession.sessionPreset = AVCaptureSession.Preset.hd1280x720
    }
    
    fileprivate func configureAudioDataOutput(for inputDevice: AVCaptureDevice, captureSession: AVCaptureSession) {
        let audioDataOutput = AVCaptureAudioDataOutput()
        let queue = DispatchQueue(label: "jp.oyster.camera_stream.audioqueues")
        audioDataOutput.setSampleBufferDelegate(self, queue: queue)
        if captureSession.canAddOutput(audioDataOutput) {
            captureSession.addOutput(audioDataOutput)
        }
        
        if let audioConnection = audioDataOutput.connection(with: AVMediaType.audio) {
            self.audioConnection = audioConnection
        }
        
        self.audioDataOutput = audioDataOutput
    }
    
    /// - Tag: DesignatePreviewLayer
    fileprivate func designatePreviewLayer(for captureSession: AVCaptureSession) {
        let videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.previewLayer = videoPreviewLayer
        
        videoPreviewLayer.name = "CameraPreview"
        videoPreviewLayer.backgroundColor = UIColor.black.cgColor
        videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspect
        
        if let previewRootLayer = self.previewView?.layer {
            previewRootLayer.masksToBounds = true
            videoPreviewLayer.frame = previewRootLayer.bounds
            previewRootLayer.addSublayer(videoPreviewLayer)
        }
    }
    
    // Removes infrastructure for AVCapture as part of cleanup.
    fileprivate func teardownAVCapture() {
        self.videoDataOutput = nil
        self.videoDataOutputQueue = nil
        
        if let previewLayer = self.previewLayer {
            previewLayer.removeFromSuperlayer()
            self.previewLayer = nil
        }
    }
    
    // MARK: Helper Methods for Error Presentation
    
    func presentErrorAlert(withTitle title: String = "Unexpected Failure", message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        Util.topViewController()?.present(alertController, animated: true)
    }
    
    func presentError(_ error: NSError) {
        self.presentErrorAlert(withTitle: "Failed with error \(error.code)", message: error.localizedDescription)
    }
    
    // MARK: Helper Methods for Handling Device Orientation & EXIF
    
    func radiansForDegrees(_ degrees: CGFloat) -> CGFloat {
        return CGFloat(Double(degrees) * Double.pi / 180.0)
    }
    
    func exifOrientationForDeviceOrientation(_ deviceOrientation: UIDeviceOrientation) -> CGImagePropertyOrientation {
        
        switch deviceOrientation {
        case .portraitUpsideDown:
            return .rightMirrored
            
        case .landscapeLeft:
            return .downMirrored
            
        case .landscapeRight:
            return .upMirrored
            
        default:
            return .leftMirrored
        }
    }
    
    func exifOrientationForCurrentDeviceOrientation() -> CGImagePropertyOrientation {
        return exifOrientationForDeviceOrientation(UIDevice.current.orientation)
    }
    
}
