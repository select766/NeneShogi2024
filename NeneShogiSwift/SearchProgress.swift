import Foundation

struct SearchTreeNodeForVisualize {
    let moveFromParent: DetailedMove
    let pv: [DetailedMove]
    let moveCount: Int
    let winrateMean: Float
    let winrateStd: Float
    
}

struct SearchTreeRootForVisualize {
    let rootMoveNode: SearchTreeNodeForVisualize
    let childNodes: [SearchTreeNodeForVisualize]
}

// 可視化及びサーバに読み筋を送るための探索進捗情報
class SearchProgress {
    let pvs: [SearchTreeRootForVisualize]
    // TODO: 残り時間
    // TODO: 探索ノード数
    // TODO: NPS
    
    init(pvs: [SearchTreeRootForVisualize]) {
        self.pvs = pvs
    }
}
