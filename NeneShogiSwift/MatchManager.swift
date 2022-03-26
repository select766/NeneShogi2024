//
//  MatchManager.swift
//  NeneShogiSwift
//
//  Created by Masatoshi Hidaka on 2022/02/14.
//

import Foundation

class ShogiUIInterface {
    var displayMessage: (String) -> Void;
    init(displayMessage: @escaping (String) -> Void) {
        self.displayMessage = displayMessage
    }
}

class MatchManager {
    let shogiUIInterface: ShogiUIInterface
    let usiServerIpAddress: String
    var usiClient: USIClient?
    init(shogiUIInterface: ShogiUIInterface, usiServerIpAddress: String) {
        self.shogiUIInterface = shogiUIInterface
        self.usiServerIpAddress = usiServerIpAddress
    }
    
    func start() {
        usiClient = USIClient(matchManager: self, usiServerIpAddress: usiServerIpAddress)
        usiClient?.start()
    }
    
    func displayMessage(_ message: String) {
        shogiUIInterface.displayMessage(message)
    }
}
