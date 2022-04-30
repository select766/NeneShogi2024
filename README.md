#  ねね将棋Swift

iPad / iPhone向け将棋AIです。開発中でまだ動きません。

# メモ
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

