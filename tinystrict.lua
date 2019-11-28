setmetatable(_G, {__index = function(_, k)
	error(('Using undefined global variable %q'):format(k))
end})
