// 簡易的な定跡

let simpleBook = [
    // 初手で以下の手を除いたランダム 2g2f, 7g7f (普通すぎる), 8g8f, 9i9h, 6i6h, 6i5h, 2h4h, 2h3h, 2h1h, 1i1h(PONANZAで除外された手)
    "lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1": ["1g1f", "2h5h", "2h6h", "2h7h", "3g3f", "3i3h", "3i4h", "4g4f", "4i3h", "4i4h", "4i5h", "5g5f", "5i4h", "5i5h", "5i6h", "6g6f", "6i7h", "7i6h", "7i7h", "9g9f"]
]

func getBookMove(positionSfen: String) -> Move? {
    if let candList = simpleBook[positionSfen] {
        let moveUSI = candList[Int.random(in: 0..<candList.count)]
        return Move.fromUSIString(moveUSI: moveUSI)
    } else {
        return nil
    }
}
