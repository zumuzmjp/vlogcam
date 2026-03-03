import Foundation

enum AppGroup {
    static let identifier = "group.zumzumjp.VlogCam"

    static var containerURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)!
    }
}
