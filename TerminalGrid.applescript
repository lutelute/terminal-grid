-- Terminal Grid - ターミナルウィンドウをグリッド配置
-- このスクリプトをAutomatorでアプリ化してキーボードショートカットを設定可能

-- 設定
property menuBarHeight : 25
property dockHeight : 70
property padding : 5

-- 画面サイズを取得
on getScreenSize()
	tell application "Finder"
		set screenBounds to bounds of window of desktop
		return {item 3 of screenBounds, item 4 of screenBounds}
	end tell
end getScreenSize

-- グリッドサイズを計算
on calculateGrid(windowCount)
	if windowCount ≤ 1 then
		return {1, 1}
	else if windowCount ≤ 2 then
		return {2, 1}
	else if windowCount ≤ 4 then
		return {2, 2}
	else if windowCount ≤ 6 then
		return {3, 2}
	else if windowCount ≤ 9 then
		return {3, 3}
	else
		return {4, (windowCount + 3) div 4}
	end if
end calculateGrid

-- Terminal.appのウィンドウを配置
on arrangeTerminalWindows(screenWidth, screenHeight)
	tell application "System Events"
		if not (exists process "Terminal") then return 0
	end tell

	tell application "Terminal"
		set windowCount to count of windows
		if windowCount = 0 then return 0

		set gridSize to my calculateGrid(windowCount)
		set cols to item 1 of gridSize
		set rows to item 2 of gridSize

		set usableHeight to screenHeight - menuBarHeight - dockHeight
		set winWidth to ((screenWidth - padding * (cols + 1)) / cols) as integer
		set winHeight to ((usableHeight - padding * (rows + 1)) / rows) as integer

		repeat with i from 1 to windowCount
			set currentWindow to window i
			set col to ((i - 1) mod cols)
			set row to ((i - 1) div cols)

			set xPos to (padding + col * (winWidth + padding)) as integer
			set yPos to (menuBarHeight + padding + row * (winHeight + padding)) as integer

			set bounds of currentWindow to {xPos, yPos, xPos + winWidth, yPos + winHeight}
		end repeat

		return windowCount
	end tell
end arrangeTerminalWindows

-- iTerm2のウィンドウを配置
on arrangeItermWindows(screenWidth, screenHeight)
	tell application "System Events"
		if not (exists process "iTerm2") then return 0
	end tell

	tell application "iTerm2"
		set windowCount to count of windows
		if windowCount = 0 then return 0

		set gridSize to my calculateGrid(windowCount)
		set cols to item 1 of gridSize
		set rows to item 2 of gridSize

		set usableHeight to screenHeight - menuBarHeight - dockHeight
		set winWidth to ((screenWidth - padding * (cols + 1)) / cols) as integer
		set winHeight to ((usableHeight - padding * (rows + 1)) / rows) as integer

		repeat with i from 1 to windowCount
			set currentWindow to window i
			set col to ((i - 1) mod cols)
			set row to ((i - 1) div cols)

			set xPos to (padding + col * (winWidth + padding)) as integer
			set yPos to (menuBarHeight + padding + row * (winHeight + padding)) as integer

			set bounds of currentWindow to {xPos, yPos, xPos + winWidth, yPos + winHeight}
		end repeat

		return windowCount
	end tell
end arrangeItermWindows

-- メイン処理
on run
	set screenSize to getScreenSize()
	set screenWidth to item 1 of screenSize
	set screenHeight to item 2 of screenSize

	set terminalCount to arrangeTerminalWindows(screenWidth, screenHeight)
	set itermCount to arrangeItermWindows(screenWidth, screenHeight)

	set totalCount to terminalCount + itermCount

	if totalCount = 0 then
		display notification "ターミナルウィンドウが見つかりません" with title "Terminal Grid"
	else
		display notification (totalCount as text) & "個のウィンドウを配置しました" with title "Terminal Grid"
	end if
end run
