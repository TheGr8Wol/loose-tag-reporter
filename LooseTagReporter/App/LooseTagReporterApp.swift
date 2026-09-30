import SwiftUI

@main
struct LooseTagReporterApp: App {
    @State private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootRouter(container: container)
                .environment(container)
        }
    }
}
