import Foundation
import CoreML

class MCTSPlayer: NNPlayerBase {
    var batchSize: Int = 16
    var cPuct: Float = 1.0
    
    enum UCTSearchResult {
        case Queued(leafNode: UCTNode, inputArray: [Float], moveLabels: [Int])
        case Discarded
        case Fixed(leafValue: Float)
    }
    
    func evaluateRootNode(position: Position, node: UCTNode) {
        let inputArray = position.getDNNInput()
        // バッチサイズ1の状況しか考慮してない
        guard let mmArray = try? MLMultiArray(shape: [1, 119, 9, 9], dataType: .float32) else {
            fatalError("Cannot allocate MLMultiArray")
        }
        let mmRawPtr = UnsafeMutablePointer<Float>(OpaquePointer(mmArray.dataPointer))
        for i in 0..<inputArray.count {
            mmRawPtr[i] = Float(inputArray[i])
        }
        let pred = try! model!.prediction(x: mmArray)
        let resultArray = UnsafeMutablePointer<Float>(OpaquePointer(pred.result.dataPointer))
        node.value = resultArray[0]
        let moveArray = UnsafeMutablePointer<Float>(OpaquePointer(pred.move.dataPointer))
        let count = node.childMoves!.count
        var policy:[Float] = Array(repeating: 0.0, count: count)
        for moveIdx in 0..<count {
            let moveLabel = position.getDNNMoveLabel(move: node.childMoves![moveIdx])
            let score = moveArray[moveLabel]
            policy[moveIdx] = score
        }
        // softmax
        var maxVal: Float = -10000.0
        for moveIdx in 0..<count {
            if policy[moveIdx] > maxVal {
                maxVal = policy[moveIdx]
            }
        }
        var sumexp: Float = 0.0
        for moveIdx in 0..<count {
            let expValue = exp(policy[moveIdx] - maxVal)
            sumexp += expValue
            policy[moveIdx] = expValue
        }
        for moveIdx in 0..<count {
            policy[moveIdx] /= sumexp
        }
        node.policy = policy
    }
    
    func evaluateTrajectories(trajectories: [([(UCTNode, Int)], UCTNode, [Float], [Int])]) -> [(Float, [Float])] {
        guard let mmArray = try? MLMultiArray(shape: [NSNumber(value: batchSize), 119, 9, 9], dataType: .float32) else {
            fatalError("Cannot allocate MLMultiArray")
        }
        let mmRawPtr = UnsafeMutablePointer<Float>(OpaquePointer(mmArray.dataPointer))
        var mmOfs = 0
        for i in 0..<trajectories.count {
            let inputArray = trajectories[i].2
            mmOfs = 119*9*9*i
            for j in 0..<inputArray.count {
                mmRawPtr[mmOfs+j] = inputArray[j]
            }
        }
        let lastsec = searchBenchDefault.startSection(id: .dnnEval)
        let pred = try! model!.prediction(x: mmArray)
        searchBenchDefault.startSection(id: lastsec)
        let resultArray = UnsafeMutablePointer<Float>(OpaquePointer(pred.result.dataPointer))
        let moveArray = UnsafeMutablePointer<Float>(OpaquePointer(pred.move.dataPointer))
        var results: [(Float, [Float])] = []
        for i in 0..<trajectories.count {
            let value = resultArray[i]
            let count = trajectories[i].3.count
            var policy:[Float] = Array(repeating: 0.0, count: count)
            for moveIdx in 0..<count {
                let moveLabel = trajectories[i].3[moveIdx]
                let score = moveArray[moveLabel]
                policy[moveIdx] = score
            }
            // softmax
            var maxVal: Float = -10000.0
            for moveIdx in 0..<count {
                if policy[moveIdx] > maxVal {
                    maxVal = policy[moveIdx]
                }
            }
            var sumexp: Float = 0.0
            for moveIdx in 0..<count {
                let expValue = exp(policy[moveIdx] - maxVal)
                sumexp += expValue
                policy[moveIdx] = expValue
            }
            for moveIdx in 0..<count {
                policy[moveIdx] /= sumexp
            }
            
            results.append((value, policy))
        }
        return results
    }
    
    override func go(info: (String) -> Void) -> String {
        let rootNode = UCTNode()
        rootNode.expandNode(board: position)
        let childCount = rootNode.childMoves!.count
        if childCount == 0 {
            return "resign"
        }
        if childCount == 1 {
            return rootNode.childMoves![0].toUSIString()
        }
        evaluateRootNode(position: position, node: rootNode)
        searchBenchDefault.startSection(id: .search)
        search(rootNode: rootNode)
        searchBenchDefault.startSection(id: .empty)
        searchBenchDefault.display()
        
        // 最大訪問数の子ノードを選択
        var bestVisit: Int32 = 0
        var bestVisitIdx = 0
        for moveIdx in 0..<rootNode.childMoves!.count {
            let visit = rootNode.childMoveCount![moveIdx]
            if visit > bestVisit {
                bestVisit = visit
                bestVisitIdx = moveIdx
            }
            //            print("\(rootNode.childMoves![moveIdx].toUSIString()): \(visit)")
        }
        let bestMove = rootNode.childMoves![bestVisitIdx].toUSIString()
        let bestWinRate = rootNode.childSumValue![bestVisitIdx] / Float(rootNode.childMoveCount![bestVisitIdx])
        
        let cpInt = winRateToCp(winrate: bestWinRate)
        info("info depth 1 score cp \(cpInt) pv \(bestMove)")
        
        return bestMove
    }
    
