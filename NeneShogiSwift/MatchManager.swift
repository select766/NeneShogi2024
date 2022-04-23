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
    var usiClient: USIClient?
    var csaClient: CSAClient?
    
    init(shogiUIInterface: ShogiUIInterface) {
        self.shogiUIInterface = shogiUIInterface
    }
    
    func startUSI(usiConfig: USIConfig) {
        usiClient = USIClient(matchManager: self, usiConfig: usiConfig)
        usiClient?.start()
    }
    
    func startCSA(csaConfig: CSAConfig) {
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
