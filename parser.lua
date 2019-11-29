local _ctx = {
	prefix = '',
	enumcounts = {},
	fieldscount = {},
	typedefs = {},
	isdeclared = {},
	isextern = {},
	defines = {},
}

function setprefix(prefix)
	_ctx.prefix = prefix
end

function isenum(typename)
	return _ctx.enumcounts[typename] ~= nil
end

function context()
	return _ctx
end

function declare(typename, t)
	_ctx.isdeclared[typename] = true
	_G[typename] = function(...)
		local arr, args, bitfield = {}, {...}, ''
		if args[1] == ':' then
			bitfield = ':' .. tonumber(args[2])
			args = {}
		else
			for i, v in ipairs(args) do
				arr[i] = '[' .. v .. ']'
			end
		end
		return function(name, indices)
			if name == '#' then
				return args
			elseif name == '@' then
				return typename
			elseif indices then
				return name .. (#indices > 0 and '[' .. table.concat(indices,'][') .. ']' or '')
			else
				return (t and t .. ' ' or '') .. typename .. ' ' .. name .. table.concat(arr) .. bitfield
			end
		end
	end
end

function declare_std()
	declare [[bool]]
	declare [[char]]
	declare [[int]]
	declare [[short]]
	declare [[long]]
	declare [[unsigned]]
	declare [[signed]]
	declare [[float]]
	declare [[double]]
	declare [[int8_t]]
	declare [[int16_t]]
	declare [[int32_t]]
	declare [[int64_t]]
	declare [[uint8_t]]
	declare [[uint16_t]]
	declare [[uint32_t]]
	declare [[uint64_t]]
end

function enumcount(name)
	return _ctx.enumcounts[name]
end

function enum(name)
	return function(t)
		local n = 0
		for k, v in pairs(t) do
			n = n + 1
			assert(type(k) == 'string', 'Enum key must my string')
			assert(type(v) == 'number', 'Enum value must by integer')
		end
		_ctx.enumcounts[name] = n
		_ctx.typedefs[#_ctx.typedefs+1] = {name, 'enum', t}
		declare(name, 'enum')
	end
end

function struct(name)
	if name == [[extern]] then
		return function(name_)
			_ctx.isextern[name_] = true
			return struct(name_)
		end
	else
		return function(t)
			local n = 0
			for k, v in pairs(t) do
				n = n + 1
				assert(type(k) == 'string', 'Struct field name must my string')
			end
			_ctx.fieldscount[name] = n
			_ctx.typedefs[#_ctx.typedefs+1] = {name, 'struct', t}
			declare(name, 'struct')
		end
	end
end

function define(t)
	for name, value in pairs(t) do
		_G[name] = name
		_ctx.defines[name] = type(value) == 'string' and '"' .. tostring(value) .. '"' or tostring(value)
	end
end
