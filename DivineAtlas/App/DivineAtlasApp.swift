import SwiftUI

@main
struct DivineAtlasApp: App {
    private let container: DependencyContainer

    init() {
        container = .live()
        Theme.configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView(container: container)
                .preferredColorScheme(.dark)
        }
    }
}
