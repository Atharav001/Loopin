import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct TaskRowView: View {
    @EnvironmentObject private var taskStore: TaskStore

    let task: Task
    var isEditing: Bool
    var onBeginEdit: () -> Void
    var onEndEdit: () -> Void
    /// Invoked when the user deletes the task (list wires delete-undo, §4.4.2).
    var onDelete: (Task) -> Void = { _ in }

    @State private var draft: String = ""
    @State private var stepDraft: String = ""
    @State private var editingFirstStep: Bool = false
    @State private var isSettingDeadline: Bool = false
    @State private var deadlineDraft: Date = Date()
    @FocusState private var editFocused: Bool
    @State private var isHovering: Bool = false

    /// Drives the completion animation: true while the row plays its ripple +
    /// teal background flash before being removed from the open list.
    @State private var completing = false

    var body: some View {
        Group {
            if isSettingDeadline {
                deadlineEditor
            } else if editingFirstStep {
                firstStepEditor
            } else if isEditing {
                editingRow
            } else {
                displayRow
            }
        }
        .transition(.opacity)
    }

    private var displayRow: some View {
        HStack(spacing: 8) {
            if let tag = task.colorTag {
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppTheme.color(for: tag))
                    .frame(width: 4)
                    .padding(.vertical, 4)
            }

            leadingMarker

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if let displayTitle = cleanDisplayTitle {
                        Text(displayTitle)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(2)
                            .foregroundStyle(task.isComplete ? AppTheme.textSecondary : AppTheme.textPrimary)
                            .strikethrough(task.isComplete)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .onTapGesture(count: 2) {
                                draft = task.title
                                onBeginEdit()
                                editFocused = true
                            }
                            .contentShape(Rectangle())
                    } else if task.linkAttachments.isEmpty && task.fileAttachments.isEmpty && task.imageAttachments.isEmpty {
                        Text("Untitled Task")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .onTapGesture(count: 2) {
                                draft = ""
                                onBeginEdit()
                                editFocused = true
                            }
                            .contentShape(Rectangle())
                    }

                    if let attachment = task.fileAttachments.first {
                        Text("[\(attachment.fileTypeTag)]")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AppTheme.accentTeal)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(AppTheme.accentTeal.opacity(0.15))
                            )
                    } else if !task.imageAttachments.isEmpty {
                        Text("[IMG]")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(AppTheme.accentViolet)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(AppTheme.accentViolet.opacity(0.15))
                            )
                    }

                    if let framing = task.framing {
                        framingBadge(for: framing)
                    }
                }

                if let firstStep = task.firstStep, !firstStep.isEmpty {
                    Text("1. \(firstStep)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.accentTeal)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !task.fileAttachments.isEmpty {
                    ForEach(task.fileAttachments) { fileAttachmentRow(for: $0) }
                }
                if let link = task.linkAttachments.first {
                    linkChip(for: link)
                }
                if let image = task.imageAttachments.first {
                    imageThumbnail(for: image)
                }
            }
            .opacity(completing ? 0.6 : 1)

            Spacer(minLength: 0)

            if let dueDate = task.dueDate {
                dueBadge(for: dueDate)
            }

            hoverActions
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(rowBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(dropTargeted ? AppTheme.accentTeal : AppTheme.borderSubtle.opacity(0.6), lineWidth: dropTargeted ? 1.5 : 1)
                )
        )
        .onHover { isHovering = $0 }
        .onDrop(of: [.fileURL, .image, .url], isTargeted: Binding(
            get: { dropTargeted },
            set: { newValue in dropTargeted = newValue }
        )) { providers in
            handleRowDrop(providers)
        }
    }

    /// Row shows a color-tag dot (§4.1), an icon-forward glyph when set and a
    /// text-free checkbox otherwise; completed rows keep the same marker.
    private var leadingMarker: some View {
        HStack(spacing: 6) {
            Button {
                complete()
            } label: {
                Image(systemName: leadingSymbol)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(leadingColor)
            }
            .buttonStyle(.plain)
            .help("Mark done")
            .disabled(completing)
            .ripple(trigger: completing, color: AppTheme.accentTeal)
        }
    }

    private var leadingSymbol: String {
        if let icon = task.icon, !task.isComplete { return icon }
        if task.isComplete { return "checkmark.circle.fill" }
        return "circle"
    }

    private var leadingColor: Color {
        if task.isComplete { return AppTheme.accentTeal }
        if task.colorTag != nil { return AppTheme.color(for: task.colorTag!) }
        return task.icon != nil ? AppTheme.accentViolet : AppTheme.textSecondary
    }

    private var cleanDisplayTitle: String? {
        let trimmed = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if let link = task.linkAttachments.first {
            if trimmed == link.url.absoluteString || trimmed == link.url.host || trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
                return nil
            }
        } else if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return nil
        }
        return trimmed
    }

    /// Task actions: important star (always visible when starred, subtle on hover) + delete.
    private var hoverActions: some View {
        HStack(spacing: 6) {
            Button {
                toggleImportant()
            } label: {
                Image(systemName: task.isImportant ? "star.fill" : "star")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(task.isImportant ? AppTheme.accentAmber : AppTheme.textSecondary)
            }
            .buttonStyle(.plain)
            .opacity(task.isImportant ? 1.0 : (isHovering ? 0.9 : 0.25))
            .help(task.isImportant ? "Unmark important" : "Mark important")

            Button {
                onDelete(task)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .buttonStyle(.plain)
            .opacity(isHovering ? 1 : 0)
            .disabled(!isHovering)
            .help("Delete")

            framingMenu
                .opacity(isHovering ? 1 : 0)
                .disabled(!isHovering)
        }
    }

    private func toggleImportant() {
        var updated = task
        updated.isImportant.toggle()
        taskStore.update(updated)
    }

    /// §4.2.3 due date rendered as a small pill badge.
    private func dueBadge(for date: Date) -> some View {
        let overdue = date < Date() && !task.isComplete
        return HStack(spacing: 3) {
            Image(systemName: "calendar")
                .font(.system(size: 9))
            Text(date, style: .date)
                .font(.system(size: 10))
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(overdue ? AppTheme.accentCoral.opacity(0.18) : AppTheme.surface)
        )
        .foregroundStyle(overdue ? AppTheme.accentCoral : AppTheme.textSecondary)
    }

    /// FR-13: one small glyph reflecting the attached framing, text-free to
    /// avoid row clutter. ⚡ for quickWin, ⏭ for doFirstNextSession.
    private func framingBadge(for framing: TaskFraming) -> some View {
        Image(systemName: framing == .quickWin ? "bolt.fill" : "forward.end.fill")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(framingColor(for: framing))
            .help(framingHelp(for: framing))
    }

    private func framingColor(for framing: TaskFraming) -> Color {
        switch framing {
        case .quickWin: return AppTheme.accentTeal
        case .doFirstNextSession: return AppTheme.accentViolet
        }
    }

    private func framingHelp(for framing: TaskFraming) -> String {
        switch framing {
        case .quickWin: return "Quick win — surfaces first in What now"
        case .doFirstNextSession: return "Do first next session"
        }
    }

    /// FR-13: the "..." context menu holding the three framing levers plus the
    /// FR-15 "add first step" action. All single-tap, no sub-forms.
    private var framingMenu: some View {
        Menu {
            Menu {
                ForEach(TaskColorTag.allCases) { tag in
                    Button {
                        setColorTag(tag)
                    } label: {
                        HStack {
                            Circle()
                                .fill(AppTheme.color(for: tag))
                                .frame(width: 10, height: 10)
                            Text(tag.label)
                            if task.colorTag == tag {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                if task.colorTag != nil {
                    Divider()
                    Button("Clear color") { setColorTag(nil) }
                }
            } label: {
                Text("Color tag")
            }

            Menu {
                ForEach(TaskIcon.allCases) { icon in
                    Button {
                        setIcon(icon.symbol)
                    } label: {
                        Label(icon.symbol, systemImage: icon.symbol)
                            .foregroundStyle(AppTheme.accentViolet)
                    }
                }
                if task.icon != nil {
                    Divider()
                    Button("Default checkbox") { setIcon(nil) }
                }
            } label: {
                Text("Row icon")
            }

            Button("Set a deadline") {
                setDeadline()
            }
            Divider()
            Button(task.framing == .quickWin ? "Unmark quick win" : "Mark as quick win") {
                toggleFraming(.quickWin)
            }
            Button(task.framing == .quickWin ? "Do first next session →" : "Do first next session") {
                setFraming(.doFirstNextSession)
            }
            if task.framing == .doFirstNextSession {
                Button("Clear 'do first'") {
                    setFraming(nil)
                }
            }
            Divider()
            Menu {
                ForEach(TaskSize.allCases, id: \.self) { size in
                    Button {
                        setSize(size)
                    } label: {
                        Label(size.label, systemImage: "checkmark")
                            .foregroundStyle(sizeColor(for: size))
                    }
                }
                if task.size != nil {
                    Divider()
                    Button("Clear") { setSize(nil) }
                }
            } label: {
                Text("Size")
            }
            Button(firstStepExists ? "Edit first step…" : "Add first step…") {
                beginFirstStepEdit()
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Task options")
    }

    private func setColorTag(_ tag: TaskColorTag?) {
        var updated = task
        updated.colorTag = tag
        taskStore.update(updated)
    }

    private func setIcon(_ symbol: String?) {
        var updated = task
        updated.icon = symbol
        taskStore.update(updated)
    }

    private func sizeColor(for size: TaskSize) -> Color {
        switch size {
        case .big: return AppTheme.accentCoral
        case .medium: return AppTheme.accentViolet
        case .small: return AppTheme.accentTeal
        }
    }

    private var firstStepExists: Bool {
        (task.firstStep ?? "").isEmpty == false
    }

    private var rowBackground: Color {
        if completing {
            return AppTheme.accentTeal.opacity(0.18)
        }
        if isHovering {
            return AppTheme.surface.opacity(1)
        }
        return AppTheme.surface
    }

    private func setSize(_ size: TaskSize?) {
        var updated = task
        updated.size = size
        taskStore.update(updated)
    }

    private func linkChip(for link: LinkAttachment) -> some View {
        HStack(spacing: 4) {
            if let favicon = link.faviconData,
               let nsImage = NSImage(data: favicon) {
                Image(nsImage: nsImage)
                    .resizable()
                    .frame(width: 12, height: 12)
            } else {
                Image(systemName: "link")
                    .font(.system(size: 10))
            }
            Text(link.fetchedTitle ?? link.url.host ?? link.url.lastPathComponent)
                .font(.system(size: 11))
                .lineLimit(1)
            Link("Open", destination: link.url)
                .font(.system(size: 10))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(AppTheme.surface)
        )
    }

    private func imageThumbnail(for image: ImageAttachment) -> some View {
        Group {
            if let data = JSONStore.readImage(named: image.imageFileName),
               let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    // MARK: - File attachment display (§4.3.1)

    /// A non-image attachment renders inline as a file-type icon + filename,
    /// in place of a bare text row.
    private func fileAttachmentRow(for attachment: FileAttachment) -> some View {
        HStack(spacing: 6) {
            Image(systemName: fileTypeSymbol(for: attachment.fileTypeTag))
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.accentViolet)
            Text(attachment.fileName)
                .font(.system(size: 11))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(AppTheme.surface)
        )
        .help("Attached: \(attachment.fileName)")
    }

    private func fileTypeSymbol(for tag: String) -> String {
        switch tag.uppercased() {
        case "PDF": return "doc.richtext"
        case "PNG", "JPG", "JPEG", "HEIC": return "photo"
        case "DOC", "DOCX": return "doc.text"
        case "XLS", "XLSX", "CSV": return "tablecells"
        case "PPT", "PPTX": return "chart.bar.doc.horizontal"
        case "ZIP", "GZ": return "archivebox"
        case "TXT", "MD": return "doc.plaintext"
        default: return "doc"
        }
    }

    // MARK: - Row-level attachment drop (§4.3.1)

    @State private var dropTargeted = false

    private func handleRowDrop(_ providers: [NSItemProvider]) -> Bool {
        guard !task.isComplete else { return false }
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.png.identifier) { data, _ in
                    guard let data else { return }
                    let fileName = "\(UUID().uuidString).png"
                    if JSONStore.writeImage(data, named: fileName) {
                        DispatchQueue.main.async {
                            attachImage(fileName)
                        }
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url, let data = try? Data(contentsOf: url) else { return }
                    let originalName = url.lastPathComponent
                    let storedName = "\(UUID().uuidString).\(url.pathExtension)"
                    guard JSONStore.writeAttachment(data, named: storedName) else { return }
                    let attachment = FileAttachment.make(fileName: originalName)
                    DispatchQueue.main.async {
                        attachFile(attachment)
                    }
                }
            }
        }
        return true
    }

    private func attachImage(_ fileName: String) {
        var updated = task
        updated.imageAttachments.append(ImageAttachment(imageFileName: fileName))
        // §4.3.3: if the task has no title, auto-fill from the filename.
        if updated.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            updated.title = (fileName as NSString).deletingPathExtension
        }
        taskStore.update(updated)
    }

    private func attachFile(_ attachment: FileAttachment) {
        var updated = task
        updated.fileAttachments.append(attachment)
        // §4.3.3: auto-fill an empty title from the filename (without extension).
        if updated.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            updated.title = (attachment.fileName as NSString).deletingPathExtension
        }
        taskStore.update(updated)
    }

    private var firstStepEditor: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("First tiny step")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
            TextField("e.g. Open the doc and write one sentence", text: $stepDraft)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
                .onSubmit {
                    commitFirstStep()
                }
                .onExitCommand {
                    editingFirstStep = false
                    onEndEdit()
                }
            HStack {
                Button("Save") { commitFirstStep() }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accentTeal)
                Button("Clear") {
                    stepDraft = ""
                    commitFirstStep()
                }
                .buttonStyle(.bordered)
                Spacer()
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .onAppear { editFocused = true }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var deadlineEditor: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Self-imposed deadline")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
            DatePicker("",
                       selection: $deadlineDraft,
                       displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("Set") { commitDeadline() }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accentTeal)
                if task.dueDate != nil {
                    Button("Clear") {
                        var updated = task
                        updated.dueDate = nil
                        taskStore.update(updated)
                        isSettingDeadline = false
                        onEndEdit()
                    }
                    .buttonStyle(.bordered)
                }
                Spacer()
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var editingRow: some View {
        HStack(spacing: 6) {
            TextField("Task title", text: $draft)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13, weight: .medium))
                .focused($editFocused)
                .onSubmit {
                    commitEdit()
                }
                .onAppear { editFocused = true }
                .onChange(of: editFocused) { _, focused in
                    guard isEditing, !focused else { return }
                    commitEdit()
                }
                .onExitCommand {
                    onEndEdit()
                }

            if let attachment = task.fileAttachments.first {
                Text("[\(attachment.fileTypeTag)]")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppTheme.accentTeal)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(AppTheme.accentTeal.opacity(0.18))
                    )
            } else if !task.imageAttachments.isEmpty {
                Text("[IMG]")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppTheme.accentViolet)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(AppTheme.accentViolet.opacity(0.18))
                    )
            }
        }
        .padding(.vertical, 2)
    }

    private func complete() {
        guard !completing else { return }
        completing = true

        // Trigger attention celebration overlay glow
        AttentionOverlayManager.shared.trigger(event: .taskCompleted)

        // Run completion ripple animation before marking task complete
        Swift.Task { @MainActor in
            try? await Swift.Task.sleep(nanoseconds: 360_000_000)
            var updated = task
            updated.isComplete = true
            taskStore.update(updated)
        }
    }

    private func commitEdit() {
        guard isEditing else { return }
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, trimmed != task.title {
            var updated = task
            updated.title = trimmed
            taskStore.update(updated)
        }
        onEndEdit()
    }

    // MARK: - Framing (FR-13)

    /// quickWin is a toggle: setting it when already set clears it.
    private func toggleFraming(_ framing: TaskFraming) {
        var updated = task
        updated.framing = (task.framing == framing) ? nil : framing
        taskStore.update(updated)
    }

    private func setFraming(_ framing: TaskFraming?) {
        var updated = task
        updated.framing = framing
        taskStore.update(updated)
    }

    // MARK: - First step (FR-15)

    private func beginFirstStepEdit() {
        stepDraft = task.firstStep ?? ""
        editingFirstStep = true
        onBeginEdit()
    }

    private func commitFirstStep() {
        let trimmed = stepDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed != (task.firstStep ?? "") {
            var updated = task
            updated.firstStep = trimmed.isEmpty ? nil : trimmed
            taskStore.update(updated)
        }
        editingFirstStep = false
        onEndEdit()
    }

    private func commitDeadline() {
        var updated = task
        updated.dueDate = deadlineDraft
        taskStore.update(updated)
        isSettingDeadline = false
        onEndEdit()
    }

    private func setDeadline() {
        deadlineDraft = task.dueDate ?? Date()
        isSettingDeadline = true
        onBeginEdit()
    }
}

#Preview {
    TaskRowView(
        task: Task(title: "File the taxes"),
        isEditing: false,
        onBeginEdit: {},
        onEndEdit: {}
    )
    .environmentObject(TaskStore())
    .padding()
}