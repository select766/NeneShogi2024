import Foundation
import CoreML

class NNPlayerBase: PlayerProtocol {
    var position: Position
    var model: DlShogiResnet10SwishBatch?
    init() {
        position = Position()
    }
    
    func isReady() {
        // モデルの準備
        let config = MLModelConfiguration()
        config.computeUnits = .all//デバイス指定(all/cpuAndGPU/cpuOnly)
        model = try! DlShogiResnet10SwishBatch(configuration: config)
    }
    
    func usiNewGame() {}
    
    func position(positionArg: String) {
        // positionコマンド
        position.setUSIPosition(positionArg: positionArg)
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
    
    func go(info: (String) -> Void, thinkingTime: ThinkingTime) -> String {
        // goコマンド
        fatalError()
    }
}
