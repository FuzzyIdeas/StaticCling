import Defaults
import Lowtech
import SwiftUI
import System

struct ActionButtons: View {
    @Binding var selectedResults: Set<FilePath>
    var focused: FocusState<FocusedField?>.Binding

    @State private var appManager: AppManager = APP_MANAGER
    @State private var fuzzy: FuzzyClient = FUZZY
    @State private var scriptManager: ScriptManager = SM
    @Default(.suppressTrashConfirm) var suppressTrashConfirm: Bool
    @Default(.terminalApp) var terminalApp
    @ObservedObject var km = KM

    var body: some View {
        let inTerminal = appManager.frontmostAppIsTerminal

        HStack {
            openButton(inTerminal: inTerminal)
            showInFinderButton
            pasteToFrontmostAppButton(inTerminal: inTerminal)
            openInTerminalButton
            Spacer()
            openWithPickerButton
            Spacer()
            copyFilesButton.disabled(focused.wrappedValue != .list)
            copyPathsButton
            trashButton.disabled(focused.wrappedValue != .list)
            quicklookButton
            renameButton
        }
        .font(.system(size: 10))
        .buttonStyle(TextButton(color: .fg.warm.opacity(0.9)))
        .lineLimit(1)
    }

    private func pasteToFrontmostApp(inTerminal: Bool) {
        if inTerminal {
            appManager.pasteToFrontmostApp(paths: selectedResults.arr, separator: " ", quoted: true)
        } else {
            appManager.pasteToFrontmostApp(
                paths: selectedResults.arr, separator: "\n", quoted: false
            )
        }
    }

    private var showInFinderButton: some View {
        Button("⌘⏎ Show in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting(selectedResults.map(\.url))
        }
        .keyboardShortcut(.return, modifiers: [.command])
        .help("Show the selected files in Finder")
    }

    @ViewBuilder
    private var openInTerminalButton: some View {
        if let terminal = terminalApp.existingFilePath?.url {
            Button("⌘T Open in \(terminalApp.filePath?.stem ?? "Terminal")") {
                let dirs = selectedResults.map { $0.isDir ? $0.url : $0.dir.url }.uniqued
                NSWorkspace.shared.open(
                    dirs, withApplicationAt: terminal, configuration: .init(),
                    completionHandler: { _, _ in }
                )
            }
            .keyboardShortcut("t", modifiers: [.command])
            .help("Open the selected files in Terminal")
        }
    }

    private var copyFilesButton: some View {
        Button(action: copyFiles) {
            Text("⌘C Copy")
        }
        .keyboardShortcut("c", modifiers: [.command])
        .help("Copy the selected files")
    }

    private var copyPathsButton: some View {
        Button(action: copyPaths) {
            Text("⌘⇧C Copy paths")
        }
        .keyboardShortcut("c", modifiers: [.command, .shift])
        .help("Copy the paths of the selected files")
    }

    private var openWithPickerButton: some View {
        Button("") {
            focused.wrappedValue = .openWith
            isPresentingOpenWithPicker = true
        }
        .keyboardShortcut("o", modifiers: [.command])
        .opacity(0)
        .frame(width: 0)
        .sheet(isPresented: $isPresentingOpenWithPicker) {
            OpenWithPickerView(fileURLs: selectedResults.map(\.url))
                .font(.medium(13))
                .focused(focused, equals: .openWith)
        }
        .disabled(selectedResults.isEmpty || fuzzy.openWithAppShortcuts.isEmpty)
    }

    @ViewBuilder
    private var trashButton: some View {
        if km.ralt || km.lalt {
            Button("⌘⌥⌫ Permanently delete", role: .destructive) {
                permanentlyDelete()
            }
            .keyboardShortcut(.delete, modifiers: [.command, .option])
            .help("Permanently delete the selected files")
        } else {
            Button("⌘⌫ Trash", role: .destructive) {
                if suppressTrashConfirm {
                    moveToTrash()
                } else {
                    isPresentingConfirm = true
                }
            }
            .keyboardShortcut(.delete, modifiers: [.command])
            .help("Move the selected files to the trash")
            .confirmationDialog(
                "Are you sure?",
                isPresented: $isPresentingConfirm
            ) {
                Button("Move to trash") {
                    moveToTrash()
                }.keyboardShortcut(.defaultAction)
            }
            .dialogIcon(Image(systemName: "trash.circle.fill"))
            .dialogSuppressionToggle(isSuppressed: $suppressTrashConfirm)
        }
    }

