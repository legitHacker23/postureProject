//
//  BodyLandmarks.swift
//  PostureProject
//
//  Created by Noah M on 2/27/25.
//

import AVFoundation
import Foundation
import Vision
import SwiftUI

class BodyLandmarks: ObservableObject {
    @Published var landmarks: [CGPoint]? = nil
    private let bodyPoseRequest = VNDetectHumanBodyPoseRequest()
    @Published var postureEval: Double?

    // Tuning knobs for leniency.
    // `goodScoreThreshold`: the regressor's raw output above which a single
    // frame is considered good posture. Lower = more forgiving per frame.
    // `rollingWindowSize`: number of recent frames used for majority vote
    // (~0.5s at 30fps). Higher = smoother but slower to react.
    // `goodMajorityFraction`: share of the rolling window that must be good
    // to surface "good" in the UI. 0.5 = bare majority.
    private let goodScoreThreshold: Double = 0.5
    private let rollingWindowSize: Int = 15
    private let goodMajorityFraction: Double = 0.5

    private var recentFrameIsGood: [Bool] = []
    
    //create a dictionary to grab convert joint locations to compatible CGPoint format
    //to calc necessary values for posture data
    //VNHumanBodyPoseObservation.JointName is the type of key
    // values are of type CGPoint
    //empty dictionary writting as "[:]"
    var landmarkDict: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
    
    //create instance to access CSVManager
//    private let csvManager = CSVManager()
    
    let postureModel = try? posture(configuration: .init())

    func processFrame(_ cgImage: CGImage) {
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do{
            try requestHandler.perform([bodyPoseRequest])
            if let results = bodyPoseRequest.results {
                handlePoseObservations(results)
            }
        } catch {
            print("Error processing frame: \(error)")
        }
    }
    
    private func handlePoseObservations(_ observations: [VNHumanBodyPoseObservation]) {
        guard let observation = observations.first else { return }
        do {
            
            //face landmarks(eyes, nose, chin)
            let facePoints = try observation.recognizedPoints(.face)
            
            //upper body landmarks (neck & shoulders)
            let upperBodyPoints = try observation.recognizedPoints(.torso)
            
            //Define the target joints
            let targetJoints: [VNHumanBodyPoseObservation.JointName] = [
                .leftEye,
                .nose,
                .rightEye,
                .neck,
                .rightShoulder,
                .leftShoulder
            ]
            let points = targetJoints.compactMap { key -> (VNHumanBodyPoseObservation.JointName, CGPoint)? in
                if let point = facePoints[key], point.confidence > 0.5 {
//                    print("\(key) with confidence: \(point.confidence)")
                    landmarkDict[key] = CGPoint(x: point.location.x, y: 1 - point.location.y)
                    return (key, CGPoint(x: point.location.x, y: 1 - point.location.y))
                }
                if let point = upperBodyPoints[key], point.confidence > 0.5 {
//                    print("\(key) with confidence: \(point.confidence)")
                    landmarkDict[key] = CGPoint(x: point.location.x, y: 1 - point.location.y)
                    return (key, CGPoint(x: point.location.x, y: 1 - point.location.y))
                }
                return nil
            }
            
            DispatchQueue.main.async {
                self.landmarks = points.map { $0.1 }
                self.postureCalculations()
            }
            
        } catch {
            print("Error handling pose observations: \(error)")
        }
    }
    
    private func postureCalculations() {
        //calculations for posture
        if let leftEye = landmarkDict[.leftEye],
           let nose = landmarkDict[.nose],
           let rightEye = landmarkDict[.rightEye],
           let neck = landmarkDict[.neck],
           let rightShoulder = landmarkDict[.rightShoulder],
           let leftShoulder = landmarkDict[.leftShoulder] {
            
            let headTilt = angle(p1: leftEye, p2: rightEye)
            let headLean = headLean(p1: leftShoulder, p2: nose, p3: rightShoulder)
            let headRotation = angle(p1: neck, p2: nose)
            //print("head rotate displacement: \(headRotation)")
            print("Head Tilt: \(headTilt), Head Lean: \(headLean), Head Rotation: \(headRotation)")
//            print("CSV File path: \(csvManager.getFilePath())")
     
            //save posture data to CSV
//            csvManager.writeToCSV(headTilt: headTilt, headLean: headLean, headRotation: headRotation, shoulderTilt: shoulderTilt)
            
            //input posture calculations to the model
            let output = try? postureModel?.prediction(Head_Tilt: headTilt, Head_Lean: headLean, Head_Rotation: headRotation)

            // Model output is a continuous leaf-average in [0, 1]. Threshold
            // below 1.0 so we don't require a "perfectly pure good" leaf.
            let rawScore = output?.Posture ?? 0.0
            let frameGood = rawScore >= goodScoreThreshold

            // Rolling-window majority vote: smooths out per-frame noise so a
            // single misclassification doesn't flip the UI state.
            recentFrameIsGood.append(frameGood)
            if recentFrameIsGood.count > rollingWindowSize {
                recentFrameIsGood.removeFirst()
            }
            let goodCount = recentFrameIsGood.filter { $0 }.count
            let goodShare = Double(goodCount) / Double(recentFrameIsGood.count)
            let smoothedGood = goodShare >= goodMajorityFraction

            postureEval = smoothedGood ? 1.0 : 0.0

            print("raw=\(rawScore) frameGood=\(frameGood) smoothed=\(smoothedGood)")

        } else {
            print("Missing landmarks, skipping calculation")
        }
    }
    
    
    //head tilt && shoulder tilt calculation
    private func angle(p1: CGPoint, p2: CGPoint) -> Double {
        let deltaY = p2.y - p1.y
        let deltaX = p2.x - p1.x
        return atan2(deltaY, deltaX) * (180.0 / .pi)
    }
    
    
    //headLean calculation
    private func headLean(p1: CGPoint, p2: CGPoint, p3: CGPoint) -> Double {
        let angleBA = atan2(p1.y - p2.y, p1.x - p2.x) * (180 / .pi)
        let angleBC = atan2(p3.y - p2.y, p3.x - p2.x) * (180 / .pi)
        
        var leanAngle = angleBC - angleBA
        
        if leanAngle < 0 {
            leanAngle += 360
        }
        if leanAngle > 180 {
             leanAngle = 360 - leanAngle
        }
        
        return leanAngle
    }
}


