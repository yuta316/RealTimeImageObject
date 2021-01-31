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

    //real time 映像
    @IBOutlet weak var realTimeView: UIView!
    //UI
    @IBOutlet var imageView: UIImageView!
    //camera立ち上げのためのクラス
    var videoCapture:VideoCapture!

    var resizePixelBuffer:CVPixelBuffer?
    var framesDone = 0
    var frameCaptureStartTime = CACurrentMediaTime()
    //非同期処理
    var semaphore = DispatchSemaphore(value: 2)
    
        //viewが表示される直前に呼ばれる
    //呼ばれたタイミングで既に画面に描画されていることに注意
   // override func viewWillAppear(_ animated: Bool) {
    //    super.viewwillApper(animated)
  //      self.videoCapture.start()
  //  }
    //ビューロード時に呼ばれる
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //カメラ立ち上げ
        setUpCamera()
        //キャプチャ開始
        //startCapture()
        frameCaptureStartTime = CACurrentMediaTime()
    }
     
    //カメラ立ち上げ
    func setUpCamera(){
        //クラスのインスタンス化
        videoCapture = VideoCapture()
        //デリゲート先を自身に設定
        videoCapture.delegate = self
        videoCapture.fps = 50
        videoCapture.setUp(sessionPreset: AVCaptureSession.Preset.vga640x480){ success in
            if success {
                if let previewLayer = self.videoCapture.previewLayer{
                    self.realTimeView.layer.addSublayer(previewLayer)
                    self.resizePreviewLayer()
                }
                self.videoCapture.start()
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

}
//View Contoroller の拡張
extension ViewController: VideoCaptureDelegate{
    
    func videoCapture(_ caputure: VideoCapture, didCaptureVideoFrame pixelBuffer: CVPixelBuffer?, timestamp: CMTime) {
        semaphore.wait()
    }
    
        //if let pixelBuffer = pixelBuffer{
        //    DispatchQueue.global().async {
        
        
    
}


