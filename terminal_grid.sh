#!/bin/bash

# Terminal Grid - ターミナルウィンドウをグリッド配置するツール
# macOS用

# 設定
MENU_BAR_HEIGHT=38
PADDING=5
CONFIG_DIR="$HOME/.config/terminal-grid"
PRESETS_DIR="$CONFIG_DIR/presets"

# 色付き出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ヘルプ表示
show_help() {
    echo "Terminal Grid - ターミナルウィンドウをグリッド配置"
    echo ""
    echo "使い方: ./terminal_grid.sh [オプション]"
    echo ""
    echo "基本オプション:"
    echo "  -h, --help              このヘルプを表示"
    echo "  -t, --terminal          Terminal.appのみ対象"
    echo "  -i, --iterm             iTerm2のみ対象"
    echo "  -a, --all               両方のターミナルを対象（デフォルト）"
    echo "  -y, --yes               プレビューをスキップして自動配置"
    echo ""
    echo "グリッド指定:"
    echo "  -g, --grid <cols>x<rows>  カスタムグリッドを指定（例: -g 3x2）"
    echo ""
    echo "ディスプレイ指定:"
    echo "  -d, --display <番号>      配置先ディスプレイを指定（1=メイン, 2=外部...）"
    echo ""
    echo "ウィンドウ選択:"
    echo "  -s, --select            配置するウィンドウを選択"
    echo ""
    echo "プリセット:"
    echo "  --save <name>           現在の設定をプリセットとして保存"
    echo "  --load <name>           プリセットを読み込んで配置"
    echo "  --list                  保存済みプリセット一覧を表示"
    echo "  --delete <name>         プリセットを削除"
    echo ""
    echo "例:"
    echo "  ./terminal_grid.sh              # プレビュー表示後に配置"
    echo "  ./terminal_grid.sh -y           # 自動でグリッド配置"
    echo "  ./terminal_grid.sh -g 3x2       # 3列2行のグリッドで配置"
    echo "  ./terminal_grid.sh -t -s        # Terminal.appのウィンドウを選択して配置"
    echo "  ./terminal_grid.sh --save work  # 現在の設定を'work'として保存"
    echo "  ./terminal_grid.sh --load work  # 'work'プリセットを適用"
}

# 全ディスプレイ情報を取得
get_all_displays() {
    osascript -e '
    set displayInfo to ""
    tell application "Finder"
        set desktopBounds to bounds of window of desktop
    end tell
    -- メインディスプレイの情報を取得
    tell application "System Events"
        set displayCount to count of desktops
    end tell
    return displayCount & "|" & (item 1 of desktopBounds) & "|" & (item 2 of desktopBounds) & "|" & (item 3 of desktopBounds) & "|" & (item 4 of desktopBounds)
    '
}

