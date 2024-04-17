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
    
    init(callback: CSAStatusCallback, csaConfig: CSAConfig) {
        queue = DispatchQueue(label: "csaClient")
        usiActor = USIActor(queue: queue, csaConfig: csaConfig, callback: callback)
        csaActor = CSAActor(queue: queue, csaConfig: csaConfig, callback: callback)
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
            logger.notice("dispatch \(type(of: message), privacy: .public) \(String(describing: message), privacy: .public)")
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
        logger.error("\(s, privacy: .public)")
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
    
    
    let callback: CSAStatusCallback
    let csaConfig: CSAConfig
    var positionForGo: Position? = nil
    var pendingMessageOnPonder: USIActorMessage? = nil
    var pvScore: Int? = nil
    var pvUSI: [String]? = nil
    
    init(queue: DispatchQueue, csaConfig: CSAConfig, callback: CSAStatusCallback) {
        self.csaConfig = csaConfig
        self.callback = callback
        super.init(queue: queue, initialState: .beforeLaunch)
    }
    
    override func stateChanged(newState: USIActorState, lastState: USIActorState) {
        logger.notice("usi state: \(String(describing: newState), privacy: .public) <- \(String(describing: lastState), privacy: .public)")
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
                    for option in csaConfig.usiOptions {
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
                    if let commandArg = commandArg {
                        let searchProgress = USISearchProgress.parseGoInfo(commandArg: commandArg)
                        // 最後に受信したPV, ScoreをbestmoveのPV, Scoreとみなす
                        if let pvUSI = searchProgress.pvUSI {
                            self.pvUSI = pvUSI
                        }
                        if let pvScore = searchProgress.score {
                            self.pvScore = pvScore
                        }
                        if let positionForGo = positionForGo {
                            emit(.csa(.searchProgress(position: positionForGo, usiSearchProgress: searchProgress)))
                        }
                    }
                } else if commandType == "bestmove" {
                    if let positionForGo = positionForGo, let commandArg = commandArg {
                        let parts = commandArg.split(separator: " ")
                        let moveUSI = String(parts[0])
                        let ponderUSI = parts.count >= 3 ? String(parts[2]) : nil
                        emit(.csa(.bestmove(position: positionForGo, moveUSI: moveUSI, ponderUSI: ponderUSI, score: pvScore, pvUSI: pvUSI)))
                        self.positionForGo = nil
                        state = .gameIdle
                    } else {
                        logger.error("wrong condition for bestmove: \(String(describing: message), privacy: .public)")
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
                    logger.error("multiple go/ponder requests while running previous ponder")
                    // error
                }
                pendingMessageOnPonder = message
                yaneSend("stop")
            case .ponder:
                // ponderをstopで終了して、bestmoveが来てからgo ponderを送りたい
                if pendingMessageOnPonder != nil {
                    logger.error("multiple go/ponder requests while running previous ponder")
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
                logger.notice("discarding usi message after gameover: \(commandType, privacy: .public)")
            case .endGameWaitEnd:
                state = .waitingGame
            default:
                // すぐに次の対局が開始する場合に本当は備えたい
                unexpected(message)
            }
        }
    }
    
    private func yaneRecv(command: String) -> Void {
        callback.appendCommnicationHistory("U< \(command)")
        logger.notice("U< \(command, privacy: .public)")
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
        callback.appendCommnicationHistory("U> \(commandWithoutNewLine)")
        logger.notice("U> \(commandWithoutNewLine, privacy: .public)")
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
        case searchProgress(position: Position, usiSearchProgress: USISearchProgress)
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
        case abortGame // 対局最中に切断・プロトコルエラーによりエンジンを終了（再接続設定がされていれば、再接続）
        case disconnected
    }
    
    enum CSAActorEmitMessage {
        case usi(USIActor.USIActorMessage)
    }
    
    let csaConfig: CSAConfig
    let callback: CSAStatusCallback
    
    // 状態
    var myColor: PColor?
    var players: [String?] = [nil, nil]
    // moves, positionはサーバから受信した指し手で変化させる（自分の指し手で直接変化させない）
    var moves: [Move]
    var position: Position
    var myRemainingTime: RemainingTime = RemainingTime(remainingTime: 0.0, decreasing: false)
    var opponentRemainingTime: RemainingTime = RemainingTime(remainingTime: 0.0, decreasing: false)
    var moveHistory: [MoveHistoryItem] = []
    var csaKifu: CSAKifu? = nil // ゲーム開始時に初期化、終了時にファイルに保存する
    var csaTimeConfig: CSATimeConfig = CSATimeConfig(totalTime: 0.0, byoyomi: 10.0, increment: 0.0)
    var myScoreCp: Int? = nil
    var lastGameResult: String? = nil
    var _tmpGameSummary: [String: String] = [:] // Game_Summary受信中の情報を蓄積する
    var _tmpAbnormalGameTerminationReason: String? = nil
    
    // 通信管理
    var connection: NWConnection?
    var recvBuffer: Data = Data()
    var lastSendTime: Date = Date()
    
    
    init(queue: DispatchQueue, csaConfig: CSAConfig, callback: CSAStatusCallback) {
        self.csaConfig = csaConfig
        self.callback = callback
        moves = []
        position = Position()
        super.init(queue: queue, initialState: .noConnection)
        setKeepalive()
    }
    
    override func stateChanged(newState: CSAActorState, lastState: CSAActorState) -> Void {
        logger.notice("csa state: \(String(describing: newState), privacy: .public) <- \(String(describing: lastState), privacy: .public)")
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
            myRemainingTime = RemainingTime(remainingTime: myRemainingTime.remainingTime + csaTimeConfig.increment, decreasing: true)
            opponentRemainingTime = opponentRemainingTime.stopDecreasing()
            runGo(ponder: false)
        case .opponentTurn:
            // 相手の手番
            opponentRemainingTime = RemainingTime(remainingTime: opponentRemainingTime.remainingTime + csaTimeConfig.increment, decreasing: true)
            myRemainingTime = myRemainingTime.stopDecreasing()
            if csaConfig.ponder {
                runGo(ponder: true)
            }
            break
        case .endingGame:
            myRemainingTime = myRemainingTime.stopDecreasing()
            opponentRemainingTime = opponentRemainingTime.stopDecreasing()
            csaKifu?.save()
            csaKifu = nil
            sendCSA(message: "LOGOUT")
            emit(.usi(.gameover(gameResult: "draw")))
        case .abortGame:
            myRemainingTime = myRemainingTime.stopDecreasing()
            opponentRemainingTime = opponentRemainingTime.stopDecreasing()
            csaKifu?.save()
            csaKifu = nil
            emit(.usi(.gameover(gameResult: "draw")))
            queue.asyncAfter(deadline: .now() + 1.0, execute: {
                self.state = .disconnected
            })
        case .disconnected:
            if csaConfig.reconnect {
                queue.asyncAfter(deadline: .now() + 10.0, execute: {
                    self.dispatch(.connect)
                })
            }
        }
    }
    
    private func secToMsStr(_ second: Double) -> String {
        return String(Int((second * 1000).rounded(.towardZero)))
    }
    
    private func runGo(ponder: Bool) {
        // remaining timeに今回手番側回ってきたことによる加算時間は含まない
        let thinkingTime = ThinkingTime(ponder: ponder, remaining: max(myRemainingTime.remainingTime - csaTimeConfig.increment, 0.0), byoyomi: csaTimeConfig.byoyomi, fisher: csaTimeConfig.increment)
        
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
                state = .disconnected
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
                state = .disconnected
            default:
                unexpected(message)
            }
        case .waitingReadyok:
            switch message {
            case .readyok:
                // 対局開始するようサーバに送る(STARTの返送を期待)
                sendCSA(message: "AGREE")
                state = .waitingStart
            case .csaDisconnected:
                state = .disconnected
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
                    // TODO REJECTの正しい対応
                    unexpected(message)
                }
            case .csaDisconnected:
                state = .disconnected
            default:
                unexpected(message)
            }
        case .myTurn:
            switch message {
            case let .csaRecv(command: command):
                _handleCSACommandGame(command: command)
            case let .searchProgress(position: position, usiSearchProgress: usiSearchProgress):
                // Positionを用いてPVを変換してSearchProgressを作成
                let pos = position.copy()
                // PVのある行だけ処理（info stringな行は無視する）
                if let pvUSI = usiSearchProgress.pvUSI {
                    var pv: [DetailedMove] = []
                    for moveUSI in pvUSI {
                        if let move = Move.fromUSIString(moveUSI: moveUSI) {
                            pv.append(pos.makeDetailedMove(move: move))
                            pos.doMove(move: move)
                        } else {
                            // なんらかの問題でパースできない
                            break
                        }
                    }
                    
                    callback.updateSearchProgress(searchProgress: SearchProgress(position: position.copy(), pv: pv, score: usiSearchProgress.score, nps: usiSearchProgress.nps))
                }
                break
            case let .bestmove(position: positionForGo, moveUSI: moveUSI, ponderUSI: _, score: score, pvUSI: _):
                guard let bestMove = Move.fromUSIString(moveUSI: moveUSI) else {
                    fatalError()
                }
                let bestMoveCSA = positionForGo.makeCSAMove(move: bestMove)
                // TODO pvUSIを送る(先頭がbestmoveと一致するかチェック必要)
                myScoreCp = score
                let moveMessage: String
                if let score = score, csaConfig.sendScore {
                    // コメントに評価値を入れる拡張
                    // CSAプロトコルでは、常に先手の立場の符号で送る
                    let scoreFromBlack = myColor == PColor.BLACK ? score : -score
                    moveMessage = "\(bestMoveCSA),'* \(scoreFromBlack)"
                } else {
                    moveMessage = bestMoveCSA
                }
                self.sendCSA(message: moveMessage)
                // 手番の転換は、サーバから消費時間が返ってきた時に行う（ponder開始がその分遅れるデメリットはある）
            case let .endGameReceived(reason: reason):
                lastGameResult = reason
                state = .endingGame
            case .csaDisconnected:
                state = .abortGame
            default:
                unexpected(message)
            }
        case .opponentTurn:
            switch message {
            case let .csaRecv(command: command):
                _handleCSACommandGame(command: command)
            case let .endGameReceived(reason: reason):
                lastGameResult = reason
                state = .endingGame
            case .csaDisconnected:
                state = .abortGame
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
                state = .disconnected
            default:
                unexpected(message)
            }
            break
        case .abortGame:
            switch message {
            case .csaDisconnected:
                break
            default:
                unexpected(message)
            }
        case .disconnected:
            switch message {
            case .connect:
                // TODO: .noConnectとの重複を減らす
                let serverEndpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(self.csaConfig.csaServerIpAddress), port: NWEndpoint.Port(rawValue: self.csaConfig.csaServerPort)!)
                startConnection(serverEndpoint: serverEndpoint)
                state = .connecting
            default:
                unexpected(message)
            }
        }
        
        emitState()
    }
    
    private func emitState() {
        let csaGameState: CSAGameState
        switch state {
        case .noConnection:
            csaGameState = .initializingUSI
        case .connecting:
            csaGameState = .initializingCSA
        case .waitingGameSummary:
            csaGameState = .waitingNewGame
        case .waitingReadyok:
            csaGameState = .initializingNewGame
        case .waitingStart:
            csaGameState = .waitingGameStart
        case .myTurn:
            csaGameState = .playing
        case .opponentTurn:
            csaGameState = .playing
        case .endingGame:
            csaGameState = .ended
        case .abortGame:
            csaGameState = .ended
        case .disconnected:
            csaGameState = .ended
        }
        
        // 配列をGUIスレッドに送ると、レースコンディションで破損する事例があるのでforceArrayCopyを使う
        callback.updateMatchStatus(
            players: forceArrayCopy(players),
            moveHistory: forceArrayCopy(moveHistory),
            remainingTimes: myColor == .BLACK ? [myRemainingTime, opponentRemainingTime] : [opponentRemainingTime, myRemainingTime],
            csaGameState: csaGameState,
            lastGameResult: lastGameResult
        )
    }
    
    private func initPosition() {
        // 対局開始時に呼び出し、局面情報、持ち時間を初期化する
        myRemainingTime = RemainingTime(remainingTime: csaTimeConfig.totalTime, decreasing: false)
        opponentRemainingTime = RemainingTime(remainingTime: csaTimeConfig.totalTime, decreasing: false)
        moves = []
        moveHistory = []
        position.setHirate()
        _tmpAbnormalGameTerminationReason = nil
        lastGameResult = nil
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
                logger.notice("parsed move: \(move.toUSIString(), privacy: .public)")
                let detail = position.makeDetailedMove(move: move)
                if move.isTerminal {
                    moveHistory.append(MoveHistoryItem(positionBeforeMove: position.copy(), positionAfterMove: nil, detailedMove: detail, usedTime: nil, scoreCp: nil))
                } else {
                    moves.append(move)
                    let positionBeforeMove = position.copy()
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
                                    logger.notice("I used \(timeParsed, privacy: .public) sec")
                                    myRemainingTime = RemainingTime(remainingTime: myRemainingTime.remainingTime - timeParsed, decreasing: myRemainingTime.decreasing)
                                } else {
                                    // 相手の消費時間
                                    logger.notice("Opponent used \(timeParsed, privacy: .public) sec")
                                    opponentRemainingTime = RemainingTime(remainingTime: opponentRemainingTime.remainingTime - timeParsed, decreasing: opponentRemainingTime.decreasing)
                                }
                            }
                        }
                    } catch {
                        logger.error("error on extracting time")
                    }
                    moveHistory.append(MoveHistoryItem(positionBeforeMove: positionBeforeMove, positionAfterMove: position.copy(), detailedMove: detail, usedTime: usedTime, scoreCp: moveColor == myColor ? myScoreCp : nil))
                    
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
                logger.error("parse move failed")
            }
        } else if command.starts(with: "%TORYO") {
            // プロトコル説明では、%TORYO,T10のように消費時間が来るとの説明があるが、floodgateの実装では消費時間情報はついていない。選手権サーバではついている。念のため先頭一致で処理する
            csaKifu?.appendMove(moveCSAWithTime: command)
            moveHistory.append(MoveHistoryItem(positionBeforeMove: position.copy(), positionAfterMove: nil, detailedMove: DetailedMove.makeResign(sideToMode: position.sideToMove), usedTime: nil, scoreCp: nil))
        } else if command.starts(with: "%KACHI") {
            csaKifu?.appendMove(moveCSAWithTime: command)
            moveHistory.append(MoveHistoryItem(positionBeforeMove: position.copy(), positionAfterMove: nil, detailedMove: DetailedMove.makeWin(sideToMode: position.sideToMove), usedTime: nil, scoreCp: nil))
        } else if ["#WIN", "#LOSE", "#DRAW", "#CENSORED"].contains(command) {
            // 対局終了
            var endReason = command
            if let _tmpAbnormalGameTerminationReason = _tmpAbnormalGameTerminationReason {
                endReason = "\(endReason)(\(_tmpAbnormalGameTerminationReason))"
            }
            dispatch(.endGameReceived(reason: endReason))
        } else if ["#TIME_UP", "#SENNICHITE", "#OUTE_SENNICHITE", "#JISHOGI", "#MAX_MOVES", "#ILLEGAL_MOVE", "#ILLEGAL_ACTION"].contains(command) {
            // 時間切れや千日手等、勝敗が決する原因となる事象
            _tmpAbnormalGameTerminationReason = command
        } else if command == "#CHUDAN" {
            // プロトコルによれば対局中断
            // 再開手順が規定されていないため、単に無視する。
        } else {
            logger.error("unhandled CSA message \(command, privacy: .public)")
        }
    }
    
    private func startConnection(serverEndpoint: NWEndpoint) {
        recvBuffer = Data()
        connection = NWConnection(to: serverEndpoint, using: .tcp)
        connection?.stateUpdateHandler = {(newState) in
            logger.notice("stateUpdateHandler: \(String(describing: newState), privacy: .public)")
            switch newState {
            case .ready:
                self.dispatch(.csaConnected)
            case .waiting(let nwError):
                // ネットワーク構成が変化するまで待つ=事実上の接続失敗
                self.callback.appendCommnicationHistory("C! Failed to connect to USI server: \(nwError)")
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
                logger.error("receive error: \(String(describing: error), privacy: .public)")
                self.callback.appendCommnicationHistory("C! \(error)")
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
                                // 接続維持用の空行が受信される場合があるので無視
                                if !commandStr.isEmpty {
                                    self.callback.appendCommnicationHistory("C< \(commandStr)")
                                    self.dispatch(.csaRecv(command: commandStr))
                                }
                            } else {
                                logger.error("C! Cannot decode CSA data as utf-8")
                                self.callback.appendCommnicationHistory("C! Cannot decode CSA data as utf-8")
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
                    self.callback.appendCommnicationHistory("C! disconnected")
                    self.connection?.cancel()
                }
            }
        })
    }
    
    private func _send(messageWithNewline: String) {
        lastSendTime = Date()
        connection?.send(content: messageWithNewline.data(using: .utf8)!, completion: .contentProcessed{ error in
            if let error = error {
                logger.error("send error: \(String(describing: error), privacy: .public) while sending \(messageWithNewline, privacy: .public)")
            }
        })
    }
    
    private func sendCSA(message: String) {
        logger.notice("C> \(message, privacy: .public)")
        callback.appendCommnicationHistory("C> \(message)")
        _send(messageWithNewline: message + "\n")
    }
    
    private func sendCSA(messages: [String]) {
        for m in messages {
            logger.notice("C> \(m, privacy: .public)")
            callback.appendCommnicationHistory("C> \(m)")
        }
        _send(messageWithNewline: messages.map({m in m + "\n"}).joined())
    }
    
    private func setKeepalive() {
        queue.asyncAfter(deadline: .now() + 10.0, execute: keepAlive)
    }
    
    private func keepAlive() {
        // TCP接続維持のために、無送信状態が40秒続いたら空行を送る(30秒未満で送ると反則)
        if lastSendTime.timeIntervalSinceNow < -40.0 {
            logger.notice("keepalive at \(Date(), privacy: .public)")
            _send(messageWithNewline: "\n")
        }
        setKeepalive()
    }
}
