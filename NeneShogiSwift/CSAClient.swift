import Foundation
import Network
import os

private let logger = Logger(subsystem: "jp.outlook.select766.NeneShogiSwift", category: "csa")

struct ThinkingTime {
    let ponder: Bool
    let remaining: Double
    let byoyomi: Double
    let fisher: Double
}

struct CSATimeConfig {
    let totalTime: Double
    let byoyomi: Double
    let increment: Double
}

class CSAClient {
    let queue: DispatchQueue
    let usiActor: USIActor
    let csaActor: CSAActor
    
    init(matchManager: MatchManager, csaConfig: CSAConfig) {
        queue = DispatchQueue(label: "csaClient")
        usiActor = USIActor(queue: queue)
        csaActor = CSAActor(queue: queue, csaConfig: csaConfig, matchManager: matchManager)
    }
    
    func start() {
        usiActor.subscribe(callback: usiActorCallback)
        csaActor.subscribe(callback: csaActorCallback)
        usiActor.dispatch(.launch)
    }
    
    private func usiActorCallback(message: USIActor.USIActorEmitMessage) {
        switch message {
        case .launchCompleted:
            csaActor.dispatch(.connect)
        case let .csa(message: message):
            csaActor.dispatch(message)
        }
    }
    
    private func csaActorCallback(message: CSAActor.CSAActorEmitMessage) {
        switch message {
        case let .usi(message):
            usiActor.dispatch(message)
        }
    }
}

class Actor<T,U: Equatable,V> {
    let queue: DispatchQueue
    var _state: U
    var subscribers: [(V) -> Void]
    
    init(queue: DispatchQueue, initialState: U) {
        self.queue = queue
        self._state = initialState
        self.subscribers = []
    }
    
    func dispatch(_ message: T) -> Void {
        queue.async {
            print("dispatch \(message)")
            self._dispatch(message: message)
        }
    }
    
    func _dispatch(message: T) {
        fatalError()
    }
    
    func emit(_ message: V) {
        for subscriber in subscribers {
            subscriber(message)
        }
    }
    
    func subscribe(callback: @escaping (V) -> Void) {
        subscribers.append(callback)
    }
    
    var state: U {
        get {
            return self._state
        }
        set {
            let lastState = self._state
            self._state = newValue
            if (newValue != lastState) {
                // これはキューではなく即時実行(すでに溜まっているメッセージの処理で、さらにstateが変化する可能性があるので)
                stateChanged(newState: newValue, lastState: lastState)
            }
        }
    }
    
    func stateChanged(newState: U, lastState: U) -> Void {
    }
    
    func unexpected(_ message: T) {
        unexpected(message: message, state: state)
    }
    
    func unexpected(message: T, state: U) {
        let s: String = "Unexpected message \(message) for state \(state)"
        logger.error("\(s)")
    }
    
}

class USIActor : Actor<USIActor.USIActorMessage, USIActor.USIActorState, USIActor.USIActorEmitMessage> {
    enum USIActorMessage {
        case launch
        case isready
        case go(position: Position, positionCommand: String, goCommand: String)
        case ponder(position: Position, positionCommand: String, goCommand: String)
        // go, goPonderを止める作用あり
        case gameover(gameResult: String)
        case usiRecv(commandType: String, commandArg: String?)
        case endGameWaitEnd
    }
    
    enum USIActorState {
        case beforeLaunch
        case launching
        case waitingGame
        case readying
        case gameIdle
        case gameGoing
        case gamePondering
        case endGameWaiting
    }
    
    enum USIActorEmitMessage {
        case csa(CSAActor.CSAActorMessage)
        case launchCompleted
    }
    
    var positionForGo: Position? = nil
    var pendingMessageOnPonder: USIActorMessage? = nil
    var pvScore: Int? = nil
    var pvUSI: [String]? = nil
    
    init(queue: DispatchQueue) {
        super.init(queue: queue, initialState: .beforeLaunch)
    }
    
    override func stateChanged(newState: USIActorState, lastState: USIActorState) {
        print("usi state: \(newState) <- \(lastState)")
        switch newState {
        case .gameGoing:
            pvScore = nil
            pvUSI = nil
        case .endGameWaiting:
            // gameoverを送ってから、一定時間は次のUSI操作をしないよう待機する時間
            queue.asyncAfter(deadline: .now() + 5.0, execute: {
                self.dispatch(.endGameWaitEnd)
            })
        default:
            break
        }
    }
    
