#!/bin/bash

# Terminal Grid インストールスクリプト

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$HOME/.local/bin"
APP_DIR="$HOME/Applications"

echo "Terminal Grid インストーラー"
echo "================================"

# コマンドラインツールのインストール
install_cli() {
    echo ""
    echo "1. コマンドラインツールをインストール中..."

    # インストールディレクトリを作成
    mkdir -p "$INSTALL_DIR"

    # スクリプトをコピー
    cp "$SCRIPT_DIR/terminal_grid.sh" "$INSTALL_DIR/terminal-grid"
    chmod +x "$INSTALL_DIR/terminal-grid"

    echo "   インストール先: $INSTALL_DIR/terminal-grid"

    # PATHの確認
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        echo ""
        echo "   ⚠️  $INSTALL_DIR がPATHに含まれていません"
        echo "   以下をシェル設定ファイル(.zshrc等)に追加してください:"
        echo ""
        echo "   export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi
}

# Automatorアプリのビルド
build_app() {
    echo ""
    echo "2. Automatorアプリをビルド中..."

    mkdir -p "$APP_DIR"

    # Automatorアプリのバンドル構造を作成
    APP_BUNDLE="$APP_DIR/Terminal Grid.app"
    rm -rf "$APP_BUNDLE"
    mkdir -p "$APP_BUNDLE/Contents/MacOS"
    mkdir -p "$APP_BUNDLE/Contents/Resources"

    # Info.plist
    cat > "$APP_BUNDLE/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>TerminalGrid</string>
    <key>CFBundleIdentifier</key>
    <string>com.user.terminalgrid</string>
    <key>CFBundleName</key>
    <string>Terminal Grid</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.14</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

    # 実行ファイル
    cat > "$APP_BUNDLE/Contents/MacOS/TerminalGrid" << 'SCRIPT'
#!/bin/bash
osascript "$(dirname "$0")/../Resources/TerminalGrid.scpt"
SCRIPT
    chmod +x "$APP_BUNDLE/Contents/MacOS/TerminalGrid"

    # AppleScriptをコンパイル
    osacompile -o "$APP_BUNDLE/Contents/Resources/TerminalGrid.scpt" "$SCRIPT_DIR/TerminalGrid.applescript"

    echo "   アプリ作成完了: $APP_BUNDLE"
}

