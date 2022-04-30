import SwiftUI

let userDefaultsCSAConfigSaveKey = "csaConfigSave"
let userDefaultsUSIServerIpAddressKey = "usiServerIpAddress"


struct CommunicationHistoryDisplayItem: Identifiable {
    let id: Int
    let displayString: String
}

struct CSAConfigSave: Codable {
    var configs: [String: CSAConfig]
    var lastUsedConfig: String?
}

struct CSAConfigSaveListItem: Identifiable {
    let id: String
    let name: String
}

func loadCSAConfigSave() -> CSAConfigSave? {
    let jsonDecoder = JSONDecoder()
    guard let data = UserDefaults.standard.data(forKey: userDefaultsCSAConfigSaveKey),
          let s = try? jsonDecoder.decode(CSAConfigSave.self, from: data) else {
        return nil
    }
    return s
}

func saveCSAConfigSave(csaConfigSave: CSAConfigSave) {
    let jsonEncoder = JSONEncoder()
    guard let data = try? jsonEncoder.encode(csaConfigSave) else {
        return
    }
    UserDefaults.standard.set(data, forKey: userDefaultsCSAConfigSaveKey)
}


func pvsToString(pvs: [SearchTreeRootForVisualize]) -> String {
    var s = ""
    for pv in pvs {
        let rm = pv.rootMoveNode
        // winrateMeanは、指したあとの手番の勝率なので反転させる
        s += "\(rm.moveFromParent.toPrintString()) \(Int((1.0 - rm.winrateMean) * 100))%±\(Int(rm.winrateStd * 100)) / \(rm.moveCount)\n"
        for child in pv.childNodes {
            s += "└\(child.moveFromParent.toPrintString())"
            for cpv in child.pv.prefix(3) {
                s += "\(cpv.toPrintString())"
            }
            s += "\n"
        }
    }
    return s
}

struct ContentView: View {
    @State var latestMessage: String = "Press Start"
    @State var matchManager: MatchManager?
    @State var matchStatus: MatchStatus? = nil
    @State var communicationHistory: [CommunicationItem] = []
    @State var commuicationHistoryDisplay: [CommunicationHistoryDisplayItem] = []
    @State var searchProgress: SearchProgress? = nil
    @State var testProgress: String = ""
    @State var usiServerIpAddress: String = UserDefaults.standard.string(forKey: userDefaultsUSIServerIpAddressKey) ?? "127.0.0.1"
    @State var csaConfigSave: CSAConfigSave
    @State var csaConfigSaveList: [CSAConfigSaveListItem]
    @State var csaConfigSelected: String
    @State var csaConfigName: String
    @State var csaServerIpAddress: String
    @State var csaServerPort: String
    @State var csaReconnect: Bool
    @State var csaLoginName: String
    @State var csaLoginPassword: String
    @State var csaPonder: Bool
    @State var csaTimeTotalSec: String
    @State var csaTimeIncrementSec: String
    @State var csaShowLoginPassword: Bool = false
    @State var debugView = false
    
    init() {
        let csaConfigSave = loadCSAConfigSave() ?? CSAConfigSave(configs: [:], lastUsedConfig: nil)
        csaConfigSaveList =  csaConfigSave.configs.keys.map { key
            in
            CSAConfigSaveListItem(id: key, name: key)
        }
        self.csaConfigSave = csaConfigSave
        csaConfigName = csaConfigSave.lastUsedConfig ?? ""
        if let lastUsedConfig = csaConfigSave.lastUsedConfig != nil ? csaConfigSave.configs[csaConfigSave.lastUsedConfig!] : nil {
            csaConfigSelected = csaConfigSave.lastUsedConfig!
            csaServerIpAddress = lastUsedConfig.csaServerIpAddress
            csaServerPort = String(lastUsedConfig.csaServerPort)
            csaReconnect = lastUsedConfig.reconnect
            csaLoginName = lastUsedConfig.loginName
            csaLoginPassword = lastUsedConfig.loginPassword
            csaPonder = lastUsedConfig.ponder
            csaTimeTotalSec = String(lastUsedConfig.timeTotalSec)
            csaTimeIncrementSec = String(lastUsedConfig.timeIncrementSec)
        } else {
            csaConfigSelected = ""
            csaServerIpAddress = "127.0.0.1"
            csaServerPort = "4081"
            csaReconnect = false
            csaLoginName = "nene"
            csaLoginPassword = "test-300-10F"
            csaPonder = true
            csaTimeTotalSec = "300"
            csaTimeIncrementSec = "10"
        }
    }
    
