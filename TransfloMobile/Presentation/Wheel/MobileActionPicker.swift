import SwiftUI
import TransfloDomain

/// A touch-first workspace: every supported option is visible without wheel groups or paging.
struct MobileActionPicker: View {
    let presenter: MobileWheelPresenter
    let viewModel: WheelViewModel
    let coordinator: WheelCoordinator
    @Environment(Localizer.self) private var localizer
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var search = ""
    @FocusState private var searchFocused: Bool

    private var options: [WheelOption] {
        MobileActionPresentation.filtered(viewModel.state.options, query: search, localizer: localizer)
    }

    var body: some View {
        if presenter.isShown {
            NavigationStack {
                VStack(spacing: 0) {
                    AppSegmentedPicker(key: .mobileChooseAction, selection: kind,
                                       options: WheelCoordinator.keyboardWheelOrder.compactMap { kind in
                        coordinator.options(for: kind).isEmpty ? nil
                            : .init(value: kind, label: WheelPresentation.title(for: kind))
                    })
                    .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 12)
                    searchField.padding(.horizontal, 20).padding(.bottom, 12)
                    if searchFocused {
                        actionList
                    } else if sizeClass == .regular {
                        HStack(alignment: .top, spacing: 0) {
                            selection.padding(20).frame(width: 260)
                            actionList
                        }
                    } else {
                        selection.padding(.horizontal, 20).padding(.bottom, 12)
                        actionList
                    }
                }
                .frame(maxWidth: 1100).frame(maxWidth: .infinity)
                .appScreenBackground()
                .mobileNavigationBar(.mobileChooseAction)
                .toolbar {
                    MobileCloseToolbar(action: coordinator.dismiss)
                }
            }
            .onAppear { search = ""; searchFocused = false }
            .onChange(of: viewModel.state.kind) { _, _ in search = "" }
            .transition(.opacity)
            .accessibilityIdentifier("mobile.actionPicker")
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(AppColors.textSecondary).accessibilityHidden(true)
            TextField(localizer.string(.mobileSearchActions), text: $search)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .submitLabel(.search).focused($searchFocused)
                .onSubmit { searchFocused = false }
                .accessibilityIdentifier("mobile.actions.search")
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(AppColors.textSecondary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(localizer.string(.mobileClearSearch))
            }
        }
        .padding(.leading, 14).padding(.trailing, search.isEmpty ? 14 : 0)
        .frame(minHeight: 46)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 14))
    }

    private var selection: some View {
        HStack(alignment: .center, spacing: 12) {
            if let url = coordinator.openItems.first { AppFileThumbnail(url: url) }
            VStack(alignment: .leading, spacing: 5) {
                Text(coordinator.openItems.first?.lastPathComponent ?? "")
                    .font(.subheadline.weight(.semibold)).lineLimit(2).truncationMode(.middle)
                AppText(.mobileBatchCount, arguments: [String(coordinator.openItems.count)],
                        style: .caption, color: .secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 18))
    }

    private var actionList: some View {
        List {
            if options.isEmpty {
                ContentUnavailableView.search(text: search)
            } else if viewModel.state.kind == .tools {
                rows(options.filter { WheelToolGroup.group(for: $0) == nil })
                ForEach(WheelToolGroup.allCases, id: \.self) { group in
                    let tools = options.filter { WheelToolGroup.group(for: $0) == group }
                    if tools.count > 1 || (group == .recipes && !tools.isEmpty) {
                        Section(localizer.string(group.title)) { rows(tools) }
                    } else {
                        rows(tools)
                    }
                }
            } else {
                rows(options)
            }
        }
        .listStyle(.insetGrouped)
        .contentMargins(.top, 0, for: .scrollContent)
        // The same side inset as the tabs, search and file card above, so every edge lines up.
        .contentMargins(.horizontal, 20, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }

    private func rows(_ options: [WheelOption]) -> some View {
        ForEach(options) { option in
            Button {
                searchFocused = false
                if coordinator.select(option) { AppFeedback.selection() }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: MobileActionPresentation.symbol(option).rawValue)
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(AppColors.accent)
                        .frame(width: 38, height: 38)
                        .background(AppColors.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 11))
                        .accessibilityHidden(true)
                    Text(MobileActionPresentation.title(option, localizer: localizer))
                        .font(.body.weight(.medium)).foregroundStyle(AppColors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.forward").font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.textSecondary).accessibilityHidden(true)
                }
                .padding(.vertical, 6).frame(minHeight: 48).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("mobile.action.\(option.id)")
        }
    }

    private var kind: Binding<WheelKind> {
        Binding(get: { viewModel.state.kind ?? .convert }, set: { coordinator.switchWheel(to: $0) })
    }
}

/// Full tool names remain searchable in either language; available options are never paged.
enum MobileActionPresentation {
    static func title(_ option: WheelOption, localizer: Localizer) -> String {
        switch option.kind {
        case .tool(let tool): localizer.string(WheelPresentation.toolLabels[tool] ?? .wheelTools)
        default:
            switch WheelPresentation.wedge(for: option).label {
            case .key(let key): localizer.string(key)
            case .verbatim(let value): value
            }
        }
    }

    static func symbol(_ option: WheelOption) -> AppSymbol {
        WheelPresentation.wedge(for: option).symbol ?? .flowFile
    }

    static func filtered(_ options: [WheelOption], query: String, localizer: Localizer) -> [WheelOption] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return options.filter { query.isEmpty || title($0, localizer: localizer).localizedStandardContains(query) }
    }
}
