//
//  VideoCaptureView.swift
//  RealTimeImageObject
//  リアルタイムに映像を映すためのクラス
//  Created by 石川裕太 on 2021/01/25.
//

import Foundation
import AVFoundation

//プロコトル宣言
protocol VideoCaptureDelegate {
    func videoCapture(capututure:VideoCaptureView,didCaptureVideoFrame: CVPixelBuffer?, timestamp: CMTime)
}

public class VideoCaptureView: NSObject{
    
    //ios/maxOSのOSメディア装置を扱うクラス, 入力から出力までデータの流れを管理.
    let captureScreen = AVCaptureSession()
    //キャプチャされたビデオを表示, previw レイヤを作成
    public var previewLayer: AVCaptureVideoPreviewLayer?
    //デリゲートのインスタンス化
    var delegate:VideoCaptureDelegate?
    
    public var fps = 15
    
    func setUpCamera(){
        
    }
}
