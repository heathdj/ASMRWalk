//
//  CameraPreview.swift
//  ASMR Walk
//

import AVFoundation
import SwiftUI
import UIKit

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let videoRotationAngle: CGFloat

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.configure(session: session, videoRotationAngle: videoRotationAngle)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.configure(session: session, videoRotationAngle: videoRotationAngle)
    }

    static func dismantleUIView(_ uiView: PreviewView, coordinator: ()) {
        // Detach before dealloc — AVCaptureSession asserts if the preview
        // layer is still connected when the session's ref count hits zero.
        uiView.previewLayer.session = nil
    }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    private var videoRotationAngle: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        previewLayer.videoGravity = .resizeAspectFill
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyVideoRotationAngle()
    }

    func configure(session: AVCaptureSession, videoRotationAngle: CGFloat) {
        previewLayer.session = session
        self.videoRotationAngle = videoRotationAngle
        applyVideoRotationAngle()

        Task { @MainActor in
            self.applyVideoRotationAngle()
        }
    }

    private func applyVideoRotationAngle() {
        guard let connection = previewLayer.connection,
              connection.isVideoRotationAngleSupported(videoRotationAngle) else {
            return
        }

        connection.videoRotationAngle = videoRotationAngle
    }
}
