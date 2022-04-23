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
    func position(moves: [Move])
    func go(info: @escaping (SearchProgress) -> Void, thinkingTime: ThinkingTime, callback: @escaping (Move, Int) -> Void)
    func stop()
}
