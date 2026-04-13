//
//  CameraPreview.swift
//  QuietPlace
//
//  Created by 이민혁 on 2/23/26.
//

import SwiftUI
import AVFoundation

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        if let connection = view.videoPreviewLayer.connection {
            applyPortraitOrientation(to: connection)
        }
        
        // ⚡️ 렌더링 최적화
        view.videoPreviewLayer.isOpaque = true
        
        debugPrint("🎥 CameraPreview created - session running: \(session.isRunning)")
        return view
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {
        // ⚡️ 세션이 다른 경우에만 재연결
        if uiView.videoPreviewLayer.session !== session {
            debugPrint("🎥 CameraPreview - RECONNECTING session")
            uiView.videoPreviewLayer.session = session
            
            // 연결 방향 재설정
            if let connection = uiView.videoPreviewLayer.connection {
                applyPortraitOrientation(to: connection)
            }
        }
        // 세션이 nil인 경우에만 재연결
        else if uiView.videoPreviewLayer.session == nil {
            debugPrint("🎥 CameraPreview - session nil, connecting")
            uiView.videoPreviewLayer.session = session
        }
    }
    
    static func dismantleUIView(_ uiView: PreviewView, coordinator: ()) {
        debugPrint("🎥 CameraPreview dismantled")
    }

    private func applyPortraitOrientation(to connection: AVCaptureConnection) {
        if #available(iOS 17.0, *) {
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
        } else if connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
    }
}

class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
}
