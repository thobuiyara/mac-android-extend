// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ExtendDisplay",
    platforms: [.macOS(.v13)],
    targets: [
        // Khai báo private API CGVirtualDisplay (CoreGraphics). Tách riêng để dễ sửa khi macOS thay đổi.
        .target(
            name: "CGVirtualDisplayPrivate",
            path: "Sources/CGVirtualDisplayPrivate",
            linkerSettings: [.linkedFramework("CoreGraphics")]
        ),
        .executableTarget(
            name: "ExtendDisplay",
            dependencies: ["CGVirtualDisplayPrivate"],
            path: "Sources/ExtendDisplay",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ScreenCaptureKit"),
                .linkedFramework("VideoToolbox"),
                .linkedFramework("Network"),
            ]
        ),
    ]
)
