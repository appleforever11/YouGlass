import SwiftUI

struct YouGlassAppRoot: View {
    @EnvironmentObject private var store: YouTubeStore
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        YouTubeHomeView()
            .onAppear { store.configureNativeMediaControls() }
            .onChange(of: scenePhase) { _, phase in
                store.handleScenePhaseChange(phase)
            }
    }
}
