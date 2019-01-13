local component = require "component"
local computer = require "computer"
local fs = require "filesystem"
local event = require "event"
local unicode = require "unicode"
local term = require "term"
local gpu = component.gpu
local w,h = gpu.getResolution()
local options = {
    projectsListUrl = "https://raw.githubusercontent.com/HeroBrine1st/UniversalInstaller/master/projects.list",
}

local language
local languagePackages = {
    eu_EN = {
        full = "English",
        error1 = "Installer was crashed. Logs are in the file ? . Please send this logs to developer.",
        connecting = "CONNECTING",
        downloading = "DOWNLOADING",
        downloadDone = "Download done",
        av1 = "Avaliable to install:",
        av0 = "Write a number for install."
        av2 = "Write a number for install. Enter \"d\" before number for see description:",
        assembling = "Assembling filelist. Please wait.",
        startDownload = "Filelist assembling done. Starting download.",
        whatstreboot = "Success. Reboot now? [Y/N] "
    },
    eu_RU = {
        full = "Russian",
        error1 = "Установщик вылетел. Журнал событий находится в ? . Отправьте этот журнал разработчику.",
        connecting   = "ПОДКЛЮЧЕНИЕ ",
        downloading  = "ЗАГРУЗКА    ",
        downloadDone = "Завершено   ",
        av1 = "Доступно для установки:",
        av0 = "Введите номер для установки."
        av2 = "Введите номер для установки. Добавьте \"d\" перед числом, что бы посмотреть описание.",
        assembling = "Собираю таблицу загрузки файлов. Пожалуйста, подождите.",
        startDownload = "Таблица загрузки файлов собрана. Начинаю загрузку.",
        whatstreboot = "Успешно. Перезагрузиться? [Y/N] ",
    }
}

local log1 = ""
local function writeLog(text)
    log1 = log1 .. text .. "\n"
end
prevErr = error
error = function(reason,...)
    gpu.setBackground(0x000000)
    gpu.setForeground(0xFFFFFF)
    term.clear()
    io.write("\n")
    writeLog("[FATAL] " .. tostring(reason))
    local f = io.open("installerLogs.log","w")
    f:write?(log1)
    f:close()
    print(languagePackages[language].error1:gsub("?","installerLogs.log"))
    print("\n\n\n\n")
    error = prevErr
    os.exit()
end

local function drawBar(progress,filename)
    if progress < 0 then return end
    local str1 = text.padRight(tostring(tonumber(progress*100)).."%",4) .. " ["
    local str3 = "] " .. filename
    local progressLen = w-#str1-#str3
    local barLen = progressLen*progress
    gpu.set(1,h,str1)
    gpu.set(#str1+progressLen+1,h,str3)
    gpu.fill(#str1+1,h,progressLen,1,"⠠")
    gpu.fill(#str1+1,h,barLen,1,"⠶")
end

local function printIn(str,noWrap)
    local strTbl = string.wrap(str,w)
    local cursorX, cursorY = term.getCursor()
    for i = 1, #strTbl do
        local line = strTbl[i]
        gpu.set(cursorX,cursorY,line)
        cursorX = unicode.len(line) + 1
        if not noWrap then
            cursorY = cursorY + 1
            cursorX = 1
            if cursorY == h-1 then
                gpu.copy(1,1,w,h-1,0,-1)
                gpu.fill(1,cursor.y,1,1," ")
            end
        end
        term.setCursor(cursorX,cursorY)
    end
end

local function write(str)
    local x, y = term.getCursor()
    term.setCursor(1,y)
    term.clearLine()
    printIn(text)
end

local function shellProgressBar(file,progress,meta)
    local text1 = ""
    if progress == -1 then 
        text1 = file .. ": 0%   " .. languagePackages[language].connecting
        if meta then
            text1 = file .. ": 0%   " .. tostring(meta)
        end
    elseif progress >= 0 and progress < 100 then
        text1 = file .. ": " .. text.padRight(tostring(progress) .. "%",4) .. " " .. languagePackages[language].downloading
    elseif progress == 100 then
        text1 = file .. ": 100% " .. languagePackages[language].downloadDone
    end
    write(text1)
    drawBar(progress/100,file)
end

local function download(url,path,buff)
    print("")
    writeLog("Downloading " .. (buff and fs.name(path) or path) .. (buff and " to buffer" or ""))
    fs.remove(path)
    fs.makeDirectory(fs.path(path))
    local name = fs.name(path)
    local file, reason = io.open(path,"w")
    if not file then error("Error opening file for writing: " .. tostring(reason)) end
    shellProgressBar(name,-1)
    local success, reqH = pcall(internet.request,url)
    if success then
        if reqH then
            local resCode, resMsg, resData
            while not resCode do
                resCode, resMsg, resData = reqH:response()
            end
            shellProgressBar(file,-1,tostring(resCode) .. " " .. tostring(resMsg))
            if resData and resData["Content-Length"] then
                local contentLength = tonumber(resData["Content-Length"][1])
                local downloadedLength = 0
                local buffer = ""
                while downloadedLength < contentLength do
                    local data, reason = reqH.read()
                    if not data and reason then reqH.close() error("Error downloading file: " .. tostring(reason)) end 
                    downloadedLength = downloadedLength + #data
                    file:write(data)
                    shellProgressBar(name,math.floor(downloadedLength/contentLength*100+0.5))
                    if buff then buffer = buffer .. data end
                end
                reqH.close()
                file:close()
                --gpu.fill(1,h,w,1," ")
                if buff then return buffer end
            else
                error("Content-Length header absent.")
            end
        else 
            error("Connection error: invalid URL address or server offline.")
        end
    else
        error(reqH)
    end
end

printIn("Select language:")
local languages = {}
for key, value in pairs(languagePackages) do
    local langNum = #languages + 1
    printIn(tostring(langNum) .. ": " .. tostring(value.full))
    languages[langNum] = key
end
printIn("Write a number for select language:", true)
while not language do
    local str = io.read()
    if not str then printIn("Exiting") os.exit() end
    local num = tonumber(str)
    if num and num > 0 and num < #languages+! then
        language = languages[num]
    else
        printIn("")
        printIn("Invalid input, try again:", true)
    end
end
languages = nil

local projectsList = download(prorepties.projectsListUrl,"/tmp/projects.list",true)
local projects,reason = load("return " .. projectsList)
if not projects then error(reason) end
projectsList = projects()
writeLog("Request project for install")
print(languagePackages[language].av1)
for i = 1, #projectsList do
    print(tostring(i) .. ". " .. projectsList[i].name .. (projectsList[i].description and ": " .. projects[i].description[language]) or "")
end
io.write(languagePackages[language].av0)

local projectToInstall
while not projectToInstall do
    local str = io.read()
    if not str then os.exit() end
    number = tonumber(str)
    if not number or number < 1 or number > #projectsList then
        printIn("")
        printIn("Invalid input, try again:",true) 
    else
        projectToInstall = projectsList[number]
    end
end

