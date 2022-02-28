//
//  USIClient.swift
//  NeneShogiSwift
//
//  Created by Masatoshi Hidaka on 2022/02/14.
//

import Foundation
import Network
import CoreML


class USIClient {
    let matchManager: MatchManager
    var serverEndpoint = NWEndpoint.hostPort(host: NWEndpoint.Host("localhost"), port: NWEndpoint.Port(8090))
    var connection: NWConnection?
    let queue: DispatchQueue
    var recvBuffer: Data = Data()
    var position: Position // 暫定的にUSIClientが対局を管理している
    let model: DlShogiResnet10SwishBatch // 暫定的にUSIClientがモデルを管理している
    init(matchManager: MatchManager) {
        self.matchManager = matchManager // TODO: 循環参照回避
        queue = DispatchQueue(label: "usiClient")
        self.position = Position()
        let config = MLModelConfiguration()
        config.computeUnits = .all//デバイス指定(all/cpuAndGPU/cpuOnly)
        model = try! DlShogiResnet10SwishBatch(configuration: config)
    }
    
    func start() {
        self.matchManager.displayMessage("connecting to USI server")
        connection = NWConnection(to: serverEndpoint, using: .tcp)
        connection?.stateUpdateHandler = {(newState) in
            print("stateUpdateHandler", newState)
            switch newState {
            case .ready:
                self.matchManager.displayMessage("connected to USI server")
                self.startRecv()
            case .waiting(let nwError):
                // ネットワーク構成が変化するまで待つ=事実上の接続失敗
                // TODO: 接続失敗時のアクション
                self.matchManager.displayMessage("Failed to connect to USI server: \(nwError)")
            default:
                break
            }
        }
        connection?.start(queue: queue)
    }
    
    func startRecv() {
        connection?.receive(minimumIncompleteLength: 0, maximumLength: 65535, completion: {(data,context,flag,error) in
            if let error = error {
                self.matchManager.displayMessage("USI receive error \(error)")
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
                                self.handleUSICommand(command: commandStr)
                            } else {
                                print("Cannot decode USI data as utf-8")
                                self.matchManager.displayMessage("Cannot decode USI data as utf-8")
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
                    self.matchManager.displayMessage("USI disconnected")
                }
            }
        })
    }
    
    func goRandom() -> String {
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
    
    func goPolicy() -> String {
        print(position.getSFEN())
        let moves = position.generateMoveList()
        let inputArray = position.getDNNInput()
        if moves.count == 0 {
            return "resign"
        }
        guard let mmArray = try? MLMultiArray(shape: [1, 119, 9, 9], dataType: .float32) else {
            fatalError("Cannot allocate MLMultiArray")
        }
        let mmRawPtr = UnsafeMutablePointer<Float>(OpaquePointer(mmArray.dataPointer))
        for i in 0..<inputArray.count {
            mmRawPtr[i] = Float(inputArray[i])
        }
        let pred = try! model.prediction(x: mmArray)
        let moveArray = UnsafeMutablePointer<Float>(OpaquePointer(pred.move.dataPointer))
        var bestMove = "resign"
        var bestScore = Float(-100.0)
        for move in moves {
            let moveLabel = position.getDNNMoveLabel(move: move)
            let score = moveArray[moveLabel]
            if score >= bestScore {
                bestScore = score
                bestMove = move.toUSIString()
            }
        }
        let resultArray = UnsafeMutablePointer<Float>(OpaquePointer(pred.result.dataPointer))
        let winrate = resultArray[0]
        let cp = logf(winrate / (1.0 - winrate)) * 600.0
        // 極端な値をInt()でキャストすると例外発生
        let cpInt: Int32
        if cp.isNaN {
            if winrate > 0.5 {
                cpInt = 30000
            } else {
                cpInt = -30000
            }
        } else {
            if cp > 30000.0 {
                cpInt = 30000
            } else if cp < -30000.0 {
                cpInt = 30000
            } else {
                cpInt = Int32(cp)
            }
        }
        sendUSI(message: "info depth 1 score cp \(cpInt) pv \(bestMove)")
        
        return bestMove
    }
    
    func handleUSICommand(command: String) {
        self.matchManager.displayMessage("USI recv: '\(command)'")
        let splits = command.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
        if splits.count < 1 {
            return
        }
        let commandType = splits[0]
        let commandArg = splits.count == 2 ? String(splits[1]) : nil
        switch commandType {
        case "usi":
            // TODO: add "option"
            sendUSI(messages: ["id name NeneShogiSwift", "id author select766", "usiok"])
        case "isready":
            sendUSI(message: "readyok")
        case "setoption":
            break
        case "usinewgame":
            break
        case "position":
            if let commandArg = commandArg {
                position.setUSIPosition(positionArg: commandArg)
            }
            break
        case "go":
            let bestMove = goPolicy()
            sendUSI(message: "bestmove \(bestMove)")
        case "gameover":
            break
        case "quit":
            // 接続を切断することで接続先のncコマンドが終了する
            connection?.cancel()
            connection = nil
            // TODO: AI側終了
        default:
            print("Unknown command \(command)")
        }
    }
    
    func _send(messageWithNewline: String) {
        connection?.send(content: messageWithNewline.data(using: .utf8)!, completion: .contentProcessed{ error in
            if let error = error {
                print("Error in send", error)
            } else {
                print("send ok")
            }
        })
        
    }
    
    func sendUSI(message: String) {
        _send(messageWithNewline: message + "\n")
    }
    
    func sendUSI(messages: [String]) {
        _send(messageWithNewline: messages.map({m in m + "\n"}).joined())
    }
}
