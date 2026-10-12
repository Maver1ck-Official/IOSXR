import CryptoKit
import Foundation
import os
import SwiftUI

struct ExperienceManifest: Codable, Identifiable {
    let id: String
    let title: String
    let version: String
    let runtimeVersion: Int
    let tiles: [ExperienceTile]
    let assets: [ExperienceAsset]
}

struct ExperienceTile: Codable, Identifiable {
    let id: String
    let title: String
    let symbol: String
}

struct ExperienceAsset: Codable {
    let path: String
    let url: URL
    let sha256: String
}

protocol ManifestSignatureVerifier {
    func verify(signature: Data, message: Data) -> Bool
}

struct Ed25519ManifestVerifier: ManifestSignatureVerifier {
    private let publicKey: Curve25519.Signing.PublicKey

    init(publicKey: Data) throws {
        self.publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKey)
    }

    func verify(signature: Data, message: Data) -> Bool {
        publicKey.isValidSignature(signature, for: message)
    }
}

enum PackageInstallError: Error {
    case insecureURL
    case invalidSignature
    case invalidManifest
    case invalidResponse
    case invalidInstalledPackage
    case incompatibleRuntime
    case packageTooLarge
    case checksumMismatch(String)
}

struct CommunityPackageInstaller {
    static let runtimeVersion = 1
    private static let logger = Logger(
        subsystem: "com.iosxr.app",
        category: "package-installation"
    )
    private let fileManager = FileManager.default
    private let session: URLSession
    private let maximumManifestSize = 256 * 1024
    private let maximumAssetSize = 50 * 1024 * 1024
    private let maximumPackageSize = 100 * 1024 * 1024

    init(session: URLSession = .shared) {
        self.session = session
    }

