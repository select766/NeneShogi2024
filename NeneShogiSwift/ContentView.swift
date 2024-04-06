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


struct ContentView: View {
    @State var latestMessage: String = "Press Start"
    @State var matchStatus: MatchStatus? = nil
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
    @State var csaSendScore: Bool
    @State var csaShowLoginPassword: Bool = false
    @State var matchRunning: Bool = false
    @State var serverType: String = "USI"
    @State var usiConfig: USIConfig?
    @State var csaConfig: CSAConfig?
    
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
            csaSendScore = lastUsedConfig.sendScore
        } else {
            csaConfigSelected = ""
            csaServerIpAddress = "127.0.0.1"
            csaServerPort = "4081"
            csaReconnect = false
            csaLoginName = "nene"
            csaLoginPassword = "test-300-10F"
            csaPonder = true
            csaSendScore = true
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
    
    func formToCSAConfig() -> CSAConfig {
        CSAConfig(csaServerIpAddress: csaServerIpAddress, csaServerPort: UInt16(csaServerPort) ?? 4081, reconnect: csaReconnect, loginName: csaLoginName, loginPassword: csaLoginPassword, ponder: csaPonder, sendScore: csaSendScore)
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
    
    
    func start(serverType: String) {
        if matchRunning {
            return
        }
        UserDefaults.standard.set(usiServerIpAddress, forKey: userDefaultsUSIServerIpAddressKey)
        if serverType == "USI" {
            usiConfig = USIConfig(usiServerIpAddress: usiServerIpAddress, usiServerPort: 8090, ponder: true)
        } else if serverType == "CSA" {
            csaConfig = formToCSAConfig()
        }
        self.serverType = serverType
        matchRunning = true
    }
    
    var body: some View {
        Group {
            if matchRunning {
                MatchView(serverType: serverType, usiConfig: usiConfig, csaConfig: csaConfig)
            } else {
                ScrollView {
                    VStack {
                        Text(latestMessage)
                            .padding()
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
                                    Toggle("Send Score", isOn: $csaSendScore).frame(width: 200.0, height: 20.0)
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
                                }
                            }
                        }.padding()
                        VStack {
                            Text("USI client mode")
                            Button(action: {
                                start(serverType: "USI")
                            }) {
                                Text("Start USI")
                            }
                            TextField("USI IP", text: $usiServerIpAddress).keyboardType(.asciiCapable).disableAutocorrection(true).frame(width: 200.0, height: 20.0)
                        }.padding()
                        HStack {
                            Button(action: testPosition) {
                                Text("Test position")
                            }.padding()
                        }
                        Text(testProgress)
                            .padding()
                    }
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
