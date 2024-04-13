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
""".split(separator: "\n").map({String($0)})
