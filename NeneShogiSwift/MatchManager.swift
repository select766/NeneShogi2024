import Foundation

class ShogiUIInterface {
    var displayMessage: (String) -> Void
    var updateSearchProgress: (SearchProgress) -> Void
    var updateMatchStatus: (MatchStatus) -> Void
    init(displayMessage: @escaping (String) -> Void, updateMatchStatus: @escaping (MatchStatus) -> Void, updateSearchProgress: @escaping (SearchProgress) -> Void) {
        self.displayMessage = displayMessage
        self.updateMatchStatus = updateMatchStatus
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
    
    func updateMatchStatus(matchStatus: MatchStatus) {
        shogiUIInterface.updateMatchStatus(matchStatus)
    }
    
    func updateSearchProgress(searchProgress: SearchProgress) {
        shogiUIInterface.updateSearchProgress(searchProgress)
    }
}
