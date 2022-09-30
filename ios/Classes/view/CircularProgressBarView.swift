//
//  CircularProgressBarView.swift
//  Runner
//
//  Created by TDA Developer on 20/08/2021.
//

import UIKit

class CircularProgressBarView: UIView {
    var countType: UserState = .prepare  {
        didSet {
            if countType == .prepare {
                startPoint = CGFloat(3 * Double.pi / 2 )
                endPoint = CGFloat(-Double.pi / 2)
                circleColor = UIColor.clear.cgColor
                progressColor = UIColor.white.cgColor
            } else {
                startPoint = CGFloat(-Double.pi / 2)
                endPoint = CGFloat(3 * Double.pi / 2)
                circleColor = UIColor.white.cgColor
                progressColor = UIColor.systemPink.cgColor
            }
            createCircularPath()
        }
    }
    
    private var circleLayer = CAShapeLayer()
    private var progressLayer = CAShapeLayer()
    
    private var startPoint: CGFloat = 0.0
    private var endPoint: CGFloat = 0.0
    
    private var circleColor = UIColor.clear.cgColor
    private var progressColor = UIColor.white.cgColor
    private let lineWidth: CGFloat  = 5.0
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    func createCircularPath() {
        // created circularPath for circleLayer and progressLayer
        let circularPath = UIBezierPath(arcCenter: CGPoint(x: frame.size.width / 2.0, y: frame.size.height / 2.0), radius: frame.size.width / 2.0, startAngle: startPoint, endAngle: endPoint, clockwise: countType != .prepare )
        // circleLayer path defined to circularPath
        circleLayer.path = circularPath.cgPath
        // ui edits
        circleLayer.fillColor = UIColor.clear.cgColor
        circleLayer.lineCap = .round
        circleLayer.lineWidth = lineWidth
        circleLayer.strokeEnd = 1.0
        circleLayer.strokeColor = circleColor
        // added circleLayer to layer
        layer.addSublayer(circleLayer)
        // progressLayer path defined to circularPath
        progressLayer.path = circularPath.cgPath
        // ui edits
        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.lineCap = .round
        progressLayer.lineWidth = lineWidth
        progressLayer.strokeEnd = 0
        progressLayer.strokeColor = progressColor
        // added progressLayer to layer
        layer.addSublayer(progressLayer)
    }
    
    func progressAnimation(duration: TimeInterval) {
        // created circularProgressAnimation with keyPath
        let circularProgressAnimation = CABasicAnimation(keyPath: "strokeEnd")
        // set the end time
        circularProgressAnimation.duration = duration
        circularProgressAnimation.toValue = 1.0
        circularProgressAnimation.fillMode = .forwards
        circularProgressAnimation.isRemovedOnCompletion = false
        progressLayer.add(circularProgressAnimation, forKey: "progressAnim")
    }
    
    func resetCircularProgress() {
       progressLayer = CAShapeLayer()
        circleLayer = CAShapeLayer()
        self.createCircularPath()

    }
    
}
