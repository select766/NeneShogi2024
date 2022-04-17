import SwiftUI

let userDefaultsCSAServerIpAddressKey = "csaServerIpAddress"
let userDefaultsUSIServerIpAddressKey = "usiServerIpAddress"

struct ContentView: View {
    @State var latestMessage: String = "Press Start"
    @State var matchManager: MatchManager?
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
        }, updateSearchProgress: {searchProgress in DispatchQueue.main.async {
            self.searchProgress = searchProgress
        }})
        UserDefaults.standard.set(usiServerIpAddress, forKey: userDefaultsUSIServerIpAddressKey)
        UserDefaults.standard.set(csaServerIpAddress, forKey: userDefaultsCSAServerIpAddressKey)
        matchManager = MatchManager(shogiUIInterface: shogiUIInterface, usiServerIpAddress: usiServerIpAddress, csaServerIpAddress: csaServerIpAddress)
        if serverType == "USI" {
            matchManager?.start()
        } else if serverType == "CSA" {
            matchManager?.startCSA()
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
            if let searchProgress = searchProgress {
                VStack {
                    Text(latestMessage)
                        .padding()
                    Text(searchProgress.rootPosition.toPrintString()).font(Font(UIFont.monospacedDigitSystemFont(ofSize: 20, weight: .medium)))
                        .padding()
                    Text(searchProgress.pv.count > 0 ? searchProgress.pv[0].toPrintString() : "-")
                        .padding()
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
