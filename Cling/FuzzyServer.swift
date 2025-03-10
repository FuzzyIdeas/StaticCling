import Foundation
import Lowtech
import Network

let SERVER_PORT = UInt16.random(in: 10000 ... 60000)

@MainActor
class FuzzyServer {
    func start() {
        do {
            let port = NWEndpoint.Port(rawValue: SERVER_PORT)!
            listener = try NWListener(using: .tcp, on: port)
            listener?.newConnectionHandler = { connection in
                mainActor { FUZZY.fetchResults() }
                connection.cancel()
            }
            listener?.start(queue: queue)
            print("Listening on port \(port)")
        } catch {
            print("Failed to start listener: \(error)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    private var listener: NWListener?
    private let queue = DispatchQueue(label: "FuzzyServerQueue")

}

@MainActor let FUZZY_SERVER = FuzzyServer()
