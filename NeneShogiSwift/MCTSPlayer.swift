import Foundation
import CoreML

class MCTSPlayer: NNPlayerBase {
    struct RootNodeInfo {
        let node: UCTNode
        let originSFEN: String
        let moves: [Move]
    }
    
    var batchSize: Int = 1
    var cPuct: Float = 1.0
    var nodeLimit = 100000
    // ルートノードの再利用を許可するか
    var reuseRoot = true
    // 現在の思考がponderかどうか
    var inPonderMode = false
    var stopSignal = false
    let timerQueue: DispatchQueue
    var lastRootNodeInfo: RootNodeInfo? = nil
    
    override init() {
        timerQueue = DispatchQueue(label: "mctsPlayerTimer")
        super.init()
    }
    
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
                let score = moveArray[moveLabel + i * 2187]
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
    
    func calculateThinkingTime(thinkingTime: ThinkingTime) -> Double {
        // 思考時間を決める
        let defaultTime = 10.0 // ルール依存だが決めうち(WCSC32用)
        let margin = 3.0 // stopSignalを設定してから、実際に停止するまで+通信遅延を加味し、時間を使い切る場合に時間切れにならないためのマージン
        let minimum = 1.0
        if thinkingTime.ponder {
            // ponderではstopされるまで思考
            return 3600.0
        }
        let maxAvailable = thinkingTime.remaining + thinkingTime.byoyomi + thinkingTime.fisher
        if maxAvailable >= defaultTime + margin {
            return defaultTime
        } else {
            return max(maxAvailable - margin, minimum)
        }
    }
    
    override func go(info: @escaping (String) -> Void, thinkingTime: ThinkingTime, callback: @escaping (Move) -> Void) {
        searchDispatchQueue.async {
            let bestMove = self.goMain(info: info, thinkingTime: thinkingTime)
            callback(bestMove)
        }
    }
    
    func goMain(info: @escaping (String) -> Void, thinkingTime: ThinkingTime) -> Move {
        inPonderMode = thinkingTime.ponder
        // 思考時間設定
        stopSignal = false
        var enableStop = true // タイマー以外の要因で探索が終了した場合に、タイマーによってstopSignalフラグを操作しないようにするためのフラグ
        defer {
            enableStop = false
        }
        let calculatedThinkingTime = calculateThinkingTime(thinkingTime: thinkingTime)
        print("Thinking time: \(calculatedThinkingTime)")
        timerQueue.asyncAfter(deadline: .now() + calculatedThinkingTime, execute: {
            if enableStop {
                self.stopSignal = true
            }
        })
        
        let rootNode = findOrMakeRootNode()
        lastRootNodeInfo = nil // メモリ解放
        if position.isNyugyoku() {
            // 入玉宣言
            return Move.Win
        }
        let childCount = rootNode.childMoves!.count
        if childCount == 0 {
            return Move.Resign
        }
        if childCount == 1 {
            return rootNode.childMoves![0]
        }
        evaluateRootNode(position: position, node: rootNode)
        
        // MCTS
        searchBenchDefault.startSection(id: .search)
        search(rootNode: rootNode)
        searchBenchDefault.startSection(id: .empty)
        searchBenchDefault.display()
        
        if !inPonderMode {
            let pv = rootNode.getPV()
            let cpInt = winRateToCp(winrate: pv.winrate)
            var infoString = "info depth \(pv.moves.count) nodes \(pv.nodeCount) score cp \(cpInt) pv"
            for move in pv.moves {
                infoString += " \(move.toUSIString())"
            }
            info(infoString)
        }
        
        var bestMove: Move = Move.Resign
        if let bestVisitInfo = rootNode.getBestVisitChild() {
            
            bestMove = bestVisitInfo.move
            if inPonderMode {
                // 勝手にやっているponderの読み筋は将棋所で正しく表示されないので読み筋のフォーマットでは出さない
                info("info string ponder result = \(bestMove.toUSIString())")
            }
            
        }
        
        if reuseRoot {
            // Swiftのリストは値型なのでmoveStackはコピーされる
            lastRootNodeInfo = RootNodeInfo(node: rootNode, originSFEN: position.originSFEN, moves: position.moveStack)
        }
        
        return bestMove
    }
    
