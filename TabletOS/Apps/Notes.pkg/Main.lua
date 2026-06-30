os.sleep(0.1) --от двойного клика
local core = require("TabletOSCore")
local computer = require("computer")
local event = require("event")
local unicode = require("unicode")
local keyboard = require("keyboard")
local graphics = require("TabletOSGraphics")
local buffer = require("doubleBuffering")
local w,h = buffer.getResolution()
local program = {theme={0xCCCCCC,0xFFFFFF-0xCCCCCC},actionBar={background=0xFFFFFF,foreground=0x000000,statusBarFore=0x000000}}

local DB_NAME = "notes"

local function loadNotes()
	local data = core.readData(DB_NAME)
	if type(data) ~= "table" then data = {} end
	return data
end

local function saveNotes(notes)
	core.saveData(DB_NAME, notes)
end

local function noteTitle(note)
	local firstLine = (note.text or ""):match("([^\n]*)") or ""
	if firstLine == "" then firstLine = "Новая заметка" end
	if unicode.len(firstLine) > w-4 then
		firstLine = unicode.sub(firstLine,1,w-5) .. "…"
	end
	return firstLine
end

-- Многострочный текстовый редактор заметки
local function editNoteText(initialText)
	local text = initialText or ""
	local saveButtonArea
	local backButtonArea
	local function redraw()
		buffer.drawRectangle(1,2,w,3,program.theme[1],program.theme[2]," ")
		buffer.drawText(2,3,program.actionBar.foreground,"Редактирование")
		local backW = 9
		local backCheck = graphics.drawButton(1,4,backW,1,"< Назад",0x999999,0xFFFFFF)
		local saveCheck = graphics.drawButton(w-9,4,10,1,"Сохранить",0x00AA00,0xFFFFFF)
		buffer.drawRectangle(1,5,w,h-5,0xFFFFFF,0x000000," ")
		local lines = {}
		for line in (text.."\n"):gmatch("([^\n]*)\n") do
			table.insert(lines,line)
		end
		if #lines == 0 then lines = {""} end
		local maxLines = h-6
		local startLine = math.max(1,#lines-maxLines+1)
		local y = 6
		for i = startLine, #lines do
			local lineText = lines[i]
			if unicode.len(lineText) > w-2 then
				lineText = unicode.sub(lineText,1,w-2)
			end
			buffer.drawText(2,y,0x000000,lineText)
			y = y + 1
			if y > h-1 then break end
		end
		-- курсор в конце последней строки
		local lastLine = lines[#lines] or ""
		local cursorY = 6 + (#lines-startLine)
		if cursorY <= h-1 then
			local cursorX = 2 + unicode.len(lastLine)
			if cursorX <= w then
				buffer.drawText(cursorX,cursorY,0x000000,"█")
			end
		end
		buffer.drawChanges()
		return backCheck, saveCheck
	end
	local backCheck, saveCheck = redraw()
	while true do
		local sig = {event.pull(0.5)}
		if not sig[1] then
			backCheck, saveCheck = redraw()
		elseif sig[1] == "key_down" then
			local code = sig[4]
			local char = sig[3]
			if code == 28 then -- Enter
				if keyboard.isControlDown() then
					return text, true
				else
					text = text .. "\n"
				end
			elseif code == 14 then -- Backspace
				text = unicode.sub(text,1,-2)
			elseif char and char ~= 0 and char ~= 13 and char ~= 8 and char ~= 9 and code ~= 200 and code ~= 208 and code ~= 203 and code ~= 205 then
				local symbol = unicode.char(char)
				if keyboard.isShiftDown() then symbol = unicode.upper(symbol) end
				text = text .. symbol
			end
			backCheck, saveCheck = redraw()
		elseif sig[1] == "touch" or sig[1] == "drop" then
			if backCheck and backCheck(sig[3],sig[4]) and sig[1] == "drop" then
				return text, false
			elseif saveCheck and saveCheck(sig[3],sig[4]) and sig[1] == "drop" then
				return text, true
			end
		elseif sig[1] == "clipboard" then
			text = text .. tostring(sig[3])
			backCheck, saveCheck = redraw()
		end
	end
end

local function openNote(notes, index)
	local note = notes[index]
	local newText, shouldSave = editNoteText(note.text)
	if shouldSave then
		note.text = newText
		note.edited = os.time()
		saveNotes(notes)
	end
	computer.pushSignal("REDRAW_ALL")
end

local function createNote(notes)
	local newText, shouldSave = editNoteText("")
	if shouldSave and newText ~= "" then
		table.insert(notes,1,{text=newText, created=os.time(), edited=os.time()})
		saveNotes(notes)
	end
	computer.pushSignal("REDRAW_ALL")
end

local function deleteNote(notes, index)
	table.remove(notes,index)
	saveNotes(notes)
	computer.pushSignal("REDRAW_ALL")
end

local function drawList()
	local notes = loadNotes()
	buffer.drawRectangle(1,2,w,h-2,program.theme[1],program.theme[2]," ")
	local buttons = {}
	local y = 5
	local newCheck = graphics.drawButton(1,y,w,1,"+ Новая заметка",0x00AA00,0xFFFFFF)
	table.insert(buttons,{check=newCheck,onClick=function() createNote(notes) end})
	y = y + 2
	if #notes == 0 then
		graphics.centerText(w/2,y,0x666666,"Заметок пока нет")
	end
	for i = 1, #notes do
		if y > h-2 then break end
		local title = noteTitle(notes[i])
		local check = graphics.drawButton(1,y,w-4,1,title,program.theme[1],program.theme[2])
		local delCheck = graphics.drawButton(w-3,y,4,1,"✕",0xAA0000,0xFFFFFF)
		table.insert(buttons,{check=check,onClick=function() openNote(notes,i) end})
		table.insert(buttons,{check=delCheck,onClick=function() deleteNote(notes,i) end})
		y = y + 1
	end
	graphics.drawActionBar({
		color=program.actionBar.background,
		text="Заметки",
		textColor=program.actionBar.foreground,
		statusBarFore=program.actionBar.statusBarFore,
	})
	buffer.drawChanges()
	return buttons
end

local function mainLoop()
	local buttons = drawList()
	while true do
		local sig = {event.pull(0.5)}
		if sig[1] == "REDRAW_ALL" then
			buttons = drawList()
		elseif sig[1] == "touch" then
			if graphics.clickedToBarButton(sig[3],sig[4]) == "HOME" then
				os.exit()
			elseif graphics.clickedToBarButton(sig[3],sig[4]) == "BACK" then
				os.exit()
			elseif sig[4] == 1 then
				graphics.processStatusBar(sig[3],sig[4])
			end
		elseif sig[1] == "drop" then
			for i = 1, #buttons do
				if buttons[i].check(sig[3],sig[4]) then
					buttons[i].onClick()
					break
				end
			end
		end
	end
end

core.pcall(mainLoop)
