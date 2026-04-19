// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BizboxNotch",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "BizboxNotch", targets: ["BizboxNotch"])
    ],
    targets: [
        .executableTarget(
            name: "BizboxNotch",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("WebKit"),
                .linkedFramework("Security"),
                .linkedFramework("UserNotifications")
            ]
        )
    ]
)
