import CoreGraphics
import CoreImage
import TransfloDomain

/// One neutral-preserving pipeline shared by the editor preview and full-resolution export.
enum ImageAdjuster {
    static func apply(_ adjustments: ImageAdjustments, to image: CGImage) throws(JobError) -> CGImage {
        let adjustments = adjustments.validated
        guard !adjustments.isNeutral else { return image }
        var output = CIImage(cgImage: image)
        if adjustments.exposure != 0 {
            output = output.applyingFilter("CIExposureAdjust", parameters: [kCIInputEVKey: adjustments.exposure])
        }
        if adjustments.highlights != 0 || adjustments.shadows != 0 {
            output = output.applyingFilter("CIHighlightShadowAdjust", parameters: [
                "inputHighlightAmount": 1 - adjustments.highlights, "inputShadowAmount": adjustments.shadows
            ])
        }
        output = output.applyingFilter("CIColorControls", parameters: [
            kCIInputContrastKey: adjustments.contrast, kCIInputSaturationKey: adjustments.saturation,
            kCIInputBrightnessKey: adjustments.brightness
        ])
        if adjustments.temperature != 0 || adjustments.tint != 0 {
            output = output.applyingFilter("CITemperatureAndTint", parameters: [
                "inputNeutral": CIVector(x: 6500, y: 0),
                "inputTargetNeutral": CIVector(x: 6500 + adjustments.temperature * 2500, y: adjustments.tint * 100)
            ])
        }
        if adjustments.vibrance != 0 {
            output = output.applyingFilter("CIVibrance", parameters: [kCIInputAmountKey: adjustments.vibrance])
        }
        output = detail(adjustments, image: output)
        let extent = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        guard let result = CIContext().createCGImage(output.cropped(to: extent), from: extent) else { throw .failed }
        return result
    }

    private static func detail(_ adjustments: ImageAdjustments, image: CIImage) -> CIImage {
        var output = image
        if adjustments.noiseReduction > 0 {
            output = output.applyingFilter("CINoiseReduction", parameters: [
                "inputNoiseLevel": adjustments.noiseReduction * 0.1, "inputSharpness": 0
            ])
        }
        if adjustments.sharpness > 0 {
            output = output.applyingFilter("CISharpenLuminance", parameters: [
                kCIInputSharpnessKey: adjustments.sharpness * 1.5
            ])
        }
        if adjustments.vignette > 0 {
            output = output.applyingFilter("CIVignette", parameters: [
                kCIInputIntensityKey: adjustments.vignette * 1.5, kCIInputRadiusKey: 1
            ])
        }
        return output
    }
}
