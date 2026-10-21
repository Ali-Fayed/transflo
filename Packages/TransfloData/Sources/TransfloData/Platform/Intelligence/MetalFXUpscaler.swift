#if canImport(MetalFX)
import CoreGraphics
import CoreImage
import Metal
import MetalFX
import TransfloDomain

/// Upscale 2× with MetalFX's spatial scaler, which reconstructs edges rather than just smoothing them.
/// Images with transparency, and Macs whose GPU can't run the scaler, use `fallback` instead.
struct MetalFXUpscaler: ImageUpscaling {
    private let fallback: any ImageUpscaling

    init(fallback: any ImageUpscaling = CoreImageUpscaler()) {
        self.fallback = fallback
    }

    func upscale(_ image: CGImage) throws(JobError) -> CGImage {
        guard !Self.hasAlpha(image), let device = MTLCreateSystemDefaultDevice(),
              MTLFXSpatialScalerDescriptor.supportsDevice(device),
              let result = Self.scale(image, device: device) else {
            return try fallback.upscale(image)
        }
        return result
    }

    static func hasAlpha(_ image: CGImage) -> Bool {
        ![.none, .noneSkipFirst, .noneSkipLast].contains(image.alphaInfo)
    }

    private static func scale(_ image: CGImage, device: any MTLDevice) -> CGImage? {
        let descriptor = MTLFXSpatialScalerDescriptor()
        descriptor.inputWidth = image.width
        descriptor.inputHeight = image.height
        descriptor.outputWidth = image.width * 2
        descriptor.outputHeight = image.height * 2
        descriptor.colorTextureFormat = .rgba8Unorm
        descriptor.outputTextureFormat = .rgba8Unorm
        descriptor.colorProcessingMode = .perceptual
        guard let scaler = descriptor.makeSpatialScaler(device: device),
              let queue = device.makeCommandQueue(),
              let input = texture(device, image.width, image.height, scaler.colorTextureUsage.union(.shaderWrite)),
              let output = texture(device, descriptor.outputWidth, descriptor.outputHeight, scaler.outputTextureUsage),
              let buffer = queue.makeCommandBuffer() else { return nil }
        let context = CIContext(mtlDevice: device)
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        // Metal's origin is the top-left corner; Core Image's is the bottom-left.
        let source = CIImage(cgImage: image).transformed(by: CGAffineTransform(scaleX: 1, y: -1)
            .translatedBy(x: 0, y: -CGFloat(image.height)))
        context.render(source, to: input, commandBuffer: buffer, bounds: source.extent, colorSpace: space)
        scaler.colorTexture = input
        scaler.outputTexture = output
        scaler.inputContentWidth = image.width
        scaler.inputContentHeight = image.height
        scaler.encode(commandBuffer: buffer)
        buffer.commit()
        buffer.waitUntilCompleted()
        guard buffer.status == .completed,
              let scaled = CIImage(mtlTexture: output, options: [.colorSpace: space]) else { return nil }
        let upright = scaled.transformed(by: CGAffineTransform(scaleX: 1, y: -1)
            .translatedBy(x: 0, y: -scaled.extent.height))
        return context.createCGImage(upright, from: upright.extent, format: .RGBA8, colorSpace: space)
    }

    private static func texture(
        _ device: any MTLDevice, _ width: Int, _ height: Int, _ usage: MTLTextureUsage
    ) -> (any MTLTexture)? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm, width: width, height: height, mipmapped: false
        )
        descriptor.usage = usage
        descriptor.storageMode = .private
        return device.makeTexture(descriptor: descriptor)
    }
}
#endif
