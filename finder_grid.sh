#!/bin/bash

# Finder Grid - Finderウィンドウをグリッド配置するツール
# macOS用

# 設定
MENU_BAR_HEIGHT=38
PADDING=5
CONFIG_DIR="$HOME/.config/finder-grid"
PRESETS_DIR="$CONFIG_DIR/presets"

# 色付き出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# グローバル変数: ディスプレイ情報キャッシュ
DISPLAY_INFO=""
DISPLAY_COUNT=0

# ヘルプ表示
show_help() {
    echo "Finder Grid - Finderウィンドウをグリッド配置"
    echo ""
    echo "使い方: ./finder_grid.sh [オプション]"
    echo ""
    echo "基本オプション:"
    echo "  -h, --help              このヘルプを表示"
    echo "  -y, --yes               プレビューをスキップして自動配置"
    echo ""
    echo "グリッド指定:"
    echo "  -g, --grid <cols>x<rows>  カスタムグリッドを指定（例: -g 3x2）"
    echo ""
    echo "ディスプレイ指定:"
    echo "  -d, --display <番号>      配置先ディスプレイを指定（1, 2, ...）"
    echo "  -m, --move <番号>         全ウィンドウを指定ディスプレイに移動して配置"
    echo ""
    echo "プリセット:"
    echo "  --save <name>           現在の設定をプリセットとして保存"
    echo "  --load <name>           プリセットを読み込んで配置"
    echo "  --list                  保存済みプリセット一覧を表示"
    echo "  --delete <name>         プリセットを削除"
    echo ""
    echo "例:"
    echo "  ./finder_grid.sh              # インタラクティブモード"
    echo "  ./finder_grid.sh -y           # 自動でグリッド配置（各ディスプレイ）"
    echo "  ./finder_grid.sh -m 1         # 全ウィンドウをディスプレイ1に配置"
    echo "  ./finder_grid.sh -m 2 -g 3x2  # ディスプレイ2に3列2行で配置"
}

# NSScreenを使って正確な画面サイズを取得（1回のosascript呼び出しで全情報取得）
get_screen_info() {
    osascript -e '
use framework "AppKit"
use scripting additions

set screenList to current application'\''s NSScreen'\''s screens()
set mainScreen to item 1 of screenList
set mainFrame to mainScreen'\''s frame()
set mainHeight to (current application'\''s NSHeight(mainFrame)) as integer
set output to ""

repeat with i from 1 to count of screenList
    set aScreen to item i of screenList
    set frame to aScreen'\''s frame()
    set visibleFrame to aScreen'\''s visibleFrame()

    set fx to (current application'\''s NSMinX(frame)) as integer
    set fy to (current application'\''s NSMinY(frame)) as integer
    set fw to (current application'\''s NSWidth(frame)) as integer
    set fh to (current application'\''s NSHeight(frame)) as integer

    set vx to (current application'\''s NSMinX(visibleFrame)) as integer
    set vy to (current application'\''s NSMinY(visibleFrame)) as integer
    set vw to (current application'\''s NSWidth(visibleFrame)) as integer
    set vh to (current application'\''s NSHeight(visibleFrame)) as integer

    set menuBarHeight to fh - vh - (vy - fy)

    -- AppleScript座標に変換（左上原点）
    set asX to fx
    set asY to mainHeight - (fy + fh)

    set output to output & i & "|" & fx & "|" & fy & "|" & fw & "|" & fh & "|" & asX & "|" & asY & "|" & vw & "|" & vh & linefeed
end repeat

return output
'
}

# ディスプレイ情報をキャッシュ
cache_display_info() {
    DISPLAY_INFO=$(get_screen_info)
    DISPLAY_COUNT=$(echo "$DISPLAY_INFO" | grep -c "|")
}

# ディスプレイ一覧を表示
show_displays() {
    echo -e "${BOLD}【接続ディスプレイ】${NC}"
    echo ""

    local count=1
    while IFS='|' read -r num fx fy fw fh asx asy vw vh; do
        if [ -n "$num" ]; then
            local main_mark=""
            [ "$fx" = "0" ] && [ "$fy" = "0" ] && main_mark=" ${GREEN}(メイン)${NC}"
            echo -e "  ${CYAN}$count)${NC} ディスプレイ$num: ${fw}x${fh} (使用可能: ${vw}x${vh})$main_mark"
            ((count++))
        fi
    done <<< "$DISPLAY_INFO"
    echo ""
}

