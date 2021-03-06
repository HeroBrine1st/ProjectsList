local component = require("component")
local gpu = component.gpu
local internet = component.internet
local computer = require("computer")
local text = require("text")
local log1 = ""
local fs = require("filesystem")
local origError = error
local term = require("term")
local event = require("event")
local gpu = require("component").gpu
local theme = {back=0,fore=0xFFFFFF}
local w,h = gpu.getResolution()
local prorepties = {
	progressBarLength = 15,
	projectsListUrl = "https://raw.githubusercontent.com/HeroBrine1st/UniversalInstaller/master/projects.list",
}
local language
local languagePackages = {
	eu_EN = {
		full = "English",
		error1 = "Installer was crashed. Logs:",
		error2 = "Please send this logs to developer.",
		connecting = "CONNECTING",
		downloading = "DOWNLOADING",
		downloadDone = "Download done",
		av1 = "Avaliable to install:",
		av2 = "Write a number for install. Enter \"d\" before number for see description:",
		assembling = "Assembling filelist. Please wait.",
		startDownload = "Filelist assembling done. Starting download.",
		whatstreboot = "Success. Reboot now? [Y/N] "
	},
	eu_RU = {
		full = "Russian",
		error1 = "Установщик вылетел. Вот журнал событий:",
		error2 = "Отправьте этот журнал разработчику.",
		connecting   = "ПОДКЛЮЧЕНИЕ ",
		downloading  = "ЗАГРУЗКА    ",
		downloadDone = "Завершено   ",
		av1 = "Доступно для установки:",
		av2 = "Введите номер для установки. Добавьте \"d\" перед числом, что бы посмотреть описание.",
		assembling = "Собираю таблицу загрузки файлов. Пожалуйста, подождите.",
		startDownload = "Таблица загрузки файлов собрана. Начинаю загрузку.",
		whatstreboot = "Успешно. Перезагрузиться? [Y/N] ",
	}
}

print("Select language:")
local fgh = 0
local languages = {}
for key, value in pairs(languagePackages) do
	fgh = fgh + 1
	print(tostring(fgh) .. ") " .. value.full)
	table.insert(languages,key)
end
io.write("Write a number for select language:")
while not s do
	local str = io.read()
	if not str then os.exit() end
	local number = tonumber(str)
	if not number or number < 1 or number > #languages then
		io.write("\nInvalid input, try again:") 
	else
		language = languages[number]
		break
	end
end
fgh = nil
languages = nil

local w,h = gpu.getResolution()
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
local origPrint = print
function print(...)
	local x, y = term.getCursor()
	if y == h then
		gpu.copy(1,1,w,h-1,0,-1)
		term.setCursor(x,y-1)
		gpu.fill(1,h-1,w,1," ")
	end
	origPrint(...)
end

local function write(text)
  local _, y = term.getCursor()
  term.setCursor(1,y-1)
  print(text)
end

local function getBar(progress)
	progress = progress < 0 and 0 or progress
	progress = progress > 100 and 100 or progress
	local bar = ""
	local barCount = prorepties.progressBarLength/100*progress
	for i = 1, barCount do
		bar = bar .. prorepties.progressBarFull
	end
	bar = text.padRight(bar,prorepties.progressBarLength)
	return bar
end

local function shellProgressBar(file,progress)
	local text1 = ""
	if progress == -1 then 
		text1 = file .. ": 0%   " .. languagePackages[language].connecting
	elseif progress >= 0 and progress < 100 then
		text1 = file .. ": " .. text.padRight(tostring(progress) .. "%",4) .. " " .. languagePackages[language].downloading
	elseif progress == 100 then
		text1 = file .. ": 100% " .. languagePackages[language].downloadDone
	end
	write(text1)
	drawBar(progress/100,file)