    override func _dispatch(message: USIActorMessage) {
        switch state {
        case .beforeLaunch:
            switch message {
            case .launch:
                startYaneuraou(recvCallback: {command in
                    self.queue.async {
                        self.yaneRecv(command: command)
                    }})
                yaneSend("usi")
                state = .launching
            default:
                unexpected(message)
            }
        case .launching:
            switch message {
            case let .usiRecv(commandType: commandType, commandArg: _):
                if ["option", "id"].contains(commandType) {
                    // do nothing
                } else if commandType == "usiok" {
                    // launch ok
                    // 対局ごとのsetoptionはうまくいくか不明なので、usiokに対応してここで行う(isreadyの直前ではなく)。
                    let options = ["setoption DNN_Model1 value ", "setoption DNN_Batch_Size1 value 8", "setoption USI_Ponder value true", "setoption Stochastic_Ponder value true"]
                    for option in options {
                        yaneSend(option)
                    }
                    emit(.launchCompleted)
                    state = .waitingGame
                } else {
                    unexpected(message)
                }
            default:
                unexpected(message)
            }
        case .waitingGame:
            switch message {
            case .isready:
                state = .readying
                yaneSend("isready")
            default:
                unexpected(message)
            }
        case .readying:
            switch message {
            case let .usiRecv(commandType: commandType, commandArg: _):
                if commandType == "info" {
                    // do nothing
                } else if commandType == "readyok" {
                    yaneSend("usinewgame")
                    emit(.csa(.readyok))
                    state = .gameIdle
                } else {
                    unexpected(message)
                }
            default:
                unexpected(message)
            }
        case .gameIdle:
            switch message {
            case let .go(position: position, positionCommand: positionCommand, goCommand: goCommand):
                positionForGo = position
                yaneSend(positionCommand)
                yaneSend(goCommand)
                state = .gameGoing
            case let .ponder(position: _, positionCommand: positionCommand, goCommand: goCommand):
                yaneSend(positionCommand)
                yaneSend(goCommand)
                state = .gamePondering
            case let .gameover(gameResult: gameResult):
                yaneSend("gameover \(gameResult)")
                state = .endGameWaiting
            case let .usiRecv(commandType: commandType, commandArg: _):
                if commandType == "info" {
                    // do nothing
                } else {
                    unexpected(message)
                }
            default:
                unexpected(message)
            }
        case .gameGoing:
            // goの中断は現状対応していない
            switch message {
            case .go:
                unexpected(message)
            case .ponder:
                unexpected(message)
            case let .gameover(gameResult: gameResult):
                // CSAで、相手の指し手を受信し、直後に千日手等での終了が宣言されると発生する
                // gameoverを送ったあとで、bestmoveが送られるレースコンディションがありうる
                yaneSend("gameover \(gameResult)")
                state = .endGameWaiting
            case let .usiRecv(commandType: commandType, commandArg: commandArg):
                if commandType == "info" {
                    parseGoInfo(commandArg: commandArg, ponder: false)
                } else if commandType == "bestmove" {
                    if let positionForGo = positionForGo, let commandArg = commandArg {
                        let parts = commandArg.split(separator: " ")
                        let moveUSI = String(parts[0])
                        let ponderUSI = parts.count >= 3 ? String(parts[2]) : nil
                        emit(.csa(.bestmove(position: positionForGo, moveUSI: moveUSI, ponderUSI: ponderUSI, score: pvScore, pvUSI: pvUSI)))
                        self.positionForGo = nil
                        state = .gameIdle
                    } else {
                        print("wrong condition for bestmove")
                        unexpected(message)
                    }
                } else {
                    unexpected(message)
                }
            default:
                unexpected(message)
            }
        case .gamePondering:
            switch message {
            case .go:
                // TODO ponderhit (今は常にstopで止めて、ponderは単に置換表を埋めている形）
                // ponderをstopで終了して、bestmoveが来てからgoを送りたい
                if pendingMessageOnPonder != nil {
                    print("multiple go/ponder requests while running previous ponder")
                    // error
                }
                pendingMessageOnPonder = message
                yaneSend("stop")
            case .ponder:
                // ponderをstopで終了して、bestmoveが来てからgo ponderを送りたい
                if pendingMessageOnPonder != nil {
                    print("multiple go/ponder requests while running previous ponder")
                    // error
                }
                pendingMessageOnPonder = message
                yaneSend("stop")
            case let .gameover(gameResult: gameResult):
                // CSAで、自分の指し手がエコーバックされ、直後に千日手等での終了が宣言されると発生する
                // gameoverを送ったあとで、bestmoveが送られるレースコンディションがありうる
                yaneSend("gameover \(gameResult)")
                state = .endGameWaiting
            case let .usiRecv(commandType: commandType, commandArg: _):
                if commandType == "info" {
                    // do nothing
                } else if commandType == "bestmove" {
                    // この指し手自体はいらない。ponderが終了しidleになったことがわかる。
                    if let pendingMessageOnPonder = pendingMessageOnPonder {
                        state = .gameIdle
                        // すでに受信したgoメッセージをエンジンに送る
                        self.pendingMessageOnPonder = nil
                        dispatch(pendingMessageOnPonder)
                    }
                } else {
                    unexpected(message)
                }
            default:
                unexpected(message)
            }
        case .endGameWaiting:
            // gameoverを送ったタイミングにより、bestmoveが来たりこなかったりするので少し待つ
            switch message {
            case let .usiRecv(commandType: commandType, commandArg: _):
                print("discarding usi message after gameover: \(commandType)")
            case .endGameWaitEnd:
                state = .waitingGame
            default:
                // すぐに次の対局が開始する場合に本当は備えたい
                unexpected(message)
            }
        }
    }
    
