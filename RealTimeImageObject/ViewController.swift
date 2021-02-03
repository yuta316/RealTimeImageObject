//
//  ViewController.swift
//  RealTimeImageObject
//
//  Created by 石川裕太 on 2021/01/25.
//

import UIKit
import Vision
import AVFoundation
import CoreMedia
import VideoToolbox

class ViewController: UIViewController{

    @IBOutlet weak var CommentLabel: UILabel!
    //映像映し出す画面
    @IBOutlet weak var realTimeView: UIView!
    //UI
    @IBOutlet var imageView: UIImageView!
    
    let useVision = false
    //camera立ち上げのためのクラス
    var videoCapture:VideoCapture!

    var resizePixelBuffer:CVPixelBuffer?
    var framesDone = 0
    var frameCaptureStartTime = CACurrentMediaTime()
    //非同期処理
    var semaphore = DispatchSemaphore(value: 2)
    
    //model定義
    let yolov3 = YOLOV3()
    
    var inflightBuffer = 0
    //予測数(同時)
    static let maxInflightBuffers = 3
    var resizedPixelBuffers: [CVPixelBuffer?] = []
    var startTimes: [CFTimeInterval] = []
    var requests: [VNCoreMLRequest] = []
    
    let ciContext = CIContext()
    
    let drawBoundingBoxes = true
    var boundingBoxes = [BoundingBox]()
    var colors: [UIColor] = []
    
    
    //ビューロード時に呼ばれる
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpBoundingBoxes()
        //画像処理用のAPI
        setUpCoreImage()
        //
        setUpVison()
        //カメラ立ち上げ
        setUpCamera()
        frameCaptureStartTime = CACurrentMediaTime()
        }
     
    //カメラ立ち上げ
    func setUpCamera(){
        //クラスのインスタンス化
        videoCapture = VideoCapture()
        //デリゲート先を自身に設定
        videoCapture.delegate = self
        videoCapture.fps = 100
        videoCapture.setUp(sessionPreset: AVCaptureSession.Preset.inputPriority){ success in
            if success {
                if let previewLayer = self.videoCapture.previewLayer{
                    self.realTimeView.layer.addSublayer(previewLayer)
                    self.resizePreviewLayer()
                }
                self.videoCapture.start()
            }
        }
    }
    
    //画像処理用のAPI ビクセルバッファの統一
    func setUpCoreImage(){
        for _ in 0..<ViewController.maxInflightBuffers {
            var resizedPixelBuffer: CVPixelBuffer?
            let status = CVPixelBufferCreate(nil, YOLOV3.inputWidth, YOLOV3.inputHeight, kCVPixelFormatType_32BGRA, nil, &resizePixelBuffer)
            //成功を返さなければ
            if status != kCVReturnSuccess {
                print("Error: coludnt create resized pixel buffer", status)
            }
            resizedPixelBuffers.append(resizePixelBuffer)
        }
    }
    
    //
    func setUpVison(){
        //mlmodel読み込み
        guard let visionModel = try? VNCoreMLModel(for: yolov3.model.model) else {
            print("Error: couldnt create Vision Model")
            return
        }
        for _ in 0..<ViewController.maxInflightBuffers{
            let request = VNCoreMLRequest(model: visionModel, completionHandler: visionRequestDidComplete)
            request.imageCropAndScaleOption = .scaleFill
            requests.append(request)
        }
    }
    func visionRequestDidComplete(request: VNRequest, error: Error?){
        if let observations = request.results as? [VNCoreMLFeatureValueObservation],
           let features = observations.first?.featureValue.multiArrayValue{
        
            let boundingBoxes = yolov3.computeBoundingBoxes(features: [features,features, features])
            let elapsed = CACurrentMediaTime() - startTimes.remove(at: 0)
            showOnMainThread(boundingBoxes, elapsed)
            CommentLabel.text = String(elapsed)
        } else {
            print("BOUGUS")
        }
        self.semaphore.signal()
    }
    
    func setUpBoundingBoxes() {
      for _ in 0..<YOLOV3.maxBoundingBoxes {
        boundingBoxes.append(BoundingBox())
      }

      // Make colors for the bounding boxes. There is one color for each class,
      // 80 classes in total.
      for r: CGFloat in [0.2, 0.4, 0.6, 0.8, 1.0] {
        for g: CGFloat in [0.3, 0.7, 0.6, 0.8] {
          for b: CGFloat in [0.4, 0.8, 0.6, 1.0] {
            let color = UIColor(red: r, green: g, blue: b, alpha: 1)
            colors.append(color)
          }
        }
      }
    }
    
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        resizePreviewLayer()
    }
    override var preferredStatusBarStyle: UIStatusBarStyle{
        return .lightContent
    }
    func resizePreviewLayer(){
        videoCapture.previewLayer?.frame = realTimeView.bounds
    }
    
    //以下予測
    func predict(image: UIImage){
        if let pixelBuffer = image.pixelBuffer(width: YOLOV3.inputWidth, height: YOLOV3.inputHeight){
            predict(pixelBuffer: pixelBuffer, inflightIndex: 0)
        }
    }
    func predict(pixelBuffer: CVPixelBuffer, inflightIndex: Int){
        let startTime = CACurrentMediaTime()
        
        //リサイズ->416x416
        if let resizedPixelBuffer = resizedPixelBuffers[inflightIndex]{
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let sx = CGFloat(YOLOV3.inputWidth) / CGFloat(CVPixelBufferGetWidth(pixelBuffer))
            let sy = CGFloat(YOLOV3.inputHeight) / CGFloat(CVPixelBufferGetHeight(pixelBuffer))
            let scaleTransform = CGAffineTransform(scaleX: sx, y: sy)
            let scaledImage = ciImage.transformed(by: scaleTransform)
            ciContext.render(scaledImage, to: resizedPixelBuffer)
            
            //モデルに入力
            if let boundingBoxes = try? yolov3.predict(image: resizedPixelBuffer){
                let elapsed = CACurrentMediaTime() - startTime
                showOnMainThread(boundingBoxes, elapsed)
            } else {
                print("BOGUS")
            }
        }
        self.semaphore.signal()
    }
    
    //画面に写す
    func showOnMainThread(_ boundingBoxes: [YOLOV3.Prediction], _ elapsed: CFTimeInterval){
        if drawBoundingBoxes {
            DispatchQueue.main.async {
                self.show(predictions: boundingBoxes)
                let fps = self.measureFPS()
                //self.CommentLabel.text="s"
                self.CommentLabel.text = String(format: "fps:%f, elapsed:%f",fps , elapsed)
            }
        }
    }
    func show(predictions: [YOLOV3.Prediction]){
        for i in 0..<boundingBoxes.count {
            if i < predictions.count{
                let prediction = predictions[i]
                
                let width = view.bounds.width
                let height = width * 16 / 9
                let scaleX = width / CGFloat(YOLOV3.inputWidth)
                let scaleY = height / CGFloat(YOLOV3.inputHeight)
                let top = (view.bounds.height - height) / 2
                
                //スケーリング
                var rect = prediction.rect
                rect.origin.x *= scaleX
                rect.origin.y *= scaleY
                rect.origin.y += top
                rect.size.width *= scaleX
                rect.size.height *= scaleY

                // Show the bounding box.
                let label = String(format: "%@ %.1f", labels[prediction.classIndex], prediction.score * 100)
                let color = colors[prediction.classIndex]
                boundingBoxes[i].show(frame: rect, label: label, color: color)
              } else {
                boundingBoxes[i].hide()
            }
        }
        
    }
    func measureFPS()->Double{
        framesDone += 1
        let frameCapturingElapsed = CACurrentMediaTime() - frameCaptureStartTime
        //成功割合
        let cuurentFPSDelivered = Double(framesDone) / frameCapturingElapsed
        if frameCapturingElapsed > 1 {
            framesDone = 0
            frameCaptureStartTime = CACurrentMediaTime()
        }
        return cuurentFPSDelivered
    }

}
//View Contoroller の拡張
extension ViewController: VideoCaptureDelegate{
    
    func videoCapture(_ caputure: VideoCapture, didCaptureVideoFrame pixelBuffer: CVPixelBuffer?, timestamp: CMTime) {
        
        if let pixelBuffer = pixelBuffer{
            semaphore.wait()
            
            let inflightIndex = inflightBuffer
            inflightBuffer += 1
            if inflightBuffer >= ViewController.maxInflightBuffers{
                inflightBuffer = 0
            }
            if useVision {
                self.predict(pixelBuffer: pixelBuffer, inflightIndex: inflightBuffer)
            } else {
                self.predict(pixelBuffer: pixelBuffer, inflightIndex: inflightIndex)
            }
        }
    }
}
