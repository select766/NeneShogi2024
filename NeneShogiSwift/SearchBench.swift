import Foundation

enum SearchBenchKeys : String {
    case empty
    case dnnEval
    case search
}

class SearchBench {
    var currentSection: SearchBenchKeys
    var sectionStartTimeNanoseconds: UInt64
    var sectionSumNanoseconds: [SearchBenchKeys: UInt64]
    init() {
        currentSection = SearchBenchKeys.empty
        sectionStartTimeNanoseconds = DispatchTime.now().uptimeNanoseconds
        sectionSumNanoseconds = [:]
    }
    
    @discardableResult
    func startSection(id: SearchBenchKeys) -> SearchBenchKeys {
        let now = DispatchTime.now().uptimeNanoseconds
        sectionSumNanoseconds[currentSection] = (sectionSumNanoseconds[currentSection] ?? 0) + (now - sectionStartTimeNanoseconds)
        let lastSection = currentSection
        currentSection = id
        sectionStartTimeNanoseconds = now
        return lastSection
    }
    
    func display() {
        for item in sectionSumNanoseconds {
            print("\(item.key.rawValue): \(Double(item.value) / 1000000000.0) sec")
        }
    }
}

let searchBenchDefault = SearchBench()
