import SwiftUI

struct ContentView: View {
    @Environment(SlackArchive.self) private var archive

    var body: some View {
        Group {
            if !archive.isLoaded && !archive.isLoading {
                welcomeView
            } else if archive.isLoading {
                loadingView
            } else {
                mainLayout
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .preferredColorScheme(.dark)
        .background(SlackTheme.mainBg)
    }

    // MARK: - Welcome Screen

    @Environment(\.openWindow) private var openWindow

    private var welcomeView: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer(minLength: 40)

                // Hero
                VStack(spacing: 12) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.secondary)
                    Text("Slaback")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                    Text("Slack Archive Viewer")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 28)

                // Steps
                VStack(alignment: .leading, spacing: 0) {
                    stepRow(
                        number: "1",
                        title: "Export your Slack workspace",
                        detail: "Go to your Slack workspace settings, then Import/Export Data, and choose Export. Slack will email you a download link when the .zip file is ready. This export contains all your messages and channel history as JSON files."
                    )

                    stepDivider

                    stepRow(
                        number: "2",
                        title: "Unzip the export",
                        detail: "Extract the .zip file. You'll get a folder containing channels.json, users.json, and a subfolder for each channel with daily message files (e.g. general/2024-01-15.json)."
                    )

                    stepDivider

                    stepRow(
                        number: "3",
                        title: "Download attached files (optional)",
                        detail: "Slack exports include message text but not the actual files and images people shared. The export only contains URLs that expire. To download them before the links expire, use the bundled download script."
                    )

                    HStack {
                        Spacer().frame(width: 40)
                        Button {
                            openWindow(id: "download-script")
                        } label: {
                            Label("View File Download Script", systemImage: "arrow.down.doc")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .padding(.leading, 16)
                        .padding(.bottom, 8)
                    }

                    stepDivider

                    stepRow(
                        number: "4",
                        title: "Open the folder here",
                        detail: "Point Slaback at your unzipped export folder. All reading happens locally — nothing leaves your Mac."
                    )
                }
                .frame(maxWidth: 520, alignment: .leading)

                Spacer(minLength: 24)

                // Open button
                Button {
                    openExportFolder()
                } label: {
                    Text("Open Slack Export Folder")
                        .font(.system(size: 15))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: "611f69"))
                .controlSize(.large)

                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Step Components

    private func stepRow(number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color(hex: "611f69")))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundStyle(SlackTheme.secondaryText)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var stepDivider: some View {
        HStack {
            Spacer().frame(width: 28)
            Rectangle()
                .fill(SlackTheme.divider)
                .frame(width: 1, height: 12)
            Spacer()
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Loading Screen

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text(archive.loadingProgress)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Main 3-Column Layout

    private var mainLayout: some View {
        HStack(spacing: 0) {
            SidebarView()
                .frame(width: 240)

            Divider()

            MessageListView()
                .frame(minWidth: 400)

            if archive.selectedThreadTs != nil {
                Divider()
                ThreadPanelView()
                    .frame(width: 340)
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: archive.selectedThreadTs != nil)
    }

    // MARK: - Folder Picker

    private func openExportFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select a Slack export folder"
        panel.prompt = "Open"

        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await archive.loadExport(from: url)
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(SlackArchive())
}
