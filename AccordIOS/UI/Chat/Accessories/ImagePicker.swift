//
 //  Image Picker.swift
 //  AccordIOS
 //
 //  Created by Serena on 31/03/2022.
 //

 import SwiftUI
 import PhotosUI

 struct ImagePicker: UIViewControllerRepresentable {

     @Binding var imageData: Data?
     @Binding var isPresented: Bool
     @Binding var imageName: URL?
     func makeCoordinator() -> Coordinator {
         Coordinator(self)
     }

     func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
     }


     typealias UIViewControllerType = PHPickerViewController

     func makeUIViewController(context: Context) -> PHPickerViewController {
         let controller = PHPickerViewController(configuration: .init())
         controller.delegate = context.coordinator
         return controller
     }

     class Coordinator: NSObject, PHPickerViewControllerDelegate {
         let parent: ImagePicker

         init(_ parent: ImagePicker) {
             self.parent = parent
         }

         func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
             guard let first = results.first else {
                 return
             }

             let provider = first.itemProvider
             if provider.canLoadObject(ofClass: UIImage.self) {
                 provider.loadObject(ofClass: UIImage.self) { img, _ in
                     self.parent.imageData = (img as? UIImage)?.pngData()
                     print("image data is nil: \(self.parent.imageData == nil)")
                     self.parent.imageName = URL(fileURLWithPath: "img-\(first.assetIdentifier ?? "").png")
                 }
             }
             self.parent.isPresented = false
         }
     }

 }
