import CoreGraphics
import CoreImage
import TransfloDomain

/// Upscale 2× with Lanczos resampling and a light luminance sharpen; keeps transparency.
struct CoreImageUpscaler: ImageUpscaling {
    static let sharpness = 0.4

    func upscale(_ image: CGImage) throws(JobError) -> CGImage {
        let scaled = CIImage(cgImage: image)
            .applyingFilter("CILanczosScaleTransform", parameters: [kCIInputScaleKey: 2, kCIInputAspectRatioKey: 1])
            .applyingFilter("CISharpenLuminance", parameters: [kCIInputSharpnessKey: Self.sharpness])
        let extent = CGRect(x: 0, y: 0, width: image.width * 2, height: image.height * 2)
        let space = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let result = CIContext().createCGImage(scaled, from: extent, format: .RGBA8, colorSpace: space) else {
            throw .failed
        }
        return result
    }
}
