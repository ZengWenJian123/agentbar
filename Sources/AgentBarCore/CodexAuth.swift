import Foundation

public struct CodexCredentials: Equatable, Sendable {
    public let accessToken: String
    public let accountID: String?
    public let displayName: String?

    public init(accessToken: String, accountID: String?, displayName: String?) {
        self.accessToken = accessToken
        self.accountID = accountID
        self.displayName = displayName
    }
}

public enum CodexAuthState: Equatable, Sendable {
    case credentials(CodexCredentials)
    case unsupportedAPIKey
    case notLoggedIn
    case notConfigured(URL)
    case invalid(String)
}

public struct CodexAuthLoader {
    private let fileManager: FileManager
    private let environment: @Sendable () -> [String: String]
    private let homeDirectory: @Sendable () -> URL

    public init(
        fileManager: FileManager = .default,
        environment: @escaping @Sendable () -> [String: String] = { ProcessInfo.processInfo.environment },
        homeDirectory: @escaping @Sendable () -> URL = { FileManager.default.homeDirectoryForCurrentUser }
    ) {
        self.fileManager = fileManager
        self.environment = environment
        self.homeDirectory = homeDirectory
    }

    public func load() -> CodexAuthState {
        let url = authURL()
        guard fileManager.fileExists(atPath: url.path) else {
            return .notConfigured(url)
        }

        do {
            let data = try Data(contentsOf: url)
            let auth = try JSONDecoder().decode(CodexAuthFile.self, from: data)
            return state(from: auth)
        } catch {
            return .invalid(PrivacyScrubber.scrub(error.localizedDescription))
        }
    }

    public func authURL() -> URL {
        if let codexHome = environment()["CODEX_HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !codexHome.isEmpty {
            return URL(fileURLWithPath: codexHome, isDirectory: true).appendingPathComponent("auth.json")
        }
        return homeDirectory().appendingPathComponent(".codex", isDirectory: true).appendingPathComponent("auth.json")
    }

    private func state(from auth: CodexAuthFile) -> CodexAuthState {
        let accessToken = auth.tokens?.accessToken?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let apiKey = auth.openAIAPIKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !accessToken.isEmpty {
            return .credentials(
                CodexCredentials(
                    accessToken: accessToken,
                    accountID: auth.tokens?.accountID?.nilIfBlank,
                    displayName: displayName(from: auth.tokens?.idToken)
                )
            )
        }

        if !apiKey.isEmpty {
            return .unsupportedAPIKey
        }

        return .notLoggedIn
    }

    private func displayName(from idToken: String?) -> String? {
        guard let idToken, !idToken.isEmpty else { return nil }
        let pieces = idToken.split(separator: ".")
        guard pieces.count >= 2,
              let data = Data(base64URLEncoded: String(pieces[1])),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let email = (object["email"] as? String)?.nilIfBlank {
            return email
        }
        if let sub = (object["sub"] as? String)?.nilIfBlank, sub.contains("@") {
            return sub
        }
        return nil
    }
}

private struct CodexAuthFile: Decodable {
    let openAIAPIKey: String?
    let tokens: CodexAuthTokens?

    enum CodingKeys: String, CodingKey {
        case openAIAPIKey = "OPENAI_API_KEY"
        case tokens
    }
}

private struct CodexAuthTokens: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let idToken: String?
    let accountID: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case idToken = "id_token"
        case accountID = "account_id"
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension Data {
    init?(base64URLEncoded value: String) {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        self.init(base64Encoded: base64)
    }
}
