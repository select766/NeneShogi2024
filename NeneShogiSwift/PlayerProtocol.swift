struct ThinkingTime {
    let ponder: Bool
    let remaining: Double
    let byoyomi: Double
    let fisher: Double
}

protocol PlayerProtocol {
    func isReady(callback: @escaping () -> Void)
    func usiNewGame()
    func position(positionArg: String)
    func go(info: @escaping (String) -> Void, thinkingTime: ThinkingTime, callback: @escaping (Move) -> Void)
}
