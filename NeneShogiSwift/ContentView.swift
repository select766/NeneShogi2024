import SwiftUI

let userDefaultsCSAServerIpAddressKey = "csaServerIpAddress"
let userDefaultsUSIServerIpAddressKey = "usiServerIpAddress"

struct MoveHistoryItem: Identifiable {
    let id: Int
    let tekazu: Int
    let detailedMove: DetailedMove
    let usedTime: Int?
    let totalUsedTime: Int
}

struct CommunicationHistoryDisplayItem: Identifiable {
    let id: Int
    let displayString: String
}

struct ContentView: View {
    @State var latestMessage: String = "Press Start"
    @State var matchManager: MatchManager?
    @State var matchStatus: MatchStatus? = nil
    @State var moveHistory: [MoveHistoryItem] = []
    @State var communicationHistory: [CommunicationItem] = []
    @State var commuicationHistoryDisplay: [CommunicationHistoryDisplayItem] = []
    @State var searchProgress: SearchProgress? = nil
    @State var testProgress: String = ""
    @State var usiServerIpAddress: String = UserDefaults.standard.string(forKey: userDefaultsUSIServerIpAddressKey) ?? "127.0.0.1"
    @State var csaServerIpAddress: String = UserDefaults.standard.string(forKey: userDefaultsCSAServerIpAddressKey) ?? "127.0.0.1"
    
    func start(serverType: String) {
        if matchManager != nil {
            return
        }
        let shogiUIInterface = ShogiUIInterface(displayMessage: {message in DispatchQueue.main.async {
            self.latestMessage = message
        }
        }, pushCommunicaionHistory: { communicationItem in
            self.communicationHistory.append(communicationItem)
            
            var cis: [CommunicationHistoryDisplayItem] = []
            for i in max(0, self.communicationHistory.count - 100)..<self.communicationHistory.count {
                let ci = self.communicationHistory[i]
                let prefix: String
                switch ci.direction {
                case .recv:
                    prefix = "< "
                case .send:
                    prefix = "> "
                }
                cis.append(CommunicationHistoryDisplayItem(id: i, displayString: prefix + ci.message))
            }
            commuicationHistoryDisplay = cis
        }, updateMatchStatus: {matchStatus in DispatchQueue.main.async {
            self.matchStatus = matchStatus
            var mh: [MoveHistoryItem] = []
            var totalUsedTimes = [0.0, 0.0]
            for i in 0..<matchStatus.moveHistory.count {
                let mi = matchStatus.moveHistory[i]
                totalUsedTimes[mi.detailedMove.sideToMove.color] += mi.usedTime ?? 0.0
                mh.append(MoveHistoryItem(id: i,tekazu: i+1,
                                          detailedMove: mi.detailedMove, usedTime: mi.usedTime != nil ? Int(mi.usedTime!) : nil,
                                          totalUsedTime: Int(totalUsedTimes[mi.detailedMove.sideToMove.color])))
            }
            self.moveHistory = mh
        }}, updateSearchProgress: {searchProgress in DispatchQueue.main.async {
            self.searchProgress = searchProgress
        }})
        UserDefaults.standard.set(usiServerIpAddress, forKey: userDefaultsUSIServerIpAddressKey)
        UserDefaults.standard.set(csaServerIpAddress, forKey: userDefaultsCSAServerIpAddressKey)
        matchManager = MatchManager(shogiUIInterface: shogiUIInterface)
        if serverType == "USI" {
            matchManager?.startUSI(usiConfig: USIConfig(usiServerIpAddress: usiServerIpAddress, usiServerPort: 8090, ponder: true))
        } else if serverType == "CSA" {
            // TODO: 時間指定UI
            // TODO: ponder可否
            matchManager?.startCSA(csaConfig: CSAConfig(csaServerIpAddress: csaServerIpAddress, csaServerPort: 4081, reconnect: true, loginName: "nene", loginPassword: "test-300-10F", ponder: true, timeTotalSec: 300.0, timeIncrementSec: 10.0))
        }
    }
    
