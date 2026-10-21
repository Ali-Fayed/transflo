import CoreGraphics
import TransfloDomain

/// Doubles an image's resolution (Strategy: MetalFX on the GPU, or Core Image).
protocol ImageUpscaling: Sendable {
    func upscale(_ image: CGImage) throws(JobError) -> CGImage
}
