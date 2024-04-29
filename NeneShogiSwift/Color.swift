struct PColor: Equatable, CustomStringConvertible {
    let color: Int
    init(_ color: Int) {
#if DEBUG
        if (color < 0 || color >= PColor.COLOR_NB) {
            fatalError("color is out of range")
        }
#endif
        self.color = color
    }
    static let BLACK = PColor(0)
    static let WHITE = PColor(1)
    static let COLOR_NB = 2
    func invert() -> PColor {
        return PColor(1 - color)
    }
    
    /// 黒（先手）="▲", 白（後手）= "△"
    var description: String {
        return color == 0 ? "▲" : "△"
    }
}
