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
setoption USI_Ponder value true
setoption Stochastic_Ponder value true
setoption BookFile value user_book1.db
setoption BookDir value .
setoption BookDepthLimit value 0
setoption BookMoves value 32
setoption IgnoreBookPly value true
""".split(separator: "\n").map({String($0)})
