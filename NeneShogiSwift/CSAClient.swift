import Foundation
import Network

enum CSAClientState {
    case waiting
    case game
    case end(gameResult: String)
}

class CSAClient {
    let csaConfig: CSAConfig
    let matchManager: MatchManager
    var serverEndpoint: NWEndpoint
    var connection: NWConnection?
    let queue: DispatchQueue
    var recvBuffer: Data = Data()
    var player: PlayerProtocol?
    var myColor: PColor?
    var moves: [Move]
    var position: Position
    var state = CSAClientState.waiting
    var myRemainingTime: Double = 0.0
    var moveHistory: [MoveHistoryItem] = []
    var lastSendTime: Date = Date()
    var goRunning = false
    var lastGoScoreCp: Int? = nil
    
    init(matchManager: MatchManager, csaConfig: CSAConfig) {
        self.matchManager = matchManager // TODO: 循環参照回避
        self.csaConfig = csaConfig
        queue = DispatchQueue(label: "csaClient")
        self.serverEndpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(self.csaConfig.csaServerIpAddress), port: NWEndpoint.Port(rawValue: self.csaConfig.csaServerPort)!)
        self.moves = []
        self.position = Position()
    }
    
    func start() {
        // AIは複数回サーバに接続する場合でも最初の1回だけ
        switch playerClass {
        case "Random":
            self.player = RandomPlayer()
        case "Policy":
            self.player = PolicyPlayer()
        case "MCTS":
            self.player = MCTSPlayer()
        default:
            fatalError("Unknown player selection")
        }
        startConnection()
        setKeepalive()
    }
    
    func startConnection() {
        self.state = .waiting
        
        matchManager.updateMatchStatus(matchStatus: MatchStatus(gameState: .connecting, position: position, moveHistory: moveHistory))
        self.matchManager.displayMessage("connecting to CSA server")
        connection = NWConnection(to: serverEndpoint, using: .tcp)
        connection?.stateUpdateHandler = {(newState) in
            print("stateUpdateHandler", newState)
            switch newState {
            case .ready:
                self.matchManager.displayMessage("connected to CSA server")
                
                self.matchManager.updateMatchStatus(matchStatus: MatchStatus(gameState: .initializing, position: self.position, moveHistory: self.moveHistory))
                self.sendCSA(message: "LOGIN \(self.csaConfig.loginName) \(self.csaConfig.loginPassword)")
                self.startRecv()
            case .waiting(let nwError):
                // ネットワーク構成が変化するまで待つ=事実上の接続失敗
                // TODO: 接続失敗時のアクション
                self.matchManager.displayMessage("Failed to connect to USI server: \(nwError)")
            case .cancelled:
                self.connection = nil
                if self.csaConfig.reconnect {
                    // LOGOUT送信の直前にサーバ側から切断され、すぐに再接続されると新しい接続に対してLOGOUTを送ってしまうかもしれないので予防的に少し待ってから再接続する
                    self.queue.asyncAfter(deadline: .now() + 5.0, execute: self.startConnection)
                }
            default:
                break
            }
        }
        connection?.start(queue: queue)
    }
    
    func startRecv() {
        connection?.receive(minimumIncompleteLength: 0, maximumLength: 65535, completion: {(data,context,flag,error) in
            if let error = error {
                self.matchManager.displayMessage("CSA receive error \(error)")
                print("receive error", error)
            } else {
                if let data = data {
                    self.recvBuffer.append(data)
                    while true {
                        if let lfPos = self.recvBuffer.firstIndex(of: 0x0a) {
                            var lineEndPos = lfPos
                            // CRをカット
                            if lineEndPos > 0 && self.recvBuffer[lineEndPos - 1] == 0x0d {
                                lineEndPos -= 1
                            }
                            if let commandStr = String(data: self.recvBuffer[..<lineEndPos], encoding: .utf8) {
                                self.matchManager.pushCommunicationHistory(communicationItem: CommunicationItem(direction: .recv, message: commandStr))
                                self.handleCSACommand(command: commandStr)
                            } else {
                                print("Cannot decode CSA data as utf-8")
                                self.matchManager.displayMessage("Cannot decode CSA data as utf-8")
                            }
                            // Data()で囲わないと、次のfirstIndexで返る値が接続開始時からの全文字列に対するindexになる？バグか仕様か不明
                            self.recvBuffer = Data(self.recvBuffer[(lfPos+1)...])
                        } else {
                            break
                        }
                    }
                    self.startRecv()
                } else {
                    // コネクション切断で発生
                    print("zero recv")
                    self.matchManager.displayMessage("CSA disconnected")
                    self.connection?.cancel()
                }
            }
        })
    }
    
    func handleCSACommand(command: String) {
        self.matchManager.displayMessage("CSA recv: '\(command)'")
        print("recv: '\(command)'")
        switch state {
        case .waiting:
            _handleCSACommandWaiting(command: command)
        case .game:
            _handleCSACommandGame(command: command)
        case .end:
            break
        }
    }
    
    func _handleCSACommandWaiting(command: String) {
        if command.starts(with: "Your_Turn") {
            if command == "Your_Turn:+" {
                myColor = PColor.BLACK
            } else if command == "Your_Turn:-" {
                myColor = PColor.WHITE
            } else {
                fatalError("Unknown turn")
            }
        } else if command.starts(with: "END Game_Summary") {
            self.player?.isReady(callback: {
                self.queue.async {
                    self.state = .game
                    self.myRemainingTime = self.csaConfig.timeTotalSec
                    self.moves = []
                    self.moveHistory = []
                    self.position.setHirate()
                    self.sendCSA(message: "AGREE")
                    
                    self.matchManager.updateMatchStatus(matchStatus: MatchStatus(gameState: .playing, position: self.position, moveHistory: self.moveHistory))
                }
            })
        }
    }
    
    func _handleCSACommandGame(command: String) {
        var mayneedgo = false
        if command.starts(with: "START") {
            // TODO: STARTとAGREE返答時の初期化をどちらかに揃える
            player?.usiNewGame()
            moves = []
            moveHistory = []
            position.setHirate()
            mayneedgo = true
            lastGoScoreCp = nil
        } else if command.starts(with: "+") || command.starts(with: "-") {
            let moveColor = command.starts(with: "+") ? PColor.BLACK : PColor.WHITE
            if let move = position.parseCSAMove(csaMove: command) {
                print("parsed move: \(move.toUSIString())")
                let detail = position.makeDetailedMove(move: move)
                if move.isTerminal {
                    moveHistory.append(MoveHistoryItem(detailedMove: detail, usedTime: nil, scoreCp: nil))
                } else {
                    mayneedgo = true
                    moves.append(move)
                    position.doMove(move: move)
                    
                    // 消費時間の計算
                    var usedTime: Double? = nil
                    do {
                        let regex = try NSRegularExpression(pattern: ",T(\\d+)$")
                        let matches = regex.matches(in: command, range: NSRange(location: 0, length: command.count))
                        if matches.count > 0 {
                            let timeStr = NSString(string: command).substring(with: matches[0].range(at: 1))
                            if let timeParsed = Double(timeStr) {
                                usedTime = timeParsed
                                if moveColor == myColor {
                                    // 自分の消費時間
                                    print("I used \(timeParsed) sec")
                                    myRemainingTime -= timeParsed
                                }
                            }
                        }
                    } catch {
                        print("error on extracting time")
                    }
                    moveHistory.append(MoveHistoryItem(detailedMove: detail, usedTime: usedTime, scoreCp: moveColor == myColor ? lastGoScoreCp : nil))
                    print("\(detail.toPrintString()), \(usedTime ?? -1.0)")
                }
            } else {
                print("parse move failed")
            }
        } else if command == "%TORYO" {
            // 消費時間情報はついていない
            moveHistory.append(MoveHistoryItem(detailedMove: DetailedMove.makeResign(sideToMode: position.sideToMove), usedTime: nil, scoreCp: nil))
        } else if command == "%KACHI" {
            moveHistory.append(MoveHistoryItem(detailedMove: DetailedMove.makeWin(sideToMode: position.sideToMove), usedTime: nil, scoreCp: nil))
        } else if ["#WIN", "#LOSE", "#DRAW", "#CHUDAN"].contains(command) {
            state = .end(gameResult: command)
            // これを送るとサーバから切断される
            // 対局終了時はサーバから自動的に切断される場合もある
            // ponder中に終わる場合があるので一応stopしておく
            guard let player = self.player else {
                fatalError()
            }
            player.stop()
            self.sendCSA(message: "LOGOUT")
            self.connection?.cancel()
        }
        if mayneedgo {
            if myColor == position.sideToMove {
                // 自分の手番
                myRemainingTime += csaConfig.timeIncrementSec
                // remaining timeに今回手番側回ってきたことによる加算時間は含まない
                let thinkingTime = ThinkingTime(ponder: false, remaining: myRemainingTime - csaConfig.timeIncrementSec, byoyomi: 0.0, fisher: csaConfig.timeIncrementSec)
                runGo(thinkingTime: thinkingTime, secondCall: false)
            }
        }
        
        switch state {
        case .end(let gameResult):
            matchManager.updateMatchStatus(matchStatus: MatchStatus(gameState: .end(gameResult: gameResult), position: position, moveHistory: moveHistory))
        default:
            matchManager.updateMatchStatus(matchStatus: MatchStatus(gameState: .playing, position: position, moveHistory: moveHistory))
        }
    }
    
    func runGo(thinkingTime: ThinkingTime, secondCall: Bool) {
        guard let player = self.player else {
            fatalError()
        }
        // ponderを止める
        player.stop()
        if goRunning {
            if !secondCall {
                print("waiting last go ends")
            }
            queue.asyncAfter(deadline: .now() + 0.01, execute: {
                self.runGo(thinkingTime: thinkingTime, secondCall: true)
            })
            return
        }
        goRunning = true
        // ponderが終わってから、positionを設定する
        let movesForGo = moves
        player.position(moves: movesForGo)
        player.go(info: {(sp: SearchProgress) in
            self.queue.async {
                self.matchManager.updateSearchProgress(searchProgress: sp)
            }
        }, thinkingTime: thinkingTime, callback: {(bestMove: Move, scoreCp: Int) in
            self.queue.async {
                self.goRunning = false
                // 千日手成立の場合、サーバから千日手が成立する手がきた後、#SENNICHITE,#DRAWが来る。手を受け取った時点で思考を開始してしまうので、思考結果を出力してしまう場合があるがレースコンディションなので仕方ない。現状、一局ごとにTCP接続を切っているので、次の対局に影響することはないので放置。
                let bestMoveCSA = self.position.makeCSAMove(move: bestMove)
                self.lastGoScoreCp = scoreCp
                self.sendCSA(message: bestMoveCSA)
                self.runPonderIfPossible(bestMove: bestMove, movesForGo: movesForGo)
            }
        })
    }
    
    func runPonderIfPossible(bestMove: Move, movesForGo: [Move]) {
        if !csaConfig.ponder {
            return
        }
        if bestMove.isTerminal {
            return
        }
        print("run ponder")
        guard let player = self.player else {
            fatalError()
        }
        // goで思考した局面+bestMoveで進めた局面で思考
        // ここでmovesを参照すると、通信タイミングによってbestmove適用前後のどちらか不定となるためまずい
        goRunning = true
        var posaftermove = movesForGo
        posaftermove.append(bestMove)
        player.position(moves: posaftermove)
        let thinkingTime = ThinkingTime(ponder: true, remaining: 3600.0, byoyomi: 0.0, fisher: 0.0)
        player.go(info: {(sp: SearchProgress) in
            self.queue.async {
                self.matchManager.updateSearchProgress(searchProgress: sp)
            }
        }, thinkingTime: thinkingTime, callback: {(bestMove: Move, _: Int) in
            self.queue.async {
                print("ponder result \(bestMove.toUSIString())")
                self.goRunning = false
            }
        })
    }
    
    func setKeepalive() {
        queue.asyncAfter(deadline: .now() + 10.0, execute: keepAlive)
    }
    
    func keepAlive() {
        // TCP接続維持のために、無送信状態が40秒続いたら空行を送る(30秒未満で送ると反則)
        if lastSendTime.timeIntervalSinceNow < -40.0 {
            print("keepalive at \(Date())")
            _send(messageWithNewline: "\n")
        }
        setKeepalive()
    }
    
    func _send(messageWithNewline: String) {
        for line in messageWithNewline.components(separatedBy: "\n") {
            if line.count > 0 {
                matchManager.pushCommunicationHistory(communicationItem: CommunicationItem(direction: .send, message: line))
            }
        }
        lastSendTime = Date()
        connection?.send(content: messageWithNewline.data(using: .utf8)!, completion: .contentProcessed{ error in
            if let error = error {
                print("cannot send", messageWithNewline)
                print("Error in send", error)
            }
        })
        
    }
    
    func sendCSA(message: String) {
        _send(messageWithNewline: message + "\n")
    }
    
    func sendCSA(messages: [String]) {
        _send(messageWithNewline: messages.map({m in m + "\n"}).joined())
    }
}
