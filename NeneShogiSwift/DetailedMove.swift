import Foundation

enum DetailedMoveSpecial {
    case Ordinary
    case Resign
    case Win
}

// 通常のMoveより詳細な情報を保持したMove。読み筋表示用。
struct DetailedMove {
    let special: DetailedMoveSpecial
    let moveFrom: Square
    let moveTo: Square
    let sideToMove: PColor
    let moveFromPieceType: Int
    let moveToPieceType: Int
    let isPromote: Bool
    let isDrop: Bool
    // TODO: 58金右、58金左のような区別に必要な情報
    
    static func makeSpecial(special: DetailedMoveSpecial, sideToMove: PColor) -> DetailedMove {
        return DetailedMove(special: special, moveFrom: Square(0), moveTo: Square(0), sideToMove: sideToMove, moveFromPieceType: 0, moveToPieceType: 0, isPromote: false, isDrop: false)
    }
    
    static func makeResign(sideToMode: PColor) -> DetailedMove {
        return makeSpecial(special: .Resign, sideToMove: sideToMode)
    }
    
    static func makeWin(sideToMode: PColor) -> DetailedMove {
        return makeSpecial(special: .Win, sideToMove: sideToMode)
    }
    
    static func makeMove(moveFrom: Square, moveTo: Square, sideToMove: PColor, moveFromPieceType: Int, isPromote: Bool) -> DetailedMove {
        return DetailedMove(special: .Ordinary, moveFrom: moveFrom, moveTo: moveTo, sideToMove: sideToMove, moveFromPieceType: moveFromPieceType, moveToPieceType: (isPromote ? moveFromPieceType + Piece.PIECE_PROMOTE : moveFromPieceType), isPromote: isPromote, isDrop: false)
    }
    
    static func makeMoveDrop(moveTo: Square, sideToMove: PColor, moveFromPieceType: Int) -> DetailedMove {
        return DetailedMove(special: .Ordinary, moveFrom: Square(81), moveTo: moveTo, sideToMove: sideToMove, moveFromPieceType: moveFromPieceType, moveToPieceType: moveFromPieceType, isPromote: false, isDrop: true)
    }
    
    func toPrintString() -> String {
        let teban = sideToMove == PColor.BLACK ? "▲" : "△"
        let content: String
        switch special {
        case .Ordinary:
            if isDrop {
                content = toPrintStringOrdinaryDrop()
            } else {
                content = toPrintStringOrdinaryMove()
            }
        case .Resign:
            content = "投了"
        case .Win:
            content = "宣言勝ち"
        }
        return teban + content
    }
    
    private func toPrintStringOrdinaryMove() -> String {
        var s =  "\(moveTo.toPrintString())\(_printCharFromPieceType[moveFromPieceType] ?? "")"
        if isPromote {
            s += "成"
        }
        // 将棋所と同じで移動元を括弧で表示（右、上などの情報がまだないので）
        s += "(\(moveFrom.file + 1)\(moveFrom.rank + 1))"
        return s
    }

    private func toPrintStringOrdinaryDrop() -> String {
        let s =  "\(moveTo.toPrintString())\(_printCharFromPieceType[moveFromPieceType] ?? "")打"
        return s
    }
    
    func toUSIString() -> String {
        switch special {
        case .Resign:
            return "resign"
        case .Win:
            return "win"
        case .Ordinary:
            break
        }
        let toFileChar = moveFileToUSI[moveTo.file]
        let toRankChar = moveRankToUSI[moveTo.rank]
        if isDrop {
            let dropChar = dropChars[moveFromPieceType]
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
