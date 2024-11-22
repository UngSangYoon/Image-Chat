//
//  ImagePicker.swift
//  llava-ios
//
//  Created by 윤웅상 on 9/9/24.
//
import SwiftUI
import PhotosUI

// ImagePicker: 갤러리에서 이미지를 선택하는 PHPickerViewController 래핑
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        @Binding var selectedImage: UIImage?

        init(selectedImage: Binding<UIImage?>) {
            _selectedImage = selectedImage
        }

        // 이미지 선택이 완료되었을 때 호출
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let provider = results.first?.itemProvider else { return }

            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, _ in
                    DispatchQueue.main.async {
                        self.selectedImage = image as? UIImage
                    }
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(selectedImage: $selectedImage)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        // 업데이트할 내용 없음
    }
}
