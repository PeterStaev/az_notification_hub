// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "az_notification_hub",
    platforms: [
        .iOS("13.0"),
    ],
    products: [
        // If the plugin name contains "_", replace with "-" for the library name.
        .library(name: "az-notification-hub", type: .static, targets: ["az_notification_hub"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        // TODO: Right now we can't use direct package deps because of https://github.com/Azure/azure-notificationhubs-ios/issues/150
        // .package(url: "https://github.com/Azure/azure-notificationhubs-ios.git", .upToNextMajor(from: "3.1.5")),
    ],
    targets: [
        // TODO: Right now we can't use direct package deps because of https://github.com/Azure/azure-notificationhubs-ios/issues/150
        // binaryTarget can be removed once problem is fixed. 
        .binaryTarget(
            name: "azure-notificationhubs-ios",
            url: "https://github.com/Azure/azure-notificationhubs-ios/releases/download/3.1.5/WindowsAzureMessaging-SDK-Apple-XCFramework-3.1.5.zip",
            checksum: "2e87b74a2959d01024458eb337c36cec8ab8d853b3e9c70077f9f6aa935c5007"
        ),
        .target(
            name: "az_notification_hub",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                // TODO: Right now we can't use direct package deps because of https://github.com/Azure/azure-notificationhubs-ios/issues/150
                // .product(name: "WindowsAzureMessaging", package: "azure-notificationhubs-ios"),
                "azure-notificationhubs-ios",
            ],
            resources: [
                // TODO: If your plugin requires a privacy manifest
                // (e.g. if it uses any required reason APIs), update the PrivacyInfo.xcprivacy file
                // to describe your plugin's privacy impact, and then uncomment this line.
                // For more information, visit:
                // https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
                // .process("PrivacyInfo.xcprivacy"),

                // TODO: If you have other resources that need to be bundled with your plugin, refer to
                // the following instructions to add them:
                // https://developer.apple.com/documentation/xcode/bundling-resources-with-a-swift-package
            ]
        )
    ]
)
