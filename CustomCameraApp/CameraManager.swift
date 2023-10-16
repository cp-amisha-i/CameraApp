//
//  CameraManager.swift
//  CustomCameraApp
//
//  Created by Amisha Italiya on 03/10/23.
//

import Photos
import SwiftUI
import AVFoundation

enum Status {
	case configured
	case unconfigured
	case unauthorized
	case failed
}

class CameraManager: ObservableObject {
	
	@Published var capturedImage: UIImage? = nil
	@Published private var flashMode: AVCaptureDevice.FlashMode = .off
	
	@Published var status = Status.unconfigured
	@Published var shouldShowAlertView = false
	
	let session = AVCaptureSession()
	let photoOutput = AVCapturePhotoOutput()
	var videoDeviceInput: AVCaptureDeviceInput?
	var position: AVCaptureDevice.Position = .back
	
	private var cameraDelegate: CameraDelegate?
	var alertError: AlertError = AlertError()
	
	// Communicate with the session and other session objects with this queue.
	private let sessionQueue = DispatchQueue(label: "com.demo.sessionQueue")
	
	func configureCaptureSession() {
		sessionQueue.async { [weak self] in
			guard let self, self.status == .unconfigured else { return }
			
			self.session.beginConfiguration()
			self.session.sessionPreset = .photo
			
			// Add video input.
			self.setupVideoInput()
			
			// Add the photo output.
			self.setupPhotoOutput()
			
			self.session.commitConfiguration()
			self.startCapturing()
		}
	}
	
	private func setupVideoInput() {
		do {
			let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
			guard let camera else {
				print("CameraManager: Video device is unavailable.")
				status = .unconfigured
				session.commitConfiguration()
				return
			}
			
			let videoInput = try AVCaptureDeviceInput(device: camera)
			
			if session.canAddInput(videoInput) {
				session.addInput(videoInput)
				videoDeviceInput = videoInput
				status = .configured
			} else {
				print("CameraManager: Couldn't add video device input to the session.")
				status = .unconfigured
				session.commitConfiguration()
				return
			}
		} catch {
			print("CameraManager: Couldn't create video device input: \(error)")
			status = .failed
			session.commitConfiguration()
			return
		}
	}
	
	private func setupPhotoOutput() {
		if session.canAddOutput(photoOutput) {
			session.addOutput(photoOutput)
			photoOutput.isHighResolutionCaptureEnabled = true
			photoOutput.maxPhotoQualityPrioritization = .quality // work for ios 15.6 and the older versions
			// photoOutput.maxPhotoDimensions = .init(width: 4032, height: 3024) // for ios 16.0*
			status = .configured
		} else {
			print("CameraManager: Could not add photo output to the session")
			status = .failed
			session.commitConfiguration()
			return
		}
	}
	
	private func startCapturing() {
		if status == .configured {
			self.session.startRunning()
		} else if status == .unconfigured || status == .unauthorized {
			DispatchQueue.main.async {
				self.alertError = AlertError(title: "Camera Error", message: "Camera configuration failed. Either your device camera is not available or its missing permissions", primaryButtonTitle: "ok", secondaryButtonTitle: nil, primaryAction: nil, secondaryAction: nil)
				self.shouldShowAlertView = true
			}
		}
	}
	
	func stopCapturing() {
		sessionQueue.async { [weak self] in
			guard let self else { return }
			if self.session.isRunning {
				self.session.stopRunning()
			}
		}
	}
	
	func toggleTorch(tourchIsOn: Bool) {
		guard let device = AVCaptureDevice.default(for: .video) else { return }
		if device.hasTorch {
			do {
				try device.lockForConfiguration()
				flashMode = tourchIsOn ? .on : .off
				if tourchIsOn {
					try device.setTorchModeOn(level: 1.0)
				} else {
					device.torchMode = .off
				}
				device.unlockForConfiguration()
			} catch {
				print("Failed to set torch mode: \(error).")
			}
		} else {
			print("Torch not available for this device.")
		}
	}
	