    private func parseGoInfo(commandArg: String?, ponder: Bool) -> Void {
        guard let commandArg = commandArg else {
            return
        }
        
        // TODO: npsなどをパース
        var score: Int? = nil
        var pvUSI: [String]? = nil
        var tokens: [String] = commandArg.split(separator: " ").map{s in String(s)}
        while tokens.count > 0 {
            let subcmd = tokens.removeFirst()
            switch subcmd {
            case "depth":
                // TODO: removeFirstはempty arrayに適用するとクラッシュするので要注意
                let depth = tokens.removeFirst()
            case "seldepth":
                let seldepth = tokens.removeFirst()
            case "time":
                let time = tokens.removeFirst()
            case "nodes":
                let nodes = tokens.removeFirst()
            case "pv":
                pvUSI = tokens
            case "multipv":
                let multipv = tokens.removeFirst()
            case "score":
                let cpOrMate = tokens.removeFirst()
                let value = tokens.removeFirst()
                if tokens.count > 0 {
                    // lowerbound or upperbound
                    let lbub = tokens.removeFirst()
                }
                if cpOrMate == "cp" {
                    score = Int(value)
                } else if cpOrMate == "mate" {
                    let mateBase = 32000
                    if let parsedValue = Int(value) {
                        if parsedValue > 0 {
                            // 手番側が parsedValue 手で勝つ
                            score = mateBase - parsedValue
                        } else {
                            // 相手側が -parsedValue 手で勝つ
                            score = -mateBase - parsedValue
                        }
                    } else {
                        if value == "+" {
                            score = mateBase
                        } else if value == "-" {
                            score = -mateBase
                        }
                    }
                }
            case "currmove":
                let moveUSI = tokens.removeFirst()
            case "hashfull":
                let hashFull = tokens.removeFirst()
            case "nps":
                let nps = tokens.removeFirst()
            case "string":
                let infoString = tokens.joined(separator: " ")
            default:
                // unknown
                tokens = []
                break
            }
        }
        
        if pvUSI != nil {
            self.pvUSI = pvUSI
        }
        
        if score != nil {
            self.pvScore = score
        }
    }
    
    private func yaneRecv(command: String) -> Void {
        print("yaneRecv \(command)")
        // やねうら王からメッセージを受信した（queueのスレッドで呼ばれる）
        let splits = command.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
        if splits.count < 1 {
            return
        }
        let commandType = String(splits[0])
        let commandArg = splits.count == 2 ? String(splits[1]) : nil
        dispatch(.usiRecv(commandType: commandType, commandArg: commandArg))
    }
    
