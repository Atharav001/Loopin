import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct QuickAddView: View {
    @EnvironmentObject private var taskStore: TaskStore
    @State private var text: String = ""
    @State private var isDropTarget: Bool = false
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isDropTarget ? "arrow.down.doc.fill" : "plus.circle.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(isDropTarget ? AppTheme.accentViolet : AppTheme.accentTeal)
                .scaleEffect(isDropTarget ? 1.15 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isDropTarget)

            TextField(
                isDropTarget ? "Drop document or image to create task…" : "Capture thoughts, drop files, paste links…",
                text: $text
            )
            .textFieldStyle(.plain)
            .focused($isFocused)
            .onSubmit(submit)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(AppTheme.textPrimary)

            // Quick attachment button: lets user browse for documents/images
            Button {
                selectFileAttachment()
            } label: {
                Image(systemName: "paperclip")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Attach document or image")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isDropTarget ? AppTheme.accentViolet.opacity(0.12) : AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            isDropTarget ? AppTheme.accentViolet : (isFocused ? AppTheme.accentTeal : AppTheme.borderSubtle),
                            lineWidth: (isDropTarget || isFocused) ? 1.5 : 1
                        )
                )
                .shadow(
                    color: isDropTarget ? AppTheme.accentViolet.opacity(0.4) : (isFocused ? AppTheme.accentTeal.opacity(0.3) : Color.clear),
                    radius: 8
                )
        )
        .onDrop(of: [.fileURL, .image, .item, .data, .url], isTargeted: $isDropTarget) { providers in
            handleDrop(providers)
        }
    }

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // If the field is empty and pasteboard holds an image or file, capture it.
        if trimmed.isEmpty {
            if NSPasteboard.general.availableType(from: [.tiff, .png]) != nil {
                taskStore.add(from: CaptureClassifier.classify(pasteboard: NSPasteboard.general))
                text = ""
                isFocused = true
                return
            } else if let fileURLs = NSPasteboard.general.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
                      let firstURL = fileURLs.first {
                createTaskFromFile(url: firstURL, customTitle: nil)
                text = ""
                isFocused = true
                return
            }
        }

        guard !trimmed.isEmpty else { return }
        taskStore.add(from: CaptureClassifier.classifyText(trimmed))
        text = ""
        isFocused = true
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let customTitle = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : text.trimmingCharacters(in: .whitespacesAndNewlines)
        var handled = false

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadDataRepresentation(forTypeIdentifier: UTType.png.identifier) { data, _ in
                    guard let data else { return }
                    let fileName = "\(UUID().uuidString).png"
                    if JSONStore.writeImage(data, named: fileName) {
                        DispatchQueue.main.async {
                            var task = Task(
                                title: customTitle ?? "Image",
                                imageAttachments: [ImageAttachment(imageFileName: fileName)]
                            )
                            taskStore.add(task)
                            self.text = ""
                        }
                    }
                }
                handled = true
            } else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    DispatchQueue.main.async {
                        self.createTaskFromFile(url: url, customTitle: customTitle)
                        self.text = ""
                    }
                }
                handled = true
            } else if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    DispatchQueue.main.async {
                        self.taskStore.add(from: ClassifiedContent(
                            titleText: customTitle ?? "",
                            url: url,
                            imageFileName: nil,
                            dueDate: nil,
                            rawPasteboardText: url.absoluteString
                        ))
                        self.text = ""
                    }
                }
                handled = true
            }
        }
        return handled
    }

    private func createTaskFromFile(url: URL, customTitle: String?) {
        guard let data = try? Data(contentsOf: url) else { return }
        let originalName = url.lastPathComponent
        let ext = url.pathExtension.lowercased()
        let isImg = ["png", "jpg", "jpeg", "heic", "webp", "gif"].contains(ext)

        let title = customTitle ?? (originalName as NSString).deletingPathExtension

        if isImg {
            let storedName = "\(UUID().uuidString).\(ext.isEmpty ? "png" : ext)"
            if JSONStore.writeImage(data, named: storedName) {
                var task = Task(title: title)
                task.imageAttachments = [ImageAttachment(imageFileName: storedName)]
                taskStore.add(task)
            }
        } else {
            let storedName = "\(UUID().uuidString).\(ext)"
            if JSONStore.writeAttachment(data, named: storedName) {
                let attachment = FileAttachment.make(fileName: originalName)
                var task = Task(title: title)
                task.fileAttachments = [attachment]
                taskStore.add(task)
            }
        }
    }

    private func selectFileAttachment() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = "Select document or image to add as task"
        panel.begin { response in
            if response == .OK, let url = panel.url {
                let customTitle = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : text.trimmingCharacters(in: .whitespacesAndNewlines)
                createTaskFromFile(url: url, customTitle: customTitle)
                text = ""
            }
        }
    }
}