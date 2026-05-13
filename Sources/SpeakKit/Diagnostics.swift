import Foundation

public enum Diagnostics {
    public static func log(_ message: @autoclosure () -> String) {
        let line = "speak: \(message())\n"
        FileHandle.standardError.write(Data(line.utf8))
    }
}
