//
//  DefaultUSISetOption.swift
//  NeneShogiSwift
//
//  Created by 日高雅俊 on 2024/04/13.
//

import Foundation

let defaultUSIOptions = """
setoption DNN_Model1 value
setoption DNN_Batch_Size1 value 8
setoption UCT_Threads1 value 4
setoption USI_Ponder value true
setoption USI_Hash value 1024
setoption Stochastic_Ponder value true
setoption BookFile value user_book1.db
setoption BookDir value .
setoption BookDepthLimit value 0
setoption BookMoves value 32
setoption IgnoreBookPly value true
setoption name NetworkDelay2 value 2200
setoption name MaxMovesToDraw value 320
""".split(separator: "\n").map({String($0)})
