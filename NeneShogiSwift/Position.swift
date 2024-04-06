let hirateBoard: [Piece] = [
    18, 0, 17, 0, 0, 0, 1, 0, 2,
    19, 21, 17, 0, 0, 0, 1, 6, 3,
    20, 0, 17, 0, 0, 0, 1, 0, 4,
    23, 0, 17, 0, 0, 0, 1, 0, 7,
    24, 0, 17, 0, 0, 0, 1, 0, 8,
    23, 0, 17, 0, 0, 0, 1, 0, 7,
    20, 0, 17, 0, 0, 0, 1, 0, 4,
    19, 22, 17, 0, 0, 0, 1, 5, 3,
    18, 0, 17, 0, 0, 0, 1, 0, 2
].map({v in Piece(v)})

let hirateHands: [[Int]] = [[0,0,0,0,0,0,0],[0,0,0,0,0,0,0]]

let hirateSFEN = "lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1"

let nyugyokuPointPieceMap = [0, 1, 1, 1, 1, 5, 5, 1, 0, 1, 1, 1, 1, 5, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
let nyugyokuPieceCountMap = [0, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

// 本当はZobrist hashとかのほうがよさそうだが簡単に使える実装でごまかす
// https://ja.wikipedia.org/wiki/%E5%B7%A1%E5%9B%9E%E5%86%97%E9%95%B7%E6%A4%9C%E6%9F%BB
let crcTable: [UInt32] = crcInitializer()

func crcInitializer() -> [UInt32] {
    var table = [UInt32](repeating: 0, count: 256)
    for i in UInt32(0)..<UInt32(256) {
        var c = i
        for _ in 0..<8 {
            c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1)
        }
        table[Int(i)] = c
    }
    return table
}

func crc32(data: [UInt8]) -> UInt32 {
    var c: UInt32 = 0xffffffff
    for d in data {
        c = crcTable[Int((c ^ UInt32(d)) & 0xff)] ^ (c >> 8)
    }
    return c & 0xffffffff
}

func crc32(pieces: ArraySlice<Piece>) -> UInt32 {
    return crc32(data: pieces.map({v in UInt8(v.piece)}))
}

func crc32(hands: [Int]) -> UInt32 {
    return crc32(data: hands.map({v in UInt8(v)}))
}

let _shortAttackTable = [
    [],
    [ [ 0, -1 ] ], // 歩
    [], // 香
    [ [ -1, -2 ],[ 1, -2 ] ], // 桂
    [ [ -1, -1 ],[ 0,-1 ],[ 1,-1 ],[ -1,1 ],[ 1,1 ] ],//銀
    [],//角
    [],//飛
    [ [ -1,-1 ],[ 0,-1 ],[ 1,-1 ],[ -1,0 ],[ 1,0 ],[ 0,1 ] ],//金
    [ [ -1,-1 ],[ 0,-1 ],[ 1,-1 ],[ -1,0 ],[ 1,0 ],[ -1,1 ],[ 0,1 ],[ 1,1 ] ],//玉
    [ [ -1,-1 ],[ 0,-1 ],[ 1,-1 ],[ -1,0 ],[ 1,0 ],[ 0,1 ] ],//と
    [ [ -1,-1 ],[ 0,-1 ],[ 1,-1 ],[ -1,0 ],[ 1,0 ],[ 0,1 ] ],//成香
    [ [ -1,-1 ],[ 0,-1 ],[ 1,-1 ],[ -1,0 ],[ 1,0 ],[ 0,1 ] ],//成桂
    [ [ -1,-1 ],[ 0,-1 ],[ 1,-1 ],[ -1,0 ],[ 1,0 ],[ 0,1 ] ],//成銀
    [ [ 0,-1 ],[ -1,0 ],[ 1,0 ],[ 0,1 ] ],//馬
    [ [ -1,-1 ],[ 1,-1 ],[ -1,1 ],[ 1,1 ] ],//竜
    [],
    [],
    [ [ 0, 1 ] ], // 後手歩
    [], // 香
    [ [ -1, 2 ],[ 1, 2 ] ], // 桂
    [ [ -1, 1 ],[ 0,1 ],[ 1,1 ],[ -1,-1 ],[ 1,-1 ] ],//銀
    [],//角
    [],//飛
    [ [ -1,1 ],[ 0,1 ],[ 1,1 ],[ -1,0 ],[ 1,0 ],[ 0,-1 ] ],//金
    [ [ -1,1 ],[ 0,1 ],[ 1,1 ],[ -1,0 ],[ 1,0 ],[ -1,-1 ],[ 0,-1 ],[ 1,-1 ] ],//玉
    [ [ -1,1 ],[ 0,1 ],[ 1,1 ],[ -1,0 ],[ 1,0 ],[ 0,-1 ] ],//と
    [ [ -1,1 ],[ 0,1 ],[ 1,1 ],[ -1,0 ],[ 1,0 ],[ 0,-1 ] ],//成香
    [ [ -1,1 ],[ 0,1 ],[ 1,1 ],[ -1,0 ],[ 1,0 ],[ 0,-1 ] ],//成桂
    [ [ -1,1 ],[ 0,1 ],[ 1,1 ],[ -1,0 ],[ 1,0 ],[ 0,-1 ] ],//成銀
    [ [ 0,1 ],[ -1,0 ],[ 1,0 ],[ 0,-1 ] ],//馬
    [ [ -1,1 ],[ 1,1 ],[ -1,-1 ],[ 1,-1 ] ],//竜
]

let _maxNonPromoteRankTable = [
    0,
    3,  // 歩(必ず成る)
    2,  // 香(2段目では必ず成る)
    2,  // 桂
    0,  // 銀
    3,  // 角(必ず成る)
    3,  // 飛(必ず成る)
    0,  // 金
    0,
    0,
    0,
    0,
    0,
    0,
    0,
]

let _longAttackTable = [
    [],
    [],  // 歩
    [ [ 0, -1 ] ],  // 香
    [],  // 桂
    [],  // 銀
    [ [ -1, -1 ],[ 1, -1 ],[ -1, 1 ],[ 1, 1 ] ],  // 角
    [ [ 0, -1 ],[ -1, 0 ],[ 1, 0 ],[ 0, 1 ] ],  // 飛
    [],  // 金
    [],  // 玉
    [],  // と
    [],  // 成香
    [],  // 成桂
    [],  // 成銀
    [ [ -1, -1 ],[ 1, -1 ],[ -1, 1 ],[ 1, 1 ] ],  // 馬
    [ [ 0, -1 ],[ -1, 0 ],[ 1, 0 ],[ 0, 1 ] ],  // 竜
    [],
    [],
    [],  // 後手歩
    [ [ 0, 1 ] ],  // 香
    [],  // 桂
    [],  // 銀
    [ [ -1, 1 ],[ 1, 1 ],[ -1, -1 ],[ 1, -1 ] ],  // 角
    [ [ 0, 1 ],[ -1, 0 ],[ 1, 0 ],[ 0, -1 ] ],  // 飛
    [],  // 金
    [],  // 玉
    [],  // と
    [],  // 成香
    [],  // 成桂
    [],  // 成銀
    [ [ -1, 1 ],[ 1, 1 ],[ -1, -1 ],[ 1, -1 ] ],  // 馬
    [ [ 0, 1 ],[ -1, 0 ],[ 1, 0 ],[ 0, -1 ] ],  // 竜
]

let _maxDropRankTable = [0,1,1,2,0,0,0,0]

let _rotatePieceTable = [
    Piece.PIECE_ZERO, Piece.W_PAWN, Piece.W_LANCE, Piece.W_KNIGHT,
    Piece.W_SILVER, Piece.W_BISHOP, Piece.W_ROOK, Piece.W_GOLD,
    Piece.W_KING, Piece.W_PRO_PAWN, Piece.W_PRO_LANCE, Piece.W_PRO_KNIGHT,
    Piece.W_PRO_SILVER, Piece.W_HORSE, Piece.W_DRAGON, Piece.W_QUEEN,
    Piece.PIECE_ZERO, Piece.B_PAWN, Piece.B_LANCE, Piece.B_KNIGHT,
    Piece.B_SILVER, Piece.B_BISHOP, Piece.B_ROOK, Piece.B_GOLD,
    Piece.B_KING, Piece.B_PRO_PAWN, Piece.B_PRO_LANCE, Piece.B_PRO_KNIGHT,
    Piece.B_PRO_SILVER, Piece.B_HORSE, Piece.B_DRAGON, Piece.B_QUEEN
]

let _checkAttackDirs = [
    [-1,-1],
    [0,-1],
    [1,-1],
    [-1,0],
    [1,0],
    [-1,1],
    [0,1],
    [1,1]
]

let _checkShortAttackPieces = [
    [ Piece.W_SILVER, Piece.W_BISHOP, Piece.W_GOLD, Piece.W_KING, Piece.W_PRO_PAWN, Piece.W_PRO_LANCE,
      Piece.W_PRO_KNIGHT, Piece.W_PRO_SILVER, Piece.W_HORSE, Piece.W_DRAGON ],  // 左上
    [ Piece.W_PAWN, Piece.W_LANCE, Piece.W_SILVER, Piece.W_ROOK, Piece.W_GOLD, Piece.W_KING, Piece.W_PRO_PAWN,
      Piece.W_PRO_LANCE,
      Piece.W_PRO_KNIGHT, Piece.W_PRO_SILVER, Piece.W_HORSE, Piece.W_DRAGON ],  // 上
    [ Piece.W_SILVER, Piece.W_BISHOP, Piece.W_GOLD, Piece.W_KING, Piece.W_PRO_PAWN, Piece.W_PRO_LANCE,
      Piece.W_PRO_KNIGHT, Piece.W_PRO_SILVER, Piece.W_HORSE, Piece.W_DRAGON ],  // 右上
    [ Piece.W_ROOK, Piece.W_GOLD, Piece.W_KING, Piece.W_PRO_PAWN, Piece.W_PRO_LANCE,
      Piece.W_PRO_KNIGHT, Piece.W_PRO_SILVER, Piece.W_HORSE, Piece.W_DRAGON ],  // 左
    [ Piece.W_ROOK, Piece.W_GOLD, Piece.W_KING, Piece.W_PRO_PAWN, Piece.W_PRO_LANCE,
      Piece.W_PRO_KNIGHT, Piece.W_PRO_SILVER, Piece.W_HORSE, Piece.W_DRAGON ],  // 右
    [ Piece.W_SILVER, Piece.W_BISHOP, Piece.W_KING, Piece.W_HORSE, Piece.W_DRAGON ],  // 左下
    [ Piece.W_ROOK, Piece.W_GOLD, Piece.W_KING, Piece.W_PRO_PAWN, Piece.W_PRO_LANCE,
      Piece.W_PRO_KNIGHT, Piece.W_PRO_SILVER, Piece.W_HORSE, Piece.W_DRAGON ],  // 下
    [ Piece.W_SILVER, Piece.W_BISHOP, Piece.W_KING, Piece.W_HORSE, Piece.W_DRAGON ],  // 右下
]

let _checkLongAttackPieces = [
    [ Piece.W_BISHOP, Piece.W_HORSE ],  // 左上
    [ Piece.W_LANCE, Piece.W_ROOK, Piece.W_DRAGON ],  // 上
    [ Piece.W_BISHOP, Piece.W_HORSE ],  // 右上
    [ Piece.W_ROOK, Piece.W_DRAGON ],  // 左
    [ Piece.W_ROOK, Piece.W_DRAGON ],  // 右
    [ Piece.W_BISHOP, Piece.W_HORSE ],  // 左下
    [ Piece.W_ROOK, Piece.W_DRAGON ],  // 下
    [ Piece.W_BISHOP, Piece.W_HORSE ],  // 右下
]

private func forceHandCopy(_ hand: [[Int]]) -> [[Int]] {
    return [forceArrayCopy(hand[0]), forceArrayCopy(hand[1])]
}

class Position {
    var board: [Piece]
    var hand: [[Int]]
    var sideToMove: PColor
    var gamePly: Int
    var originSFEN: String
    var hashHistory: [UInt64]
    var checkHistory: [Bool]
    var moveStack: [Move]
    var undoStack: [UndoMoveInfo]
    
    init() {
        board = forceArrayCopy(hirateBoard)
        hand = forceHandCopy(hirateHands)
        sideToMove = PColor.BLACK
        gamePly = 1
        originSFEN = hirateSFEN
        hashHistory = []
        checkHistory = []
        moveStack = []
        undoStack = []
        hashHistory.append(hash())
        checkHistory.append(inCheck())
    }
    
    func copy() -> Position {
        let dst = Position()
        dst.board = forceArrayCopy(board)
        dst.hand = forceHandCopy(hand)
        dst.sideToMove = sideToMove
        dst.gamePly = gamePly
        dst.originSFEN = originSFEN
        dst.hashHistory = forceArrayCopy(hashHistory)
        dst.checkHistory = forceArrayCopy(checkHistory)
        dst.moveStack = forceArrayCopy(moveStack)
        dst.undoStack = forceArrayCopy(undoStack)
        return dst
    }
    
    
    func setHirate() {
        board = hirateBoard
        hand = hirateHands
        sideToMove = PColor.BLACK
        gamePly = 1
        originSFEN = hirateSFEN
        hashHistory = []
        checkHistory = []
        moveStack = []
        undoStack = []
        hashHistory.append(hash())
        checkHistory.append(inCheck())
    }
    
    func doMove(move: Move) {
        var fromSq: Square, toSq: Square, handType: Int, lastFromValue: Piece, lastToValue: Piece, lastHandValue: Int
        if move.isDrop {
            // 駒打ち
            // 持ち駒を減らす
            let ptHand = move.moveDroppedPiece - Piece.PIECE_HAND_ZERO
            handType = ptHand
            lastHandValue = hand[sideToMove.color][ptHand]
            hand[sideToMove.color][ptHand] = lastHandValue - 1
            var piece = move.moveDroppedPiece
            if sideToMove == PColor.WHITE {
                piece += Piece.PIECE_WHITE
            }
            toSq = move.moveTo
            board[toSq.square] = Piece(piece)
            
            // 置く前はコマがなかったはず
            fromSq = toSq
            lastFromValue = Piece.PIECE_ZERO
            lastToValue = Piece.PIECE_ZERO
        } else {
            // 駒の移動
            fromSq = move.moveFrom
            toSq = move.moveTo
            let capturedPiece = board[toSq.square]
            if (capturedPiece != Piece.PIECE_ZERO) {
                // 持ち駒を増やす
                // 駒種に変換
                let pt = capturedPiece.piece % Piece.PIECE_RAW_NB
                let ptHand = pt - Piece.PIECE_HAND_ZERO
                handType = ptHand
                lastHandValue = hand[sideToMove.color][ptHand]
                hand[sideToMove.color][ptHand] = lastHandValue + 1
            } else {
                // 持ち駒は不変
                // 便宜上、hand[sideToMove.color][0]の値を保存
                handType = 0
                lastHandValue = hand[sideToMove.color][0]
            }
            
            lastFromValue = board[fromSq.square]
            board[fromSq.square] = Piece.PIECE_ZERO
            lastToValue = capturedPiece
            board[toSq.square] = Piece(lastFromValue.piece + (move.isPromote ? Piece.PIECE_PROMOTE : 0))
        }
        
        sideToMove = sideToMove.invert()
        gamePly += 1
        moveStack.append(move)
        undoStack.append(UndoMoveInfo(fromSq: fromSq, fromValue: lastFromValue, toSq: toSq, toValue: lastToValue, handType: handType, handValue: lastHandValue))
        hashHistory.append(hash())
        checkHistory.append(inCheck())
    }
    
    func undoMove() {
        gamePly -= 1
        let undoMoveInfo = undoStack.popLast()!
        _ = moveStack.popLast()
        sideToMove = sideToMove.invert()
        hand[sideToMove.color][undoMoveInfo.handType] = undoMoveInfo.handValue
        board[undoMoveInfo.fromSq.square] = undoMoveInfo.fromValue
        board[undoMoveInfo.toSq.square] = undoMoveInfo.toValue
        _ = hashHistory.popLast()
        _ = checkHistory.popLast()
    }
    
    func hash() -> UInt64 {
        let upper = crc32(pieces: board[..<41]) ^ crc32(hands: hand[0])
        let lower = crc32(pieces: board[41...]) ^ crc32(hands: hand[1])
        return UInt64(upper) << 32 | UInt64(lower)
    }
    
    func eqBoard(other: Position) -> Bool {
        if (sideToMove != other.sideToMove) {
            return false;
        }
        if (board != other.board) {
            return false;
        }
        if (hand != other.hand) {
            return false;
        }
        return true
    }
    
    /*
     盤上の駒を動かす手をすべて生成する。
     先手番を前提とする。
     ただし、香車の2段目・歩・角・飛の不成りおよび行き場のない駒を生じる手は除く。
     */
    func _generateMoveMove() -> [Move] {
        var moveList: [Move] = []
        for fromFile in 0..<9 {
            for fromRank in 0..<9 {
                let fromSq = Square.fromFileRank(file: fromFile, rank: fromRank)
                let fromPiece = board[fromSq.square]
                if !fromPiece.isColor(color: PColor.BLACK) {
                    continue
                }
                let canPromote = fromPiece.piece <= Piece.B_ROOK.piece
                let maxNonPromoteRank = _maxNonPromoteRankTable[fromPiece.piece]
                // 短い利きの処理
                for shortAttack in _shortAttackTable[fromPiece.piece] {
                    let x = shortAttack[0]
                    let y = shortAttack[1]
                    let toFile = fromFile + x
                    let toRank = fromRank + y
                    guard let toSq = Square.fromFileRankIfValid(file: toFile, rank: toRank) else {
                        continue
                    }
                    let toPiece = board[toSq.square]
                    // 自分の駒があるところには進めない
                    if (toPiece.isColor(color: PColor.BLACK)) {
                        continue
                    }
                    if toRank >= maxNonPromoteRank {
                        // 行き場のない駒にはならない(&無意味な不成ではない)
                        moveList.append(Move.makeMove(moveFrom: fromSq, moveTo: toSq, isPromote: false))
                    }
                    if canPromote && (fromRank < 3 || toRank < 3) {
                        // 成れる駒で、成る条件を満たす
                        moveList.append(Move.makeMove(moveFrom: fromSq, moveTo: toSq, isPromote: true))
                    }
                }
                
                //長い利きの処理
                for longAttack in _longAttackTable[fromPiece.piece] {
                    let x = longAttack[0]
                    let y = longAttack[1]
                    var toFile = fromFile
                    var toRank = fromRank
                    while true {
                        toFile += x
                        toRank += y
                        guard let toSq = Square.fromFileRankIfValid(file: toFile, rank: toRank) else {
                            break
                        }
                        let toPiece = board[toSq.square]
                        // 自分の駒があるところには進めない
                        if (toPiece.isColor(color: PColor.BLACK)) {
                            break
                        }
                        if toRank >= maxNonPromoteRank && fromRank >= maxNonPromoteRank {
                            // 成って損がないのに成らない状況以外(角・飛)
                            moveList.append(Move.makeMove(moveFrom: fromSq, moveTo: toSq, isPromote: false))
                        }
                        if canPromote && (fromRank < 3 || toRank < 3) {
                            // 成れる駒で、成る条件を満たす
                            moveList.append(Move.makeMove(moveFrom: fromSq, moveTo: toSq, isPromote: true))
                        }
                        if toPiece.isExist() {
                            // 白駒があるので、これ以上進めない
                            break
                        }
                    }
                }
            }
        }
        return moveList
    }
    
    func _generateMoveDrop() -> [Move] {
        var moveList: [Move] = []
        // 二歩を避けるため、歩がすでにある筋を列挙
        var pawnFiles = Array(repeating: false, count: 9)
        for toFile in 0..<9 {
            for toRank in 0..<9 {
                let toSq = Square.fromFileRank(file: toFile, rank: toRank)
                let toPiece = board[toSq.square]
                if toPiece == Piece.B_PAWN {
                    pawnFiles[toFile] = true
                    break
                }
            }
        }
        
        for toFile in 0..<9 {
            for toRank in 0..<9 {
                let toSq = Square.fromFileRank(file: toFile, rank: toRank)
                let toPiece = board[toSq.square]
                if toPiece.isExist() {
                    // 駒のある場所には打てない
                    continue
                }
                
                for pt in Piece.PIECE_HAND_ZERO..<Piece.PIECE_HAND_NB {
                    if hand[0][pt - Piece.PIECE_HAND_ZERO] > 0 {
                        if pt == Piece.PAWN && pawnFiles[toFile] {
                            // 二歩
                            continue
                        }
                        
                        let maxDropRank = _maxDropRankTable[pt]
                        if toRank < maxDropRank {
                            continue
                        }
                        
                        moveList.append(Move.makeMoveDrop(moveDroppedPiece: pt, moveTo: toSq))
                    }
                }
            }
        }
        return moveList
    }
    
    func generateMoveList() -> [Move] {
        if sideToMove == PColor.BLACK {
            return _generateMoveListBlack()
        } else {
            rotatePositionInplace()
            let blackMoveList = _generateMoveListBlack()
            var moveList: [Move] = []
            for rotMove in blackMoveList {
                let toSq = Square(Square.SQ_NB - 1 - rotMove.moveTo.square)
                if rotMove.isDrop {
                    moveList.append(Move.makeMoveDrop(moveDroppedPiece: rotMove.moveDroppedPiece, moveTo: toSq))
                } else {
                    let fromSq = Square(Square.SQ_NB - 1 - rotMove.moveFrom.square)
                    moveList.append(Move.makeMove(moveFrom: fromSq, moveTo: toSq, isPromote: rotMove.isPromote))
                }
            }
            rotatePositionInplace()
            return moveList
        }
    }
    
    func _generateMoveListBlack() -> [Move] {
        let possibleList = _generateMoveMove() + _generateMoveDrop()
        var legalList: [Move] = []
        for m in possibleList {
            var legal = true
            doMove(move: m)
            // 王手放置チェック
            if (_inCheckBlack()) {
                // 後手番になっているのに先手が王手をかけられている
                legal = false
            }
            // 打ち歩詰めチェック
            if legal && m.isDrop && m.moveDroppedPiece == Piece.PAWN {
                /*
                 王手放置のときにチェックすると、玉を取る手が生成されてバグる
                 現在の手番(後手)が詰んでいるとき、打ち歩詰め
                 玉の頭に打った時だけ判定すればよい
                 */
                let whiteKingCheckPos = m.moveTo.square - 1 // 1段目に打つ手は生成しないので、必ず盤内
                if board[whiteKingCheckPos] == Piece.W_KING {
                    if generateMoveList().isEmpty {
                        legal = false
                    }
                }
            }
            undoMove()
            if legal {
                legalList.append(m)
            }
        }
        
        return legalList
    }
    
    /*
     先手が王手された状態かどうかをチェックする。
     先手が指して、後手番状態で呼び出すことも可能。この場合、王手放置のチェックとなる。
     */
    func _inCheckBlack() -> Bool {
        /*
         先手玉からみて各方向に後手の駒があれば、王手されていることになる。
         例えば、先手玉の1つ上(y-方向)に後手歩があれば王手。
         先手玉の右下に、他の駒に遮られずに角があれば王手。
         長い利きの場合、途中のマスがすべて空でなければならない。
         */
        var bkSq = Square(0) // black kingの位置
        for sq in 0..<Square.SQ_NB {
            if board[sq] == Piece.B_KING {
                bkSq = Square(sq)
                break
            }
        }
        
        let bkFile = bkSq.file
        let bkRank = bkSq.rank
        for dirI in 0..<_checkAttackDirs.count {
            let dir = _checkAttackDirs[dirI]
            let x = dir[0]
            let y = dir[1]
            var attFile = bkFile + x//attacker's file
            var attRank = bkRank + y
            guard let attSq = Square.fromFileRankIfValid(file: attFile, rank: attRank) else {
                continue
            }
            
            let attPiece = board[attSq.square]
            if attPiece.isExist() {
                // 隣に駒があるなら、それが玉に効く種類かどうか判定
                if _checkShortAttackPieces[dirI].contains(attPiece) {
                    // 短い利きが有効
                    return true
                }
            } else {
                // マスが空なら、長い利きをチェック
                while true {
                    attFile += x
                    attRank += y
                    guard let attSq = Square.fromFileRankIfValid(file: attFile, rank: attRank) else {
                        break
                    }
                    let attPiece = board[attSq.square]
                    if _checkLongAttackPieces[dirI].contains(attPiece) {
                        // 長い利きが有効
                        return true
                    }
                    if attPiece.isExist() {
                        // 空白以外の駒があるなら利きが切れる
                        break
                    }
                }
            }
        }
        
        // 桂馬の利きチェック
        for x in [-1, 1] {
            let attFile = bkFile + x
            let attRank = bkRank - 2
            guard let attSq = Square.fromFileRankIfValid(file: attFile, rank: attRank) else {
                continue
            }
            
            let attPiece = board[attSq.square]
            if attPiece == Piece.W_KNIGHT {
                // 桂馬がいる
                return true
            }
        }
        return false
    }
    
    func inCheck() -> Bool {
        if sideToMove == PColor.BLACK {
            return _inCheckBlack()
        } else {
            rotatePositionInplace()
            let ret = _inCheckBlack()
            rotatePositionInplace()
            return ret
        }
    }
    
    /*
     逆の手番から見た盤面に変化させる。
     盤面・持ち駒・手番を反転。
     */
    func rotatePositionInplace() {
        // 盤面を180度回し、駒の色を入れ替える。
        for sq in 0..<((Square.SQ_NB + 1) / 2) {
            let invSq = Square.SQ_NB - 1 - sq
            let sqItem = board[sq]
            let invSqItem = board[invSq]
            board[sq] = _rotatePieceTable[invSqItem.piece]
            board[invSq] = _rotatePieceTable[sqItem.piece]
        }
        // 持ち駒を入れ替える。
        let bh = hand[0]
        let wh = hand[1]
        hand[0] = wh
        hand[1] = bh
        
        sideToMove = sideToMove.invert()
    }
    
    func mateSearch() -> Move? {
        let myMoveList = generateMoveList()
        for move in myMoveList {
            doMove(move: move)
            let mate = generateMoveList().count == 0
            undoMove()
            if mate {
                return move
            }
        }
        return nil
    }
    
    func isSennichite() -> Float? {
        // ハッシュ値で検証するので、誤って千日手判定される可能性あり
        let hc = hashHistory.count
        let currentHash = hashHistory[hc-1]
        for i in (0..<hc-1).reversed() {
            if hashHistory[i] == currentHash {
                // 千日手成立
                // 現局面, 現局面-2, ..., iが王手なら、連続王手の千日手で、手番でない（１つ前の手で王手をかけた）側が負け。現局面の評価は勝ち相当の1.0
                // 現局面-1, 現局面-3, ..., iが王手なら、連続王手の千日手で、手番側が負け。
                // 連続王手の千日手でなければ引き分けで0.5
                var idx = hc - 1
                var tebanOute = true
                while idx >= i {
                    if !checkHistory[idx] {
                        tebanOute = false
                        break
                    }
                    idx -= 2
                }
                if tebanOute {
                    // 相手に王手をかけられた状態なので手番側の勝ち
                    return 1.0
                }
                var aiteOute = true
                idx = hc - 2
                while idx >= i {
                    if !checkHistory[idx] {
                        aiteOute = false
                        break
                    }
                    idx -= 2
                }
                if aiteOute {
                    // 相手番が常に王手＝自分がかけた側なので手番側の負け
                    return 0.0
                }
                
                // 引き分け
                return 0.5
            }
        }
        return nil
    }
    
    func _isNyugyokuAsSente(minPoint: Int) -> Bool {
        var bkSq = Square(0) // black kingの位置
        for sq in 0..<Square.SQ_NB {
            if board[sq] == Piece.B_KING {
                bkSq = Square(sq)
                break
            }
        }
        if bkSq.rank >= 3 {
            // 2. 敵陣三段目まで(rank=0,1,2)でないのでダメ
            return false
        }
        
        var point = 0
        var pieceCount = 0
        for file in 0..<9 {
            for rank in 0..<3 {
                let p = board[file * 9 + rank].piece
                pieceCount += nyugyokuPieceCountMap[p]
                point += nyugyokuPointPieceMap[p]
            }
        }
        
        if pieceCount < 10 {
            // 4. 宣言側の敵陣三段目以内の駒は、玉を除いて１０枚以上存在する。
            return false
        }
        point += hand[0][0] // 歩
        point += hand[0][1]
        point += hand[0][2]
        point += hand[0][3]
        point += hand[0][4] * 5 // 角
        point += hand[0][5] * 5 // 飛
        point += hand[0][6]
        
        if point < minPoint {
            return false
        }
        
        return true
    }
    
    func isNyugyoku() -> Bool {
        /*
         入玉宣言勝ちルール(第32回世界コンピュータ将棋選手権ルールより)
         一 宣言側の手番である。
         二 宣言側の玉が敵陣三段目以内に入っている。
         三 宣言側が、大駒５点小駒１点で計算して
         ・先手の場合２８点以上の持点がある。
         ・後手の場合２７点以上の持点がある。
         ・点数の対象となるのは、宣言側の持駒と敵陣三段目以内に存在する玉を除く宣言側の駒
         のみである。
         四 宣言側の敵陣三段目以内の駒は、玉を除いて１０枚以上存在する。
         五 宣言側の玉に王手がかかっていない。
         六 宣言側の持ち時間が残っている。
         */
        // 1., 6.はここでは問わない
        if checkHistory[checkHistory.count-1] {
            // 5. 王手なのでだめ
            return false
        }
        
        var inv = false
        var minPoint = 28
        // 常に先手番として思考する（点数基準だけは違うので注意）
        if sideToMove == PColor.WHITE {
            rotatePositionInplace()
            inv = true
            minPoint = 27
        }
        
        let result = _isNyugyokuAsSente(minPoint: minPoint)
        
        if inv {
            rotatePositionInplace()
        }
        
        return result
    }
    
    func setSFEN(sfen: String) {
        let elems: [String.SubSequence] = sfen.split(separator: " ")
        let boardStr = elems[0]
        let colorStr = elems[1]
        let handStr = elems[2]
        let plyStr = elems[3]
        for (rank, rankLine) in boardStr.split(separator: "/").enumerated() {
            var fileFromLeft = 0
            var isPromote = false
            for token in rankLine {
                if token == "+" {
                    isPromote = true
                    continue
                }
                if let tokenNum = token.wholeNumberValue {
                    // 数値の指す数だけ空のマス
                    for _ in 0..<tokenNum {
                        let sq = Square.fromFileRank(file: 8 - fileFromLeft, rank: rank)
                        board[sq.square] = Piece.PIECE_ZERO
                        fileFromLeft += 1
                    }
                } else {
                    // 駒
                    var piece = Piece.fromPieceString(pieceString: String(token))!
                    if isPromote {
                        piece = Piece(piece.piece + Piece.PIECE_PROMOTE)
                    }
                    let sq = Square.fromFileRank(file: 8 - fileFromLeft, rank: rank)
                    board[sq.square] = piece
                    fileFromLeft += 1
                }
                isPromote = false
            }
        }
        
        hand = [[0,0,0,0,0,0,0],[0,0,0,0,0,0,0]]
        if handStr != "-" {
            var numPiece = 0
            for token in handStr {
                if let tokenNum = token.wholeNumberValue {
                    // 駒の数が10以上のときがあるので注意
                    numPiece = numPiece * 10 + tokenNum
                } else {
                    let piece = Piece.fromPieceString(pieceString: String(token))!
                    let pieceColor = piece.isColor(color: PColor.BLACK) ? PColor.BLACK : PColor.WHITE
                    numPiece = numPiece == 0 ? 1 : numPiece
                    hand[pieceColor.color][piece.piece % Piece.PIECE_RAW_NB - Piece.PIECE_HAND_ZERO] = numPiece
                    numPiece = 0
                }
            }
        }
        
        sideToMove = colorStr == "w" ? PColor.WHITE : PColor.BLACK
        gamePly = Int(plyStr)!
        
        originSFEN = sfen
        moveStack = []
        undoStack = []
        hashHistory = []
        checkHistory = []
        hashHistory.append(hash())
        checkHistory.append(inCheck())
    }
    
    func getSFEN() -> String {
        // 盤面
        // SFENは段ごとに、左から右に走査する
        var sfen = ""
        for y in 0..<9 {
            if y > 0 {
                sfen += "/"
            }
            var blankLen = 0
            for x in 0..<9 {
                let sq = (8 - x) * 9 + y
                let piece = board[sq]
                if piece.isExist() {
                    if blankLen > 0 {
                        sfen += String(blankLen)
                        blankLen = 0
                    }
                    sfen += piece.toPieceString()!
                } else {
                    blankLen += 1
                }
            }
            if blankLen > 0 {
                sfen += String(blankLen)
            }
        }
        
        // 手番
        if sideToMove == PColor.BLACK {
            sfen += " b "
        } else {
            sfen += " w "
        }
        
        // 持ち駒
        // 同じ局面・手数の時にSFENを完全一致させるため、飛、角、金、銀、桂、香、歩の順とする
        var handPieces = ""
        for color in [PColor.BLACK, PColor.WHITE] {
            let handForColor = hand[color.color]
            let pieceColorOffset = color.color * Piece.PIECE_WHITE
            for pt in [Piece.ROOK, Piece.BISHOP, Piece.GOLD, Piece.SILVER, Piece.KNIGHT, Piece.LANCE, Piece.PAWN] {
                let pieceCt = handForColor[pt - Piece.PIECE_HAND_ZERO]
                if pieceCt > 0 {
                    if pieceCt > 1 {
                        handPieces += String(pieceCt)
                    }
                    handPieces += Piece(pt + pieceColorOffset).toPieceString()!
                }
            }
        }
        if handPieces.isEmpty {
            handPieces = "-"
        }
        sfen += handPieces
        
        // 手数
        sfen += " " + String(gamePly)
        return sfen
    }
    
    // 初形からのMoveリストで局面をセットする。
    func setPosition(moves: [Move]) {
        setHirate()
        for move in moves {
            doMove(move: move)
        }
    }
    
    /**
     USIの"position"コマンドの引数に従って局面をセットする。
     positionArg: "startpos moves 7g7f ..."
     */
    func setUSIPosition(positionArg: String) {
        var items: [String.SubSequence] = positionArg.split(separator: " ")
        if items[0] == "position" {
            items.removeFirst()
        }
        if items[0] == "startpos" {
            items.removeFirst()
            self.setHirate()
        } else if items[0] == "sfen" {
            // position sfen lnsg... b - 3 moves 7g7f ...
            fatalError("setposition with sfen not yet implemented")
        } else {
            fatalError("unexpected syntax")
        }
        if items.count > 0 { //将棋所で初形だと"position startpos"で終わり
            if (items.removeFirst() != "moves") {
                fatalError("keyword moves expected")
            }
            for moveStr in items {
                guard let move = Move.fromUSIString(moveUSI: String(moveStr)) else {
                    fatalError("move \(moveStr) cannot be parsed")
                }
                doMove(move: move)
            }
        }
    }
    
    func parseCSAMove(csaMove: String) -> Move? {
        // CSA形式の指し手をパースする。
        // 注意: パース結果は局面依存
        // %TORYO, %KACHIはパースする。
        // %CHUDANなど指し手に対応しないものはnilを返す。
        if csaMove.starts(with: "%") {
            if csaMove == "%TORYO" {
                return Move.Resign
            } else if csaMove == "%KACHI" {
                return Move.Win
            } else {
                return nil
            }
        } else {
            // +7776FU
            let fromNum = Int(csaMove[csaMove.index(csaMove.startIndex, offsetBy: 1)..<csaMove.index(csaMove.startIndex, offsetBy: 3)])!
            let toNum = Int(csaMove[csaMove.index(csaMove.startIndex, offsetBy: 3)..<csaMove.index(csaMove.startIndex, offsetBy: 5)])!
            let toPieceStr = csaMove[csaMove.index(csaMove.startIndex, offsetBy: 5)..<csaMove.index(csaMove.startIndex, offsetBy: 7)]
            let toSq = Square.fromFileRank(file: toNum / 10 - 1, rank: toNum % 10 - 1)
            guard let toPieceType = _pieceTypeFromCSAChar[String(toPieceStr)] else {
                return nil
            }
            if fromNum == 0 {
                // 駒打ち
                return Move.makeMoveDrop(moveDroppedPiece: toPieceType, moveTo: toSq)
            } else {
                // 駒の移動
                let fromSq = Square.fromFileRank(file: fromNum / 10 - 1, rank: fromNum % 10 - 1)
                let fromPiece = board[fromSq.square]
                let promote = fromPiece.toPieceType() != toPieceType
                return Move.makeMove(moveFrom: fromSq, moveTo: toSq, isPromote: promote)
            }
        }
    }
    
    func makeCSAMove(move: Move) -> String {
        if move.moveFrom == move.moveTo {
            if move.moveFrom.square == 0 {
                return "%TORYO"
            } else if move.moveFrom.square == 1 {
                return "%KACHI"
            }
        }
        var csaMove = sideToMove == PColor.BLACK ? "+" : "-"
        let moveTo = String(move.moveTo.file + 1) + String(move.moveTo.rank + 1)
        if move.isDrop {
            csaMove += "00"
            csaMove += moveTo
            csaMove += _csaCharFromPieceType[move.moveDroppedPiece]!
        } else {
            let moveFrom = String(move.moveFrom.file + 1) + String(move.moveFrom.rank + 1)
            let fromPieceType = board[move.moveFrom.square].toPieceType()
            let toPieceType: Int
            if move.isPromote {
                toPieceType = fromPieceType + Piece.PIECE_PROMOTE
            } else {
                toPieceType = fromPieceType
            }
            csaMove += moveFrom
            csaMove += moveTo
            csaMove += _csaCharFromPieceType[toPieceType]!
        }
        return csaMove
    }
    
    func getDNNInput() -> [Float32] {
        var inv = false
        if sideToMove == PColor.WHITE {
            rotatePositionInplace()
            inv = true
        }
        var input = Array.init(repeating: Float(0.0), count: 119*9*9)
        var check = false
        for fromFile in 0..<9 {
            for fromRank in 0..<9 {
                let fromSq = Square.fromFileRank(file: fromFile, rank: fromRank)
                let fromPiece = board[fromSq.square]
                if !fromPiece.isExist() {
                    continue
                }
                let color = fromPiece.getColor()
                if color == PColor.BLACK {
                    input[(fromPiece.piece - 1) * 81 + fromSq.square] = 1.0
                } else {
                    input[(fromPiece.piece - 17 + 31) * 81 + fromSq.square] = 1.0
                }
                // 短い利きの処理
                for shortAttack in _shortAttackTable[fromPiece.piece] {
                    let x = shortAttack[0]
                    let y = shortAttack[1]
                    let toFile = fromFile + x
                    let toRank = fromRank + y
                    guard let toSq = Square.fromFileRankIfValid(file: toFile, rank: toRank) else {
                        continue
                    }
                    let toPiece = board[toSq.square]
                    // toSqに利きがある
                    if color == PColor.BLACK {
                        input[(fromPiece.piece - 1 + 14) * 81 + toSq.square] = 1.0
                    } else {
                        input[(fromPiece.piece - 17 + 31 + 14) * 81 + toSq.square] = 1.0
                        if toPiece == Piece.B_KING {
                            check = true
                        }
                    }
                    // 利き数加算
                    if color == PColor.BLACK {
                        // ch28〜30を利き数に応じて1にする
                        input[(28 + 2) * 81 + toSq.square] = input[(28 + 1) * 81 + toSq.square]
                        input[(28 + 1) * 81 + toSq.square] = input[(28 + 0) * 81 + toSq.square]
                        input[(28 + 0) * 81 + toSq.square] = 1.0
                    } else {
                        input[(59 + 2) * 81 + toSq.square] = input[(59 + 1) * 81 + toSq.square]
                        input[(59 + 1) * 81 + toSq.square] = input[(59 + 0) * 81 + toSq.square]
                        input[(59 + 0) * 81 + toSq.square] = 1.0
                    }
                }
                
                //長い利きの処理
                for longAttack in _longAttackTable[fromPiece.piece] {
                    let x = longAttack[0]
                    let y = longAttack[1]
                    var toFile = fromFile
                    var toRank = fromRank
                    while true {
                        toFile += x
                        toRank += y
                        guard let toSq = Square.fromFileRankIfValid(file: toFile, rank: toRank) else {
                            break
                        }
                        let toPiece = board[toSq.square]
                        // toSqに利きがある
                        if color == PColor.BLACK {
                            input[(fromPiece.piece - 1 + 14) * 81 + toSq.square] = 1.0
                        } else {
                            input[(fromPiece.piece - 17 + 31 + 14) * 81 + toSq.square] = 1.0
                            if toPiece == Piece.B_KING {
                                check = true
                            }
                        }
                        // 利き数加算
                        if color == PColor.BLACK {
                            // ch28〜30を利き数に応じて1にする
                            input[(28 + 2) * 81 + toSq.square] = input[(28 + 1) * 81 + toSq.square]
                            input[(28 + 1) * 81 + toSq.square] = input[(28 + 0) * 81 + toSq.square]
                            input[(28 + 0) * 81 + toSq.square] = 1.0
                        } else {
                            input[(59 + 2) * 81 + toSq.square] = input[(59 + 1) * 81 + toSq.square]
                            input[(59 + 1) * 81 + toSq.square] = input[(59 + 0) * 81 + toSq.square]
                            input[(59 + 0) * 81 + toSq.square] = 1.0
                        }
                        if toPiece.isExist() {
                            // 駒があるので、これ以上進めない
                            break
                        }
                    }
                }
            }
        }
        
        var fillChs: [Int] = []
        
        for i in 0..<2 {
            for (p, ch) in [(Piece.PAWN, 0), (Piece.LANCE, 8), (Piece.KNIGHT, 12), (Piece.SILVER, 16), (Piece.GOLD, 20), (Piece.BISHOP, 24), (Piece.ROOK, 26)] {
                var num = hand[i][p-Piece.PIECE_HAND_ZERO]
                if num > 8 {
                    num = 8
                }
                for n in 0..<num {
                    fillChs.append(62 + i * 28 + ch + n)
                }
            }
        }
        
        if check {
            fillChs.append(118)
        }
        
        for ch in fillChs {
            for i in (ch*81)..<((ch+1)*81) {
                input[i] = 1.0
            }
        }
        
        if inv {
            rotatePositionInplace()
        }
        return input
    }
    
    // 現局面に対するmoveをDetailedMoveに変換する
    func makeDetailedMove(move: Move) -> DetailedMove {
        if move.moveFrom == move.moveTo {
            if move.moveFrom.square == 0 {
                return DetailedMove.makeResign(sideToMode: sideToMove)
            } else if move.moveFrom.square == 1 {
                return DetailedMove.makeWin(sideToMode: sideToMove)
            }
        }
        if move.isDrop {
            return DetailedMove.makeMoveDrop(moveTo: move.moveTo, sideToMove: sideToMove, moveFromPieceType: move.moveDroppedPiece)
        } else {
            let moveFromPieceType = board[move.moveFrom.square].toPieceType()
            return DetailedMove.makeMove(moveFrom: move.moveFrom, moveTo: move.moveTo, sideToMove: sideToMove, moveFromPieceType: moveFromPieceType, isPromote: move.isPromote)
        }
    }
    
    func toPrintString() -> String {
        var s = ""
        s += "  ９　８　７　６　５　４　３　２　１\n"
        for rank in 0..<9 {
            for file in (0..<9).reversed() {
                let piece = board[Square.fromFileRank(file: file, rank: rank).square]
                if piece.isExist() {
                    if piece.isColor(color: PColor.BLACK) {
                        s += "Λ\(_printOneCharFromPieceType[piece.toPieceType()]!)"
                    } else {
                        s += "Ｖ\(_printOneCharFromPieceType[piece.toPieceType()]!)"
                    }
                } else {
                    s += "・　"
                }
            }
            s += " \(moveRankForPrint[rank])"
            s += "\n"
        }
        s += sideToMove == PColor.BLACK ? "先手番\n" : "後手番\n"
        for teban in 0..<2 {
            let handOfTeban = hand[teban]
            s += "\(teban == 0 ? "先" : "後")手持駒 "
            for handOfs in 0..<handOfTeban.count {
                let handCount = handOfTeban[handOfs]
                if handCount > 0 {
                    s += "\(_printOneCharFromPieceType[Piece.PIECE_HAND_ZERO + handOfs]!)"
                    if handCount > 1 {
                        s += "\(handCount)"
                    }
                }
            }
            s += "\n"
        }
        return s
    }
    
    func getDNNMoveLabel(move: Move) -> Int {
        var moveTo = move.moveTo
        if sideToMove == PColor.WHITE {
            moveTo = moveTo.rotate()
        }
        
        if move.isDrop {
            return (move.moveDroppedPiece - Piece.PAWN + 20) * 81 + moveTo.square
        } else {
            var moveFrom = move.moveFrom
            if sideToMove == PColor.WHITE {
                moveFrom = moveFrom.rotate()
            }
            
            let dirX = moveFrom.file - moveTo.file
            let dirY = moveTo.rank - moveFrom.rank
            var ch: Int
            if (dirX == -1 && dirY == -2) {
                ch = 8
            }
            else if (dirX == 1 && dirY == -2) {
                ch = 9
            } else if (dirX < 0) {
                if (dirY < 0) {
                    ch = 1
                } else if (dirY == 0) {
                    ch = 3
                } else {
                    ch = 6
                }
            } else if (dirX == 0) {
                if (dirY < 0) {
                    ch = 0
                } else {
                    ch = 5
                }
            } else {
                // fild_diff > 0
                if (dirY < 0) {
                    ch = 2
                } else if (dirY == 0) {
                    ch = 4
                } else {
                    ch = 7
                }
            }
            
            if move.isPromote {
                ch += 10
            }
            
            return ch * 81 + moveTo.square
        }
    }
}