end

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
	print(languagePackages[language].error1)
	print(log1)
	print(languagePackages[language].error2)
	print("\n\n\n\n")
	error = prevErr
	os.exit()
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
			local resCode, _, resData
			while not resCode do
				resCode, _, resData = reqH:response()
			end
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
				error("Content-Length header absent. Error code: ERR_HEADER_ABSENT")
			end
		else 
			error("Connection error: invalid URL address or server offline. Error code: ERR_NAME_NOT_RESOLVED")
		end
	else
		error(reqH)
	end
end

local projectsList = download(prorepties.projectsListUrl,"/tmp/projects.list",true)
local projects,reason = load("return " .. projectsList)
if not projects then error(reason) end
projectsList = projects()
writeLog("Request project for install")
print(languagePackages[language].av1)
for i = 1, #projectsList do
	print(tostring(i) .. ") " .. projectsList[i].name)
end
io.write(languagePackages[language].av2)
local s = false
local raw = ""
local scriptRaw
local versionToInstall
while not s do
	local str = io.read()
	if not str then os.exit() end
	local descView = false
	local number
	if str:sub(1,1) == "d" then
		descView = true
		number = tonumber(str:sub(2,-1))
	else
		number = tonumber(str)
	end
	if not number or number < 1 or number > #projectsList then
		io.write("\nInvalid input, try again:") 
	else
		if descView then
			print("Description:")
			print(projectsList[number].description[language])
			print(languagePackages[language].av2)
		else
			s = true
			raw = projectsList[number].raw
			scriptRaw = projectsList[number].script
		end
	end
end
writeLog("Request version for install")
local versionsList = download(raw,"/tmp/versions.list",true)
local versions, r = load("return " .. versionsList)
if not versions then error(r) end
versionsList = versions()
print(languagePackages[language].av1)
for i = 1, #versionsList do
	print(tostring(i) .. ") " .. versionsList[i].version .. ((i == #versionsList and not versionsList[i].exp) and " // LATEST STABLE" or (versionsList[i].exp and " // WIP" or "")))
end
io.write(languagePackages[language].av2)
local su = false
local versionNumber
while not su do
	local str = io.read()
	if not str then os.exit() end
	local descView = false
	local number
	if str:sub(1,1) == "d" then
		descView = true
		number = tonumber(str:sub(2,-1))
	else
		number = tonumber(str)
	end
	if not number or number < 1 or number > #versionsList then
		print("Invalid input, try again:") 
	else
		if descView then
			print("Description:")
			print(versionsList[number].description[language])
			io.write(languagePackages[language].av2)
		else
			su = true
			versionNumber = number
		end
	end
end
versionToInstall = versionsList[versionNumber].version
writeLog("Version selected. Assembling filelist.")
print(languagePackages[language].assembling)
local filelist = {}
for i = 1, versionNumber do
	local raw = versionsList[i].raw
	local buffer = download(raw,"/tmp/version" .. tostring(i) .. ".list",true)
	local f, r = load("return " .. buffer)
	if not f then error(r) end
	local list = f()
	for i = 1, #list do
		local filename = list[i].path
		for i = 1, #filelist do
			if filelist[i] and filelist[i].path == filename then
				table.remove(filelist,i)
			end
		end
		table.insert(filelist,list[i])
	end
end
print(languagePackages[language].startDownload)
for i = 1, #filelist do
	local path = filelist[i].path
	local url = filelist[i].url
	writeLog("Downloading " .. path .. " from " .. url)
	download(url,path)
end
if scriptRaw then
	print("")
	print("Processing script")
	local scriptCode = download(scriptRaw,"/tmp/script.lua",true)
	local scriptF, reason = load(scriptCode)
	if not scriptF then error(reason) end
	scriptF(tostring(versionToInstall),versionNumber)
end
gpu.fill(1,h,w,1," ")
print = origPrint
io.write(languagePackages[language].whatstreboot)
local str = io.read()
if str:sub(1,1):lower() == "y" then require("computer").shutdown(true) end 