# 指定ディスプレイの情報を取得
get_display_bounds() {
    local display_num=$1
    local count=1

    while IFS='|' read -r num fx fy fw fh asx asy vw vh; do
        if [ -n "$num" ] && [ "$count" -eq "$display_num" ]; then
            echo "$asx $asy $vw $vh $fw $fh"
            return 0
        fi
        ((count++))
    done <<< "$DISPLAY_INFO"
    return 1
}

# Finderウィンドウ情報を取得（ウィンドウ数のみ高速取得）
get_finder_window_count() {
    osascript -e '
    tell application "System Events"
        if not (exists process "Finder") then return 0
    end tell
    tell application "Finder"
        return count of (every Finder window whose visible is true)
    end tell
    ' 2>/dev/null
}

# ウィンドウとディスプレイの対応を取得
get_windows_with_display() {
    osascript -e '
tell application "Finder"
    set output to ""
    set windowList to every Finder window whose visible is true

    repeat with i from 1 to count of windowList
        set w to item i of windowList
        set wname to name of w
        set b to bounds of w
        set wx to item 1 of b
        set wy to item 2 of b
        set output to output & i & "|" & wx & "|" & wy & "|" & wname & linefeed
    end repeat
    return output
end tell
'
}

# ウィンドウがどのディスプレイにあるか判定
get_window_display() {
    local wy=$1

    # Y座標が負の場合は外部ディスプレイ（上に配置されている）
    if [ "$wy" -lt 0 ]; then
        echo "2"
    else
        echo "1"
    fi
}

# 画面クリアとヘッダー表示
show_header() {
    printf "\033c"
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║             Finder Grid - ウィンドウ配置ツール             ║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ウィンドウ一覧をプレビュー表示（ディスプレイ別）
show_window_preview() {
    local windows_info
    windows_info=$(get_windows_with_display)

    show_header
    show_displays

    echo -e "${BOLD}【現在のFinderウィンドウ】${NC}"
    echo ""

    # ディスプレイごとにウィンドウを分類して表示
    local disp_num=1
    while IFS='|' read -r dnum fx fy fw fh asx asy vw vh; do
        if [ -n "$dnum" ]; then
            local main_mark=""
            [ "$fx" = "0" ] && [ "$fy" = "0" ] && main_mark=" (メイン)"

            # このディスプレイのY座標範囲を計算
            local y_min=$asy
            local y_max=$((asy + fh))

            local win_count=0
            local win_list=""
            local count=1

            while IFS='|' read -r idx wx wy wname; do
                if [ -n "$idx" ]; then
                    # Y座標でディスプレイを判定
                    local win_disp=$(get_window_display "$wy")
                    if [ "$win_disp" = "$disp_num" ]; then
                        local short_name="${wname:0:45}"
                        [ ${#wname} -gt 45 ] && short_name="${short_name}..."
                        win_list="${win_list}  ${CYAN}${count}.${NC} $short_name\n"
                        ((win_count++))
                        ((count++))
                    fi
                fi
            done <<< "$windows_info"

            echo -e "${GREEN}■ ディスプレイ$disp_num$main_mark: ${win_count}個${NC}"
            if [ "$win_count" -gt 0 ]; then
                echo -e "$win_list"
            else
                echo -e "  ${YELLOW}(なし)${NC}"
            fi
            echo ""
            ((disp_num++))
        fi
    done <<< "$DISPLAY_INFO"

    local total_count=$(echo "$windows_info" | grep -c "|")

    if [ "$total_count" -eq 0 ]; then
        echo -e "${YELLOW}Finderウィンドウが見つかりません${NC}"
        return 1
    fi

    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    return 0
}

# インタラクティブメニュー
interactive_menu() {
    while true; do
        show_window_preview

        echo ""
        echo -e "${BOLD}【操作】${NC}"
        echo ""
        echo -e "  ${CYAN}a)${NC} 自動配置（各ディスプレイ内で配置）"
        echo ""
        echo -e "  ${BOLD}ディスプレイを選んで配置:${NC}"

        local disp_num=1
        while IFS='|' read -r dnum fx fy fw fh asx asy vw vh; do
            if [ -n "$dnum" ]; then
                local main_mark=""
                [ "$fx" = "0" ] && [ "$fy" = "0" ] && main_mark=" (メイン)"
                echo -e "  ${CYAN}$disp_num)${NC} ディスプレイ$disp_num$main_mark に全ウィンドウを配置"
                ((disp_num++))
            fi
        done <<< "$DISPLAY_INFO"

        echo ""
        echo -e "  ${CYAN}g)${NC} グリッドサイズを指定して配置"
        echo -e "  ${CYAN}r)${NC} 更新    ${CYAN}q)${NC} 終了"
        echo ""
        echo -ne "${BOLD}選択: ${NC}"

        read -r choice

        case $choice in
            a|A)
                echo ""
                echo -e "${BOLD}各ディスプレイ内で自動配置中...${NC}"
                local arranged=$(arrange_finder_windows_per_display 0 0)
                echo -e "${GREEN}✓ ${arranged}個のウィンドウを配置しました${NC}"
                echo ""
                echo -ne "Enterで続行..."
                read -r
                ;;
            [1-9])
                if [ "$choice" -le "$DISPLAY_COUNT" ]; then
                    select_grid_and_arrange "$choice"
                else
                    echo -e "${RED}無効な選択です${NC}"
                    sleep 1
                fi
                ;;
            g|G)
                select_display_and_grid
                ;;
            r|R)
                cache_display_info
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

