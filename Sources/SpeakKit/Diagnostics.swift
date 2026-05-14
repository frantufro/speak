import Foundation
import os

public enum Diagnostics {
    private static let logger = Logger(subsystem: "com.frantufro.speak", category: "speak")

    public static func log(_ message: @autoclosure () -> String) {
        let rendered = message()
        // os_log so GUI launches (Finder/Spotlight) are visible via
        // `log show --process speak --predicate 'subsystem == "com.frantufro.speak"'`.
        logger.log("\(rendered, privacy: .public)")
        // Mirror to stderr so terminal launches still see output inline.
        FileHandle.standardError.write(Data("speak: \(rendered)\n".utf8))
    }
}
