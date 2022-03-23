protocol PlayerProtocol {
    func isReady()
    func usiNewGame()
    func position(positionArg: String)
    func go(info: (String) -> Void) -> String
}