# ディスプレイとグリッドを選択して配置
select_display_and_grid() {
    echo ""
    echo -e "${BOLD}配置先ディスプレイを選択:${NC}"

    local disp_num=1
    while IFS='|' read -r dnum fx fy fw fh asx asy vw vh; do
        if [ -n "$dnum" ]; then
            local main_mark=""
            [ "$fx" = "0" ] && [ "$fy" = "0" ] && main_mark=" (メイン)"
            echo -e "  ${CYAN}$disp_num)${NC} ディスプレイ$disp_num$main_mark (${fw}x${fh})"
            ((disp_num++))
        fi
    done <<< "$DISPLAY_INFO"

    echo ""
    echo -ne "${BOLD}ディスプレイ番号: ${NC}"
    read -r disp_choice

    if [[ "$disp_choice" =~ ^[0-9]+$ ]] && [ "$disp_choice" -ge 1 ] && [ "$disp_choice" -le "$DISPLAY_COUNT" ]; then
        select_grid_and_arrange "$disp_choice"
    else
        echo -e "${RED}無効な選択です${NC}"
        sleep 1
    fi
}

# グリッドを選択して配置
select_grid_and_arrange() {
    local target_display=$1

    echo ""
    echo -e "${BOLD}ディスプレイ$target_display に配置 - グリッドを選択:${NC}"
    echo ""
    echo -e "  ${CYAN}a)${NC} 自動"
    echo -e "  ${CYAN}2)${NC} 2列    ${CYAN}3)${NC} 3列    ${CYAN}4)${NC} 4列    ${CYAN}5)${NC} 5列"
    echo -e "  ${CYAN}c)${NC} カスタム (列x行を指定)"
    echo ""
    echo -ne "${BOLD}選択: ${NC}"
    read -r grid_choice

    local cols=0
    local rows=0

    case $grid_choice in
        a|A)
            cols=0
            rows=0
            ;;
        2|3|4|5)
            cols=$grid_choice
            echo ""
            echo -e "  ${CYAN}a)${NC} 自動    ${CYAN}1)${NC} 1行    ${CYAN}2)${NC} 2行    ${CYAN}3)${NC} 3行    ${CYAN}4)${NC} 4行"
            echo -ne "${BOLD}行数: ${NC}"
            read -r rows_choice
            case $rows_choice in
                a|A) rows=0 ;;
                [1-4]) rows=$rows_choice ;;
                *) rows=0 ;;
            esac
            ;;
        c|C)
            echo -ne "${BOLD}列数: ${NC}"
            read -r cols
            echo -ne "${BOLD}行数: ${NC}"
            read -r rows
            if ! [[ "$cols" =~ ^[0-9]+$ ]] || ! [[ "$rows" =~ ^[0-9]+$ ]]; then
                echo -e "${RED}無効な入力です${NC}"
                sleep 1
                return
            fi
            ;;
        *)
            echo -e "${RED}無効な選択です${NC}"
            sleep 1
            return
            ;;
    esac

    echo ""
    echo -e "${BOLD}ディスプレイ$target_display に配置中...${NC}"
    local arranged=$(arrange_all_windows_to_display "$target_display" "$cols" "$rows")
    echo -e "${GREEN}✓ ${arranged}個のウィンドウを配置しました${NC}"
    echo ""
    echo -ne "Enterで続行..."
    read -r
}

