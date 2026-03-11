import SwiftUI

@main
struct SlabackApp: App {
    @State private var archive = SlackArchive()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(archive)
        }
        .defaultSize(width: 1200, height: 800)

        Window("File Download Script", id: "download-script") {
            FileDownloadScriptView()
        }
        .defaultSize(width: 750, height: 600)
    }
}