    func findOrMakeRootNode() -> UCTNode {
        // ルートノードの作成
        if let foundRootNode = findRootNode() {
            // 千日手を２回の繰り返しで成立して末端ノードにしている。
            // ルール上は千日手成立してない場面を思考するため、ルートノードを作り直す。新規作成したルートノードは末端ノードにならない。
            if !foundRootNode.terminal {
                print("ROOT found")
                return foundRootNode
            }
        }
        print("NEW ROOT")
        let rootNode = UCTNode()
        rootNode.expandNode(board: position)
        return rootNode
    }
    
    func findRootNode() -> UCTNode? {
        // 前回の探索結果から、今回のルートノードを探す
        // 今回の局面が、前回の局面から進んだ局面であり、実際に探索したノードが存在していればそれを返す
        guard let lastRootNodeInfo = lastRootNodeInfo else {
            return nil
        }
        if lastRootNodeInfo.originSFEN != position.originSFEN {
            return nil
        }
        
        if lastRootNodeInfo.moves.count > position.moveStack.count {
            return nil
        }
        
        for i in 0..<lastRootNodeInfo.moves.count {
            if lastRootNodeInfo.moves[i] != position.moveStack[i] {
                return nil
            }
        }
        
        var node = lastRootNodeInfo.node
        for i in lastRootNodeInfo.moves.count..<position.moveStack.count {
            let move = position.moveStack[i]
            guard let childMoves = node.childMoves else {
                return nil
            }
            var matchIdx = -1
            for j in 0..<childMoves.count {
                if childMoves[j] == move {
                    matchIdx = j
                    break
                }
            }
            if matchIdx < 0 {
                return nil
            }
            guard let childNode = node.childNodes?[matchIdx] else {
                return nil
            }
            node = childNode
        }
        
        return node
    }
    
    func searchOnce(rootNode: UCTNode) {
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
        // print("queue: \(queueItems.count), discard: \(trajectriesBatchDiscarded.count), fixed: \(fixedItems.count)")
        
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
    
    
    func search(rootNode: UCTNode) {
        // 探索を行なって木を成長させる
        for _ in 0..<100000 {
            if stopSignal {
                print("break by stop")
                break
            }
            if rootNode.moveCount >= nodeLimit {
                // ツリーの大きさでおおよその上限を決める
                // 開始局面における探索で、デバッガが表示するアプリ全体のメモリ使用量は
                // moveCount=10000で30MB
                // moveCount=100000で126MB (探索に105秒かかった)
                // 1手1分以上考えることはなかなかないので100000を上限にしておく。分岐が多い局面では同じノード数でもメモリ消費が増えるため。
                print("break by moveCount")
                break
            }
            // searchOnce(rootNode: rootNode)
            // autoreleasepoolがないとgoメソッド全体が終了するまで中で確保されたメモリが解放されず、メモリを使いすぎてクラッシュする(デバッガで表示されるサイズから、DNNの入出力バッファが解放されていないと推測される)
            autoreleasepool(invoking: {
                searchOnce(rootNode: rootNode)
            })
        }
    }
    
    func uctSearch(node: UCTNode, trajectory: inout [(UCTNode, Int)]) -> UCTSearchResult {
        if node.childNodes == nil {
            node.childNodes = Array(repeating: nil, count: node.childMoves!.count)
        }
        let nextIndex = selectMaxUcbChild(node: node)
        position.doMove(move: node.childMoves![nextIndex])
        trajectory.append((node, nextIndex))
        
        node.moveCount += 1 // vloss
        node.childMoveCount![nextIndex] += 1 // vloss
        
        defer {
            position.undoMove()
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
            if position.isNyugyoku() {
                // 末端ノード(宣言勝ち)
                newChildNode.value = 1.0
                newChildNode.terminal = true
                return UCTSearchResult.Fixed(leafValue: 1.0)
            }
            if newChildNode.childMoves!.count == 0 {
                // 末端ノード(詰み)
                newChildNode.value = 0.0
                newChildNode.terminal = true
                return UCTSearchResult.Fixed(leafValue: 0.0)
            } else {
                if let sennichite = position.isSennichite() {
                    // 末端ノード(千日手)
                    newChildNode.value = sennichite
                    newChildNode.terminal = true
                    return UCTSearchResult.Fixed(leafValue: sennichite)
                } else {
                    var moveLabels: [Int] = []
                    for i in 0..<newChildNode.childMoves!.count {
                        moveLabels.append(position.getDNNMoveLabel(move: newChildNode.childMoves![i]))
                    }
                    return UCTSearchResult.Queued(leafNode: newChildNode, inputArray: position.getDNNInput(), moveLabels: moveLabels)
                }
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
    
    override func stop() {
        stopSignal = true
    }
}
