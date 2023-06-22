local filepath = ""

---@param fileHandler ReadHandle
local function applyPaletteFromFile(fileHandler)
    local cols = {}
    for i = 1, 16 do
        local line = fileHandler.readLine()
        if not line then
            error("File could not be read completely!")
        end
        local occurrences = {}
        for str in line:gmatch("%d+") do
            if not tonumber(str) then
                error(("Can't put %s as a number"):format(str))
            end
            occurrences[#occurrences+1] = tonumber(str)
        end
        if #occurrences > 3 then
            error("More colors than should be possible!")
        end
        cols[#cols+1] = {unpack(occurrences)}
    end
    for i = 1, 16 do
        term.setPaletteColor(2^(i-1), cols[i][1]/255, cols[i][2]/255, cols[i][3]/255)
    end
end

do
    local applyOnly = false
    if #arg > 2 then
        error("Too many arguments passed!")
    end
    for i, argument in ipairs(arg) do
        if argument == "--help" then
            print("Color Switch by Simadude")
            print("Version 1.0.0")
            print("A simple program that allows you to edit and save your palettes!\n")
            print("colsw apply [PATH]; applies the palette from the file and quits.\n")
            print("colsw [PATH]; opens existing palette file (or creates a new one)\n")
            print("colsw --help; prints out this helpful message\n")
            print("Repo - https://github.com/simadude/colorswitch")
            return
        elseif argument == "apply" and #arg == 2 and i == 1 then
            applyOnly = true
        elseif #arg == 1 and i == 1 then
            filepath = fs.combine(shell.dir(), argument)
            if fs.isDir(filepath) then
                error(("Path %s is not a file"):format(filepath))
            elseif fs.isReadOnly(filepath) then
                error(("Path %s is ReadOnly"):format(filepath))
            end
        elseif #arg == 2 and i == 2 and applyOnly then
            filepath = fs.combine(shell.dir(), argument)
            if fs.isDir(filepath) then
                error(("Path %s is not a file"):format(filepath))
            elseif fs.isReadOnly(filepath) then
                error(("Path %s is ReadOnly"):format(filepath))
            end
            if not fs.exists(filepath) then
                error(("Path %s does not exist"):format(filepath))
            end
        else
            error(("Encountered unforseen argument: %s"):format(argument))
        end
    end
    if filepath ~= "" and fs.exists(filepath) then
        local fh, e = fs.open(filepath, "r")
        if not fh then error(e) end
        ---@cast fh ReadHandle
        applyPaletteFromFile(fh);
    end
    if applyOnly then
        return
    end
end

-- index of a chosen color (1-16)
local chosenColor = 1
-- index of a chosen RGB value to change ( 1 - red, 2 - green, 3 - blue)
local chosenValue = 1

---@type string[]
local rgbstr = {};

local function saveFile()
    if filepath == "" then return end
    local fh, e = fs.open(filepath, "w")
    if not fh then error(e) end
    for i = 1, 16 do
        local r, g, b = term.getPaletteColor(2^(i-1))
        r, g, b = r*255, g*255, b*255
        fh.writeLine(("%s, %s, %s"):format(r, g, b))
    end
    fh.flush()
    fh.close()
end

local function changeRGB()
    ---@type number[]
    local rgb = {term.getPaletteColor(2^(chosenColor-1))}
    for i, value in ipairs(rgb) do
        rgbstr[i] = tostring(value*255)
    end
end

local function changePalette()
    local r, g, b = tonumber(rgbstr[1]) --[[@as number]], tonumber(rgbstr[2])--[[@as number]], tonumber(rgbstr[3])--[[@as number]]
    term.setPaletteColour(2^(chosenColor-1), r/255, g/255, b/255)
end

changeRGB()

local function colorToHex(col)
    return ("%x"):format(col)
end

local function redraw()
    term.clear()
    term.setCursorBlink(false)
    local width, height = term.getSize()
    local colorNames = {
        "white",
        "orange",
        "magenta",
        "lightBlue",
        "yellow",
        "lime",
        "pink",
        "gray",
        "lightGray",
        "cyan",
        "purple",
        "blue",
        "brown",
        "green",
        "red",
        "black"
    }
    local longestNameLength = 1;
    for _, colorName in ipairs(colorNames) do
        longestNameLength = math.max(longestNameLength, #colorName)
    end 
    for i = 1, 16 do
        local colorName = colorNames[i]
        term.setCursorPos(width - 8 - #colorName, i+1)
        term.blit(colorName..": ", ("0"):rep(#colorName+2), ("f"):rep(#colorName+1)..colorToHex(i-1))
        if chosenColor == i then
            term.setCursorPos(width - 8 - longestNameLength - 1, i+1)
            term.write((">"):rep(longestNameLength - #colorName + 1))
        end
        term.setCursorPos(width - 4 + ((i-1) % 4), height/2 + math.floor((i-1) / 4))
        term.blit(" ", "0", colorToHex(i-1))
    end

    term.setCursorPos(3, 5)
    term.write("red:   "..rgbstr[1])
    term.setCursorPos(3, 6)
    term.write("green: "..rgbstr[2])
    term.setCursorPos(3, 7)
    term.write("blue:  "..rgbstr[3])


    term.setCursorBlink(true)
    term.setCursorPos(10+#rgbstr[chosenValue], 4+chosenValue)
end

local holdingShift = false
local holdingCtrl = false

local function eventLoop()
    while true do
        local event = {os.pullEvent()}
        if event[1] == "char" then
            if tonumber(event[2]) then
                local digit = event[2]
                if tonumber(rgbstr[chosenValue]..digit) < 255 then
                    rgbstr[chosenValue] = tostring(tonumber(rgbstr[chosenValue]..digit))
                else
                    rgbstr[chosenValue] = "255"
                end
            elseif event[2] == "s" then
                changePalette()
                saveFile()
            elseif event[2] == "q" then
                return
            end
        elseif event[1] == "key" then
            if event[2] == keys.backspace then
                rgbstr[chosenValue] = tostring(tonumber(rgbstr[chosenValue]:sub(1, #rgbstr[chosenValue]-1)))
                if rgbstr[chosenValue] == "nil" then
                    rgbstr[chosenValue] = "0"
                end
            elseif event[2] == keys.down and not holdingShift then
                chosenValue = math.min(chosenValue + 1, 3)
            elseif event[2] == keys.up and not holdingShift then
                chosenValue = math.max(chosenValue - 1, 1)
            elseif event[2] == keys.down and holdingShift then
                chosenColor = math.min(chosenColor + 1, 16)
                changeRGB()
            elseif event[2] == keys.up and holdingShift then
                chosenColor = math.max(chosenColor - 1, 1)
                changeRGB()
            elseif event[2] == keys.leftShift then
                holdingShift = true
            end
        elseif event[1] == "key_up" then
            if event[2] == keys.leftShift then
                holdingShift = false
            end
        end
        redraw()
    end
end

term.clear()
redraw()
eventLoop()

term.clear()
term.setCursorPos(1, 1)