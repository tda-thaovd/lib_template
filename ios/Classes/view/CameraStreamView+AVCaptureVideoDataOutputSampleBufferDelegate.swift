//
//  CameraStreamView+.swift
//  CameraModule
//
//  Created by Huy Nguyen on 25/08/2021.
//

import AVKit
import Vision

extension CameraStreamView {
    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    /// - Tag: PerformRequests
    // Handle delegate method callback on receiving a sample buffer.
    
    func saveImage(sampleBuffer: CMSampleBuffer) -> URL? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let documentDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let fileName = UUID().uuidString
        let imagePath = documentDir.appendingPathComponent("\(fileName).jpg")
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let image = UIImage(ciImage: ciImage)
        
        if let imageData = image.resized(toWidth: 200.0)?.jpegData(compressionQuality: 0.8) {
            do {
                try imageData.write(to: imagePath)
                return imagePath
            } catch {
                return nil
            }
        }
        
        return nil
    }
    
    func setUpWriter() {
        do {
            try videoWriter = AVAssetWriter(outputURL: self.videoOutputURL!, fileType: .mp4)
        } catch let writerError as NSError {
            print("Error opening video file \(writerError)")
        }
    
        var videoSettings = videoDataOutput!.recommendedVideoSettingsForAssetWriter(writingTo: .mp4)
        
        if var propertiesKey = videoSettings?["AVVideoCompressionPropertiesKey"] as? [String: Any], let averageBitRate = propertiesKey["AverageBitRate"] as? Int32 {
            propertiesKey["AverageBitRate"] = averageBitRate / 2
            videoSettings?[AVVideoCompressionPropertiesKey] = propertiesKey
        }

        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        
        if let videoInput = self.videoInput,
            let canAddInput = videoWriter?.canAdd(videoInput),
            canAddInput {
            videoWriter?.add(videoInput)
        } else {
            print("couldn't add video input")
        }
        
        do {
            try audioWriter = AVAssetWriter(outputURL: self.audioOutputURL!, fileType: .m4a)
        } catch let writerError as NSError {
            print("Error opening video file \(writerError)")
        }
        
        let audioOutputSettings = audioDataOutput!.recommendedAudioSettingsForAssetWriter(writingTo: .m4a) as? [String : Any]
        
        micAudioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioOutputSettings)
        if let micAudioInput = self.micAudioInput,
            let canAddInput = audioWriter?.canAdd(micAudioInput),
            canAddInput {
            audioWriter?.add(micAudioInput)
        } else {
            print("couldn't add mic audio input")
        }
    }
    
    func handleOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        switch captureState {
        case .start:
            if self.videoWriter == nil {
                self.setUpWriter()
            }
            guard let videoWriter = self.videoWriter,
                let audioWriter = self.audioWriter,
                !isPaused else {
                    return
            }
            
            let presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            
            if (connection == videoConnection) {
                if videoWriter.status == .unknown {
                    if videoWriter.startWriting() {
                        print("video writing started")
                        self.sessionStartTime = presentationTimeStamp
                        self.videoThumbnailURL = self.saveImage(sampleBuffer: sampleBuffer)
                        videoWriter.startSession(atSourceTime: presentationTimeStamp)
                    }
                } else if videoWriter.status == .writing {
                    if let isReadyForMoreMediaData = videoInput?.isReadyForMoreMediaData,
                        isReadyForMoreMediaData {
                        if let appendInput = videoInput?.append(sampleBuffer),
                            !appendInput {
                            print("couldn't write video buffer")
                        }
                    }
                }
            } else if (connection == audioConnection) {
                if audioWriter.status == .unknown {
                    if audioWriter.startWriting() {
                        print("audio writing started")
                        audioWriter.startSession(atSourceTime: presentationTimeStamp)
                    }
                } else if audioWriter.status == .writing {
                    if let isReadyForMoreMediaData = micAudioInput?.isReadyForMoreMediaData,
                        isReadyForMoreMediaData {
                        if let appendInput = micAudioInput?.append(sampleBuffer),
                            !appendInput {
                            print("couldn't write mic audio buffer")
                        }
                    }
                }
            }
            break
        case .captured:
            captureState = .end
            DispatchQueue.main.async {
                if (self.currentQuestion >= self.questions.count - 1) {
                    self.currentState = .processing
                }
                
            }
            
            finishRecord { url, error in
                print(url)
                self.output.append(VideoInfo(questionId: self.questions[self.currentQuestion].id,
                                             videoDir: url?.path ?? "",
                                             thumbnailDir: self.videoThumbnailURL?.path))
                
                DispatchQueue.main.async {
                    if (self.currentQuestion < self.questions.count - 1) {
                        self.currentState = .prepare
                        self.currentQuestion += 1
                    } else {
                        print(self.recordOutputs)
                        self.currentState = .end
                    }
                }
                
            }
            break
        default:
            break
        }
    }
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        // If record done -> Stop handle captureOutput
        if(captureState == .end) {
            return
        }
        
        handleOutput(output, didOutput: sampleBuffer, from: connection)
        
        // Audio output don't have image source
        if (connection == audioConnection) {
            return
        }
        
        // When start record -> Stop detect face
        if(captureState != .idle) {
            return
        }
        
        var requestHandlerOptions: [VNImageOption: AnyObject] = [:]
        
        let cameraIntrinsicData = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil)
        if cameraIntrinsicData != nil {
            requestHandlerOptions[VNImageOption.cameraIntrinsics] = cameraIntrinsicData
        }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to obtain a CVPixelBuffer for the current output frame.")
            return
        }
        
        let exifOrientation = self.exifOrientationForCurrentDeviceOrientation()
        
        guard let requests = self.trackingRequests, !requests.isEmpty else {
            // No tracking object detected, so perform initial detection
            let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                                            orientation: exifOrientation,
                                                            options: requestHandlerOptions)
            
            do {
                guard let detectRequests = self.detectionRequests else {
                    return
                }
                try imageRequestHandler.perform(detectRequests)
            } catch let error as NSError {
                NSLog("Failed to perform FaceRectangleRequest: %@", error)
            }
            return
        }
        
        do {
            try self.sequenceRequestHandler.perform(requests,
                                                     on: pixelBuffer,
                                                     orientation: exifOrientation)
        } catch let error as NSError {
            NSLog("Failed to perform SequenceRequest: %@", error)
        }
        
        // Setup the next round of tracking.
        var newTrackingRequests = [VNTrackObjectRequest]()
        for trackingRequest in requests {
            
            guard let results = trackingRequest.results else {
                return
            }
            
            guard let observation = results[0] as? VNDetectedObjectObservation else {
                return
            }
            
            if !trackingRequest.isLastFrame {
                if observation.confidence > 0.3 {
                    trackingRequest.inputObservation = observation
                } else {
                    trackingRequest.isLastFrame = true
                }
                newTrackingRequests.append(trackingRequest)
            }
        }
        self.trackingRequests = newTrackingRequests
        
        if newTrackingRequests.isEmpty {
            // Nothing to track, so abort.
            return
        }
        
        // Perform face landmark tracking on detected faces.
        var faceLandmarkRequests = [VNDetectFaceLandmarksRequest]()
        
        // Perform landmark detection on tracked faces.
        for trackingRequest in newTrackingRequests {
            
            let faceLandmarksRequest = VNDetectFaceLandmarksRequest(completionHandler: { (request, error) in
                
                if error != nil {
                    print("FaceLandmarks error: \(String(describing: error)).")
                }
                
                guard let landmarksRequest = request as? VNDetectFaceLandmarksRequest,
                    let results = landmarksRequest.results as? [VNFaceObservation] else {
                        return
                }
                
                DispatchQueue.main.async {
                    self.drawFaceObservations(results)
                }
            })
            
            guard let trackingResults = trackingRequest.results else {
                return
            }
            
            guard let observation = trackingResults[0] as? VNDetectedObjectObservation else {
                return
            }
            let faceObservation = VNFaceObservation(boundingBox: observation.boundingBox)
            faceLandmarksRequest.inputFaceObservations = [faceObservation]
            
            // Continue to track detected facial landmarks.
            faceLandmarkRequests.append(faceLandmarksRequest)
            
            let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                                            orientation: exifOrientation,
                                                            options: requestHandlerOptions)
            
            do {
                try imageRequestHandler.perform(faceLandmarkRequests)
            } catch let error as NSError {
                NSLog("Failed to perform FaceLandmarkRequest: %@", error)
            }
        }
    }
    
    func finishRecord(completionHandler handler: @escaping (URL?, Error?) -> Void) {
        self.videoInput?.markAsFinished()
        self.videoWriter?.finishWriting {
            self.isVideoWritingFinished = true
            print("video writing finished")
            completion()
        }
        
        self.micAudioInput?.markAsFinished()
        self.audioWriter?.finishWriting {
            self.isAudioWritingFinished = true
            print("audio writing finished")
            completion()
        }
        
        func completion() {
            if self.isVideoWritingFinished && self.isAudioWritingFinished {
                self.isVideoWritingFinished = false
                self.isAudioWritingFinished = false
                self.isPaused = false
                self.videoInput = nil
                self.videoWriter = nil
                self.micAudioInput = nil
                self.audioWriter = nil
                merge()
            }
        }
        
        func merge() {
            let mergeComposition = AVMutableComposition()
            
            print("merge video with audio started")
            
            let videoAsset = AVAsset(url: self.videoOutputURL!)
            let videoTracks = videoAsset.tracks(withMediaType: .video)
            print(videoAsset.duration.seconds)
            let videoCompositionTrack = mergeComposition.addMutableTrack(withMediaType: .video,
                                                                         preferredTrackID: kCMPersistentTrackID_Invalid)
            do {
                try videoCompositionTrack?.insertTimeRange(CMTimeRange(start: CMTime.zero, end: videoAsset.duration),
                                                           of: videoTracks.first!,
                                                           at: CMTime.zero)
            } catch let error {
                removeURLsIfNeeded()
                handler(nil, error)
            }
            videoCompositionTrack?.preferredTransform = videoTracks.first!.preferredTransform
            
            let audioAsset = AVAsset(url: self.audioOutputURL!)
            let audioTracks = audioAsset.tracks(withMediaType: .audio)
            print(audioAsset.duration.seconds)
            for audioTrack in audioTracks {
                let audioCompositionTrack = mergeComposition.addMutableTrack(withMediaType: .audio,
                                                                             preferredTrackID: kCMPersistentTrackID_Invalid)
                do {
                    try audioCompositionTrack?.insertTimeRange(CMTimeRange(start: CMTime.zero, end: audioAsset.duration),
                                                               of: audioTrack,
                                                               at: CMTime.zero)
                } catch let error {
                    print(error)
                }
            }
            let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as NSString
            _filename = UUID().uuidString
            let outputURL = URL(fileURLWithPath: documentsPath.appendingPathComponent("\(_filename)_MergeVideo.mp4"))
            do {
                try FileManager.default.removeItem(at: outputURL)
            } catch {}

            let exportSession = AVAssetExportSession(asset: mergeComposition,
                                                     presetName: AVAssetExportPreset1280x720)
            exportSession?.outputFileType = .mp4
            exportSession?.shouldOptimizeForNetworkUse = true
            exportSession?.outputURL = outputURL
            exportSession?.fileLengthLimit = 1024 * 1024 * 20
            exportSession?.exportAsynchronously {
                if let error = exportSession?.error {
                    self.removeURLsIfNeeded()
                    handler(nil, error)
                } else {
                    self.removeURLsIfNeeded()
                    handler(exportSession?.outputURL, nil)
                }
            }
        }
    }
    
    func removeURLsIfNeeded() {
        do {
            try FileManager.default.removeItem(at: self.videoOutputURL!)
            try FileManager.default.removeItem(at: self.audioOutputURL!)
        } catch {}
    }
    
}
