//
//  util.swift
//  NeneShogiSwift
//
//  Created by 日高雅俊 on 2024/04/06.
//

import Foundation

// Swiftの配列は値型であり、関数に渡すなどするとコピーされたように見える。
// しかし実際にはcopy-on-writeであり、マルチスレッド環境下でデータが破損する場合がある。
// 複数スレッドで共有する想定の配列は、この関数でコピーする。
func forceArrayCopy<T>(_ array: [T]) -> [T] {
    var dst = [T]()
    dst.append(contentsOf: array)
    return dst
}
