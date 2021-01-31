//
//  VideoCapture.swift
//  RealTimeImageObject
//
//  Created by 石川裕太 on 2021/01/30.

import AVFoundation
import UIKit

//ビデオキャプチャデリゲート
public protocol VideoCaptureDelegate: class {
    //キャプチャ開始時に呼ばれる
    func videoCapture(_ capture: VideoCapture, didCaptureVideoFrame: CVPixelBuffer?, timestamp: CMTime)
}
    
//ビデオキャプチャ
public class VideoCapture: NSObject{
    //プレビュー表示用のレイヤ
    public var previewLayer: AVCaptureVideoPreviewLayer?
    public weak var delegate: VideoCaptureDelegate?
    public var fps = 15
    
    //1.AVCaptureSessionの設定 , データの流れを管理
    let captureSession = AVCaptureSession()
    let videoOutput = AVCaptureVideoDataOutput()
    // ラベルを指定してキューを生成
    let queue = DispatchQueue(label: "net.machinethink.camera-queue")
    
    var lastTimeStamp = CMTime()
    
    //セットアップ
    //sessionPreset : 出力の品質レベルまたはビットレートを示す定数値
    public func setUp(sessionPreset: AVCaptureSession.Preset = .medium,
                      completion: @escaping (Bool)->Void){
        //サブスレッドで実行(非同期)
        queue.async{
            let success = self.setUpCamera(sessionPreset: sessionPreset)
            ////メインスレッドで実行(非同期)
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }
    //カメラの設定を行う
    func setUpCamera(sessionPreset :AVCaptureSession.Preset)->Bool{
        captureSession.beginConfiguration()
        captureSession.sessionPreset = sessionPreset
        
        //2.AVCaptureDeviceクラスを用いたデバイスの設定
        //キャプチャセッションの入力を提供し、ハードウェア固有のキャプチャ機能の制御を提供
        guard let captureDevice = AVCaptureDevice.default(for: AVMediaType.video) else {
            print("Error: no video devices available")
            return false
        }
        //キャプチャーの入力データを受け付けるオブジェクト
        guard  let videoInput = try? AVCaptureDeviceInput(device: captureDevice) else {
            print("Error: could not create AVCaptureDeviceInput")
            return false
        }
        //AVCaptureDeviceにデータを渡す
        if captureSession.canAddInput(videoInput){
            captureSession.addInput(videoInput)
        }
        //4.カメラの取得している映像の表示,
        //プレビュー表示用のレイヤ
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspect
        previewLayer.connection?.videoOrientation = .portrait
        self.previewLayer = previewLayer
        
        let settings: [String : Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: NSNumber(value: kCVPixelFormatType_32BGRA),
        ]
        //出力データの設定
        videoOutput.videoSettings = settings
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        if captureSession.canAddOutput(videoOutput){
            captureSession.addOutput(videoOutput)
        }
        
        videoOutput.connection(with: AVMediaType.video)?.videoOrientation = .portrait
        captureSession.commitConfiguration()
        
        return true
    }
    public func start(){
        if !captureSession.isRunning{
            captureSession.startRunning()
        }
    }

    public func stop(){
        if captureSession.isRunning{
            captureSession.stopRunning()
        }
    }
    
}

extension VideoCapture: AVCaptureVideoDataOutputSampleBufferDelegate{
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let deltaTime = timestamp - lastTimeStamp
        if deltaTime >= CMTimeMake(value: 1, timescale: Int32(fps)){
            lastTimeStamp = timestamp
            let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
            delegate?.videoCapture(self, didCaptureVideoFrame: imageBuffer, timestamp: timestamp)
        }
    }
    public func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        print("dropped frame")
    }
}
