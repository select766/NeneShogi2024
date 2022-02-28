let _pieceFromChar = [
    "P": Piece.B_PAWN, "L": Piece.B_LANCE, "N": Piece.B_KNIGHT, "S": Piece.B_SILVER,
    "B": Piece.B_BISHOP, "R": Piece.B_ROOK, "G": Piece.B_GOLD, "K": Piece.B_KING,
    "+P": Piece.B_PRO_PAWN, "+L": Piece.B_PRO_LANCE, "+N": Piece.B_PRO_KNIGHT, "+S": Piece.B_PRO_SILVER,
    "+B": Piece.B_HORSE, "+R": Piece.B_DRAGON,
    "p": Piece.W_PAWN, "l": Piece.W_LANCE, "n": Piece.W_KNIGHT, "s": Piece.W_SILVER,
    "b": Piece.W_BISHOP, "r": Piece.W_ROOK, "g": Piece.W_GOLD, "k": Piece.W_KING,
    "+p": Piece.W_PRO_PAWN, "+l": Piece.W_PRO_LANCE, "+n": Piece.W_PRO_KNIGHT, "+s": Piece.W_PRO_SILVER,
    "+b": Piece.W_HORSE, "+r": Piece.W_DRAGON
]
let _charFromPiece = Dictionary(uniqueKeysWithValues: _pieceFromChar.map({key, value in (value.piece, key)}))

struct Piece: Equatable {
    let piece: Int
    init(_ piece: Int) {
        self.piece = piece
    }
    
    // 駒が特定の色かどうか判定する
    func isColor(color: PColor) -> Bool {
        if (self.piece == Piece.PIECE_ZERO.piece) {
            return false
        }
        return self.piece / Piece.PIECE_WHITE == color.color
    }
    
    // 駒の色を取得する。駒がない場合はBLACKが返る
    func getColor() -> PColor {
        return self.piece >= Piece.PIECE_WHITE ? PColor.WHITE : PColor.BLACK
    }
    
    // 駒が存在するかどうか(空のマスでないか)を判定する
    func isExist() -> Bool {
        return self.piece != Piece.PIECE_ZERO.piece
    }
    
    func toPieceString() -> String? {
        return _charFromPiece[piece]
    }
    
    static func fromPieceString(pieceString: String) -> Piece? {
        return _pieceFromChar[pieceString]
    }
    
    static let PAWN = 1  // 歩
    static let LANCE = 2  // 香
    static let KNIGHT = 3  // 桂
    static let SILVER = 4  // 銀
    static let BISHOP = 5  // 角
    static let ROOK = 6  // 飛
    static let GOLD = 7  // 金
    static let KING = 8  // 玉
    static let PRO_PAWN = 9  // と
    static let PRO_LANCE = 10  // 成香
    static let PRO_KNIGHT = 11  // 成桂
    static let PRO_SILVER = 12  // 成銀
    static let HORSE = 13  // 馬
    static let DRAGON = 14  // 竜
    static let QUEEN = 15  // 未使用
    
    // 先手の駒
    static let B_PAWN = Piece(1)
    static let B_LANCE = Piece(2)
    static let B_KNIGHT = Piece(3)
    static let B_SILVER = Piece(4)
    static let B_BISHOP = Piece(5)
    static let B_ROOK = Piece(6)
    static let B_GOLD = Piece(7)
    static let B_KING = Piece(8)
    static let B_PRO_PAWN = Piece(9)
    static let B_PRO_LANCE = Piece(10)
    static let B_PRO_KNIGHT = Piece(11)
    static let B_PRO_SILVER = Piece(12)
    static let B_HORSE = Piece(13)
    static let B_DRAGON = Piece(14)
    static let B_QUEEN = Piece(15)  // 未使用
    
    // 後手の駒
    static let W_PAWN = Piece(17)
    static let W_LANCE = Piece(18)
    static let W_KNIGHT = Piece(19)
    static let W_SILVER = Piece(20)
    static let W_BISHOP = Piece(21)
    static let W_ROOK = Piece(22)
    static let W_GOLD = Piece(23)
    static let W_KING = Piece(24)
    static let W_PRO_PAWN = Piece(25)
    static let W_PRO_LANCE = Piece(26)
    static let W_PRO_KNIGHT = Piece(27)
    static let W_PRO_SILVER = Piece(28)
    static let W_HORSE = Piece(29)
    static let W_DRAGON = Piece(30)
    static let W_QUEEN = Piece(31)  // 未使用
    
    static let PIECE_NB = 32
    static let PIECE_ZERO = Piece(0)
    static let PIECE_PROMOTE = 8
    static let PIECE_WHITE = 16
    static let PIECE_RAW_NB = 8
    static let PIECE_HAND_ZERO = PAWN  // 手駒の駒種最小値
    static let PIECE_HAND_NB = KING  // 手駒の駒種最大値 + Piece(1)
}
