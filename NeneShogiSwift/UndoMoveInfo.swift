struct UndoMoveInfo {
    let fromSq: Square
    let toSq: Square
    let handType: Int
    let fromValue: Piece
    let toValue: Piece
    let handValue: Int
    init(fromSq: Square, fromValue: Piece, toSq: Square, toValue: Piece, handType: Int, handValue: Int) {
        self.fromSq=fromSq
        self.fromValue=fromValue
        self.toSq=toSq
        self.toValue=toValue
        self.handType=handType
        self.handValue=handValue
    }
}
