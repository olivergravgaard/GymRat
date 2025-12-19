import Foundation
import SwiftUI
import PhotosUI
import Combine

extension View {
    @ViewBuilder
    func cropImagePicker (isPresented: Binding<Bool>, croppedImage: Binding<UIImage?>) -> some View {
        CustomImagePicker(isPresented: isPresented, uiImage: croppedImage) {
            self
        }
    }
    
    @ViewBuilder
    func frame (_ size: CGSize) -> some View {
        self
            .frame(width: size.width, height: size.height)
    }
}

fileprivate struct CustomImagePicker<Content: View>: View {
    var content: Content
    @Binding var isPresented: Bool
    @Binding var uiImage: UIImage?
    
    init (isPresented: Binding<Bool>, uiImage: Binding<UIImage?>, @ViewBuilder content: @escaping () -> Content) {
        self._isPresented = isPresented
        self._uiImage = uiImage
        self.content = content()
    }
    
    @State private var photosItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var showCropView: Bool = false
    
    var body: some View {
        content
            .photosPicker(isPresented: $isPresented, selection: $photosItem)
            .onChange(of: photosItem) { _, newValue in
                if let newValue {
                    Task {
                        if let imageData = try? await newValue.loadTransferable(type: Data.self), let image = UIImage(data: imageData) {
                            await MainActor.run {
                                selectedImage = image
                                showCropView.toggle()
                            }
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showCropView) {
                selectedImage = nil
            } content: {
                CropView(image: selectedImage) { croppedImage, status in
                    if let croppedImage {
                        self.uiImage = croppedImage
                    }
                }
            }

    }
}

struct CropView: View {
    
    @Environment(\.dismiss) var dismiss
    
    var image: UIImage?
    var onCrop: (UIImage?, Bool) -> ()
    
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 0
    @State private var offset: CGSize = .zero
    @State private var lastStoredOffset: CGSize = .zero
    @GestureState private var isInteracting: Bool = false
    
    var body: some View {
        ImageView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                Color.black
                    .ignoresSafeArea()
            }
            .overlay(alignment: .top) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                    .padding()
                    Spacer()
                    Button {
                        let renderer = ImageRenderer(content: ImageView())
                        renderer.proposedSize = .init(width: 200, height: 200)
                        if let image = renderer.uiImage {
                            onCrop(image, true)
                        }else {
                            onCrop(nil, false)
                        }
                        
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                    .padding()
                }
                .padding()
            }
    }
    
    @ViewBuilder
    func ImageView () -> some View {
        let cropSize = CGSize(width: 200, height: 200)
        GeometryReader {
            let size = $0.size
            
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .overlay {
                        GeometryReader { proxy in
                            let rect = proxy.frame(in: .named("CROP_VIEW"))
                            
                            Color.clear
                                .onChange(of: isInteracting) { oldValue, newValue in
                                    
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        if rect.minX > 0 {
                                            offset.width = (offset.width - rect.minX)
                                        }
                                        
                                        if rect.minY > 0 {
                                            offset.height = (offset.height - rect.minY)
                                        }
                                        
                                        if rect.maxX < size.width {
                                            offset.width = (rect.minX - offset.width)
                                        }
                                        
                                        if rect.maxY < size.height {
                                            offset.height = (rect.minY - offset.height)
                                        }
                                    }
                                    
                                    if !newValue {
                                        lastStoredOffset = offset
                                        lastScale = scale
                                    }
                                }
                        }
                    }
                    .frame(size)
            }
        }
        .offset(offset)
        .scaleEffect(scale)
        .coordinateSpace(name: "CROP_VIEW")
        .gesture(
            DragGesture()
                .updating($isInteracting, body: { _, out, _ in
                    out = true
                }).onChanged({ value in
                    let translation = value.translation
                    offset = CGSize(width: translation.width + lastStoredOffset.width, height: translation.height + lastStoredOffset.height)
                })
        )
        .gesture(
            MagnificationGesture()
                .updating($isInteracting, body: { _, out, _ in
                    out = true
                }).onChanged({ value in
                    let updatedScale = value + lastScale
                    scale = (updatedScale < 1 ? 1 : updatedScale)
                }).onEnded({ value in
                    withAnimation(.easeIn(duration: 0.2)) {
                        if scale < 1 {
                            scale = 1
                            lastScale = 0
                        }else {
                            lastScale = scale - 1
                        }
                    }
                })
        )
        .frame(cropSize)
        .cornerRadius(cropSize.height / 2)
    }
}
