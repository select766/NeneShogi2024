
import Foundation

class UCTNode {
    var moveCount: Int32
    var sumValue: Float
    var childMoves: [Move]?
    var childMoveCount: [Int32]?
    var childSumValue: [Float]?
    var childNodes: [UCTNode?]?
    var policy: [Float]?
    var value: Float?
    var terminal: Bool
    
    init() {
        moveCount = 0
        sumValue = 0.0
        terminal = false
    }
    
    func createChildNode(index: Int) -> UCTNode {
        let newNode = UCTNode()
        self.childNodes![index] = newNode
        return newNode
    }
    
    func expandNode(board: Position) {
        let moveList = board.generateMoveList()
        self.childMoves = moveList
        self.childMoveCount = Array(repeating: 0, count: moveList.count)
        self.childSumValue = Array(repeating: 0.0, count: moveList.count)
    }
}