    private func yaneSend(_ commandWithoutNewLine: String) -> Void {
        print("yaneSend \(commandWithoutNewLine)")
        sendToYaneuraou(messageWithoutNewLine: commandWithoutNewLine)
    }
}

class CSAActor : Actor<CSAActor.CSAActorMessage, CSAActor.CSAActorState, CSAActor.CSAActorEmitMessage> {
    enum CSAActorMessage {
        case connect
        case csaConnected
        case csaDisconnected
        // コマンド1行（CRLFなし）
        case csaRecv(command: String)
        case gameSummaryReceived
        case readyok
        case bestmove(position: Position, moveUSI: String, ponderUSI: String?, score: Int?, pvUSI: [String]?)
        case endGameReceived(reason: String)
    }
    
    enum CSAActorState {
        case noConnection
        case connecting
        // LOGIN送信で開始、対局情報受信完了まで
        case waitingGameSummary
        case waitingReadyok
        case waitingStart
        case myTurn
        case opponentTurn
        case endingGame
    }
    
    enum CSAActorEmitMessage {
        case usi(USIActor.USIActorMessage)
    }
    
    let csaConfig: CSAConfig
    let matchManager: MatchManager
    
    // 状態
    var myColor: PColor?
    var players: [String?] = [nil, nil]
    // moves, positionはサーバから受信した指し手で変化させる（自分の指し手で直接変化させない）
    var moves: [Move]
    var position: Position
    var myRemainingTime: Double = 0.0
    var opponentRemainingTime: Double = 0.0
    var moveHistory: [MoveHistoryItem] = []
    var csaKifu: CSAKifu? = nil // ゲーム開始時に初期化、終了時にファイルに保存する
    var csaTimeConfig: CSATimeConfig = CSATimeConfig(totalTime: 0.0, byoyomi: 10.0, increment: 0.0)
    var myScoreCp: Int? = nil
    var _tmpGameSummary: [String: String] = [:] // Game_Summary受信中の情報を蓄積する
    
    // 通信管理
    var connection: NWConnection?
    var recvBuffer: Data = Data()
    var lastSendTime: Date = Date()
    
    
    init(queue: DispatchQueue, csaConfig: CSAConfig, matchManager: MatchManager) {
        self.csaConfig = csaConfig
        self.matchManager = matchManager
        moves = []
        position = Position()
        super.init(queue: queue, initialState: .noConnection)
        setKeepalive()
    }
    
    override func stateChanged(newState: CSAActorState, lastState: CSAActorState) -> Void {
        print("state: \(newState) <- \(lastState)")
        switch newState {
        case .noConnection:
            break
        case .connecting:
            break
        case .waitingGameSummary:
            break
        case .waitingReadyok:
            break
        case .waitingStart:
            break
        case .myTurn:
            // 自分の手番になった
            myRemainingTime += csaTimeConfig.increment
            runGo(ponder: false)
        case .opponentTurn:
            // 相手の手番
            opponentRemainingTime += csaTimeConfig.increment
            if csaConfig.ponder {
                runGo(ponder: true)
            }
            break
        case .endingGame:
            csaKifu?.save()
            csaKifu = nil
            sendCSA(message: "LOGOUT")
            emit(.usi(.gameover(gameResult: "draw")))
        }
    }
    
    private func secToMsStr(_ second: Double) -> String {
        return String(Int((second * 1000).rounded(.towardZero)))
    }
    
    private func runGo(ponder: Bool) {
        // remaining timeに今回手番側回ってきたことによる加算時間は含まない
        let thinkingTime = ThinkingTime(ponder: ponder, remaining: max(myRemainingTime - csaTimeConfig.increment, 0.0), byoyomi: csaTimeConfig.byoyomi, fisher: csaTimeConfig.increment)
        
        var positionCommand = "position startpos"
        if moves.count > 0 {
            positionCommand += " moves " + moves.map({ move in
                move.toUSIString()
            }).joined(separator: " ")
        }

        var goCommand = ""
        if thinkingTime.ponder {
            goCommand = "go ponder btime 1000 wtime 1000 binc 1000"
        } else {
            if myColor == .BLACK {
                goCommand = "go btime \(secToMsStr(thinkingTime.remaining)) wtime 1000 "
                if thinkingTime.fisher > 0.0 {
                    goCommand += "binc \(secToMsStr(thinkingTime.fisher)) winc 1000"
                } else {
                    goCommand += "byoyomi \(secToMsStr(thinkingTime.byoyomi))"
                }
            } else {
                goCommand = "go btime 1000 wtime \(secToMsStr(thinkingTime.remaining)) "
                if thinkingTime.fisher > 0.0 {
                    goCommand += "binc 1000 winc \(secToMsStr(thinkingTime.fisher))"
                } else {
                    goCommand += "byoyomi \(secToMsStr(thinkingTime.byoyomi))"
                }
            }
        }
        
        if ponder {
            emit(.usi(.ponder(position: position.copy(), positionCommand: positionCommand, goCommand: goCommand)))
        } else {
            emit(.usi(.go(position: position.copy(), positionCommand: positionCommand, goCommand: goCommand)))
        }
    }
    
