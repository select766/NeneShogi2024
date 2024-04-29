import SwiftUI

struct BoardView: View {
    // Boardのwidth: gridSize * 12, height: gridSize * 10
    // iPhone 15 Pro: 852 x 393
    var maxSize: CGSize
    
    var gridSize: CGFloat {
        return min(maxSize.height / 10.0, maxSize.width / 12.0) // 親ビューの 幅または高さを目一杯使う
    }

    struct BoardViewPieceItem: Identifiable {
        let id: Int
        let gridSize: CGFloat
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
                    return squareToPosition(square: square)
                } else {
                    // 持ち駒
                    let pieceType = piece.toPieceType()
                    let handOfs = pieceType - Piece.PIECE_HAND_ZERO
                    // TODO
                    if color == PColor.BLACK {
                        return CGPoint(x: gridSize * CGFloat(10.875 + 0.5), y: gridSize * CGFloat(2.75 + 7 - 0.5 - CGFloat(handOfs)))
                    } else {
                        return CGPoint(x: gridSize * CGFloat(0.125+0.5), y: gridSize * CGFloat(0.25+0.5+CGFloat(handOfs)))
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
        
        private func squareToPosition(square: Square) -> CGPoint {
            // TODO ロジックの重複を回避
            return CGPoint(x: gridSize * 10 - CGFloat(square.file) * gridSize, y: gridSize + CGFloat(square.rank) * gridSize)
        }
    }
    
    var matchStatus: MatchStatus
    var body: some View {
        // ZStackは後ろに書いたものが手前に表示される
        ZStack(alignment: .topLeading) {
            Image("Board").resizable().frame(width: gridSize * 12, height: gridSize * 10)
            if let lastMove = getLastOrdinaryMove() {
                // 最後の移動先に色をつける
                Image("BGMove").resizable().frame(width: gridSize, height: gridSize).position(squareToPosition(square: lastMove.moveTo))
            }
            ForEach(getBoardViewPieceList(), content: {
                p in
                ZStack(alignment: .bottomTrailing) {
                    Image(p.imageName).resizable().frame(width: gridSize, height: gridSize).rotationEffect(.degrees(p.angle))
                    if p.handCount > 1 {
                        Text("\(p.handCount)").foregroundStyle(.black).font(.system(size: gridSize * 0.5)).background(Color.white).padding(2.0)
                    }
                }.position(p.position)
            })
        }.frame(width: gridSize * 12, height: gridSize * 10)
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
        guard let lastItem = matchStatus.moveHistory.last else {
            return []
        }
        let position = lastItem.positionAfterMove ?? lastItem.positionBeforeMove
        var pis: [BoardViewPieceItem] = []
        for sq in 0..<Square.SQ_NB {
            let piece = position.board[sq]
            if piece.isExist() {
                pis.append(BoardViewPieceItem(id: sq, gridSize: gridSize, square: Square(sq), handCount: 0, piece: piece))
            }
        }
        
        // 持ち駒
        for color in 0..<PColor.COLOR_NB {
            let handOfColor = position.hand[color]
            for handPiece in Piece.PIECE_HAND_ZERO..<Piece.PIECE_HAND_NB {
                let count = handOfColor[handPiece - Piece.PIECE_HAND_ZERO]
                if count > 0 {
                    pis.append(BoardViewPieceItem(id: 100 + color * 10 + handPiece, gridSize: gridSize, square: nil, handCount: count, piece: Piece(handPiece + color * Piece.PIECE_WHITE)))
                }
            }
        }
        return pis
    }
    
    private func squareToPosition(square: Square) -> CGPoint {
        return CGPoint(x: gridSize * 10 - CGFloat(square.file) * gridSize, y: gridSize + CGFloat(square.rank) * gridSize)
    }
}

struct BoardView_Previews: PreviewProvider {    
    static var previews: some View {
        BoardView(maxSize: CGSize(width: 300.0, height: 300.0), matchStatus: getSampleMatchStatus())
    }
}
