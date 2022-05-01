// 簡易的な定跡
let useBook = true

let simpleBook = [
    // 初手で以下の手を除いたランダム 2g2f, 7g7f (普通すぎる), 8g8f, 9i9h, 6i6h, 6i5h, 2h4h, 2h3h, 2h1h, 1i1h(PONANZAで除外された手)
    "lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1": ["1g1f", "2h5h", "2h6h", "2h7h", "3g3f", "3i3h", "3i4h", "4g4f", "4i3h", "4i4h", "4i5h", "5g5f", "5i4h", "5i5h", "5i6h", "6g6f", "6i7h", "7i6h", "7i7h", "9g9f"],
    // 後手番の初手: 34, 84歩以外で評価値上位3手
    "lnsgkgsnl/1r5b1/ppppppppp/9/9/8P/PPPPPPPP1/1B5R1/LNSGKGSNL w - 2": [
        "1c1d",
        "4c4d",
        "9c9d"
    ],
    "lnsgkgsnl/1r5b1/ppppppppp/9/9/7P1/PPPPPPP1P/1B5R1/LNSGKGSNL w - 2": [
        "1c1d",
        "9c9d",
        "4a3b"
    ],
    "lnsgkgsnl/1r5b1/ppppppppp/9/9/6P2/PPPPPP1PP/1B5R1/LNSGKGSNL w - 2": [
        "1c1d",
        "9c9d",
        "4a3b"
    ],
    "lnsgkgsnl/1r5b1/ppppppppp/9/9/5P3/PPPPP1PPP/1B5R1/LNSGKGSNL w - 2": [
        "1c1d",
        "9c9d",
        "4a3b"
    ],
    "lnsgkgsnl/1r5b1/ppppppppp/9/9/4P4/PPPP1PPPP/1B5R1/LNSGKGSNL w - 2": [
        "1c1d",
        "7a6b",
        "7a7b"
    ],
    "lnsgkgsnl/1r5b1/ppppppppp/9/9/3P5/PPP1PPPPP/1B5R1/LNSGKGSNL w - 2": [
        "6c6d",
        "9c9d",
        "8b6b"
    ],
    "lnsgkgsnl/1r5b1/ppppppppp/9/9/2P6/PP1PPPPPP/1B5R1/LNSGKGSNL w - 2": [
        "1c1d",
        "9c9d",
        "4a3b"
    ],
    "lnsgkgsnl/1r5b1/ppppppppp/9/9/1P7/P1PPPPPPP/1B5R1/LNSGKGSNL w - 2": [
        "6c6d",
        "7a7b",
        "6a5b",
        "5a4b"
    ],
    "lnsgkgsnl/1r5b1/ppppppppp/9/9/P8/1PPPPPPPP/1B5R1/LNSGKGSNL w - 2": [
        "1c1d",
        "9c9d",
        "4a3b"
    ],
    "lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5RL/LNSGKGSN1 w - 2": [
        "1c1d",
        "9c9d",
        "7a7b",
        "4a3b"
    ],
    "lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/LB5R1/1NSGKGSNL w - 2": [
        "1c1d",
        "9c9d",
        "7a7b"
    ],
    "lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B4SR1/LNSGKG1NL w - 2": [
        "1c1d",
        "9c9d",
        "4a3b"
    ],
    "lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B3S1R1/LNSGKG1NL w - 2": [
        "1c1d",
        "9c9d",
        "4a3b"
    ],
    "lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B1S3R1/LN1GKGSNL w - 2": [
        "1c1d",
        "4c4d",
        "9c9d"
    ],
    "lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1BS4R1/LN1GKGSNL w - 2": [
        "1c1d",
        "9c9d",
        "4a3b"
    ],
    "lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B6R/LNSGKGSNL w - 2": [
        "1c1d",
        "7a6b",
        "5a4b"
    ],
    "lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B4R2/LNSGKGSNL w - 2": [
        "1c1d",
        "7a6b",
        "5a4b"
    ],
    "lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B3R3/LNSGKGSNL w - 2": [
        "1c1d",
        "6a5b",
        "5a4b"
    ],
    "lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B2R4/LNSGKGSNL w - 2": [
        "1c1d",
        "7c7d",
        "6a5b"
    ],
    "lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B1R5/LNSGKGSNL w - 2": [
        "1c1d",
        "7c7d",
        "9c9d"
    ],
    "lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1BR6/LNSGKGSNL w - 2": [
        "1c1d",
        "7a6b",
        "5a4b"
    ],
    "lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B4GR1/LNSGK1SNL w - 2": [
        "1c1d",
        "9c9d",
        "4a3b"
    ],
    "lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B3G1R1/LNSGK1SNL w - 2": [
        "1c1d",
        "9c9d",
        "4a3b"
    ],
    "lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B2G2R1/LNSGK1SNL w - 2": [
        "1c1d",
        "9c9d",
        "4a3b"
    ],
    "lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B2G2R1/LNS1KGSNL w - 2": [
        "1c1d",
        "3a4b",
        "7a6b"
    ],
    "lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B1G3R1/LNS1KGSNL w - 2": [
        "1c1d",
        "9c9d",
        "4a3b"
    ],
    "lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1BG4R1/LNS1KGSNL w - 2": [
        "4c4d",
        "9c9d",
        "8b4b"
    ],
    "lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B3K1R1/LNSG1GSNL w - 2": [
        "4c4d",
        "9c9d",
        "4a3b"
    ],
    "lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B2K2R1/LNSG1GSNL w - 2": [
        "4c4d",
        "9c9d",
        "4a3b"
    ],
    "lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B1K3R1/LNSG1GSNL w - 2": [
        "1c1d",
        "7a7b",
        "4a3b"
    ]
]

func getBookMove(positionSfen: String) -> Move? {
    if !useBook {
        return nil
    }
    if let candList = simpleBook[positionSfen] {
        let moveUSI = candList[Int.random(in: 0..<candList.count)]
        return Move.fromUSIString(moveUSI: moveUSI)
    } else {
        return nil
    }
}
