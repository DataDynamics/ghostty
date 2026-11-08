import Foundation

struct SSHProfile: Codable, Identifiable, Equatable {
    enum Authentication: String, Codable, CaseIterable, Identifiable {
        case configuration, password, privateKey, certificate
        var id: Self { self }
        var title: String {
            switch self {
            case .configuration: return "SSH Configuration"
            case .password: return "Password"
            case .privateKey: return "Private Key"
            case .certificate: return "Private Key + OpenSSH Certificate"
            }
        }
    }

    var id = UUID()
    var name = ""
    var folderID: UUID?
    var favorite = false
    var destination = ""
    var username = ""
    var port: Int?
    var authentication: Authentication = .configuration
    var identityFile = ""
    var certificateFile = ""
    var passwordID: UUID?
    var passphraseID: UUID?

    func validate() throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SSHError.message("Enter a connection name.")
        }
        let hostCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._:%")
        guard !destination.isEmpty, !destination.hasPrefix("-"),
              destination.unicodeScalars.allSatisfy({ hostCharacters.contains($0) }) else {
            throw SSHError.message("Enter a hostname, IP address, or SSH alias without a user or port.")
        }
        let userCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        guard !username.hasPrefix("-"), username.unicodeScalars.allSatisfy({ userCharacters.contains($0) }) else {
            throw SSHError.message("The username contains unsupported characters.")
        }
        if let port, !(1...65535).contains(port) { throw SSHError.message("Port must be between 1 and 65535.") }
        if authentication == .privateKey || authentication == .certificate {
            guard identityFile.hasPrefix("/"), !identityFile.contains("\n"), !identityFile.contains("\0") else {
                throw SSHError.message("Choose an absolute private key path.")
            }
        }
        if authentication == .certificate {
            guard certificateFile.hasPrefix("/"), !certificateFile.contains("\n"), !certificateFile.contains("\0") else {
                throw SSHError.message("Choose an absolute OpenSSH certificate path.")
            }
        }
    }
}

struct SSHFolder: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
}

struct SSHSessionDocument: Codable, Equatable {
    var schemaVersion = 1
    var folders: [SSHFolder] = []
    var profiles: [SSHProfile] = []
}

enum SSHError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let text): return text }
    }
}

enum SSHInvocation {
    static func arguments(for profile: SSHProfile, manual: Bool = false) throws -> [String] {
        try profile.validate()
        // Keep the session in this PTY and prevent reuse of an already-authenticated master.
        var args = ["-o", "StrictHostKeyChecking=ask", "-o", "ControlMaster=no", "-o", "ControlPath=none",
                    "-o", "ForkAfterAuthentication=no", "-o", "PermitLocalCommand=no", "-o", "NumberOfPasswordPrompts=1"]
        if !profile.username.isEmpty { args += ["-l", profile.username] }
        if let port = profile.port { args += ["-p", String(port)] }
        switch profile.authentication {
        case .configuration: break
        case .password:
            args += ["-o", manual ? "PreferredAuthentications=keyboard-interactive,password" : "PreferredAuthentications=password"]
        case .privateKey, .certificate:
            args += ["-o", "PreferredAuthentications=publickey", "-o", "IdentitiesOnly=yes", "-i", profile.identityFile]
            if profile.authentication == .certificate {
                args += ["-o", "CertificateFile=\"\(configQuote(profile.certificateFile))\""]
            }
        }
        return args + ["--", profile.destination]
    }

    static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func configQuote(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }
}

/// Stored alongside the value inside Keychain, binding a secret to its original connection.
struct SSHCredentialContext: Codable, Equatable {
    var destination: String
    var username: String
    var port: Int?
    var authentication: SSHProfile.Authentication
    var identityFile: String
    var certificateFile: String

    init(_ profile: SSHProfile) {
        destination = profile.destination
        username = profile.username
        port = profile.port
        authentication = profile.authentication
        identityFile = profile.identityFile
        certificateFile = profile.certificateFile
    }
}
