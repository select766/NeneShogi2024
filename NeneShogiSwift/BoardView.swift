import SwiftUI

struct BoardView: View {
    struct BoardViewPieceItem: Identifiable {
        let id: Int
        let square: Square? // nilなら持ち駒
        let handCount: Int
        let piece: Piece
        var color: PColor {
            get {
                return piece.getColor()
            }
        }
        var angle: Double {
            get {
                return color == PColor.WHITE ? 180 : 0
            }
        }
        var position: CGPoint {
            get {
                if let square = square {
                    // 盤上
                    return BoardView.squareToPosition(square: square)
                } else {
                    // 持ち駒
                    let pieceType = piece.toPieceType()
                    let handOfs = pieceType - Piece.PIECE_HAND_ZERO
                    if color == PColor.BLACK {
                        return CGPoint(x: 696+32, y: 176+64*7-32-handOfs*64)
                    } else {
                        return CGPoint(x: 8+32, y: 16+32+handOfs*64)
                    }
                }
            }
        }
        var imageName: String {
            get {
                let ptKey: [Int: String] = [
                    1: "FU",
                    2: "KY",
                    3: "KE",
                    4: "GI",
                    5: "KA",
                    6: "HI",
                    7: "KI",
                    8: "OU",
                    9: "TO",
                    10: "NY",
                    11: "NK",
                    12: "NG",
                    13: "UM",
                    14: "RY",
                ]
                let pieceType = piece.toPieceType()
                var k = ptKey[pieceType] ?? ""
                if k == "OU" && color == PColor.BLACK {
                    k = "GY" // 先手は「玉」を表示。後手は「王」
                }
                return "Piece\(k)"
            }
        }
    }
    
    var matchStatus: MatchStatus
    var body: some View {
        // ZStackは後ろに書いたものが手前に表示される
        ZStack(alignment: .topLeading) {
            Image("Board")
            if let lastMove = getLastOrdinaryMove() {
                // 最後の移動先に色をつける
                Image("BGMove").position(BoardView.squareToPosition(square: lastMove.moveTo))
            }
            ForEach(getBoardViewPieceList(), content: {
                p in
                ZStack(alignment: .bottomTrailing) {
                    Image(p.imageName).rotationEffect(.degrees(p.angle))
                    if p.handCount > 1 {
                        Text("\(p.handCount)").font(.title).background(Color.white).padding(2.0)
                    }
                }.position(p.position)
            })
        }
    }
    
    private func getLastOrdinaryMove() -> DetailedMove? {
        // 最後の通常の指し手を取得（投了があればその前）
        for mh in matchStatus.moveHistory.reversed() {
            if case .Ordinary = mh.detailedMove.special {
                return mh.detailedMove
            }
        }
        return nil
    }
    
    private func getBoardViewPieceList() -> [BoardViewPieceItem] {
        let position = matchStatus.position
        var pis: [BoardViewPieceItem] = []
        for sq in 0..<Square.SQ_NB {
            let piece = position.board[sq]
            if piece.isExist() {
                pis.append(BoardViewPieceItem(id: sq, square: Square(sq), handCount: 0, piece: piece))
            }
        }
        
        // 持ち駒
        for color in 0..<PColor.COLOR_NB {
            let handOfColor = position.hand[color]
            for handPiece in Piece.PIECE_HAND_ZERO..<Piece.PIECE_HAND_NB {
                let count = handOfColor[handPiece - Piece.PIECE_HAND_ZERO]
                if count > 0 {
                    pis.append(BoardViewPieceItem(id: 100 + color * 10 + handPiece, square: nil, handCount: count, piece: Piece(handPiece + color * Piece.PIECE_WHITE)))
                }
            }
        }
        return pis
    }
    
    static private func squareToPosition(square: Square) -> CGPoint {
        return CGPoint(x: 640 - square.file * 64, y: 64 + square.rank * 64)
    }
}

struct BoardView_Previews: PreviewProvider {
    static var sampleMatchStatus: MatchStatus {
        get {
            let position = Position()
            position.setSFEN(sfen: "9/1+P7/2+P+P4l/5+P+R2/2K+S5/LPS6/2N1P1g+p+p/2GG1+s1+rk/5+s1b+p b G2LPb3n8p 1")
            return MatchStatus(gameState: .playing, players: ["player1", "player2"], position: position, moveHistory: [MoveHistoryItem(detailedMove: DetailedMove(special: .Ordinary, moveFrom: Square(Square.SQ_NB), moveTo: Square.fromFileRank(file: 2, rank: 6), sideToMove: PColor.WHITE, moveFromPieceType: Piece.GOLD, moveToPieceType: Piece.GOLD, isPromote: false, isDrop: true), usedTime: 1.0, scoreCp: -300)])
        }
    }
    
    static var previews: some View {
        BoardView(matchStatus: sampleMatchStatus)
    }
}
