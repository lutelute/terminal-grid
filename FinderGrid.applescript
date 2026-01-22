-- Finder Grid - Finderウィンドウをグリッド配置
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

-- Finderウィンドウを配置
on arrangeFinderWindows(screenWidth, screenHeight)
	tell application "System Events"
		if not (exists process "Finder") then return 0
	end tell

	tell application "Finder"
		-- 可視ウィンドウのみ取得（デスクトップを除く）
		set visibleWindows to every Finder window whose visible is true
		set windowCount to count of visibleWindows
		if windowCount = 0 then return 0

		set gridSize to my calculateGrid(windowCount)
		set cols to item 1 of gridSize
		set rows to item 2 of gridSize

		set usableHeight to screenHeight - menuBarHeight - dockHeight
		set winWidth to ((screenWidth - padding * (cols + 1)) / cols) as integer
		set winHeight to ((usableHeight - padding * (rows + 1)) / rows) as integer

		repeat with i from 1 to windowCount
			set currentWindow to item i of visibleWindows
			set col to ((i - 1) mod cols)
			set row to ((i - 1) div cols)

			set xPos to (padding + col * (winWidth + padding)) as integer
			set yPos to (menuBarHeight + padding + row * (winHeight + padding)) as integer

			set bounds of currentWindow to {xPos, yPos, xPos + winWidth, yPos + winHeight}
		end repeat

		return windowCount
	end tell
end arrangeFinderWindows

-- メイン処理
on run
	set screenSize to getScreenSize()
	set screenWidth to item 1 of screenSize
	set screenHeight to item 2 of screenSize

	set finderCount to arrangeFinderWindows(screenWidth, screenHeight)

	if finderCount = 0 then
		display notification "Finderウィンドウが見つかりません" with title "Finder Grid"
	else
		display notification (finderCount as text) & "個のウィンドウを配置しました" with title "Finder Grid"
	end if
end run
