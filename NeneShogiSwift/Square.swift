let moveFileForPrint: [String] = ["１","２","３","４","５","６","７","８","９"]
let moveRankForPrint: [String] = ["一","二","三","四","五","六","七","八","九"]

struct Square: Equatable {
    static let SQ_NB = 81;
    let square: Int
    init(_ square: Int) {
#if DEBUG
        if (square < 0 || square > Square.SQ_NB) {
            // SQ_NBはdropの移動元として現在許容している
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
    
    func toPrintString() -> String {
        if (file < 0 || file >= 9 || rank < 0 || rank >= 9) {
            // warning
            return "";
        }
        return moveFileForPrint[file] + moveRankForPrint[rank]
    }
}
