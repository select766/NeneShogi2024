
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
    
    // 最大訪問数の子ノードを選択する
    func getBestVisitChild() -> (index: Int, move: Move, winrate: Float, childNode: UCTNode?)? {
        
        guard let childMoves = childMoves, let childMoveCount = childMoveCount, let childSumValue = childSumValue else {
            return nil
        }
        
        if terminal {
            // 合法手はあるが終端（宣言勝ちなど）の状況を想定
            return nil
        }

        var bestVisit: Int32 = 0 // 全ノード訪問0回なら、bestVisitを更新せず、読み筋なしとする(そうしないとランダムな指し手がPV末端に出る)
        var bestVisitIdx = -1
        for moveIdx in 0..<childMoves.count {
            let visit = childMoveCount[moveIdx]
            if visit > bestVisit {
                bestVisit = visit
                bestVisitIdx = moveIdx
            }
        }
        if bestVisitIdx < 0 {
            return nil
        }
        let bestMove = childMoves[bestVisitIdx]
        let bestWinRate = childSumValue[bestVisitIdx] / Float(childMoveCount[bestVisitIdx])
        
        let childNode = childNodes?[bestVisitIdx]
        return (index: bestVisitIdx, move: bestMove, winrate: bestWinRate, childNode)
    }
    
    func getPV() -> (moves: [Move], winrate: Float, nodeCount: Int32) {
        var currentNode = self
        let nodeCount = currentNode.moveCount
        var moves: [Move] = []
        var isRoot = true
        var winrate: Float = 0.0
        while (moves.count < 64) { // 極端に長い表示を避けるための制限
            if let bestVisitInfo = currentNode.getBestVisitChild() {
                moves.append(bestVisitInfo.move)
                if isRoot {
                    winrate = bestVisitInfo.winrate
                }
                if let childNode = bestVisitInfo.childNode {
                    currentNode = childNode
                } else {
                    break
                }
            } else {
                break
            }
            
            isRoot = false
        }
        
        return (moves: moves, winrate: winrate, nodeCount: nodeCount)
    }
    
    func printSummary() {
        print("moveCount \(moveCount)")
        print("sumValue \(sumValue)")
        if let childMoves = childMoves {
            for i in 0..<childMoves.count {
                print("\(childMoves[i].toUSIString()): \(policy![i]) \(childMoveCount![i]) - \(childSumValue![i])")
            }
        }
    }
    
    
    func getVisualizePV(rootPosition: Position) -> [SearchTreeRootForVisualize] {
        return getVisualizePV1(rootPosition: rootPosition)
    }
    
    private func getVisualizePV1(rootPosition: Position) -> [SearchTreeRootForVisualize] {
        guard let childMoves = childMoves, let childMoveCount = childMoveCount, let childNodes = childNodes else {
            return []
        }
        
        var pvs: [SearchTreeRootForVisualize] = []
        // moveCount降順
        let childOrdered = childMoveCount.enumerated().sorted(by: {$0.element > $1.element})
        for childInfo in childOrdered.prefix(3) {
            let childIdx = childInfo.offset
            let move = childMoves[childIdx]
            let detailedMove = rootPosition.makeDetailedMove(move: move)
            rootPosition.doMove(move: move)
            if let childNode = childNodes[childIdx] {
                let rootMoveNode = childNode.getVisualizePVChild(moveFromParent: detailedMove, position: rootPosition)
                
                pvs.append(SearchTreeRootForVisualize(rootMoveNode: rootMoveNode, childNodes: childNode.getVisualizePV2(rootPosition: rootPosition)))
            } else {
                // TODO なんか入れる
            }
            
            rootPosition.undoMove()
        }
        // moveCount降順
        pvs.sort(by: {$0.rootMoveNode.moveCount > $1.rootMoveNode.moveCount})
        return pvs

    }
    
    private func getVisualizePV2(rootPosition: Position) -> [SearchTreeNodeForVisualize] {
        guard let childMoves = childMoves, let childMoveCount = childMoveCount, let childNodes = childNodes else {
            return []
        }
        
        var pvs: [SearchTreeNodeForVisualize] = []
        // moveCount降順
        let childOrdered = childMoveCount.enumerated().sorted(by: {$0.element > $1.element})
        for childInfo in childOrdered.prefix(3) {
            let childIdx = childInfo.offset
            let move = childMoves[childIdx]
            let detailedMove = rootPosition.makeDetailedMove(move: move)
            rootPosition.doMove(move: move)
            if let childNode = childNodes[childIdx] {
                let rootMoveNode = childNode.getVisualizePVChild(moveFromParent: detailedMove, position: rootPosition)
                pvs.append(rootMoveNode)
            } else {
                // TODO なんか入れる
            }
            
            rootPosition.undoMove()
        }
        pvs.sort(by: {$0.moveCount > $1.moveCount})
        return pvs

    }
    
    private func getVisualizePVChild(moveFromParent: DetailedMove, position: Position) -> SearchTreeNodeForVisualize {
        var currentNode = self
        let nodeCount = currentNode.moveCount
        var isRoot = true
        var winrate: Float = 0.0
        var detailedMoves: [DetailedMove] = []
        var doMoveCount = 0
        while (detailedMoves.count < 10) { // 極端に長い表示を避けるための制限
            if let bestVisitInfo = currentNode.getBestVisitChild() {
                let detailedMove = position.makeDetailedMove(move: bestVisitInfo.move)
                detailedMoves.append(detailedMove)
                position.doMove(move: bestVisitInfo.move)
                doMoveCount += 1
                if isRoot {
                    winrate = bestVisitInfo.winrate
                }
                if let childNode = bestVisitInfo.childNode {
                    currentNode = childNode
                } else {
                    break
                }
            } else {
                break
            }
            
            isRoot = false
        }
        for _ in 0..<doMoveCount {
            position.undoMove()
        }
        
        return SearchTreeNodeForVisualize(moveFromParent: moveFromParent, pv: detailedMoves, moveCount: Int(nodeCount), winrateMean: winrate, winrateStd: 0.0)
    }
}