	func setFocusOnTap(devicePoint: CGPoint) {
		guard let cameraDevice = self.videoDeviceInput?.device else { return }
		do {
			try cameraDevice.lockForConfiguration()
			if cameraDevice.isFocusModeSupported(.autoFocus) {
				cameraDevice.focusMode = .autoFocus
				cameraDevice.focusPointOfInterest = devicePoint
			}
			cameraDevice.exposurePointOfInterest = devicePoint
			cameraDevice.exposureMode = .autoExpose
			cameraDevice.isSubjectAreaChangeMonitoringEnabled = true
			cameraDevice.unlockForConfiguration()
		} catch {
			print("Failed to configure focus: \(error)")
		}
	}
	
	func setZoomScale(factor: CGFloat){
		guard let device = self.videoDeviceInput?.device else { return }
		do {
			try device.lockForConfiguration()
			device.videoZoomFactor = max(device.minAvailableVideoZoomFactor, max(factor, device.minAvailableVideoZoomFactor))
			device.unlockForConfiguration()
		} catch {
			print(error.localizedDescription)
		}
	}
	
	func switchCamera() {
		guard let videoDeviceInput else { return }
		
		// Remove the current video input
		session.removeInput(videoDeviceInput)
		
		// Add the new video input
		setupVideoInput()
	}
	
	func captureImage() {
		sessionQueue.async { [weak self] in
			guard let self else { return }
			
			var photoSettings = AVCapturePhotoSettings()
			
			// Capture HEIC photos when supported
			if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
				photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
			}
			
			// Sets the flash option for the capture
			if self.videoDeviceInput!.device.isFlashAvailable {
				photoSettings.flashMode = self.flashMode
			}
			
			photoSettings.isHighResolutionPhotoEnabled = true
			
			// Sets the preview thumbnail pixel format
			if let previewPhotoPixelFormatType = photoSettings.availablePreviewPhotoPixelFormatTypes.first {
				photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPhotoPixelFormatType]
			}
			photoSettings.photoQualityPrioritization = .quality
			
			if let videoConnection = photoOutput.connection(with: .video), videoConnection.isVideoOrientationSupported {
				videoConnection.videoOrientation = .portrait
			}
			
			cameraDelegate = CameraDelegate { [weak self] image in
				self?.capturedImage = image
			}
			
			if let cameraDelegate {
				self.photoOutput.capturePhoto(with: photoSettings, delegate: cameraDelegate)
			}
		}
	}
}

class CameraDelegate: NSObject, AVCapturePhotoCaptureDelegate {
	
	private let completion: (UIImage?) -> Void
	
	init(completion: @escaping (UIImage?) -> Void) {
		self.completion = completion
	}
	
	func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
		if let error {
			print("CameraManager: Error while capturing photo: \(error)")
			completion(nil)
			return
		}
		
		if let imageData = photo.fileDataRepresentation(), let capturedImage = UIImage(data: imageData) {
			saveImageToGallery(capturedImage)
			completion(capturedImage)
		} else {
			print("CameraManager: Image not fetched.")
		}
	}
	
	func saveImageToGallery(_ image: UIImage) {
		PHPhotoLibrary.shared().performChanges {
			PHAssetChangeRequest.creationRequestForAsset(from: image)
		} completionHandler: { success, error in
			if success {
				print("Image saved to gallery.")
			} else if let error {
				print("Error saving image to gallery: \(error)")
			}
		}
	}
}

public struct AlertError {
	public var title: String = ""
	public var message: String = ""
	public var primaryButtonTitle = "Accept"
	public var secondaryButtonTitle: String?
	public var primaryAction: (() -> ())?
	public var secondaryAction: (() -> ())?
	
	public init(title: String = "", message: String = "", primaryButtonTitle: String = "Accept", secondaryButtonTitle: String? = nil, primaryAction: (() -> ())? = nil, secondaryAction: (() -> ())? = nil) {
		self.title = title
		self.message = message
		self.primaryAction = primaryAction
		self.primaryButtonTitle = primaryButtonTitle
		self.secondaryAction = secondaryAction
	}
}
