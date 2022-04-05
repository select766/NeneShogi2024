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
    let csaServerIpAddress: String
    var usiClient: USIClient?
    var csaClient: CSAClient?
    
    init(shogiUIInterface: ShogiUIInterface, usiServerIpAddress: String,
         csaServerIpAddress: String) {
        self.shogiUIInterface = shogiUIInterface
        self.usiServerIpAddress = usiServerIpAddress
        self.csaServerIpAddress = csaServerIpAddress
    }
    
    func start() {
        usiClient = USIClient(matchManager: self, usiServerIpAddress: usiServerIpAddress)
        usiClient?.start()
    }
    
    func startCSA() {
        csaClient = CSAClient(matchManager: self, csaServerIpAddress: csaServerIpAddress)
        csaClient?.start()
    }
    
    func displayMessage(_ message: String) {
        shogiUIInterface.displayMessage(message)
    }
}
