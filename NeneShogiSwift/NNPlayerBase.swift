import Foundation
import CoreML

class NNPlayerBase: PlayerProtocol {
    var position: Position
    var model: DlShogiResnet15x224SwishBatch?
    let searchDispatchQueue: DispatchQueue
    init() {
        position = Position()
        searchDispatchQueue = DispatchQueue(label: "NNPlayerBase")
    }
    
    func isReady(callback: @escaping () -> Void) {
        searchDispatchQueue.async {
            // モデルの準備
            let config = MLModelConfiguration()
            config.computeUnits = .all//デバイス指定(all/cpuAndGPU/cpuOnly)
            self.model = try! DlShogiResnet15x224SwishBatch(configuration: config)
            callback()
        }
    }
    
    func usiNewGame() {}
    
    func position(positionArg: String) {
        // positionコマンド
        position.setUSIPosition(positionArg: positionArg)
    }
    
    func position(moves: [Move]) {
        position.setPosition(moves: moves)
    }
    
    func winRateToCp(winrate: Float)-> Int {
        let cp = logf(winrate / (1.0 - winrate)) * 600.0
        // 極端な値をInt()でキャストすると例外発生
        let cpInt: Int
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
                cpInt = Int(cp)
            }
        }
        return cpInt
    }
    
    func go(info: @escaping (SearchProgress) -> Void, thinkingTime: ThinkingTime, callback: @escaping (Move) -> Void) {
        // goコマンド
        fatalError()
    }
    
    func stop() {}
}
