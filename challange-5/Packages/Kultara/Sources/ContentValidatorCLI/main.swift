import ContentKit
import Foundation

// The build-time content gate (`NFR-MAINT-02`). Every rule lives in `ContentKit` so the runtime
// loader and this command cannot disagree about what valid content is; this file is argument
// handling and an exit code.
//
//   content-validator <content-directory>
//
// Exit 0 when all sixteen rules pass, 1 otherwise. Nothing else — a CI step needs one bit.

let arguments = Array(CommandLine.arguments.dropFirst())

guard let path = arguments.first, !path.hasPrefix("-") else {
    FileHandle.standardError.write(Data("""
    usage: content-validator <content-directory>

    Validates an authored content tree against rules V1–V16 of docs/schema.md §A.9.
    The directory is the one holding manifest.json, places/, quests/, assets/ and consent/.

    consent/ must be present: V4 and V5 enforce NFR-GOV-01 and NFR-GOV-03, and a run that
    silently skips them would report a pass it has not earned.

    """.utf8))
    exit(2)
}

let root = URL(fileURLWithPath: path).standardizedFileURL
let report = ContentValidationRun.run(contentRoot: root)

print(report.text)
exit(report.exitCode)
