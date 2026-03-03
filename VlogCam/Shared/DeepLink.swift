import Foundation

enum DeepLink {
    case record
    case album(String)

    static let scheme = "vlogcam"

    static func parse(_ url: URL) -> DeepLink? {
        guard url.scheme == scheme else { return nil }
        switch url.host {
        case "record":
            return .record
        case "album":
            if let id = url.pathComponents.dropFirst().first {
                return .album(id)
            }
            return nil
        default:
            return nil
        }
    }

    var url: URL {
        switch self {
        case .record:
            URL(string: "\(DeepLink.scheme)://record")!
        case .album(let id):
            URL(string: "\(DeepLink.scheme)://album/\(id)")!
        }
    }
}