    func search(rootNode: UCTNode) {
        // 一定の回数探索を行なって木を成長させる
        for iter in 0..<100 {
            print("iter \(iter)")
            var queueItems: [([(UCTNode, Int)], UCTNode, [Float], [Int])] = []
            var fixedItems: [([(UCTNode, Int)], Float)] = []
            var trajectriesBatchDiscarded: [[(UCTNode, Int)]] = []
            
            for _ in 0..<batchSize {
                var trajectory: [(UCTNode, Int)] = []
                let searchResult = uctSearch(node: rootNode, trajectory: &trajectory)
                switch searchResult {
                case .Queued(let leafNode, let inputArray, let moveLabels):
                    queueItems.append((trajectory, leafNode, inputArray, moveLabels))
                case .Discarded:
                    trajectriesBatchDiscarded.append(trajectory)
                case .Fixed(let value):
                    fixedItems.append((trajectory, value))
                }
            }
            print("queue: \(queueItems.count), discard: \(trajectriesBatchDiscarded.count), fixed: \(fixedItems.count)")
            
            // 評価
            let evaluated = evaluateTrajectories(trajectories: queueItems)
            
            // backup
            for i in 0..<queueItems.count {
                let queueItem = queueItems[i]
                let ev = evaluated[i]
                let leafNode = queueItem.1
                leafNode.value = ev.0
                leafNode.policy = ev.1
                var value = 1.0 - ev.0
                let trajs = queueItem.0
                for j in (0..<trajs.count).reversed() {
                    let middleNode = trajs[j].0
                    let nextIndex = trajs[j].1
                    middleNode.sumValue += value
                    middleNode.childSumValue![nextIndex] += value
                    // virtual loss相殺
                    //                    middleNode.moveCount += 0
                    //                    middleNode.childMoveCount![nextIndex] += 0
                    value = 1.0 - value
                }
            }
            for i in 0..<fixedItems.count {
                let fixedItem = fixedItems[i]
                var value = 1.0 - fixedItem.1
                let trajs = fixedItem.0
                for j in (0..<trajs.count).reversed() {
                    let middleNode = trajs[j].0
                    let nextIndex = trajs[j].1
                    middleNode.sumValue += value
                    middleNode.childSumValue![nextIndex] += value
                    // virtual loss相殺
                    //                    middleNode.moveCount += 0
                    //                    middleNode.childMoveCount![nextIndex] += 0
                    value = 1.0 - value
                }
            }
            for i in 0..<trajectriesBatchDiscarded.count {
                let trajs = trajectriesBatchDiscarded[i]
                for j in (0..<trajs.count).reversed() {
                    let middleNode = trajs[j].0
                    let nextIndex = trajs[j].1
                    // virtual lossを戻す
                    middleNode.moveCount -= 1
                    middleNode.childMoveCount![nextIndex] -= 1
                }
            }
        }
    }
    
    func uctSearch(node: UCTNode, trajectory: inout [(UCTNode, Int)]) -> UCTSearchResult {
        if node.childNodes == nil {
            node.childNodes = Array(repeating: nil, count: node.childMoves!.count)
        }
        let nextIndex = selectMaxUcbChild(node: node)
        let undoInfo = position.doMove(move: node.childMoves![nextIndex])
        trajectory.append((node, nextIndex))
        
        node.moveCount += 1 // vloss
        node.childMoveCount![nextIndex] += 1 // vloss
        
        defer {
            position.undoMove(undoMoveInfo: undoInfo)
        }
        
        if let childNode = node.childNodes![nextIndex] {
            // 子ノードがあるので再帰的に探索
            if childNode.terminal {
                return UCTSearchResult.Fixed(leafValue: childNode.value!)
            } else {
                if childNode.value != nil {
                    let childSearchResult = uctSearch(node: childNode, trajectory: &trajectory)
                    return childSearchResult
                } else {
                    // 評価中
                    return UCTSearchResult.Discarded
                }
            }
        } else {
            // 子ノードを作成
            let newChildNode = node.createChildNode(index: nextIndex)
            newChildNode.expandNode(board: position)
            if newChildNode.childMoves!.count == 0 {
                // 末端ノード(詰み)
                newChildNode.value = 0.0
                newChildNode.terminal = true
                return UCTSearchResult.Fixed(leafValue: 0.0)
            } else {
                var moveLabels: [Int] = []
                for i in 0..<newChildNode.childMoves!.count {
                    moveLabels.append(position.getDNNMoveLabel(move: newChildNode.childMoves![i]))
                }
                return UCTSearchResult.Queued(leafNode: newChildNode, inputArray: position.getDNNInput(), moveLabels: moveLabels)
            }
        }
    }
    
    func selectMaxUcbChild(node: UCTNode) -> Int {
        var maxUcb: Float = -1.0
        var maxIndex = 0
        let moveCount = Float(node.moveCount)
        for i in 0..<node.childMoveCount!.count {
            let childMoveCount = Float(node.childMoveCount![i])
            let childSumValue = node.childSumValue![i]
            let q: Float
            if childMoveCount > 0.0 {
                q = childSumValue / childMoveCount
            } else {
                q = 0.0
            }
            let u: Float
            if moveCount > 0.0 {
                u = sqrtf(moveCount / (childMoveCount+1.0))
            } else {
                u = 1.0
            }
            let ucb = q + cPuct * u * node.policy![i]
            if ucb > maxUcb {
                maxUcb = ucb
                maxIndex = i
            }
        }
        
        return maxIndex
    }
}
