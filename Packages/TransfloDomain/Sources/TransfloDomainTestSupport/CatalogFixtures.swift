import TransfloDomain

/// A small catalog for tests: PNG ↔ JPG via `imageio` (then `ffmpeg`), PNG → WebP via `ffmpeg`, MP3 → WAV.
public enum CatalogFixtures {
    public static let png = format("png", "PNG", family: .image)
    public static let jpg = FormatDescriptor(
        id: FormatID("jpg"),
        displayName: "JPG",
        extensions: ["jpg", "jpeg"],
        family: .image
    )
    public static let webp = format("webp", "WebP", family: .image)
    public static let mp3 = format("mp3", "MP3", family: .audio)
    public static let wav = format("wav", "WAV", family: .audio)

    private static func format(_ id: String, _ name: String, family: FormatFamily) -> FormatDescriptor {
        FormatDescriptor(id: FormatID(id), displayName: name, extensions: [id], family: family)
    }

    public static let imageIO = EngineID("imageio")
    public static let ffmpeg = EngineID("ffmpeg")

    public static let catalog = ConversionCatalog(
        formats: [png, jpg, webp, mp3, wav],
        paths: [
            ConversionPath(source: png.id, target: jpg.id, engines: [imageIO, ffmpeg]),
            ConversionPath(source: png.id, target: webp.id, engines: [ffmpeg]),
            ConversionPath(source: jpg.id, target: png.id, engines: [imageIO]),
            ConversionPath(source: jpg.id, target: webp.id, engines: [ffmpeg]),
            ConversionPath(source: mp3.id, target: wav.id, engines: [ffmpeg])
        ]
    )
}

/// A small tool catalog: Compress (image/audio), Rotate (image), Merge (2+ audio), Rename (any file).
public enum ToolFixtures {
    public static let catalog = ToolCatalog(tools: [
        ToolDescriptor(kind: .compress, families: [.image, .audio]),
        ToolDescriptor(kind: .rotate, families: [.image]),
        ToolDescriptor(kind: .merge, families: [.audio], requiresMultipleFiles: true),
        ToolDescriptor(kind: .rename, families: [], appliesToAnyFile: true, isInteractive: true)
    ])
}
