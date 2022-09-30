//
//  CameraStreamView+Vision.swift
//  CameraModule
//
//  Created by Huy Nguyen on 25/08/2021.
//

import Foundation
import Vision
import AVKit

extension CameraStreamView {
    
    // MARK: - Performing Vision Requests
    
    /// - Tag: WriteCompletionHandler
    func prepareVisionRequest() {
        
        //self.trackingRequests = []
        var requests = [VNTrackObjectRequest]()
        
        let faceDetectionRequest = VNDetectFaceRectanglesRequest(completionHandler: { (request, error) in
            
            if error != nil {
                print("FaceDetection error: \(String(describing: error)).")
            }
            
            guard let faceDetectionRequest = request as? VNDetectFaceRectanglesRequest,
                let results = faceDetectionRequest.results as? [VNFaceObservation] else {
                    return
            }
            DispatchQueue.main.async {
                // Add the observations to the tracking list
                for observation in results {
                    let faceTrackingRequest = VNTrackObjectRequest(detectedObjectObservation: observation)
                    requests.append(faceTrackingRequest)
                }
                self.trackingRequests = requests
            }
        })
        
        // Start with detection.  Find face, then track it.
        self.detectionRequests = [faceDetectionRequest]
        
        self.sequenceRequestHandler = VNSequenceRequestHandler()
    }
    
    fileprivate func detectFace(faceObservation: VNFaceObservation) {
        let faceBoundingBoxOnScreen = previewLayer?.layerRectConverted(fromMetadataOutputRect: faceObservation.boundingBox)
        let recordFrame = imvFace.frame
        
        // Buffer for size
        let spaceInsideFree = CGFloat(50)
        
        let offset = isRectVisibleInView(rect: recordFrame, inRect: faceBoundingBoxOnScreen ?? CGRect())
        let detected = offset.x < spaceInsideFree && offset.y < spaceInsideFree
        
        if (detected != isDetectFace) {
            isDetectFace = detected
        }
    }
    
    /// - Tag: DrawPaths
    func drawFaceObservations(_ faceObservations: [VNFaceObservation]) {
        for faceObservation in faceObservations {
            self.detectFace(faceObservation: faceObservation)
        }
    }
    
    func isRectVisibleInView(rect: CGRect, inRect: CGRect) -> CGPoint {
        var offset = CGPoint()

        if inRect.contains(rect) {
            return CGPoint(x: 0, y: 0)
        }

        if rect.origin.x < inRect.origin.x {
            // It's out to the left
            offset.x = inRect.origin.x - rect.origin.x
        } else if (rect.origin.x + rect.width) > (inRect.origin.x + inRect.width) {
            // It's out to the right
            offset.x = (rect.origin.x + rect.width) - (inRect.origin.x + inRect.width)
        }

        if rect.origin.y < inRect.origin.y {
            // It's out to the top
            offset.y = inRect.origin.y - rect.origin.y
        } else if rect.origin.y + rect.height > inRect.origin.y + inRect.height {
            // It's out to the bottom
            offset.y = (rect.origin.y + rect.height) - inRect.origin.y + inRect.height
        }

        return offset
    }
    
}