    private func permanentlyDelete() {
        var removed = Set<FilePath>()
        for path in selectedResults {
            log.info("Permanently deleting \(path.shellString)")
            do {
                try FileManager.default.removeItem(at: path.url)
                removed.insert(path)
            } catch {
                log.error("Error deleting \(path.shellString): \(error)")
            }
        }

        selectedResults.subtract(removed)
        fuzzy.results = fuzzy.results.filter { !removed.contains($0) && $0.exists }
    }

    private var quicklookButton: some View {
        Button(action: quicklook) {
            Text("⌘Y Quicklook")
        }
        .keyboardShortcut("y", modifiers: [.command])
        .help("Preview the selected files")
    }

    private var renameButton: some View {
        Button("⌘R Rename") {
            isPresentingRenameView = true
        }
        .sheet(isPresented: $isPresentingRenameView, onDismiss: renameFiles) {
            RenameView(originalPaths: selectedResults.arr, renamedPaths: $renamedPaths)
        }
        .keyboardShortcut("r", modifiers: [.command])
        .help("Rename the selected files")
    }

    private func openButton(inTerminal: Bool) -> some View {
        Button(action: openSelectedResults) {
            Text(inTerminal ? "⌘⇧⏎" : "⏎") + Text(" Open")
        }
        .keyboardShortcut(.return, modifiers: inTerminal ? [.command, .shift] : [])
        .help("Open the selected files with their default app")
    }

    private func pasteToFrontmostAppButton(inTerminal: Bool) -> some View {
        Button(action: { pasteToFrontmostApp(inTerminal: inTerminal) }) {
            Text(inTerminal ? "⏎" : "⌘⇧⏎")
                + Text(" Paste to \(appManager.lastFrontmostApp?.name ?? "frontmost app")")
        }
        .keyboardShortcut(.return, modifiers: inTerminal ? [] : [.command, .shift])
        .help("Paste the paths of the selected files to the frontmost app")
    }

    private func copyFiles() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects(selectedResults.map(\.url) as [NSPasteboardWriting])
    }

    private func copyPaths() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(
            appManager.frontmostAppIsTerminal
                ? selectedResults.map { $0.shellString.replacingOccurrences(of: " ", with: "\\ ") }.joined(separator: " ")
                : selectedResults.map(\.string).joined(separator: "\n"), forType: .string
        )
    }

    private func moveToTrash() {
        var removed = Set<FilePath>()
        for path in selectedResults {
            log.info("Trashing \(path.shellString)")
            do {
                try FileManager.default.trashItem(at: path.url, resultingItemURL: nil)
                removed.insert(path)
            } catch {
                log.error("Error trashing \(path.shellString): \(error)")
            }
        }

        selectedResults.subtract(removed)
        fuzzy.results = fuzzy.results.filter { !removed.contains($0) && $0.exists }
    }

    private func quicklook() {
        QuickLooker.quicklook(urls: selectedResults.map(\.url))
    }

    private func openSelectedResults() {
        for url in selectedResults.map(\.url) {
            NSWorkspace.shared.open(url)
        }
    }

    private func renameFiles() {
        NSApp.mainWindow?.becomeKey()
        focus()

        guard let renamedPaths else { return }
        do {
            let renamed = try performRenameOperation(
                originalPaths: selectedResults.arr, renamedPaths: renamedPaths
            )
            fuzzy.results = fuzzy.results.map { renamed[$0] ?? $0 }
            selectedResults = selectedResults.map { renamed[$0] ?? $0 }.set
        } catch {
            log.error("Error renaming files: \(error)")
        }
        self.renamedPaths = nil
    }

    @State private var isPresentingRenameView = false
    @State private var renamedPaths: [FilePath]? = nil
    @State private var isPresentingOpenWithPicker = false
    @State private var isPresentingConfirm = false
}
