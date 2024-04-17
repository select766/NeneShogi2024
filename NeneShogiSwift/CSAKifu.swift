import Foundation
import os

let loggerForCSAKifu = Logger(subsystem: "jp.outlook.select766.NeneShogiSwift", category: "csaKifu")

class CSAKifu {
    var body: String
    var fileName: String
    init(players: [String?]) {
        let startDate = Date()
        let formatForBody = DateFormatter()
        formatForBody.dateFormat = "yyyy/mm/dd H:M:S"
        body = """
V2.2
N+\(players[0] ?? "")
N-\(players[1] ?? "")
$START_TIME:\(formatForBody.string(from: startDate))
P1-KY-KE-GI-KI-OU-KI-GI-KE-KY
P2 * -HI *  *  *  *  * -KA *
P3-FU-FU-FU-FU-FU-FU-FU-FU-FU
P4 *  *  *  *  *  *  *  *  *
P5 *  *  *  *  *  *  *  *  *
P6 *  *  *  *  *  *  *  *  *
P7+FU+FU+FU+FU+FU+FU+FU+FU+FU
P8 * +KA *  *  *  *  * +HI *
P9+KY+KE+GI+KI+OU+KI+GI+KE+KY
+

"""
        let formatForFileName = DateFormatter()
        formatForFileName.dateFormat = "yyyymmddHMS"
        fileName = "kifu_\(formatForFileName.string(from: startDate)).csa"
    }
    
    func appendMove(moveCSAWithTime: String) {
        // +2726FU,T10
        let elems = moveCSAWithTime.split(separator: ",")
        body += "\(elems[0])\n"
        if elems.count > 1 {
            body += "\(elems[1])\n"
        }
        
    }
    
    @discardableResult
    func save() -> Bool {
        guard let dirURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            loggerForCSAKifu.error("FileManager.default.urls failed")
            return false
        }
        
        let fileURL = dirURL.appendingPathComponent(fileName)
 
        do {
            try body.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            loggerForCSAKifu.error("String.write failed \(String(describing: error), privacy: .public)")
            return false
        }
        
        loggerForCSAKifu.notice("Written kifu to \(self.fileName, privacy: .public)")
        return true
    }
}
