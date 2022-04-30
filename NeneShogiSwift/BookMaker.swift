// 定跡のようなものを作る補助機構
// AirDropなどを用いてPCと連携する必要がある
// 探索対象局面の局面(startpos moves 7g7f...)を「ファイル」アプリで「このiPad内」の「NeneShogiSwift」フォルダに"book_from.txt"として1行1局面で記載する
// 探索結果について"局面\tbestMove\tscore"の形式で"book_score.txt"として1行1局面で保存する

import Foundation

class BookMaker {
    let player: MCTSPlayer
    var sfens: [String] = []
    var results: [String] = []
    var progressMessage: (String) -> Void = {_ in}
    
    init() {
        player = MCTSPlayer()
    }
    
    func makeBook(progressMessage: @escaping (String) -> Void) {
        guard let sfens = readSFENs() else {
            progressMessage("Failed to load sfens")
            return
        }
        
        self.sfens = sfens
        self.progressMessage = progressMessage
        
        progressMessage("Initializing player")
        player.isReady {
            progressMessage("Running")
            self.processNext()
        }
    }
    
    private func processNext() {
        if sfens.count > 0 {
            let sfen = sfens.removeFirst()
            print("sfen: \(sfen)")
            player.position(positionArg: sfen)
            player.go(info: { _ in
            }, thinkingTime: ThinkingTime(ponder: false, remaining: 100.0, byoyomi: 0.0, fisher: 10.0)) { bestMove, scoreCp in
                self.results.append("\(sfen)\t\(bestMove.toUSIString())\t\(String(scoreCp))")
                self.progressMessage("\(self.results.count) / \(self.results.count + self.sfens.count) completed")
                self.processNext()
            }
            
        } else {
            // end. save
            progressMessage("Saving")
            if save() {
                progressMessage("Saved")
            } else {
                progressMessage("Save failed")
            }
        }
        
    }
    
    private func save() -> Bool {
        var txtToWrite = ""
        for item in results {
            txtToWrite += "\(item)\n"
        }
        guard let dirURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return false
        }
        
        let fileURL = dirURL.appendingPathComponent("book_score.txt")
 
        do {
            try txtToWrite.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            return false
        }
        
        return true
    }
    
    private func readSFENs() -> [String]? {
        guard let dirURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        let fileURL = dirURL.appendingPathComponent("book_from.txt")

        guard let fileContents = try? String(contentsOf: fileURL) else {
            return nil
        }
        
        var sfens: [String] = []
        for line in fileContents.split(separator: "\n") {
            if line.count > 0 {
                sfens.append(String(line))
            }
        }
        
        return sfens
    }
}
