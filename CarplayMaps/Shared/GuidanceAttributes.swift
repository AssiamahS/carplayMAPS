import Foundation
import ActivityKit

struct GuidanceAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        var instruction: String
        var distance: String
        var eta: String
    }

    var destination: String
}
