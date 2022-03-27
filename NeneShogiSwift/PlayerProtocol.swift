struct ThinkingTime {
    let ponder: Bool
    let remaining: Double
    let byoyomi: Double
    let fisher: Double
}

protocol PlayerProtocol {
    func isReady()
    func usiNewGame()
    func position(positionArg: String)
    func go(info: (String) -> Void, thinkingTime: ThinkingTime) -> String
}