# 全ウィンドウを指定ディスプレイに移動して配置（単一osascript呼び出し）
arrange_all_windows_to_display() {
    local target_display=$1
    local cols=$2
    local rows=$3
    local pad=$PADDING

    # ターゲットディスプレイの情報を取得
    local bounds=$(get_display_bounds "$target_display")
    if [ -z "$bounds" ]; then
        echo "0"
        return
    fi

    read -r asx asy vw vh fw fh <<< "$bounds"

    osascript -e "
tell application \"Finder\"
    set windowList to every Finder window whose visible is true
    set cnt to count of windowList
    if cnt = 0 then return 0

    set pad to $pad
    set screenX to $asx
    set screenY to $asy
    set screenW to $vw
    set screenH to $vh

    if $cols > 0 then
        set cols to $cols
    else if cnt ≤ 2 then
        set cols to 2
    else if cnt ≤ 4 then
        set cols to 2
    else if cnt ≤ 6 then
        set cols to 3
    else if cnt ≤ 9 then
        set cols to 3
    else
        set cols to 4
    end if

    if $rows > 0 then
        set rows to $rows
    else
        set rows to (cnt + cols - 1) div cols
    end if

    set winW to ((screenW - pad * (cols + 1)) / cols) as integer
    set winH to ((screenH - pad * (rows + 1)) / rows) as integer

    repeat with i from 1 to cnt
        set targetWindow to item i of windowList
        set idx to i - 1
        set c to idx mod cols
        set r to idx div cols
        set x1 to screenX + pad + c * (winW + pad)
        set y1 to screenY + pad + r * (winH + pad)
        set bounds of targetWindow to {x1, y1, x1 + winW, y1 + winH}
    end repeat

    return cnt
end tell
"
}

