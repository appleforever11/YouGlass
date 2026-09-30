import Foundation
import Combine

@MainActor
final class YouGlassSearchState: ObservableObject {
    @Published var query = ""
    @Published var results: [VideoItem] = []
    @Published var isLoading = false
    @Published var message = "Search YouTube"
    @Published var emptyMessage: String?
}