    override func _dispatch(message: CSAActorMessage) {
        switch state {
        case .noConnection:
            switch message {
            case .connect:
                let serverEndpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(self.csaConfig.csaServerIpAddress), port: NWEndpoint.Port(rawValue: self.csaConfig.csaServerPort)!)
                startConnection(serverEndpoint: serverEndpoint)
                state = .connecting
            default:
                unexpected(message)
            }
            break
        case .connecting:
            switch message {
            case .csaConnected:
                self.sendCSA(message: "LOGIN \(self.csaConfig.loginName) \(self.csaConfig.loginPassword)")
                state = .waitingGameSummary
            case .csaDisconnected:
                // 接続失敗
                // TODO
                state = .noConnection
                break
            default:
                unexpected(message)
            }
            break
        case .waitingGameSummary:
            switch message {
            case let .csaRecv(command: command):
                _handleCSACommandWaiting(command: command)
            case .gameSummaryReceived:
                emit(.usi(.isready))
                state = .waitingReadyok
            case .csaDisconnected:
                state = .noConnection
            default:
                unexpected(message)
            }
        case .waitingReadyok:
            switch message {
            case .readyok:
                // 対局開始するようサーバに送る(STARTの返送を期待)
                sendCSA(message: "AGREE")
                state = .waitingStart
            default:
                // 待機中の切断やREJECTもありうる
                unexpected(message)
            }
        case .waitingStart:
            switch message {
            case let .csaRecv(command: command):
                if command.starts(with: "START") {
                    // 対局開始
                    initPosition()
                    // 自分の手番なら思考開始
                    if myColor == position.sideToMove {
                        state = .myTurn
                    } else {
                        state = .opponentTurn
                    }
                } else {
                    unexpected(message)
                }
            default:
                unexpected(message)
            }
        case .myTurn:
            switch message {
            case let .csaRecv(command: command):
                _handleCSACommandGame(command: command)
            case let .bestmove(position: positionForGo, moveUSI: moveUSI, ponderUSI: _, score: score, pvUSI: pvUSI):
                guard let bestMove = Move.fromUSIString(moveUSI: moveUSI) else {
                    fatalError()
                }
                let bestMoveCSA = positionForGo.makeCSAMove(move: bestMove)
                // TODO pvUSIを送る
                myScoreCp = score
                let moveMessage: String
                if let score = score, csaConfig.sendScore {
                    // コメントに評価値を入れる拡張
                    moveMessage = "\(bestMoveCSA),'* \(score)"
                } else {
                    moveMessage = bestMoveCSA
                }
                self.sendCSA(message: moveMessage)
                // 手番の転換は、サーバから消費時間が返ってきた時に行う（ponder開始がその分遅れるデメリットはある）
            case let .endGameReceived(reason: _):
                state = .endingGame
            default:
                unexpected(message)
            }
        case .opponentTurn:
            switch message {
            case let .csaRecv(command: command):
                _handleCSACommandGame(command: command)
            case let .endGameReceived(reason: _):
                state = .endingGame
            default:
                unexpected(message)
            }
        case .endingGame:
            // LOGOUT送信したので、サーバから切断されるのを待つ
            switch message {
            case let .csaRecv(command: command):
                if command != "LOGOUT:completed" {
                    unexpected(message)
                }
            case .csaDisconnected:
                state = .noConnection
            default:
                unexpected(message)
            }
            break
        }
        
