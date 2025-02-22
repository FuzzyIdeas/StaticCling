import Defaults
import Lowtech
import LowtechIndie
import SwiftUI

struct SettingsView: View {
    @ObservedObject var updateManager = UM

    @Default(.checkForUpdates) private var checkForUpdates
    @Default(.updateCheckInterval) private var updateCheckInterval
    @Default(.showWindowAtLaunch) private var showWindowAtLaunch

    private func selectApp(type: String, onCompletion: @escaping (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.title = "Select \(type) App"
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.directoryURL = "/Applications".fileURL

        if panel.runModal() == .OK, let url = panel.url {
            onCompletion(url)
        }
    }

    var body: some View {
        Form {
            HStack {
                (
                    Text("Text editor")
                        + Text("\nUsed for editing text files")
                        .round(11, weight: .regular).foregroundColor(.secondary)
                ).fixedSize()
                Spacer()
                Button(editorApp.filePath?.stem ?? "TextEdit") {
                    selectApp(type: "Text Editor") { url in
                        editorApp = url.path
                    }
                }.truncationMode(.middle)
            }
            HStack {
                (
                    Text("Terminal")
                        + Text("\nUsed for running shell commands and opening folders")
                        .round(11, weight: .regular).foregroundColor(.secondary)
                ).fixedSize()
                Spacer()
                Button(terminalApp.filePath?.stem ?? "Terminal") {
                    selectApp(type: "Terminal") { url in
                        terminalApp = url.path
                    }
                }.truncationMode(.middle)
            }

            HStack {
                (
                    Text("Ignore File")
                        + Text("\nUses gitignore syntax for excluding files from the index")
                        .round(11, weight: .regular).foregroundColor(.secondary)
                ).fixedSize()
                Spacer()
                Button("Edit Ignore File") {
                    NSWorkspace.shared.open([fsignore.url], withApplicationAt: editorApp.fileURL ?? "/Applications/TextEdit.app".fileURL!, configuration: .init(), completionHandler: { _, _ in })
                }.truncationMode(.middle)
            }

            Toggle(isOn: $showWindowAtLaunch) {
                (
                    Text("Show window at launch")
                        + Text("\nShow the main window when StaticCling is first launched")
                        .round(11, weight: .regular).foregroundColor(.secondary)
                ).fixedSize()
            }

            if let updater = updateManager.updater {
                Section(header: Text("Updates *(current version: `v\(Bundle.main.version)`)*")) {
                    Toggle("Automatically check for updates", isOn: $checkForUpdates)
                    Picker("Update check interval", selection: $updateCheckInterval) {
                        Text("Daily").tag(UpdateCheckInterval.daily.rawValue)
                        Text("Every 3 days").tag(UpdateCheckInterval.everyThreeDays.rawValue)
                        Text("Weekly").tag(UpdateCheckInterval.weekly.rawValue)
                    }.pickerStyle(.segmented)

                    GentleUpdateView(updater: updater)
                }
            }

        }
        .formStyle(.grouped)
        .padding()
        .alert(isPresented: $showErrorAlert) {
            Alert(
                title: Text("Error"), message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    @Default(.editorApp) private var editorApp
    @Default(.terminalApp) private var terminalApp
}
