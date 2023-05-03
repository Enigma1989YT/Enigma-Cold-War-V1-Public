--load hooks in ECW directory

local ecwDir = lfs.writedir() .. "Missions\\ECW\\hooks\\"

for file in lfs.dir(ecwDir) do
	if file ~= "." and file ~= ".." then
		local f = path..'/'..file
		dofile(f)
	end
end
