import Foundation

class RandomPlayer: PlayerProtocol {
    var position: Position
    init() {
        position = Position()
    }
    
    func isReady() {}
    
    func usiNewGame() {
    }
    
    func position(positionArg: String) {
        // positionコマンド
        position.setUSIPosition(positionArg: positionArg)
    }
    
    func go(info: (String) -> Void) -> String {
        // goコマンド
        let moves = position.generateMoveList()
        let bestMove: String
        if moves.count > 0 {
            let rnd = Int.random(in: 0..<moves.count)
            bestMove = moves[rnd].toUSIString()
        } else {
            bestMove = "resign"
        }
        return bestMove
    }
}
