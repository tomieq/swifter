import Swifter
import Dispatch
import Foundation
import AudioToolbox

let clientTimeout = ThreadSafeCache<String, CFAbsoluteTime>()
let server = HttpServer()
server.name = "Web Switch"
server.globalHeaders.addHeader("X-Now", Int(Date().timeIntervalSince1970))
server.requestBodyLimit = .limit(.KB(100))

server.metrics.onOpenConnectionsChanged = { number in
    print("amount of connections: \(number)")
}

server.middleware.append( { request, header in
   print("Request \(request.id) \(request.method) \(request.path) \(request.queryParams.dict) from \(request.clientIP ?? "")")
   print("Request \(request.id) body: \(request.body.string ?? "nil")")
   print("Request \(request.id) headers: \n\(request.headers.dict.map{ "\($0.key): \($0.value)" }.joined(separator: "\n"))")
   request.onFinished  { summary in
       print("Request \(summary.requestID) finished with \(summary.responseCode) [\(summary.responseSize)] in \(String(format: "%.3f", summary.durationInSeconds)) seconds")
   }
   return nil
})

server.notFoundHandler = { request, _ in
    .ok(.text("works"))
}
/*
let elfHeader: [UInt8] = [0x7f, 0x45, 0x4c, 0x46,
                          0x02, 0x01, 0x01, 0x03]
server.notFoundHandler = { request, _ in
    DispatchQueue.main.async {
        AudioServicesPlayAlertSound(1057)
    }
    let startTime = CFAbsoluteTimeGetCurrent()
    var elapsedTime = startTime
    var closedGracefully = false
    let clientIP = request.clientIP ?? ""
    request.onFinished { _ in
        if !closedGracefully {
            let timeout = elapsedTime - 0.09
            print("Updated timeout for clientIP: \(clientIP) with \(timeout.readable) seconds")
            clientTimeout[clientIP] = elapsedTime - 0.09
        }
    }
    let timeout = clientTimeout[clientIP] ?? 29
    print("Starting generating random data within timeout: \(timeout.readable) seconds")
    return .raw(200, "OK", { writer in
        try writer.write(elfHeader)
        for _ in 0...800 {
            for _ in 0...2048 {
//                    try writer.write(Data.random(length: 512))
                try writer.write(Data(repeating: UInt8.random(in: UInt8.min...UInt8.max), count: 512))
//                    try writer.write(Data(repeating: 0x55, count: 512))
                elapsedTime = CFAbsoluteTimeGetCurrent() - startTime
                if elapsedTime > timeout {
                    closedGracefully = true
                    return
                }
            }
        }
    })
}
 */
let semaphore = DispatchSemaphore(value: 0)
do {
    try server.start(443, forceIPv4: true)
    print("Server has started port = \(try server.port). Try to connect now...")
    semaphore.wait()
} catch {
    print("Server start error: \(error)")
    semaphore.signal()
}

extension Double {
    var readable: String {
        String(format: "%.3f", self)
    }
}