        // TODO 状態の種類見直し
        let matchStatusGameState: MatchStatus.GameState
        switch state {
        case .connecting, .noConnection:
            matchStatusGameState = .connecting
        case .waitingStart, .waitingReadyok, .waitingGameSummary:
            matchStatusGameState = .initializing
        case .myTurn, .opponentTurn:
            matchStatusGameState = .playing
        case .endingGame:
            matchStatusGameState = .end(gameResult: "Unknown")
        }
        matchManager.updateMatchStatus(matchStatus: MatchStatus(gameState: matchStatusGameState, players: players, position: position, moveHistory: moveHistory))
    }
    
    private func initPosition() {
        // 対局開始時に呼び出し、局面情報、持ち時間を初期化する
        myRemainingTime = csaTimeConfig.totalTime
        opponentRemainingTime = csaTimeConfig.totalTime
        moves = []
        moveHistory = []
        position.setHirate()
        csaKifu = CSAKifu(players: players)
    }
    
    private func _handleCSACommandWaiting(command: String) {
        if command.starts(with: "BEGIN Game_Summary") {
            _tmpGameSummary = [:]
        }
        let items = command.split(separator: ":", maxSplits: 2)
        _tmpGameSummary[String(items[0])] = items.count > 1 ? String(items[1]) : ""
        
        if command.starts(with: "END Game_Summary") {
            players[0] = _tmpGameSummary["Name+"]
            players[1] = _tmpGameSummary["Name-"]
            
            switch _tmpGameSummary["Your_Turn"] {
            case "+":
                myColor = PColor.BLACK
            case "-":
                myColor = PColor.WHITE
            default:
                logger.error("Your_Turn is unspecified")
                myColor = PColor.BLACK
            }
            
            // FIXME 先手後手で異なる持ち時間には非対応
            if _tmpGameSummary["Time_Unit"] != "1sec" {
                logger.error("Time_Unit!=1sec")
            }
            // 持ち時間情報がないときは、安全側に倒して、秒読み10秒として扱う
            csaTimeConfig = CSATimeConfig(totalTime: Double(_tmpGameSummary["Total_Time"] ?? "0") ?? 0.0, byoyomi: Double(_tmpGameSummary["Byoyomi"] ?? "10") ?? 10.0, increment: Double(_tmpGameSummary["Increment"] ?? "0") ?? 0.0)
            
            dispatch(.gameSummaryReceived)
        }
        // TODO 指定局面戦への対応ではBEGIN Positionの中の指し手を読む必要あり
    }
    
    func _handleCSACommandGame(command: String) {
        if command.starts(with: "+") || command.starts(with: "-") {
            // 自分または相手の指し手
            csaKifu?.appendMove(moveCSAWithTime: command)
            let moveColor = command.starts(with: "+") ? PColor.BLACK : PColor.WHITE
            if let move = position.parseCSAMove(csaMove: command) {
                print("parsed move: \(move.toUSIString())")
                let detail = position.makeDetailedMove(move: move)
                if move.isTerminal {
                    moveHistory.append(MoveHistoryItem(detailedMove: detail, usedTime: nil, scoreCp: nil))
                } else {
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
                                } else {
                                    // 相手の消費時間
                                    print("Opponent used \(timeParsed) sec")
                                    opponentRemainingTime -= timeParsed
                                }
                            }
                        }
                    } catch {
                        print("error on extracting time")
                    }
                    moveHistory.append(MoveHistoryItem(detailedMove: detail, usedTime: usedTime, scoreCp: moveColor == myColor ? myScoreCp : nil))
                    print("\(detail.toPrintString()), \(usedTime ?? -1.0)")
                    
                    // 手番を反転させて、思考開始
                    if moveColor == myColor {
                        // 自分が指した手が返ってきたので相手番
                        // 厳密には、不正な指し手->#ILLEGAL_MOVE->#WINという順に受信する場合があり
                        // 不正な指し手を受信した時点でponderが開始してしまい、思考エンジンに問題が発生するリスクがある。
                        state = .opponentTurn
                    } else {
                        state = .myTurn
                    }
                }
            } else {
                print("parse move failed")
            }
        } else if command.starts(with: "%TORYO") {
            // プロトコル説明では、%TORYO,T10のように消費時間が来るとの説明があるが、floodgateの実装では消費時間情報はついていない。選手権サーバではついている。念のため先頭一致で処理する
            csaKifu?.appendMove(moveCSAWithTime: command)
            moveHistory.append(MoveHistoryItem(detailedMove: DetailedMove.makeResign(sideToMode: position.sideToMove), usedTime: nil, scoreCp: nil))
        } else if command.starts(with: "%KACHI") {
            csaKifu?.appendMove(moveCSAWithTime: command)
            moveHistory.append(MoveHistoryItem(detailedMove: DetailedMove.makeWin(sideToMode: position.sideToMove), usedTime: nil, scoreCp: nil))
        } else if ["#WIN", "#LOSE", "#DRAW", "#CENSORED"].contains(command) {
            // 対局終了
            dispatch(.endGameReceived(reason: command))
        } else if ["#TIME_UP", "#SENNICHITE", "#OUTE_SENNICHITE", "#JISHOGI", "#MAX_MOVES", "#ILLEGAL_MOVE", "#ILLEGAL_ACTION"].contains(command) {
            // 時間切れや千日手等、勝敗が決する原因となる事象
            // TODO 画面表示
        } else if command == "#CHUDAN" {
            // プロトコルによれば対局中断
            // 再開手順が規定されていないため、単に無視する。
        } else {
            print("unhandled CSA message \(command)")
        }
    }
    
    private func startConnection(serverEndpoint: NWEndpoint) {
        recvBuffer = Data()
        connection = NWConnection(to: serverEndpoint, using: .tcp)
        connection?.stateUpdateHandler = {(newState) in
            logger.log("stateUpdateHandler: \(String(describing: newState))")
            print("stateUpdateHandler", newState)
            switch newState {
            case .ready:
                self.dispatch(.csaConnected)
            case .waiting(let nwError):
                // ネットワーク構成が変化するまで待つ=事実上の接続失敗
                self.matchManager.displayMessage("Failed to connect to USI server: \(nwError)")
                self.connection?.cancel()
            case .cancelled:
                self.connection = nil
                // 接続が（自分からor相手からorエラーで）切断した
                // TODO csaConfig.reconnect の場合再接続
                self.dispatch(.csaDisconnected)
            default:
                break
            }
        }
        connection?.start(queue: queue)
        startRecv()
    }
    
    private func startRecv() {
        connection?.receive(minimumIncompleteLength: 0, maximumLength: 65535, completion: {(data,context,flag,error) in
            if let error = error {
                logger.error("receive error: \(String(describing: error))")
                self.matchManager.displayMessage("CSA receive error \(error)")
                // エラーはおそらく続行できないので接続切断
                self.connection?.cancel()
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
                                self.dispatch(.csaRecv(command: commandStr))
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
                    logger.error("receive zero")
                    self.matchManager.displayMessage("CSA disconnected")
                    self.connection?.cancel()
                }
            }
        })
    }
    
    private func _send(messageWithNewline: String) {
        lastSendTime = Date()
        connection?.send(content: messageWithNewline.data(using: .utf8)!, completion: .contentProcessed{ error in
            if let error = error {
                logger.error("send error: \(String(describing: error))")
                print("cannot send", messageWithNewline)
            }
        })
    }
    
    private func sendCSA(message: String) {
        logger.log("send: \(message)")
        print("csasend \(message)")
        matchManager.pushCommunicationHistory(communicationItem: CommunicationItem(direction: .send, message: message))
        _send(messageWithNewline: message + "\n")
    }
    
    private func sendCSA(messages: [String]) {
        for m in messages {
            logger.log("send: \(m)")
            print("csasend \(m)")
            matchManager.pushCommunicationHistory(communicationItem: CommunicationItem(direction: .send, message: m))
        }
        _send(messageWithNewline: messages.map({m in m + "\n"}).joined())
    }
    
    private func setKeepalive() {
        queue.asyncAfter(deadline: .now() + 10.0, execute: keepAlive)
    }
    
    private func keepAlive() {
        // TCP接続維持のために、無送信状態が40秒続いたら空行を送る(30秒未満で送ると反則)
        if lastSendTime.timeIntervalSinceNow < -40.0 {
            print("keepalive at \(Date())")
            _send(messageWithNewline: "\n")
        }
        setKeepalive()
    }
}
