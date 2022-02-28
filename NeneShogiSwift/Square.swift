struct Square: Equatable {
    static let SQ_NB = 81;
    let square: Int
    init(_ square: Int) {
#if DEBUG
        if (square < 0 || square >= Square.SQ_NB) {
            fatalError("square is out of range")
        }
#endif
        self.square = square
    }
    
    static func fromFileRank(file: Int, rank: Int) -> Square {
        return Square(file * 9 + rank)
    }
    
    static func fromFileRankIfValid(file: Int, rank: Int) -> Square? {
        if (file < 0 || file >= 9 || rank < 0 || rank >= 9) {
            return nil;
        }
        return Square(file * 9 + rank)
    }
    
    var file: Int {
        get {
            return square / 9
        }
    }
    
    var rank: Int {
        get {
            return square % 9
        }
    }

    func rotate() -> Square {
        return Square(80 - square)
    }
}