    func start(serverType: String) {
        if matchManager != nil {
            return
        }
        let shogiUIInterface = ShogiUIInterface(displayMessage: {message in DispatchQueue.main.async {
            self.latestMessage = message
        }
        }, pushCommunicaionHistory: { communicationItem in
            DispatchQueue.main.async {
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
            }
        }, updateMatchStatus: {matchStatus in DispatchQueue.main.async {
            self.matchStatus = matchStatus
        }}, updateSearchProgress: {searchProgress in DispatchQueue.main.async {
            self.searchProgress = searchProgress
        }})
        UserDefaults.standard.set(usiServerIpAddress, forKey: userDefaultsUSIServerIpAddressKey)
        matchManager = MatchManager(shogiUIInterface: shogiUIInterface)
        if serverType == "USI" {
            matchManager?.startUSI(usiConfig: USIConfig(usiServerIpAddress: usiServerIpAddress, usiServerPort: 8090, ponder: true))
        } else if serverType == "CSA" {
            matchManager?.startCSA(csaConfig: formToCSAConfig())
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
    
    func formToCSAConfig() -> CSAConfig {
        CSAConfig(csaServerIpAddress: csaServerIpAddress, csaServerPort: UInt16(csaServerPort) ?? 4081, reconnect: csaReconnect, loginName: csaLoginName, loginPassword: csaLoginPassword, ponder: csaPonder, timeTotalSec: Double(csaTimeTotalSec) ?? 300.0, timeIncrementSec: Double(csaTimeIncrementSec) ?? 10.0)
    }
    
    func onStartCSAClick() {
        // 最後に使用したプリセット名のみ更新
        csaConfigSave.lastUsedConfig = csaConfigName
        saveCSAConfigSave(csaConfigSave: csaConfigSave)
        start(serverType: "CSA")
    }
    
    func onSaveCSAConfigClick() {
        csaConfigSave.configs[csaConfigName] = formToCSAConfig()
        saveCSAConfigSave(csaConfigSave: csaConfigSave)
    }
    
    func onDeleteCSAConfigClick() {
        csaConfigSave.configs.removeValue(forKey: csaConfigName)
        saveCSAConfigSave(csaConfigSave: csaConfigSave)
    }
    
    var body: some View {
        Group {
            if let matchStatus = matchStatus {
                VStack {
                    ScoreBarView(matchStatus: matchStatus)
                    HStack {
                        BoardView(matchStatus: matchStatus)
                        VStack(alignment: .leading) {
                            if debugView {
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
                            } else {
                                if let searchProgress = searchProgress {
                                    Text("ノード数: \(searchProgress.totalNodes), NPS: \(searchProgress.nps)").font(Font(UIFont.monospacedDigitSystemFont(ofSize: 20, weight: .medium)))
                                    
                                    Text(pvsToString(pvs: searchProgress.pvs)).font(Font(UIFont.monospacedDigitSystemFont(ofSize: 20, weight: .medium)))
                                }
                                
                                MoveHistoryView(matchStatus: matchStatus)
                            }
                            Button(action: {
                                debugView = !debugView
                            }) {
                                Text("Debug")
                            }
                        }
                    }
                }
                
                
            } else {
                VStack {
                    Text(latestMessage)
                        .padding()
                    VStack {
                        Text("USI client mode")
                        Button(action: {
                            start(serverType: "USI")
                        }) {
                            Text("Start USI")
                        }
                        TextField("USI IP", text: $usiServerIpAddress).keyboardType(.asciiCapable).disableAutocorrection(true).frame(width: 100.0, height: 20.0)
                    }.padding()
                    VStack {
                        Text("CSA client mode")
                        TextField("Config name", text: $csaConfigName).frame(width: 100.0, height: 20.0)
                        Group {
                            HStack {
                                Text("IP")
                                TextField("IP", text: $csaServerIpAddress).keyboardType(.asciiCapable).disableAutocorrection(true).frame(width: 200.0, height: 20.0)
                            }
                            HStack {
                                Text("Port")
                                TextField("Port", text: $csaServerPort).keyboardType(.numberPad).disableAutocorrection(true).frame(width: 40.0, height: 20.0)
                            }
                            HStack {
                                Toggle("Reconnect", isOn: $csaReconnect).frame(width: 200.0, height: 20.0)
                            }
                        }
                        Group {
                            HStack {
                                Text("Login name")
                                TextField("Login name", text: $csaLoginName).keyboardType(.asciiCapable).disableAutocorrection(true).frame(width: 200.0, height: 20.0)
                            }
                            HStack {
                                Text("Login password")
                                Group {
                                    if csaShowLoginPassword {
                                        TextField("Login password", text: $csaLoginPassword).keyboardType(.asciiCapable).disableAutocorrection(true).frame(width: 200.0, height: 20.0)
                                        
                                    } else {
                                        SecureField("Login password", text: $csaLoginPassword).frame(width: 200.0, height: 20.0)
                                    }
                                }
                            }
                            HStack {
                                Toggle("Show password", isOn: $csaShowLoginPassword).frame(width: 200.0, height: 20.0)
                            }
                        }
                        Group {
                            HStack {
                                Toggle("Ponder", isOn: $csaPonder).frame(width: 200.0, height: 20.0)
                            }
                            HStack {
                                Text("Total time")
                                TextField("", text: $csaTimeTotalSec).keyboardType(.decimalPad).disableAutocorrection(true).frame(width: 100.0, height: 20.0)
                            }
                            HStack {
                                Text("Increment time")
                                TextField("", text: $csaTimeIncrementSec).keyboardType(.decimalPad).disableAutocorrection(true).frame(width: 100.0, height: 20.0)
                            }
                        }
                        HStack {
                            Button(action: onSaveCSAConfigClick) {
                                Text("Save")
                            }
                            Button(action: onDeleteCSAConfigClick) {
                                Text("Delete")
                            }
                            Button(action: onStartCSAClick) {
                                Text("Start CSA")
                            }
                        }
                        Picker(selection: $csaConfigSelected, label: Text("Saved servers")) {
                            ForEach(csaConfigSaveList) {
                                saveListItem in Text(saveListItem.name).tag(saveListItem.id)
                            }
                        }.onChange(of: csaConfigSelected) {
                            selectedKey in
                            if let lastUsedConfig = csaConfigSave.configs[selectedKey] {
                                csaConfigName = selectedKey
                                csaServerIpAddress = lastUsedConfig.csaServerIpAddress
                                csaServerPort = String(lastUsedConfig.csaServerPort)
                                csaReconnect = lastUsedConfig.reconnect
                                csaLoginName = lastUsedConfig.loginName
                                csaLoginPassword = lastUsedConfig.loginPassword
                                csaPonder = lastUsedConfig.ponder
                                csaTimeTotalSec = String(lastUsedConfig.timeTotalSec)
                                csaTimeIncrementSec = String(lastUsedConfig.timeIncrementSec)
                            }
                        }
                    }.padding()
                    HStack {
                        Button(action: testPosition) {
                            Text("Test position")
                        }.padding()
                        Button(action: testDNNInput) {
                            Text("Test dnn input")
                        }.padding()
                    }
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
