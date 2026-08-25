import SwiftUI
import UniformTypeIdentifiers

struct ReminderBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var backup: ReminderBackup

    init(backup: ReminderBackup) {
        self.backup = backup
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        backup = try JSONDecoder.rjBackup.decode(ReminderBackup.self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = try JSONEncoder.rjBackup.encode(backup)
        return FileWrapper(regularFileWithContents: data)
    }
}

extension JSONEncoder {
    static var rjBackup: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var rjBackup: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
