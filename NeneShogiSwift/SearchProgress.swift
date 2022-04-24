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
    let nps: Int
    let totalNodes: Int
    
    init(pvs: [SearchTreeRootForVisualize], nps: Int, totalNodes: Int) {
        self.pvs = pvs
        self.nps = nps
        self.totalNodes = totalNodes
    }
}