    func install(
        manifestURL: URL,
        signature: Data,
        verifier: any ManifestSignatureVerifier
    ) async throws -> URL {
        guard manifestURL.scheme?.lowercased() == "https" else {
            throw PackageInstallError.insecureURL
        }

        let manifestData = try await downloadData(
            from: manifestURL,
            maximumSize: maximumManifestSize
        )
        guard verifier.verify(signature: signature, message: manifestData) else {
            throw PackageInstallError.invalidSignature
        }

        let manifest: ExperienceManifest
        do {
            manifest = try JSONDecoder().decode(ExperienceManifest.self, from: manifestData)
        } catch {
            throw PackageInstallError.invalidManifest
        }
        try validate(manifest)

        let root = try experiencesDirectory()
        let staging = root.appendingPathComponent(".install-\(UUID().uuidString)", isDirectory: true)
        let destination = root
            .appendingPathComponent(manifest.id, isDirectory: true)
            .appendingPathComponent(manifest.version, isDirectory: true)

        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
        do {
            var totalAssetSize = 0
            for asset in manifest.assets {
                let data = try await downloadData(from: asset.url, maximumSize: maximumAssetSize)
                totalAssetSize += data.count
                guard totalAssetSize <= maximumPackageSize else {
                    throw PackageInstallError.packageTooLarge
                }
                let digest = SHA256.hash(data: data)
                    .map { String(format: "%02x", $0) }
                    .joined()
                guard digest == asset.sha256.lowercased() else {
                    throw PackageInstallError.checksumMismatch(asset.path)
                }

                let fileURL = staging.appendingPathComponent(asset.path)
                try fileManager.createDirectory(
                    at: fileURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try data.write(to: fileURL, options: .atomic)
            }

            let manifestFile = staging.appendingPathComponent("manifest.json")
            try manifestData.write(to: manifestFile, options: .atomic)
            try fileManager.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try fileManager.moveItem(at: staging, to: destination)
            return destination
        } catch {
            do {
                try fileManager.removeItem(at: staging)
            } catch {
                Self.logger.error("Could not clean failed package staging directory: \(error.localizedDescription, privacy: .public)")
            }
            throw error
        }
    }

    private func validate(_ manifest: ExperienceManifest) throws {
        let identifierPattern = "^[A-Za-z0-9][A-Za-z0-9.-]{0,79}$"
        guard
            manifest.id.range(of: identifierPattern, options: .regularExpression) != nil,
            !manifest.title.isEmpty,
            manifest.title.count <= 100,
            manifest.version.range(of: "^[A-Za-z0-9.-]{1,40}$", options: .regularExpression) != nil,
            manifest.runtimeVersion == Self.runtimeVersion,
            manifest.tiles.count <= 64,
            manifest.assets.count <= 128,
            Set(manifest.tiles.map(\.id)).count == manifest.tiles.count,
            Set(manifest.assets.map(\.path)).count == manifest.assets.count
        else {
            throw manifest.runtimeVersion == Self.runtimeVersion
                ? PackageInstallError.invalidManifest
                : PackageInstallError.incompatibleRuntime
        }

        for tile in manifest.tiles {
            guard
                !tile.id.isEmpty,
                tile.id.count <= 80,
                !tile.title.isEmpty,
                tile.title.count <= 100,
                tile.symbol.count <= 40
            else {
                throw PackageInstallError.invalidManifest
            }
        }

        for asset in manifest.assets {
            let components = asset.path.split(separator: "/", omittingEmptySubsequences: false)
            guard
                !components.isEmpty,
                components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }),
                !asset.path.hasPrefix("/"),
                asset.path != "manifest.json",
                asset.url.scheme?.lowercased() == "https",
                asset.url.host != nil,
                asset.sha256.range(of: "^[A-Fa-f0-9]{64}$", options: .regularExpression) != nil
            else {
                throw PackageInstallError.invalidManifest
            }
        }
    }

    private func downloadData(from url: URL, maximumSize: Int) async throws -> Data {
        let (temporaryURL, response) = try await session.download(from: url)
        defer {
            do {
                try fileManager.removeItem(at: temporaryURL)
            } catch {
                Self.logger.error("Could not remove temporary download: \(error.localizedDescription, privacy: .public)")
            }
        }

        guard
            response.url?.scheme?.lowercased() == "https",
            let httpResponse = response as? HTTPURLResponse,
            (200..<300).contains(httpResponse.statusCode)
        else {
            throw PackageInstallError.invalidResponse
        }

        let attributes = try fileManager.attributesOfItem(atPath: temporaryURL.path)
        guard
            let fileSize = attributes[.size] as? NSNumber,
            fileSize.intValue <= maximumSize
        else {
            throw PackageInstallError.packageTooLarge
        }
        return try Data(contentsOf: temporaryURL, options: .mappedIfSafe)
    }

    private func experiencesDirectory() throws -> URL {
        let support = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = support.appendingPathComponent("Experiences", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

struct LibraryView: View {
    @State private var experiences: [ExperienceManifest] = []
    @State private var selectedExperience: ExperienceManifest?
    @State private var loadError: String?

    var body: some View {
        NavigationStack {
            Group {
                if let loadError {
                    ContentUnavailableView(
                        "Library Could Not Be Loaded",
                        systemImage: "exclamationmark.triangle",
                        description: Text(loadError)
                    )
                } else if experiences.isEmpty {
                    ContentUnavailableView(
                        "Your Library Is Empty",
                        systemImage: "square.stack.3d.up",
                        description: Text("Verified, compatible experiences will appear here after installation.")
                    )
                } else {
                    List(experiences) { experience in
                        Button {
                            selectedExperience = experience
                        } label: {
                            Label(experience.title, systemImage: "play.rectangle")
                        }
                    }
                }
            }
            .navigationTitle("Library")
            .sheet(item: $selectedExperience) { experience in
                ExperienceRuntimeView(manifest: experience)
            }
            .task {
                do {
                    experiences = try loadInstalledExperiences()
                } catch {
                    loadError = error.localizedDescription
                }
            }
        }
    }

    private func loadInstalledExperiences() throws -> [ExperienceManifest] {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        let root = support.appendingPathComponent("Experiences", isDirectory: true)
        guard FileManager.default.fileExists(atPath: root.path) else {
            return []
        }

        let packageDirectories = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        var installed: [ExperienceManifest] = []
        for package in packageDirectories {
            let versions = try FileManager.default.contentsOfDirectory(
                at: package,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            for versionDirectory in versions {
                let manifestURL = versionDirectory.appendingPathComponent("manifest.json")
                guard FileManager.default.fileExists(atPath: manifestURL.path) else {
                    continue
                }
                do {
                    let data = try Data(contentsOf: manifestURL)
                    let manifest = try JSONDecoder().decode(ExperienceManifest.self, from: data)
                    guard manifest.runtimeVersion == CommunityPackageInstaller.runtimeVersion else {
                        continue
                    }
                    installed.append(manifest)
                } catch {
                    throw PackageInstallError.invalidInstalledPackage
                }
            }
        }
        return installed
    }
}

private struct ExperienceRuntimeView: View {
    let manifest: ExperienceManifest

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130))], spacing: 16) {
                    ForEach(manifest.tiles) { tile in
                        VStack(spacing: 12) {
                            Image(systemName: safeSymbol(tile.symbol))
                                .font(.largeTitle)
                            Text(tile.title)
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity, minHeight: 120)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                .padding()
            }
            .navigationTitle(manifest.title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func safeSymbol(_ requested: String) -> String {
        let allowedSymbols: Set<String> = [
            "star", "circle", "square", "heart", "bolt", "globe",
            "gamecontroller", "leaf", "moon", "sun.max"
        ]
        return allowedSymbols.contains(requested) ? requested : "square"
    }
}
