//
//  CameraViewModel.swift
//  CustomCameraApp
//
//  Created by Amisha Italiya on 04/10/23.
//

import SwiftUI
import Combine
import Photos
import AVFoundation

class CameraViewModel: ObservableObject {
	
	@ObservedObject var cameraManager = CameraManager()
	
	@Published var isFlashOn = false
	@Published var showAlertError = false
	@Published var showSettingAlert = false
	@Published var isPermissionGranted: Bool = false
	
	@Published var capturedImage: UIImage?
	
	var alertError: AlertError!
	var session: AVCaptureSession = .init()
	private var cancelables = Set<AnyCancellable>()
	
	init() {
		session = cameraManager.session
	}
	
	deinit {
		cameraManager.stopCapturing()
	}
	
	func setupBindings() {
		cameraManager.$shouldShowAlertView.sink { [weak self] value in
			self?.alertError = self?.cameraManager.alertError
			self?.showAlertError = value
		}
		.store(in: &cancelables)
		
		cameraManager.$capturedImage.sink { [weak self] image in
			self?.capturedImage = image
		}.store(in: &cancelables)
	}
	
	func requestCameraPermission() {
		AVCaptureDevice.requestAccess(for: .video) { [weak self] isGranted in
			guard let self else { return }
			if isGranted {
				self.configureCamera()
				DispatchQueue.main.async {
					self.isPermissionGranted = true
				}
			}
		}
	}
	
	func configureCamera() {
		checkForDevicePermission()
		cameraManager.configureCaptureSession()
	}
	
	func checkForDevicePermission() {
		let videoStatus = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
		
		DispatchQueue.main.async { [weak self] in
			if videoStatus == .authorized {
				self?.isPermissionGranted = true
			} else if videoStatus == .notDetermined {
				AVCaptureDevice.requestAccess(for: .video, completionHandler: { _ in })
			} else if videoStatus == .denied {
				self?.isPermissionGranted = false
				self?.showSettingAlert = true
			}
		}
	}
	
	func switchCamera() {
		cameraManager.position = cameraManager.position == .back ? .front : .back
		cameraManager.switchCamera()
	}
	
	func switchFlash() {
		isFlashOn.toggle()
		cameraManager.toggleTorch(tourchIsOn: isFlashOn)
	}
	
	func zoom(with factor: CGFloat) {
		cameraManager.setZoomScale(factor: factor)
	}
	
	func setFocus(point: CGPoint) {
		cameraManager.setFocusOnTap(devicePoint: point)
	}
	
	func captureImage() {
		requestGalleryPermission()
		let permission = checkGalleryPermissionStatus()
		if permission.rawValue != 2 {
			cameraManager.captureImage()
		}
	}
	
	func requestGalleryPermission() {
		PHPhotoLibrary.requestAuthorization { status in
			switch status {
			case .authorized:
				break
			case .denied:
				self.showSettingAlert = true
			default:
				break
			}
		}
	}
	
	func checkGalleryPermissionStatus() -> PHAuthorizationStatus {
		return PHPhotoLibrary.authorizationStatus()
	}
}
