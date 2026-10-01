import Foundation

enum IconBuildError: LocalizedError {
    case invalidArguments

    var errorDescription: String? {
        switch self {
        case .invalidArguments:
            "Usage: create_icns.swift <AppIcon.iconset> <AppIcon.icns>"
        }
    }
}

func bigEndian(_ value: UInt32) -> [UInt8] {
    [
        UInt8((value >> 24) & 0xff),
        UInt8((value >> 16) & 0xff),
        UInt8((value >> 8) & 0xff),
        UInt8(value & 0xff),
    ]
}

do {
    let arguments = CommandLine.arguments
    guard arguments.count == 3 else { throw IconBuildError.invalidArguments }

    let iconset = URL(fileURLWithPath: arguments[1], isDirectory: true)
    let destination = URL(fileURLWithPath: arguments[2])
    let representations = [
        ("icp4", "icon_16x16.png"),
        ("icp5", "icon_32x32.png"),
        ("icp6", "icon_32x32@2x.png"),
        ("ic07", "icon_128x128.png"),
        ("ic08", "icon_256x256.png"),
        ("ic09", "icon_512x512.png"),
        ("ic10", "icon_512x512@2x.png"),
    ]

    var elements = Data()
    for (type, filename) in representations {
        let png = try Data(contentsOf: iconset.appendingPathComponent(filename))
        elements.append(type.data(using: .ascii)!)
        elements.append(contentsOf: bigEndian(UInt32(png.count + 8)))
        elements.append(png)
    }

    var icon = Data()
    icon.append("icns".data(using: .ascii)!)
    icon.append(contentsOf: bigEndian(UInt32(elements.count + 8)))
    icon.append(elements)
    try icon.write(to: destination, options: .atomic)
} catch {
    fputs("App-icon build failed: \(error.localizedDescription)\n", stderr)
    exit(1)
}
