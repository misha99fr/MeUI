local fs = require("filesystem")
if fs.exists("/TabletOS/UpdateCache/updater-binary") then
	local success, reason = pcall(dofile,"/TabletOS/UpdateCache/updater-binary")
	os.execute("rm -r /TabletOS/UpdateCache/updater-binary")
	os.execute("rm -r /TabletOS/UpdateCache/updater-script")
	os.execute("rm -r /TabletOS/UpdateCache")
	if not success then
		require("TabletOSCore").newNotification(10,"D","Update failed.",tostring(reason))
		--error(reason)
	else
		require("computer").shutdown(true)
	end
end

-- MeUI Recovery: если установлен флаг, загружаем recovery вместо обычной ОС.
-- Флаг удаляется ДО запуска recovery, чтобы случайный сбой не зациклил загрузку.
if fs.exists("/TabletOS/recovery.flag") then
	fs.remove("/TabletOS/recovery.flag")
	local f,r = loadfile("/TabletOS/Recovery/Main.lua")
	if f then
		xpcall(f,function(...)
			local str = ""
			for i = 1, #{...} do
				str = str .. " " .. ({...})[i]
			end
			io.write(str)
			if os.sleep then os.sleep(2) end
		end)
	end
	-- Если recovery завершился (например, перезагрузка не сработала) - продолжаем обычную загрузку.
end


local f,r = loadfile("/OS.lua")
if not f then error(r) end
xpcall(f,function(...)
	local str = ""
	for i = 1, #{...} do
		str = str .. " " .. ({...})[i]
	end
	io.write(str)
	if os.sleep then os.sleep(1) end
end)