    func testPosition() {
        DispatchQueue.global(qos: .background).async {
            let position = Position()
            var failed = false
            let positionTestCases = loadPositionTestCases()
            for (i, tc) in positionTestCases.enumerated() {
                position.setUSIPosition(positionArg: tc.positionCommand)
                if position.getSFEN() != tc.sfen {
                    print("\(i) error: \(position.getSFEN()) != \(tc.sfen)")
                    failed = true
                    break
                }
                if position.inCheck() != tc.inCheck {
                    print("\(i) error inCheck: \(position.inCheck()) != \(tc.inCheck)")
                    failed = true
                    break
                }
                let actualMoveSet = Set(position.generateMoveList().map({m in m.toUSIString()}))
                
                if actualMoveSet != tc.legalMoves {
                    print("\(i) error moveset: \(actualMoveSet) != \(tc.legalMoves)")
                    failed = true
                    break
                    
                }
                if i % 100 == 0 {
                    DispatchQueue.main.async {
                        self.testProgress = "\(i) / \(positionTestCases.count)"
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.testProgress = failed ? "failed " : "completed"
            }
        }
    }
    
    func testDNNInput() {
        DispatchQueue.global(qos: .background).async {
            //let position = Position()
            //var failed = false
            // テストケース1024件を読むのに5分ほどかかってしまうが仕方ない(release build)
            print("loading")
            var failed = false
            let dnnInputTestCase = loadDNNInputTestCases()
            print(dnnInputTestCase[0].moveUSI)
            for (i, tc) in dnnInputTestCase.enumerated() {
                let position = Position()
                position.setSFEN(sfen: tc.sfen)
                let dnnInput = position.getDNNInput()
                for j in 0..<tc.x.count {
                    if dnnInput[j] != Float(tc.x[j]) {
                        print("case \(i) input[\(j)]: \(dnnInput[j]) != \(tc.x[j]) sfen=\(tc.sfen)")
                        print(position.hand)
                        failed = true
                        break
                    }
                }
                
                let moveLabel = position.getDNNMoveLabel(move: Move.fromUSIString(moveUSI: tc.moveUSI)!)
                if moveLabel != tc.moveLabel {
                    print("case \(i) move: \(moveLabel) != \(tc.moveLabel) sfen=\(tc.sfen) move=\(tc.moveUSI)")
                    failed = true
                }
                
                if failed {
                    break
                }
            }
            
            DispatchQueue.main.async {
                self.testProgress = failed ? "failed " : "completed"
            }
        }
    }
    
    var body: some View {
        Group {
            if let matchStatus = matchStatus {
                VStack {
                    Text(latestMessage)
                        .padding()
                    Text(matchStatus.position.toPrintString()).font(Font(UIFont.monospacedDigitSystemFont(ofSize: 20, weight: .medium)))
                        .padding()
                    Text("指し手 消費時間/合計").padding()
                    ScrollView(.vertical, showsIndicators: true) {
                        ScrollViewReader {
                            proxy in
                            VStack {
                                ForEach(moveHistory) {moveHistoryItem in
                                    Text("\(moveHistoryItem.tekazu): \(moveHistoryItem.detailedMove.toPrintString()) - \(moveHistoryItem.usedTime != nil ? String(moveHistoryItem.usedTime!) : "*") / \(moveHistoryItem.totalUsedTime)").id(moveHistoryItem.id)
                                }
                            }.onChange(of: (self.matchStatus?.moveHistory.count ?? 0) - 1, perform: {
                                value in withAnimation {
                                    proxy.scrollTo(value, anchor: .bottom)
                                }
                            })
                        }
                        
                    }.frame(maxWidth: .infinity, maxHeight: 120.0)
                    
                    ScrollView(.vertical, showsIndicators: true) {
                        ScrollViewReader {
                            proxy in
                            VStack {
                                ForEach(commuicationHistoryDisplay) {cItem in
                                    Text(cItem.displayString).id(cItem.id)
                                }
                            }.onChange(of: (self.commuicationHistoryDisplay.last?.id ?? 0), perform: {
                                value in proxy.scrollTo(value, anchor: .bottom)
                            })
                        }
                        
                    }.frame(maxWidth: .infinity, maxHeight: 120.0)
                }
            } else {
                VStack {
                    Text(latestMessage)
                        .padding()
                    Button(action: {
                        start(serverType: "USI")
                    }) {
                        Text("Start USI")
                    }.padding()
                    TextField("USI IP", text: $usiServerIpAddress).frame(width: 100.0, height: 50.0).padding()
                    Button(action: {
                        start(serverType: "CSA")
                    }) {
                        Text("Start CSA")
                    }.padding()
                    TextField("CSA IP", text: $csaServerIpAddress).frame(width: 100.0, height: 50.0).padding()
                    Button(action: testPosition) {
                        Text("Test position")
                    }.padding()
                    Button(action: testDNNInput) {
                        Text("Test dnn input")
                    }.padding()
                    Text(testProgress)
                        .padding()
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
