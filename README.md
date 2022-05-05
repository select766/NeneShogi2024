#  ねね将棋Swift

iPad / iPhone向け将棋AIの試作品です。TCPを介したUSI/CSAプロトコルで通信対局する専用で、人間との対局機能未実装。将棋AI専門家向け。第32回世界コンピュータ将棋選手権(2022年5月)出場。二次予選にシードとして出場し、28チーム中27位。

![実行画面](misc/screenshot.png)

深層学習モデルをAppleの機械学習専用チップであるNeural Engine上で動作させる点が特徴。iPad(第9世代)を用いた場合思考時間1手約10秒で、floodgateレート3300程度。概ね人間のプロ並みの強さ。

App Storeでは配布していません。各自でMac上のXcodeでビルドすることが必要です。iPad(第9世代)向けの画面レイアウトとなっています。iPhoneでもロジックは動くもののUIが画面内に収まらないので実質使えません。

# メモ
## テストケースデータの解凍
巨大なテキストファイルがあるため、解凍が必要

```
cd NeneShogiSwift
gzip -k DNNInputTestCase.txt.gz
gzip -k PositionTestCase.txt.gz
```

## 合法手生成テストデータの作成

`NeneShogiSwift/PositionTestCase.txt`に置くことでビルド時にアプリに取り込まれる

過去のねね将棋用に（やねうら王を用いて）作ったテストケースデータを変換して使う

注意: 連続王手の千日手は考慮してない。千日手、入玉宣言の可否も含めたテストが今後必要

ファイルを取得しPythonで1行=1局面のファイルを作成 https://github.com/select766/neneshogi/blob/master/data/testcase/generate_position_testcase.pickle.yaml

```
import yaml
import json
cases = yaml.safe_load(open("path/to/generate_position_testcase.pickle.yaml"))
with open("NeneShogiSwift/PositionTestCase.txt", "w") as f:
    for case in cases:
        f.write(json.dumps({"sfen": case["sfen"], "legalMoves": case["legal_moves"], "positionCommand": case["position_command"], "inCheck": case["in_check"]}) + "\n")
```

## ログの取り出し
iPadをMacに接続した状態で以下のコマンドを実行する

```
sudo log collect --device --last 1d
```

ねね将棋のログを抽出して標準出力に表示

```
log show --archive system_logs.logarchive --predicate '(subsystem IN {"jp.outlook.select766.NeneShogiSwift"})' --last 1d
```

