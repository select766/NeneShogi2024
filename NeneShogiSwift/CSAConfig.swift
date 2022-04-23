// CSAプロトコルの接続情報
struct CSAConfig {
    var csaServerIpAddress: String
    var csaServerPort: UInt16
    var reconnect: Bool
    var loginName: String
    var loginPassword: String
    var ponder: Bool
    // 開始時の持ち時間
    var timeTotalSec: Double
    // 手番が来た時の加算時間（フィッシャー）※秒読み未実装
    var timeIncrementSec: Double
}
