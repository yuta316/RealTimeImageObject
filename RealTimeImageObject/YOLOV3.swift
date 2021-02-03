//
//  YOLOV3.swift
//  RealTimeImageObject
//
//  Created by 石川裕太 on 2021/02/02.
//

import Foundation
import UIKit
import CoreML

class YOLOV3 {
    public static let inputWidth = 416
    public static let inputHeight = 416
    public static let maxBoundingBoxes = 10
    
    let confidenceThreshold: Float = 0.3
    let iouThreshold: Float = 0.5
    
    struct Prediction {
        let classIndex: Int
        let score: Float
        let rect: CGRect
    }
    
    let model = pyyolov3()
    
    public init(){}
    
    public func predict(image: CVPixelBuffer)-> [Prediction]{
        if let output = try? model.prediction(input_1: image){
            return computeBoundingBoxes(features: [output.output1,output.output2,output.output3])
        } else{
            return []
        }
    }
    
    //出力をBoxに変形
    public func computeBoundingBoxes(features: [MLMultiArray])->[Prediction]{
        var predictions = [Prediction]()
        
        let output1 = features[0]
        let output2 = features[1]
        let output3 = features[2]
        
        
        var featurePointer = UnsafeMutablePointer<Double>(OpaquePointer(output1.dataPointer))
        var channelStride = output1.strides[0].intValue
        var yStride = output1.strides[1].intValue
        var xStride = output1.strides[2].intValue
        
        func offset(_ channel: Int, _ x: Int, _ y: Int)->Int{
            return channel*channelStride + x*xStride + y*yStride
        }
        
        let output = [output1,output2,output3]
        let gridHeight = [13, 26, 52]
        let gridWidth = [13, 26, 52]
        let boxesPerCell = 3
        let numClasses = 80
        let blockSize: Float = 32
        
        for i in 0..<3 {
            featurePointer = UnsafeMutablePointer<Double>(OpaquePointer(output[i].dataPointer))
            channelStride = output[i].strides[0].intValue
            yStride = output[i].strides[1].intValue
            xStride = output[i].strides[2].intValue
            
            for cy in 0..<gridHeight[i]{
                for cx in 0..<gridWidth[i]{
                    for b in 0..<boxesPerCell{
                        let channel = b*(numClasses + 5)
                        print(cy,cx,b)
                        print(offset(channel, cx, cy))
                        let tx = Float(featurePointer[offset(channel, cx, cy)])
                        let ty = Float(featurePointer[offset(channel+1, cx, cy)])
                        let tw = Float(featurePointer[offset(channel+2, cx, cy)])
                        let th = Float(featurePointer[offset(channel+3, cx, cy)])
                        let tc = Float(featurePointer[offset(channel+4, cx, cy)])
                        print(cy,cx,b)
                        let scale = powf(2.0, Float(i))
                        let x = (Float(cx) * blockSize + sigmoid(tx))/scale
                        let y = (Float(cy) * blockSize + sigmoid(ty))/scale
                        
                        let w = exp(tw) * anchors[i][2*b]
                        let h = exp(th) * anchors[i][2*b+1]
                        let confidence = sigmoid(tc)
                        
                        var classes = [Float](repeating: 0, count: numClasses)
                        for c in 0..<numClasses{
                            classes[c] = Float(featurePointer[offset(channel+5, cx,cy)])
                        }
                        classes = softmax(classes)
                        let (detectedClass, bestClassScore) = classes.argmax()
                        let confidenceClass = bestClassScore * confidence
                        
                        if confidenceClass > confidenceThreshold {
                            let rect = CGRect(x: CGFloat(x-w/2), y: CGFloat(y-h/2), width: CGFloat(w), height: CGFloat(h))
                            let prediction = Prediction(classIndex: detectedClass,
                                                        score: confidenceClass,
                                                        rect: rect)
                            predictions.append(prediction)
                        }
                    }
                }
            }
        }
        
    

        return nonMaxSuppression(boxes: predictions, limit: YOLOV3.maxBoundingBoxes, threshold: iouThreshold)
    }
}



