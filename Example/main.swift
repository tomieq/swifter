import Swifter
import Foundation

let server = HttpServer()

do {
    try server.start(9080, forceIPv4: true)
    print("Server has started (port = \(try server.port)). Try to connect now...")
    RunLoop.main.run()
} catch {
    print("Server start error: \(error)")
}