# NSScreenを使って正確な画面サイズを取得
# 出力形式: index|frame_x|frame_y|frame_w|frame_h|applescript_x|applescript_y|usable_w|usable_h
get_screen_size_nsscreen() {
    osascript << 'EOF'
use framework "AppKit"
use scripting additions

set screenList to current application's NSScreen's screens()
set mainScreen to item 1 of screenList
set mainFrame to mainScreen's frame()
set mainHeight to (current application's NSHeight(mainFrame)) as integer
set output to ""

repeat with i from 1 to count of screenList
    set aScreen to item i of screenList
    set frame to aScreen's frame()
    set visibleFrame to aScreen's visibleFrame()

    -- NSScreenの座標（左下原点）
    set fx to (current application's NSMinX(frame)) as integer
    set fy to (current application's NSMinY(frame)) as integer
    set fw to (current application's NSWidth(frame)) as integer
    set fh to (current application's NSHeight(frame)) as integer

    set vx to (current application's NSMinX(visibleFrame)) as integer
    set vy to (current application's NSMinY(visibleFrame)) as integer
    set vw to (current application's NSWidth(visibleFrame)) as integer
    set vh to (current application's NSHeight(visibleFrame)) as integer

    -- AppleScript座標（左上原点）に変換
    -- メニューバーの高さ = frame.height - visible.height - (visible.y - frame.y)
    set menuBarHeight to fh - vh - (vy - fy)

    -- AppleScript用のy座標（左上原点、メニューバーの下から）
    -- メインディスプレイの場合: y = menuBarHeight
    -- 他のディスプレイの場合: 座標変換が必要
    if fx = 0 and fy = 0 then
        -- メインディスプレイ
        set asX to vx
        set asY to menuBarHeight
    else
        -- 外部ディスプレイ: 左上原点に変換
        -- AppleScript y = mainHeight - (fy + fh) + menuBarHeight
        set asX to fx
        set asY to (mainHeight - (fy + fh)) + menuBarHeight
    end if

    set output to output & i & "|" & fx & "|" & fy & "|" & fw & "|" & fh & "|" & asX & "|" & asY & "|" & vw & "|" & vh & linefeed
end repeat

return output
EOF
}

# ディスプレイ選択メニュー
# 引数: $1 = auto_mode (true/false), $2 = display_num (任意)
select_display() {
    local auto_mode=${1:-false}
    local specified_display=${2:-""}
    local display_info
    display_info=$(get_screen_size_nsscreen)

    local displays=()
    local display_names=()
    local main_display_idx=0
    local count=1

    # まずディスプレイ情報を収集
    while IFS='|' read -r num x y w h vx vy vw vh; do
        if [ -n "$num" ]; then
            displays+=("$vx $vy $vw $vh")
            display_names+=("${w}x${h}")
            # メインディスプレイ(原点0,0)のインデックスを記録
            [ "$x" = "0" ] && [ "$y" = "0" ] && main_display_idx=$((count-1))
            ((count++))
        fi
    done <<< "$display_info"

    # ディスプレイ番号が指定されている場合
    if [ -n "$specified_display" ]; then
        local idx=$((specified_display - 1))
        if [ "$idx" -ge 0 ] && [ "$idx" -lt ${#displays[@]} ]; then
            echo -e "${CYAN}ディスプレイ $specified_display (${display_names[$idx]}) を使用${NC}" >&2
            echo "${displays[$idx]}"
            return 0
        else
            echo -e "${RED}エラー: ディスプレイ $specified_display は存在しません${NC}" >&2
            return 1
        fi
    fi

    # ディスプレイが1つ、または自動モードならメインディスプレイを返す
    if [ ${#displays[@]} -eq 1 ] || [ "$auto_mode" = true ]; then
        echo "${displays[$main_display_idx]}"
        return 0
    fi

    # 複数ディスプレイがある場合は選択メニューを表示
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
    echo -e "${BOLD}  ディスプレイ選択${NC}" >&2
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" >&2
    echo "" >&2

    count=1
    while IFS='|' read -r num x y w h vx vy vw vh; do
        if [ -n "$num" ]; then
            local main_mark=""
            [ "$x" = "0" ] && [ "$y" = "0" ] && main_mark="${GREEN}(メイン)${NC}"
            echo -e "  ${CYAN}${count})${NC} ディスプレイ $num: ${w}x${h} (使用可能: ${vw}x${vh}) $main_mark" >&2
            ((count++))
        fi
    done <<< "$display_info"

    echo "" >&2

    while true; do
        echo -ne "${BOLD}配置先のディスプレイを選択 [1-$((count-1))]: ${NC}" >&2
        read -r choice

        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -lt "$count" ]; then
            echo "${displays[$((choice-1))]}"
            return 0
        fi

        echo -e "${RED}無効な選択です${NC}" >&2
    done
}

# Terminal.appのウィンドウ情報を取得
get_terminal_windows() {
    osascript -e '
    tell application "System Events"
        if not (exists process "Terminal") then return ""
    end tell
    tell application "Terminal"
        set output to ""
        set windowList to every window whose visible is true
        repeat with w in windowList
            try
                set windowName to name of w
                set windowId to id of w
                set output to output & windowId & "|" & windowName & linefeed
            end try
        end repeat
        return output
    end tell
    ' 2>/dev/null
}

# iTerm2のウィンドウ情報を取得
get_iterm_windows() {
    osascript -e '
    tell application "System Events"
        if not (exists process "iTerm2") then return ""
    end tell
    tell application "iTerm2"
        set output to ""
        repeat with w in windows
            try
                set windowName to name of w
                set windowId to id of w
                set output to output & windowId & "|" & windowName & linefeed
            end try
        end repeat
        return output
    end tell
    ' 2>/dev/null
}

# ディスプレイ別ウィンドウ情報を取得
get_windows_by_display() {
    osascript << 'EOF'
tell application "Terminal"
    set output to ""
    repeat with w in (every window whose visible is true)
        set wid to id of w
        set wname to name of w
        set b to bounds of w
        set wy to item 2 of b
        set tabCount to count of tabs of w

        if wy < 0 then
            set disp to "2"
        else
            set disp to "1"
        end if

        set output to output & wid & "|" & disp & "|" & wname & "|" & tabCount & linefeed
    end repeat
    return output
end tell
EOF
}

# 画面クリアとヘッダー表示
show_header() {
    printf "\033c"
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║            Terminal Grid - ウィンドウ配置ツール            ║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ウィンドウ一覧をプレビュー表示（ディスプレイ別）
show_window_preview() {
    local target=$1

    local windows_info
    windows_info=$(get_windows_by_display)

    local display1_count=0
    local display2_count=0

    # カウント
    while IFS='|' read -r id disp name tabs; do
        [ -n "$id" ] && [ "$disp" = "1" ] && ((display1_count++))
        [ -n "$id" ] && [ "$disp" = "2" ] && ((display2_count++))
    done <<< "$windows_info"

    show_header

    echo -e "${BOLD}【現在のウィンドウ】${NC}"
    echo ""

    # ディスプレイ1
    echo -e "${GREEN}■ ディスプレイ1 (メイン): ${display1_count}個${NC}"
    local count=1
    while IFS='|' read -r id disp name tabs; do
        if [ -n "$id" ] && [ "$disp" = "1" ]; then
            local short_name="${name:0:45}"
            [ ${#name} -gt 45 ] && short_name="${short_name}..."
            local tab_info=""
            [ -n "$tabs" ] && [ "$tabs" -gt 1 ] 2>/dev/null && tab_info=" ${YELLOW}[${tabs}tabs]${NC}"
            echo -e "  ${CYAN}$count.${NC} $short_name$tab_info"
            ((count++))
        fi
    done <<< "$windows_info"
    [ "$display1_count" -eq 0 ] && echo -e "  ${YELLOW}(なし)${NC}"

    echo ""

    # ディスプレイ2
    echo -e "${GREEN}■ ディスプレイ2 (外部): ${display2_count}個${NC}"
    count=1
    while IFS='|' read -r id disp name tabs; do
        if [ -n "$id" ] && [ "$disp" = "2" ]; then
            local short_name="${name:0:45}"
            [ ${#name} -gt 45 ] && short_name="${short_name}..."
            local tab_info=""
            [ -n "$tabs" ] && [ "$tabs" -gt 1 ] 2>/dev/null && tab_info=" ${YELLOW}[${tabs}tabs]${NC}"
            echo -e "  ${CYAN}$count.${NC} $short_name$tab_info"
            ((count++))
        fi
    done <<< "$windows_info"
    [ "$display2_count" -eq 0 ] && echo -e "  ${YELLOW}(なし)${NC}"

    local total_count=$((display1_count + display2_count))

    if [ "$total_count" -eq 0 ]; then
        echo ""
        echo -e "${YELLOW}ウィンドウが見つかりません${NC}"
        return 1
    fi

    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    return 0
}

# インタラクティブメニュー
interactive_menu() {
    while true; do
        show_window_preview "all"

        echo ""
        echo -e "${BOLD}【グリッド配置】${NC}"
        echo ""
        echo -e "  ${CYAN}a)${NC} 自動配置 (推奨)"
        echo ""
        echo -e "  ${BOLD}列数選択:${NC}"
        echo -e "  ${CYAN}2)${NC} 2列    ${CYAN}3)${NC} 3列    ${CYAN}4)${NC} 4列    ${CYAN}5)${NC} 5列"
        echo ""
        echo -e "  ${CYAN}c)${NC} カスタム (列x行を指定)"
        echo ""
        echo -e "  ${CYAN}r)${NC} 更新    ${CYAN}q)${NC} 終了"
        echo ""
        echo -ne "${BOLD}選択: ${NC}"

        read -r choice

        case $choice in
            a|A)
                echo ""
                echo -e "${BOLD}自動グリッド配置を実行中...${NC}"
                local arranged=$(arrange_terminal_windows 0 0)
                echo -e "${GREEN}✓ ${arranged}個のウィンドウを配置しました${NC}"
                echo ""
                echo -ne "Enterで続行..."
                read -r
                ;;
            2)
                select_rows_and_arrange 2
                ;;
            3)
                select_rows_and_arrange 3
                ;;
            4)
                select_rows_and_arrange 4
                ;;
            5)
                select_rows_and_arrange 5
                ;;
            c|C)
                echo ""
                echo -ne "${BOLD}列数を入力: ${NC}"
                read -r cols
                echo -ne "${BOLD}行数を入力: ${NC}"
                read -r rows
                if [[ "$cols" =~ ^[0-9]+$ ]] && [[ "$rows" =~ ^[0-9]+$ ]]; then
                    echo ""
                    echo -e "${BOLD}${cols}列 x ${rows}行 で配置中...${NC}"
                    local arranged=$(arrange_terminal_windows "$cols" "$rows")
                    echo -e "${GREEN}✓ ${arranged}個のウィンドウを配置しました${NC}"
                else
                    echo -e "${RED}無効な入力です${NC}"
                fi
                echo ""
                echo -ne "Enterで続行..."
                read -r
                ;;
            r|R)
                continue
                ;;
            q|Q)
                printf "\033c"
                echo "終了しました"
                exit 0
                ;;
            *)
                echo -e "${RED}無効な選択です${NC}"
                sleep 1
                ;;
        esac
    done
}

# 行数を選択して配置
select_rows_and_arrange() {
    local cols=$1
    echo ""
    echo -e "${BOLD}${cols}列で配置 - 行数を選択:${NC}"
    echo ""
    echo -e "  ${CYAN}a)${NC} 自動    ${CYAN}1)${NC} 1行    ${CYAN}2)${NC} 2行    ${CYAN}3)${NC} 3行    ${CYAN}4)${NC} 4行"
    echo ""
    echo -ne "${BOLD}行数: ${NC}"
    read -r rows_choice

    local rows=0
    case $rows_choice in
        a|A) rows=0 ;;
        1) rows=1 ;;
        2) rows=2 ;;
        3) rows=3 ;;
        4) rows=4 ;;
        *)
            if [[ "$rows_choice" =~ ^[0-9]+$ ]]; then
                rows=$rows_choice
            else
                echo -e "${RED}無効な選択です${NC}"
                sleep 1
                return
            fi
            ;;
    esac

    echo ""
    if [ "$rows" -eq 0 ]; then
        echo -e "${BOLD}${cols}列 x 自動行 で配置中...${NC}"
    else
        echo -e "${BOLD}${cols}列 x ${rows}行 で配置中...${NC}"
    fi
    local arranged=$(arrange_terminal_windows "$cols" "$rows")
    echo -e "${GREEN}✓ ${arranged}個のウィンドウを配置しました${NC}"
    echo ""
    echo -ne "Enterで続行..."
    read -r
}

# グリッド配置オプションを表示して選択
show_grid_options() {
    local window_count=$1
    local screen_width=$2
    local screen_height=$3

    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  グリッド配置オプション${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    local options=()
    local option_num=1

    # 利用可能なグリッドオプションを生成
    for cols in 1 2 3 4; do
        local rows=$(( (window_count + cols - 1) / cols ))
        if [ $rows -le 6 ]; then
            local win_w=$(( (screen_width - PADDING * (cols + 1)) / cols ))
            local win_h=$(( (screen_height - PADDING * (rows + 1)) / rows ))
            options+=("$cols $rows")

            # 推奨マークを付ける
            local recommended=""
            if [ $window_count -le 2 ] && [ $cols -eq 2 ]; then
                recommended="${GREEN}(推奨)${NC}"
            elif [ $window_count -le 4 ] && [ $cols -eq 2 ]; then
                recommended="${GREEN}(推奨)${NC}"
            elif [ $window_count -le 6 ] && [ $cols -eq 3 ]; then
                recommended="${GREEN}(推奨)${NC}"
            elif [ $window_count -le 9 ] && [ $cols -eq 3 ]; then
                recommended="${GREEN}(推奨)${NC}"
            elif [ $window_count -gt 9 ] && [ $cols -eq 4 ]; then
                recommended="${GREEN}(推奨)${NC}"
            fi

            echo -e "  ${CYAN}${option_num})${NC} ${BOLD}${cols}列 x ${rows}行${NC} (各ウィンドウ: ${win_w}x${win_h}px) $recommended"
            ((option_num++))
        fi
    done

    echo ""
    echo -e "  ${CYAN}0)${NC} キャンセル"
    echo ""

    # 選択を受け付け
    while true; do
        echo -ne "${BOLD}選択してください [1-$((option_num-1))]: ${NC}"
        read -r choice

        if [ "$choice" = "0" ]; then
            echo "キャンセルしました"
            exit 0
        fi

        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -lt "$option_num" ]; then
            local selected="${options[$((choice-1))]}"
            echo "$selected"
            return 0
        fi

        echo -e "${RED}無効な選択です。もう一度入力してください。${NC}"
    done
}

# Terminal.appのウィンドウをグリッド配置（ディスプレイ別に自動配置）
arrange_terminal_windows() {
    local cols=$1
    local rows=$2
    local menu_bar_h=$MENU_BAR_HEIGHT
    local pad=$PADDING

    osascript << EOF
tell application "Terminal"
    activate
    delay 0.3

    -- ディスプレイ別にウィンドウを分類（タブ数1のウィンドウのみ対象）
    set display1Windows to {}
    set display2Windows to {}
    set skippedWindows to 0

    repeat with w in (every window whose visible is true)
        set wid to id of w
        set tabCount to count of tabs of w

        -- 複数タブを持つウィンドウは配置対象から除外
        if tabCount > 1 then
            set skippedWindows to skippedWindows + 1
        else
            set b to bounds of w
            set wy to item 2 of b

            if wy < 0 then
                set end of display2Windows to wid
            else
                set end of display1Windows to wid
            end if
        end if
    end repeat

    set totalArranged to 0
    set menuBarH to $menu_bar_h
    set pad to $pad

    -- ディスプレイ1 (メイン: 1800x1169)
    if (count of display1Windows) > 0 then
        set cnt to count of display1Windows

        -- グリッドサイズを決定
        if $cols > 0 then
            set cols to $cols
        else if cnt ≤ 2 then
            set cols to 2
        else if cnt ≤ 4 then
            set cols to 2
        else if cnt ≤ 6 then
            set cols to 3
        else
            set cols to 4
        end if
        set rows to (cnt + cols - 1) div cols

        set screenW to 1800
        set screenH to 1169 - menuBarH

        set winW to ((screenW - pad * (cols + 1)) / cols) as integer
        set winH to ((screenH - pad * (rows + 1)) / rows) as integer
        set startY to menuBarH

        repeat with i from 1 to cnt
            set wid to item i of display1Windows
            set idx to i - 1
            set c to idx mod cols
            set r to idx div cols
            set x1 to pad + c * (winW + pad)
            set y1 to startY + pad + r * (winH + pad)

            set frontmost of window id wid to true
            delay 0.1
            set bounds of window id wid to {x1, y1, x1 + winW, y1 + winH}
            delay 0.1
            set totalArranged to totalArranged + 1
        end repeat
    end if

    -- ディスプレイ2 (外部: 1920x1080、メインディスプレイの上に配置)
    -- 注意: Terminal.appは外部ディスプレイで複数行配置に制限があるため、
    -- 行数を最小限に抑える配置を行う
    if (count of display2Windows) > 0 then
        set cnt to count of display2Windows

        -- グリッドサイズを決定
        if $cols > 0 then
            -- カスタムモード: ユーザー指定の列数を使用
            set cols to $cols
            set rows to (cnt + cols - 1) div cols
        else
            -- 自動モード: 最小幅200pxを確保しつつ行数を最小化
            set minWidth to 200
            set screenW to 1920
            set maxCols to ((screenW - pad) / (minWidth + pad)) as integer
            if maxCols < 1 then set maxCols to 1

            if cnt ≤ maxCols then
                -- 1行に収まる場合
                set cols to cnt
                set rows to 1
            else
                -- 複数行必要: 最小行数で配置（行分布の問題は許容）
                set cols to maxCols
                set rows to (cnt + cols - 1) div cols
            end if
        end if

        set screenW to 1920
        set screenH to 1080 - menuBarH

        set winW to ((screenW - pad * (cols + 1)) / cols) as integer
        set winH to ((screenH - pad * (rows + 1)) / rows) as integer
        set startY to -1080 + menuBarH

        -- 全ウィンドウを配置
        repeat with i from 1 to cnt
            set wid to item i of display2Windows
            set idx to i - 1
            set c to idx mod cols
            set r to idx div cols
            set x1 to -384 + pad + c * (winW + pad)
            set actualY to startY + pad + r * (winH + pad)
            set boundsY to actualY + 1080

            set bounds of window id wid to {x1, boundsY, x1 + winW, boundsY + winH}
            delay 0.1
            set totalArranged to totalArranged + 1
        end repeat
    end if

    return totalArranged
end tell
EOF
}

# iTerm2のウィンドウをグリッド配置
arrange_iterm_windows() {
    local screen_x=$1
    local screen_y=$2
    local screen_width=$3
    local screen_height=$4
    local cols=$5
    local rows=$6

    local window_width=$(( (screen_width - PADDING * (cols + 1)) / cols ))
    local window_height=$(( (screen_height - PADDING * (rows + 1)) / rows ))

    osascript << EOF 2>/dev/null
tell application "System Events"
    if not (exists process "iTerm2") then return 0
end tell
tell application "iTerm2"
    set windowList to every window
    set windowCount to count of windowList
    set colCount to $cols
    set winWidth to $window_width
    set winHeight to $window_height
    set padding to $PADDING
    set screenX to $screen_x
    set screenY to $screen_y
    set windowIndex to 0

    repeat with i from 1 to windowCount
        set currentWindow to item i of windowList
        try
            set col to (windowIndex mod colCount)
            set row to (windowIndex div colCount)

            set xPos to screenX + padding + col * (winWidth + padding)
            set yPos to screenY + padding + row * (winHeight + padding)

            set bounds of currentWindow to {xPos, yPos, xPos + winWidth, yPos + winHeight}
            set windowIndex to windowIndex + 1
        end try
    end repeat
    return windowIndex
end tell
EOF
}

# ウィンドウ数を取得
get_window_count() {
    local target=$1
    local count=0

    if [ "$target" = "terminal" ] || [ "$target" = "all" ]; then
        local terminal_windows=$(get_terminal_windows)
        while IFS='|' read -r id name; do
            [ -n "$id" ] && ((count++))
        done <<< "$terminal_windows"
    fi

    if [ "$target" = "iterm" ] || [ "$target" = "all" ]; then
        local iterm_windows=$(get_iterm_windows)
        while IFS='|' read -r id name; do
            [ -n "$id" ] && ((count++))
        done <<< "$iterm_windows"
    fi

    echo "$count"
}

# メイン処理
main() {
    local target="all"
    local auto_mode=false
    local select_mode=false
    local custom_grid=""
    local display_num=""
    local preset_save=""
    local preset_load=""
    local preset_delete=""
    local list_mode=false

    # 引数解析
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -t|--terminal)
                target="terminal"
                shift
                ;;
            -i|--iterm)
                target="iterm"
                shift
                ;;
            -a|--all)
                target="all"
                shift
                ;;
            -y|--yes)
                auto_mode=true
                shift
                ;;
            -s|--select)
                select_mode=true
                shift
                ;;
            -g|--grid)
                custom_grid="$2"
                shift 2
                ;;
            -d|--display)
                display_num="$2"
                shift 2
                ;;
            --save)
                preset_save="$2"
                shift 2
                ;;
            --load)
                preset_load="$2"
                shift 2
                ;;
            --delete)
                preset_delete="$2"
                shift 2
                ;;
            --list)
                list_mode=true
                shift
                ;;
            *)
                shift
                ;;
        esac
    done

    # プリセット一覧表示
    if [ "$list_mode" = true ]; then
        list_presets
        exit 0
    fi

    # プリセット削除
    if [ -n "$preset_delete" ]; then
        delete_preset "$preset_delete"
        exit 0
    fi

    # プリセット読み込み
    if [ -n "$preset_load" ]; then
        local preset_data
        preset_data=$(load_preset "$preset_load")
        if [ $? -ne 0 ]; then
            exit 1
        fi
        read -r target cols rows display_num selected_windows <<< "$preset_data"
        auto_mode=true
        echo -e "${CYAN}プリセット '$preset_load' を読み込みました${NC}"
    fi

    # インタラクティブモード（デフォルト）
    if [ "$auto_mode" = false ] && [ -z "$custom_grid" ]; then
        interactive_menu
        exit 0
    fi

    # 自動モードまたはカスタムグリッド指定時
    local cols=0
    local rows=0

    # カスタムグリッドが指定されている場合
    if [ -n "$custom_grid" ]; then
        local parsed=$(parse_grid "$custom_grid")
        if [ -z "$parsed" ]; then
            echo -e "${RED}エラー: グリッド形式が不正です（例: 3x2）${NC}"
            exit 1
        fi
        read -r cols rows <<< "$parsed"
        echo -e "${CYAN}カスタムグリッド: ${BOLD}${cols}列 x ${rows}行${NC}"
    fi

    # プレビュー表示
    show_window_preview "all"

    echo ""
    echo -e "${BOLD}配置を実行中...${NC}"

    # 全ウィンドウを配置（ディスプレイ別に自動配置）
    local arranged=$(arrange_terminal_windows "$cols" "$rows")
    if [ -n "$arranged" ] && [ "$arranged" -gt 0 ] 2>/dev/null; then
        echo -e "${GREEN}✓ Terminal.app: ${arranged}個のウィンドウを配置${NC}"
    fi

    echo ""
    echo -e "${GREEN}${BOLD}完了!${NC}"
}

