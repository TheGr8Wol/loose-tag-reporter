import Foundation
import Security
import TagReportingCore
import CryptoKit

enum StaffCodePolicy {
    static let minLength = 4
    static let maxLength = 10

    static func isValid(_ code: String) -> Bool {
        guard (minLength...maxLength).contains(code.count) else { return false }
        return code.allSatisfy(\.isNumber)
    }
}

struct StaffSession: Equatable, Sendable, Codable {
    var empID: String
    var authenticatedAt: Date
    var lastActiveAt: Date
}

enum SessionConfig {
    /// Background gap beyond which the prior staff is logged out.
    static let idleTimeout: TimeInterval = 15 * 60
}

@MainActor
@Observable
final class SessionStore {
    private(set) var session: StaffSession?
    private let keychain = KeychainSessionPersistence()

    var isAuthenticated: Bool { session != nil }

    var currentReporter: ReporterContext? {
        guard let session else { return nil }
        return ReporterContext(empID: session.empID, capturedAt: session.authenticatedAt)
    }

    init() {
        if let loaded = keychain.load() {
            // Cold launch must honour idle window via lastActiveAt (A2-L-001).
            if Date().timeIntervalSince(loaded.lastActiveAt) > SessionConfig.idleTimeout {
                keychain.clear()
                session = nil
            } else {
                session = loaded
            }
        } else {
            session = nil
        }
    }

    @discardableResult
    func signIn(empID: String) -> Bool {
        guard StaffCodePolicy.isValid(empID) else { return false }
        let now = Date()
        let next = StaffSession(empID: empID, authenticatedAt: now, lastActiveAt: now)
        session = next
        keychain.save(next)
        return true
    }

    func signOut() {
        session = nil
        keychain.clear()
    }

    func touch() {
        guard var session else { return }
        session.lastActiveAt = Date()
        self.session = session
        keychain.save(session)
    }

    /// Call on foreground. Returns true if session was cleared due to idle timeout.
    @discardableResult
    func applyIdlePolicy(backgroundedAt: Date?) -> Bool {
        guard let session, let backgroundedAt else { return false }
        if Date().timeIntervalSince(backgroundedAt) > SessionConfig.idleTimeout {
            signOut()
            return true
        }
        touch()
        return false
    }

    /// Mid-draft re-auth by a different code → caller must discard draft + photos.
    func wouldReplaceReporter(with empID: String) -> Bool {
        guard let session else { return false }
        return session.empID != empID
    }
}

struct KeychainSessionPersistence {
    private let service = "com.example.loosetagreporter.session"
    private let account = "staff"

    func save(_ session: StaffSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }

    func load() -> StaffSession? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(StaffSession.self, from: data)
    }

    func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

/// POC role-PIN gate (supervisor + lp_admin). Salted SHA-256 + constant-time compare.
/// No PINs ship in source: they are provisioned out-of-band and only salted hashes are kept.
struct LocalDashboardAuth: DashboardAuthProviding, Sendable {
    private let salt: String
    private let supervisorHash: String
    private let lpAdminHash: String

    init(
        salt: String,
        supervisorPIN: String,
        lpAdminPIN: String
    ) {
        self.salt = salt
        self.supervisorHash = Self.hash(pin: supervisorPIN, salt: salt)
        self.lpAdminHash = Self.hash(pin: lpAdminPIN, salt: salt)
    }

    func verifySupervisorPIN(_ pin: String) async -> Bool {
        Self.constantTimeEquals(Self.hash(pin: pin, salt: salt), supervisorHash)
    }

    func verifyLPAdminPIN(_ pin: String) async -> Bool {
        Self.constantTimeEquals(Self.hash(pin: pin, salt: salt), lpAdminHash)
    }

    static func hash(pin: String, salt: String) -> String {
        let input = Data((salt + ":" + pin).utf8)
        let digest = SHA256.hash(data: input)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func constantTimeEquals(_ a: String, _ b: String) -> Bool {
        let aBytes = Array(a.utf8)
        let bBytes = Array(b.utf8)
        guard aBytes.count == bBytes.count else { return false }
        var diff: UInt8 = 0
        for i in 0..<aBytes.count {
            diff |= aBytes[i] ^ bBytes[i]
        }
        return diff == 0
    }
}

/// Default gate when no role PINs have been provisioned: every PIN is refused.
struct DenyAllDashboardAuth: DashboardAuthProviding, Sendable {
    func verifySupervisorPIN(_ pin: String) async -> Bool { false }
    func verifyLPAdminPIN(_ pin: String) async -> Bool { false }
}
