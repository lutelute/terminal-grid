# Terminal Grid

macOSのターミナルウィンドウをグリッド状に自動配置するツール。

## 機能

- **複数ディスプレイ対応**: メインディスプレイと外部ディスプレイを自動検出
- **タブフィルタリング**: 複数タブを持つウィンドウは配置対象から除外
- **自動グリッド計算**: ウィンドウ数に応じて最適な列数を自動決定
- **カスタムグリッド**: 列数・行数を手動指定可能

## インストール

```bash
git clone https://github.com/lutelute/terminal-grid.git
cd terminal-grid
chmod +x terminal_grid.sh
```

## 使い方

### 対話モード（推奨）

```bash
./terminal_grid.sh
```

メニューが表示されます：
- `a` - 自動配置（推奨）
- `2`〜`5` - 指定列数で配置
- `c` - カスタム（列x行を指定）
- `r` - 更新
- `q` - 終了

### コマンドラインオプション

```bash
# 自動配置（確認なし）
./terminal_grid.sh -y

# 3列2行のグリッドで配置
./terminal_grid.sh -g 3x2

# Terminal.appのみ対象
./terminal_grid.sh -t

# iTerm2のみ対象
./terminal_grid.sh -i
```

### オプション一覧

| オプション | 説明 |
|-----------|------|
| `-h, --help` | ヘルプを表示 |
| `-t, --terminal` | Terminal.appのみ対象 |
| `-i, --iterm` | iTerm2のみ対象 |
| `-a, --all` | 両方のターミナルを対象（デフォルト） |
| `-y, --yes` | プレビューをスキップして自動配置 |
| `-g, --grid <cols>x<rows>` | カスタムグリッドを指定 |
| `-d, --display <番号>` | 配置先ディスプレイを指定 |
| `-s, --select` | 配置するウィンドウを選択 |

### プリセット機能

```bash
# 現在の設定を保存
./terminal_grid.sh --save work

# プリセットを読み込んで配置
./terminal_grid.sh --load work

# プリセット一覧
./terminal_grid.sh --list

# プリセットを削除
./terminal_grid.sh --delete work
```

## 動作環境

- macOS
- Terminal.app または iTerm2

## 制限事項

- 外部ディスプレイでの複数行配置は、Terminal.appの制限により行分布が不均一になる場合があります
- 複数タブを持つウィンドウは配置対象から自動的に除外されます

## ライセンス

MIT