# 各ディスプレイ内でウィンドウを配置（単一osascript呼び出し）
arrange_finder_windows_per_display() {
    local cols=$1
    local rows=$2
    local pad=$PADDING

    # ディスプレイ情報を配列として取得
    local display_bounds=()
    while IFS='|' read -r dnum fx fy fw fh asx asy vw vh; do
        if [ -n "$dnum" ]; then
            display_bounds+=("$asx|$asy|$vw|$vh|$fh")
        fi
    done <<< "$DISPLAY_INFO"

    # AppleScriptに渡すディスプレイ情報を構築
    local as_displays=""
    for bounds in "${display_bounds[@]}"; do
        as_displays="${as_displays}${bounds};"
    done

    osascript -e "
tell application \"Finder\"

    -- ディスプレイ情報をパース
    set displayData to \"$as_displays\"
    set displayList to {}
    set oldDelims to AppleScript's text item delimiters
    set AppleScript's text item delimiters to \";\"
    set displayParts to text items of displayData
    set AppleScript's text item delimiters to oldDelims

    repeat with dp in displayParts
        if dp is not \"\" then
            set AppleScript's text item delimiters to \"|\"
            set coords to text items of (dp as text)
            set AppleScript's text item delimiters to oldDelims
            if (count of coords) ≥ 5 then
                set end of displayList to {asx:(item 1 of coords) as integer, asy:(item 2 of coords) as integer, vw:(item 3 of coords) as integer, vh:(item 4 of coords) as integer, fh:(item 5 of coords) as integer}
            end if
        end if
    end repeat

    set windowList to every Finder window whose visible is true
    set totalArranged to 0
    set pad to $PADDING

    -- 各ディスプレイについて処理
    repeat with dispIdx from 1 to count of displayList
        set dispInfo to item dispIdx of displayList
        set dAsx to asx of dispInfo
        set dAsy to asy of dispInfo
        set dVw to vw of dispInfo
        set dVh to vh of dispInfo
        set dFh to fh of dispInfo

        -- このディスプレイのウィンドウを収集
        set dispWindows to {}
        repeat with i from 1 to count of windowList
            set w to item i of windowList
            set b to bounds of w
            set wy to item 2 of b

            -- Y座標でディスプレイを判定
            if dispIdx = 1 then
                if wy ≥ 0 then
                    set end of dispWindows to i
                end if
            else
                if wy < 0 then
                    set end of dispWindows to i
                end if
            end if
        end repeat

        set cnt to count of dispWindows
        if cnt > 0 then
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

            set winW to ((dVw - pad * (cols + 1)) / cols) as integer
            set winH to ((dVh - pad * (rows + 1)) / rows) as integer

            repeat with j from 1 to cnt
                set winIdx to item j of dispWindows
                set targetWindow to item winIdx of windowList
                set idx to j - 1
                set c to idx mod cols
                set r to idx div cols
                set x1 to dAsx + pad + c * (winW + pad)
                set y1 to dAsy + pad + r * (winH + pad)

                set bounds of targetWindow to {x1, y1, x1 + winW, y1 + winH}
                set totalArranged to totalArranged + 1
            end repeat
        end if
    end repeat

    return totalArranged
end tell
"
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

# プリセット保存
save_preset() {
    local name=$1
    local cols=$2
    local rows=$3
    local display=$4

    mkdir -p "$PRESETS_DIR"

    cat > "$PRESETS_DIR/${name}.preset" << EOF
COLS=$cols
ROWS=$rows
DISPLAY=$display
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
    echo "$COLS $ROWS $DISPLAY"
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
        echo -e "  ${CYAN}$name${NC}: ${COLS}x${ROWS} グリッド, ディスプレイ$DISPLAY"
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

# メイン処理
main() {
    # ディスプレイ情報をキャッシュ
    cache_display_info

    local auto_mode=false
    local custom_grid=""
    local display_num=""
    local move_display=""
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
            -y|--yes)
                auto_mode=true
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
            -m|--move)
                move_display="$2"
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
        read -r cols rows move_display <<< "$preset_data"
        auto_mode=true
        custom_grid="${cols}x${rows}"
        echo -e "${CYAN}プリセット '$preset_load' を読み込みました${NC}"
    fi

    # インタラクティブモード（デフォルト）
    if [ "$auto_mode" = false ] && [ -z "$custom_grid" ] && [ -z "$move_display" ]; then
        interactive_menu
        exit 0
    fi

    # グリッドサイズを解析
    local cols=0
    local rows=0
    if [ -n "$custom_grid" ]; then
        local parsed=$(parse_grid "$custom_grid")
        if [ -z "$parsed" ]; then
            echo -e "${RED}エラー: グリッド形式が不正です（例: 3x2）${NC}"
            exit 1
        fi
        read -r cols rows <<< "$parsed"
    fi

    # 配置実行
    show_header
    show_displays

    echo -e "${BOLD}配置を実行中...${NC}"
    echo ""

    local arranged
    if [ -n "$move_display" ]; then
        # 指定ディスプレイに全ウィンドウを移動して配置
        if [ "$move_display" -gt "$DISPLAY_COUNT" ]; then
            echo -e "${RED}エラー: ディスプレイ $move_display は存在しません${NC}"
            exit 1
        fi
        echo -e "${CYAN}全ウィンドウをディスプレイ$move_display に配置${NC}"
        arranged=$(arrange_all_windows_to_display "$move_display" "$cols" "$rows")
    else
        # 各ディスプレイ内で配置
        echo -e "${CYAN}各ディスプレイ内でウィンドウを配置${NC}"
        arranged=$(arrange_finder_windows_per_display "$cols" "$rows")
    fi

    echo -e "${GREEN}✓ ${arranged}個のウィンドウを配置しました${NC}"
    echo ""
    echo -e "${GREEN}${BOLD}完了!${NC}"
}

main "$@"
