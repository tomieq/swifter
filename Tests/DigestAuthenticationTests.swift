import Foundation
import Testing
@testable import Swifter

@Suite struct DigestAuthenticationTests {
    @Test func validDigest() {
        let realm = "MyRealm"
        let username = "alice"
        let password = "secret"
        let nonce = "nonce123"
        let cnonce = "cnonce"
        let nc = "00000001"
        let qop = "auth"
        let path = "/protected"

        let auth = DigestAuthentication(realm: realm) { user in
            return user == username ? password : nil
        }

        let request = HttpRequest(socketID: UUID())
        request.method = HttpMethod.GET
        request.path = path

        let ha1 = "\(username):\(realm):\(password)".utf8.md5.rawValue
        let ha2 = "GET:\(path)".utf8.md5.rawValue
        let response = Array("\(ha1):\(nonce):\(nc):\(cnonce):\(qop):\(ha2)".utf8).md5.rawValue

        let header = "Digest username=\"\(username)\", realm=\"\(realm)\", nonce=\"\(nonce)\", uri=\"\(path)\", response=\"\(response)\", qop=\(qop), nc=\(nc), cnonce=\"\(cnonce)\""
        request.headers.storage.append(("Authorization", header))

        do {
            let user = try auth.authorizedUser(request)
            #expect(user == username)
        } catch {
            Issue.record("Expected to authorize, but got error: \(error)")
        }
    }
}
