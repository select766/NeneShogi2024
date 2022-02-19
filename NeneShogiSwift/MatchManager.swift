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
    var usiClient: USIClient?
    init(shogiUIInterface: ShogiUIInterface) {
        self.shogiUIInterface = shogiUIInterface
    }
    
    func start() {
        usiClient = USIClient(matchManager: self)
        usiClient?.start()
    }
    
    func displayMessage(_ message: String) {
        shogiUIInterface.displayMessage(message)
    }
}