# プリセット保存
save_preset() {
    local name=$1
    local target=$2
    local cols=$3
    local rows=$4
    local display=$5
    local selected_windows=$6

    mkdir -p "$PRESETS_DIR"

    cat > "$PRESETS_DIR/${name}.preset" << EOF
# Terminal Grid Preset: $name
TARGET=$target
COLS=$cols
ROWS=$rows
DISPLAY=$display
SELECTED_WINDOWS=$selected_windows
EOF

    echo -e "${GREEN}✓ プリセット '$name' を保存しました${NC}"
}

# プリセット読み込み
load_preset() {
    local name=$1
    local preset_file="$PRESETS_DIR/${name}.preset"

    if [ ! -f "$preset_file" ]; then
        echo -e "${RED}エラー: プリセット '$name' が見つかりません${NC}"
        return 1
    fi

    source "$preset_file"
    echo "$TARGET $COLS $ROWS $DISPLAY $SELECTED_WINDOWS"
}

# プリセット一覧表示
list_presets() {
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  保存済みプリセット${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    if [ ! -d "$PRESETS_DIR" ] || [ -z "$(ls -A "$PRESETS_DIR" 2>/dev/null)" ]; then
        echo -e "  ${YELLOW}プリセットがありません${NC}"
        echo ""
        return
    fi

    for preset in "$PRESETS_DIR"/*.preset; do
        local name=$(basename "$preset" .preset)
        source "$preset"
        echo -e "  ${CYAN}$name${NC}: ${COLS}x${ROWS} グリッド, ターゲット: $TARGET"
    done
    echo ""
}

# プリセット削除
delete_preset() {
    local name=$1
    local preset_file="$PRESETS_DIR/${name}.preset"

    if [ ! -f "$preset_file" ]; then
        echo -e "${RED}エラー: プリセット '$name' が見つかりません${NC}"
        return 1
    fi

    rm "$preset_file"
    echo -e "${GREEN}✓ プリセット '$name' を削除しました${NC}"
}

# インタラクティブなウィンドウ選択
select_windows_interactive() {
    local target=$1
    local terminal_windows=""
    local iterm_windows=""
    declare -a all_windows
    declare -a window_apps

    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  ウィンドウ選択${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    local count=1

    if [ "$target" = "terminal" ] || [ "$target" = "all" ]; then
        terminal_windows=$(get_terminal_windows)
        if [ -n "$terminal_windows" ]; then
            echo ""
            echo -e "${GREEN}【Terminal.app】${NC}"
            while IFS='|' read -r id name; do
                if [ -n "$id" ]; then
                    local short_name="${name:0:50}"
                    [ ${#name} -gt 50 ] && short_name="${short_name}..."
                    echo -e "  ${CYAN}$count.${NC} $short_name"
                    all_windows+=("$id")
                    window_apps+=("terminal")
                    ((count++))
                fi
            done <<< "$terminal_windows"
        fi
    fi

    if [ "$target" = "iterm" ] || [ "$target" = "all" ]; then
        iterm_windows=$(get_iterm_windows)
        if [ -n "$iterm_windows" ]; then
            echo ""
            echo -e "${GREEN}【iTerm2】${NC}"
            while IFS='|' read -r id name; do
                if [ -n "$id" ]; then
                    local short_name="${name:0:50}"
                    [ ${#name} -gt 50 ] && short_name="${short_name}..."
                    echo -e "  ${CYAN}$count.${NC} $short_name"
                    all_windows+=("$id")
                    window_apps+=("iterm")
                    ((count++))
                fi
            done <<< "$iterm_windows"
        fi
    fi

    if [ ${#all_windows[@]} -eq 0 ]; then
        echo -e "${YELLOW}ウィンドウが見つかりません${NC}"
        return 1
    fi

    echo ""
    echo -e "番号を入力して選択（複数はスペース区切り、${BOLD}a${NC}=全選択）"
    echo -ne "${BOLD}選択: ${NC}"
    read -r selection

    if [ "$selection" = "a" ] || [ "$selection" = "A" ]; then
        # 全選択
        local result=""
        for ((i=0; i<${#all_windows[@]}; i++)); do
            [ -n "$result" ] && result="$result,"
            result="${result}${window_apps[$i]}:${all_windows[$i]}"
        done
        echo "$result"
        return 0
    fi

    # 選択されたウィンドウを返す
    local result=""
    for num in $selection; do
        if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -lt "$count" ]; then
            local idx=$((num - 1))
            [ -n "$result" ] && result="$result,"
            result="${result}${window_apps[$idx]}:${all_windows[$idx]}"
        fi
    done

    if [ -z "$result" ]; then
        echo -e "${RED}無効な選択です${NC}"
        return 1
    fi

    echo "$result"
}

# 選択されたTerminal.appウィンドウのみを配置
arrange_selected_terminal_windows() {
    local screen_x=$1
    local screen_y=$2
    local screen_width=$3
    local screen_height=$4
    local cols=$5
    local rows=$6
    local selected_ids=$7

    local window_width=$(( (screen_width - PADDING * (cols + 1)) / cols ))
    local window_height=$(( (screen_height - PADDING * (rows + 1)) / rows ))

    osascript << EOF
tell application "Terminal"
    set selectedIds to {$(echo "$selected_ids" | tr ',' ',')}
    set windowIndex to 0
    set colCount to $cols
    set winWidth to $window_width
    set winHeight to $window_height
    set padding to $PADDING
    set screenX to $screen_x
    set screenY to $screen_y
    set arrangedCount to 0

    repeat with w in (every window whose visible is true)
        try
            set wid to id of w
            if selectedIds contains wid then
                set col to (windowIndex mod colCount)
                set row to (windowIndex div colCount)

                set xPos to screenX + padding + col * (winWidth + padding)
                set yPos to screenY + padding + row * (winHeight + padding)

                set bounds of w to {xPos, yPos, xPos + winWidth, yPos + winHeight}
                set windowIndex to windowIndex + 1
                set arrangedCount to arrangedCount + 1
            end if
        end try
    end repeat
    return arrangedCount
end tell
EOF
}

# 選択されたiTerm2ウィンドウのみを配置
arrange_selected_iterm_windows() {
    local screen_x=$1
    local screen_y=$2
    local screen_width=$3
    local screen_height=$4
    local cols=$5
    local rows=$6
    local selected_ids=$7

    local window_width=$(( (screen_width - PADDING * (cols + 1)) / cols ))
    local window_height=$(( (screen_height - PADDING * (rows + 1)) / rows ))

    osascript << EOF
tell application "iTerm2"
    set selectedIds to {$(echo "$selected_ids" | tr ',' ',')}
    set windowIndex to 0
    set colCount to $cols
    set winWidth to $window_width
    set winHeight to $window_height
    set padding to $PADDING
    set screenX to $screen_x
    set screenY to $screen_y
    set arrangedCount to 0

    repeat with w in windows
        try
            set wid to id of w
            if selectedIds contains wid then
                set col to (windowIndex mod colCount)
                set row to (windowIndex div colCount)

                set xPos to screenX + padding + col * (winWidth + padding)
                set yPos to screenY + padding + row * (winHeight + padding)

                set bounds of w to {xPos, yPos, xPos + winWidth, yPos + winHeight}
                set windowIndex to windowIndex + 1
                set arrangedCount to arrangedCount + 1
            end if
        end try
    end repeat
    return arrangedCount
end tell
EOF
}

# カスタムグリッドのパース
parse_grid() {
    local grid=$1
    if [[ "$grid" =~ ^([0-9]+)x([0-9]+)$ ]]; then
        echo "${BASH_REMATCH[1]} ${BASH_REMATCH[2]}"
    else
        echo ""
    fi
}

main "$@"
