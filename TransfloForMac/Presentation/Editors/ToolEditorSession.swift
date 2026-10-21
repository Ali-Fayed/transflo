/// The model behind one open editor, typed per tool.
enum ToolEditorSession {
    case assembly(AssemblyEditorViewModel)
    case backgroundRemoval(BackgroundRemovalEditorViewModel)
    case audio(AudioToolEditorViewModel)
    case codes(CodeResultsViewModel)
    case removeMetadata(MetadataRemovalEditorViewModel)
    case rotate(RotateEditorViewModel)
    case compress(CompressEditorViewModel)
    case resize(ResizeEditorViewModel)
    case crop(CropEditorViewModel)
    case adjust(AdjustEditorViewModel)
    case trim(TrimEditorViewModel)
    case speed(SpeedEditorViewModel)
    case split(SplitEditorViewModel)
    case snapshot(SnapshotEditorViewModel)
    case annotate(AnnotateEditorViewModel)
    case redact(RedactEditorViewModel)
    case background(AddBackgroundEditorViewModel)
    case collage(CollageEditorViewModel)
    case bleep(BleepEditorViewModel)
    case reorganize(ReorganizePagesEditorViewModel)
    case extract(ExtractPagesEditorViewModel)
    case metadata(MetadataEditorViewModel)
    case rename(RenameEditorViewModel)
    case smartRename(SmartRenameEditorViewModel)

    var previewUnavailable: Bool {
        switch self {
        case .assembly, .backgroundRemoval, .audio, .codes, .removeMetadata: false
        case .compress, .rename, .metadata, .smartRename: false
        case .rotate(let model): model.preview.thumbnail == nil
        case .resize(let model): model.preview.width == nil || model.preview.height == nil
        case .crop(let model): model.preview.thumbnail == nil
        case .adjust(let model): model.preview.thumbnail == nil
        case .trim(let model): model.duration <= 0
        case .speed(let model): model.preview.duration == nil
        case .split(let model): model.isPDF ? model.preview.pageCount == nil : model.preview.duration == nil
        case .snapshot(let model): model.duration <= 0
        case .annotate(let model): model.preview.thumbnail == nil
        case .redact(let model): model.preview.thumbnail == nil
        case .background(let model): model.preview.thumbnail == nil
        case .collage(let model): model.thumbnails.isEmpty || model.thumbnails.allSatisfy { $0 == nil }
        case .bleep(let model): model.duration <= 0
        case .reorganize(let model): model.pageCount == 0
        case .extract(let model): model.pageCount == 0
        }
    }

    var model: any ToolEditorModel {
        switch self {
        case .assembly(let model): model
        case .backgroundRemoval(let model): model
        case .audio(let model): model
        case .codes(let model): model
        case .removeMetadata(let model): model
        case .rotate(let model): model
        case .compress(let model): model
        case .resize(let model): model
        case .crop(let model): model
        case .adjust(let model): model
        case .trim(let model): model
        case .speed(let model): model
        case .split(let model): model
        case .snapshot(let model): model
        case .annotate(let model): model
        case .redact(let model): model
        case .background(let model): model
        case .collage(let model): model
        case .bleep(let model): model
        case .reorganize(let model): model
        case .extract(let model): model
        case .metadata(let model): model
        case .rename(let model): model
        case .smartRename(let model): model
        }
    }
}
