import Foundation

class ShogiUIInterface {
    var displayMessage: (String) -> Void
    var updateSearchProgress: (SearchProgress) -> Void
    init(displayMessage: @escaping (String) -> Void, updateSearchProgress: @escaping (SearchProgress) -> Void) {
        self.displayMessage = displayMessage
        self.updateSearchProgress = updateSearchProgress
    }
}

class MatchManager {
    let shogiUIInterface: ShogiUIInterface
    let usiServerIpAddress: String
    let csaConfig: CSAConfig
    var usiClient: USIClient?
    var csaClient: CSAClient?
    
    init(shogiUIInterface: ShogiUIInterface, usiServerIpAddress: String,
         csaConfig: CSAConfig) {
        self.shogiUIInterface = shogiUIInterface
        self.usiServerIpAddress = usiServerIpAddress
        self.csaConfig = csaConfig
    }
    
    func start() {
        usiClient = USIClient(matchManager: self, usiServerIpAddress: usiServerIpAddress)
        usiClient?.start()
    }
    
    func startCSA() {
        csaClient = CSAClient(matchManager: self, csaConfig: csaConfig)
        csaClient?.start()
    }
    
    func displayMessage(_ message: String) {
        shogiUIInterface.displayMessage(message)
    }
    
    func updateSearchProgress(searchProgress: SearchProgress) {
        shogiUIInterface.updateSearchProgress(searchProgress)
    }
}
