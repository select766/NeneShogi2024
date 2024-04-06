// CSAプロトコルの接続情報
struct CSAConfig: Codable {
    var csaServerIpAddress: String
    var csaServerPort: UInt16
    var reconnect: Bool
    var loginName: String
    var loginPassword: String
    var ponder: Bool
}