# キーボードショートカット用のクイックアクションを作成
setup_keyboard_shortcut() {
    echo ""
    echo "3. キーボードショートカット設定..."

    local SERVICES_DIR="$HOME/Library/Services"
    mkdir -p "$SERVICES_DIR"

    # クイックアクション(ワークフロー)のバンドル構造を作成
    local WORKFLOW="$SERVICES_DIR/Terminal Grid.workflow"
    rm -rf "$WORKFLOW"
    mkdir -p "$WORKFLOW/Contents"

    # document.wflow (ワークフロー定義)
    cat > "$WORKFLOW/Contents/document.wflow" << 'WFLOW'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>AMApplicationBuild</key>
	<string>523</string>
	<key>AMApplicationVersion</key>
	<string>2.10</string>
	<key>AMDocumentVersion</key>
	<string>2</string>
	<key>actions</key>
	<array>
		<dict>
			<key>action</key>
			<dict>
				<key>AMAccepts</key>
				<dict>
					<key>Container</key>
					<string>List</string>
					<key>Optional</key>
					<true/>
					<key>Types</key>
					<array>
						<string>com.apple.cocoa.string</string>
					</array>
				</dict>
				<key>AMActionVersion</key>
				<string>2.0.3</string>
				<key>AMApplication</key>
				<array>
					<string>Automator</string>
				</array>
				<key>AMCategory</key>
				<string>AMCategoryUtilities</string>
				<key>AMIconName</key>
				<string>Run Script</string>
				<key>AMName</key>
				<string>シェルスクリプトを実行</string>
				<key>AMParameterProperties</key>
				<dict>
					<key>COMMAND_STRING</key>
					<dict/>
					<key>CheckedForUserDefaultShell</key>
					<dict/>
					<key>inputMethod</key>
					<dict/>
					<key>shell</key>
					<dict/>
					<key>source</key>
					<dict/>
				</dict>
				<key>AMProvides</key>
				<dict>
					<key>Container</key>
					<string>List</string>
					<key>Types</key>
					<array>
						<string>com.apple.cocoa.string</string>
					</array>
				</dict>
				<key>ActionBundlePath</key>
				<string>/System/Library/Automator/Run Shell Script.action</string>
				<key>ActionName</key>
				<string>シェルスクリプトを実行</string>
				<key>ActionParameters</key>
				<dict>
					<key>COMMAND_STRING</key>
					<string>$HOME/.local/bin/terminal-grid -y</string>
					<key>CheckedForUserDefaultShell</key>
					<true/>
					<key>inputMethod</key>
					<integer>1</integer>
					<key>shell</key>
					<string>/bin/bash</string>
					<key>source</key>
					<string></string>
				</dict>
				<key>BundleIdentifier</key>
				<string>com.apple.RunShellScript</string>
				<key>CFBundleVersion</key>
				<string>2.0.3</string>
				<key>CanShowSelectedItemsWhenRun</key>
				<false/>
				<key>CanShowWhenRun</key>
				<true/>
				<key>Category</key>
				<array>
					<string>AMCategoryUtilities</string>
				</array>
				<key>Class Name</key>
				<string>RunShellScriptAction</string>
				<key>InputUUID</key>
				<string>00000000-0000-0000-0000-000000000000</string>
				<key>Keywords</key>
				<array>
					<string>シェル</string>
					<string>スクリプト</string>
					<string>コマンド</string>
					<string>実行</string>
					<string>Unix</string>
				</array>
				<key>OutputUUID</key>
				<string>00000000-0000-0000-0000-000000000001</string>
				<key>UUID</key>
				<string>00000000-0000-0000-0000-000000000002</string>
				<key>UnlocalizedApplications</key>
				<array>
					<string>Automator</string>
				</array>
				<key>arguments</key>
				<dict>
					<key>0</key>
					<dict>
						<key>default value</key>
						<integer>0</integer>
						<key>name</key>
						<string>inputMethod</string>
						<key>required</key>
						<string>0</string>
						<key>type</key>
						<string>0</string>
						<key>uuid</key>
						<string>0</string>
					</dict>
					<key>1</key>
					<dict>
						<key>default value</key>
						<string></string>
						<key>name</key>
						<string>source</string>
						<key>required</key>
						<string>0</string>
						<key>type</key>
						<string>0</string>
						<key>uuid</key>
						<string>1</string>
					</dict>
					<key>2</key>
					<dict>
						<key>default value</key>
						<false/>
						<key>name</key>
						<string>CheckedForUserDefaultShell</string>
						<key>required</key>
						<string>0</string>
						<key>type</key>
						<string>0</string>
						<key>uuid</key>
						<string>2</string>
					</dict>
					<key>3</key>
					<dict>
						<key>default value</key>
						<string></string>
						<key>name</key>
						<string>COMMAND_STRING</string>
						<key>required</key>
						<string>0</string>
						<key>type</key>
						<string>0</string>
						<key>uuid</key>
						<string>3</string>
					</dict>
					<key>4</key>
					<dict>
						<key>default value</key>
						<string>/bin/sh</string>
						<key>name</key>
						<string>shell</string>
						<key>required</key>
						<string>0</string>
						<key>type</key>
						<string>0</string>
						<key>uuid</key>
						<string>4</string>
					</dict>
				</dict>
				<key>isViewVisible</key>
				<integer>1</integer>
				<key>location</key>
				<string>529.500000:305.000000</string>
				<key>nibPath</key>
				<string>/System/Library/Automator/Run Shell Script.action/Contents/Resources/Base.lproj/main.nib</string>
			</dict>
			<key>isViewVisible</key>
			<integer>1</integer>
		</dict>
	</array>
	<key>connectors</key>
	<dict/>
	<key>workflowMetaData</key>
	<dict>
		<key>applicationBundleIDsByPath</key>
		<dict/>
		<key>applicationPaths</key>
		<array/>
		<key>inputTypeIdentifier</key>
		<string>com.apple.Automator.nothing</string>
		<key>outputTypeIdentifier</key>
		<string>com.apple.Automator.nothing</string>
		<key>presentationMode</key>
		<integer>15</integer>
		<key>processesInput</key>
		<integer>0</integer>
		<key>serviceInputTypeIdentifier</key>
		<string>com.apple.Automator.nothing</string>
		<key>serviceOutputTypeIdentifier</key>
		<string>com.apple.Automator.nothing</string>
		<key>serviceProcessesInput</key>
		<integer>0</integer>
		<key>systemImageName</key>
		<string>NSTouchBarListViewTemplate</string>
		<key>useAutomaticInputType</key>
		<integer>0</integer>
		<key>workflowTypeIdentifier</key>
		<string>com.apple.Automator.servicesMenu</string>
	</dict>
</dict>
</plist>
WFLOW

    echo "   クイックアクション作成完了: $WORKFLOW"
    echo ""
    echo -e "   ${BOLD}キーボードショートカットの設定手順:${NC}"
    echo "   ┌──────────────────────────────────────────────────────────┐"
    echo "   │ 1. システム設定 > キーボード > キーボードショートカット  │"
    echo "   │ 2. 左側で「サービス」を選択                              │"
    echo "   │ 3. 「一般」の中から「Terminal Grid」を見つける           │"
    echo "   │ 4. 右側をダブルクリックしてショートカットを設定          │"
    echo "   │    （推奨: ⌃⌥⌘G など）                                  │"
    echo "   └──────────────────────────────────────────────────────────┘"
}

# メイン処理
main() {
    install_cli
    build_app
    setup_keyboard_shortcut

    echo ""
    echo "================================"
    echo "インストール完了!"
    echo ""
    echo "使い方:"
    echo "  コマンドライン: terminal-grid"
    echo "  アプリ: 「Terminal Grid.app」を起動"
    echo ""
    echo "新機能:"
    echo "  terminal-grid -g 3x2      # 3列2行のグリッド"
    echo "  terminal-grid -s          # ウィンドウを選択して配置"
    echo "  terminal-grid --save work # プリセット保存"
    echo "  terminal-grid --load work # プリセット読み込み"
    echo "  terminal-grid --list      # プリセット一覧"
    echo ""
}

main
