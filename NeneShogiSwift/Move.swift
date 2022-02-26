import Foundation

let moveFileToUSI: [String] = "123456789".map({String($0)})
let moveRankToUSI: [String] = "abcdefghi".map({String($0)})
let dropChars: [String] = " PLNSBRG".map({String($0)})

struct Move: Equatable {
    let moveFrom: Square;
    let moveTo: Square;
    let moveDroppedPiece: Int;
    let isPromote: Bool;
    let isDrop: Bool;
    
    init() {
        self.init(moveFrom: Square(0), moveTo: Square(0), moveDroppedPiece: 0, isPromote: false, isDrop: false)
    }
    
    init(moveFrom: Square, moveTo: Square, moveDroppedPiece: Int, isPromote: Bool, isDrop: Bool) {
        self.moveFrom = moveFrom
        self.moveTo = moveTo
        self.moveDroppedPiece = moveDroppedPiece
        self.isPromote = isPromote
        self.isDrop = isDrop
    }
    
    static func makeMove(moveFrom: Square, moveTo: Square, isPromote: Bool = false) -> Move {
        return Move(moveFrom: moveFrom, moveTo: moveTo, moveDroppedPiece: 0, isPromote: isPromote, isDrop: false)
    }
    
    static func makeMoveDrop(moveDroppedPiece: Int, moveTo: Square) -> Move {
        return Move(moveFrom: Square(0), moveTo: moveTo, moveDroppedPiece: moveDroppedPiece, isPromote: false, isDrop: true)
    }
    
    func hash() -> Int {
        return moveTo.square + (moveFrom.square << 7) + (moveDroppedPiece << 7) + (isDrop ? 16384 : 0) + (isPromote ? 32768 : 0)
    }
    
    static func fromUSIString(moveUSI: String) -> Move? {
        guard let rawAscii = moveUSI.data(using: .ascii) else {
            return nil
        }
        let toFile = rawAscii[2] - 0x31// - '1'
        let toRank = rawAscii[3] - 0x61// - 'a'
        let toSq = Square.fromFileRank(file: Int(toFile), rank: Int(toRank))
        let fromFile = rawAscii[0] - 0x31
        if (fromFile > 8) {
            // piece drop format: P*7g
            let dropPt: Int
            switch rawAscii[0] {
            case 0x50://P
                dropPt = Piece.PAWN
            case 0x4c://L
                dropPt = Piece.LANCE
            case 0x4e://N
                dropPt = Piece.KNIGHT
            case 0x53://S
                dropPt = Piece.SILVER
            case 0x42://B
                dropPt = Piece.BISHOP
            case 0x52://R
                dropPt = Piece.ROOK
            case 0x47://G
                dropPt = Piece.GOLD
            default:
                fatalError("Unknown piece type")
            }
            
            return makeMoveDrop(moveDroppedPiece: dropPt, moveTo: toSq)
        } else {
            let fromRank = rawAscii[1] - 0x61// - 'a'
            let isPromote = rawAscii.count >= 5
            return makeMove(moveFrom: Square.fromFileRank(file: Int(fromFile), rank: Int(fromRank)), moveTo: toSq, isPromote: isPromote)
        }
    }
    
    func toUSIString() -> String {
        let toFileChar = moveFileToUSI[moveTo.file]
        let toRankChar = moveRankToUSI[moveTo.rank]
        if isDrop {
            let dropChar = dropChars[moveDroppedPiece]
            return dropChar + "*" + toFileChar + toRankChar
        } else {
            let fromFileChar = moveFileToUSI[moveFrom.file]
            let fromRankChar = moveRankToUSI[moveFrom.rank]
            var s = fromFileChar + fromRankChar + toFileChar + toRankChar
            if isPromote {
                s += "+"
            }
            return s
        }
    }
}
