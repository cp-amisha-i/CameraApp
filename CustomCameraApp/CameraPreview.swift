//
//  CameraPreview.swift
//  CustomCameraApp
//
//  Created by Amisha Italiya on 03/10/23.
//

import SwiftUI
import Photos
import AVFoundation // To access the camera related swift classes and methods

struct CameraPreview: UIViewRepresentable { // for attaching AVCaptureVideoPreviewLayer to SwiftUI View
	
	let session: AVCaptureSession
	var onTap: (CGPoint) -> Void
	
	func makeUIView(context: Context) -> VideoPreviewView {
		let view = VideoPreviewView()
		view.backgroundColor = .black
		view.videoPreviewLayer.session = session
		view.videoPreviewLayer.videoGravity = .resizeAspect
		view.videoPreviewLayer.connection?.videoOrientation = .portrait
		
		// Add a tap gesture recognizer to the view
		let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleTapGesture(_:)))
		view.addGestureRecognizer(tapGesture)
		return view
	}
	
	public func updateUIView(_ uiView: VideoPreviewView, context: Context) { }
	
	class VideoPreviewView: UIView {
		override class var layerClass: AnyClass {
			 AVCaptureVideoPreviewLayer.self
		}
		
		var videoPreviewLayer: AVCaptureVideoPreviewLayer {
			return layer as! AVCaptureVideoPreviewLayer
		}
	}
	
	func makeCoordinator() -> Coordinator {
		Coordinator(self)
	}
	
	class Coordinator: NSObject {
		
		var parent: CameraPreview
		
		init(_ parent: CameraPreview) {
			self.parent = parent
		}
		
		@objc func handleTapGesture(_ sender: UITapGestureRecognizer) {
			let location = sender.location(in: sender.view)
			parent.onTap(location)
		}
	}
}

struct ImagePickerView: UIViewControllerRepresentable {
	@Binding var image: Image?
	@Environment(\.presentationMode) private var presentationMode
	var saveToGallery: Bool = false // Add a flag to control whether to save to gallery

	func makeUIViewController(context: UIViewControllerRepresentableContext<ImagePickerView>) -> UIImagePickerController {
		let imagePicker = UIImagePickerController()
		imagePicker.sourceType = .camera
		imagePicker.delegate = context.coordinator
		return imagePicker
	}

	func updateUIViewController(_ uiViewController: UIImagePickerController, context: UIViewControllerRepresentableContext<ImagePickerView>) {}

	func makeCoordinator() -> Coordinator {
		Coordinator(self)
	}

	class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
		var parent: ImagePickerView

		init(_ parent: ImagePickerView) {
			self.parent = parent
		}

		func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
			if let uiImage = info[.originalImage] as? UIImage {
				parent.image = Image(uiImage: uiImage)
				if parent.saveToGallery {
					saveImageToGallery(uiImage)
				}
			}
			parent.presentationMode.wrappedValue.dismiss()
		}

		func saveImageToGallery(_ image: UIImage) {
			PHPhotoLibrary.shared().performChanges {
				PHAssetChangeRequest.creationRequestForAsset(from: image)
			} completionHandler: { success, error in
				if success {
					print("Image saved to gallery.")
				} else if let error = error {
					print("Error saving image to gallery: \(error)")
				}
			}
		}
	}
}
