local _ctx = context()

local PREFIX = _ctx.prefix .. '_SERIALIZE_' 
local INDICES = {'i','j','k','i1','j1','k1','i2','j2','k2'}
local SERIALIZERS = {
	bool = 'fprintf(f, "%%s", %s ? "true" : "false");',
	char = 'fprintf(f, "%%c", %s);',
	int = 'fprintf(f, "%%d", %s);',
	short = 'fprintf(f, "%%ld", %s);',
	long = 'fprintf(f, "%%ld", %s);',
	signed = 'fprintf(f, "%%d", %s);',
	unsigned = 'fprintf(f, "%%u", %s);',
	float = 'fprintf(f, "%%g", %s);',
	double = 'fprintf(f, "%%g", %s);',
	int8_t = 'fprintf(f, "%%" PRId8, %s);',
	int16_t = 'fprintf(f, "%%" PRId16, %s);',
	int32_t = 'fprintf(f, "%%" PRId32, %s);',
	int64_t = 'fprintf(f, "%%" PRId64, %s);',
	uint8_t = 'fprintf(f, "%%" PRIdu8, %s);',
	uint16_t = 'fprintf(f, "%%" PRIu16, %s);',
	uint32_t = 'fprintf(f, "%%" PRIu32, %s);',
	uint64_t = 'fprintf(f, "%%" PRIu64, %s);',
}
local INDENT = '  '

print[[
/* Generated by serialize.lua, do not edit by hand */

#include <inttypes.h>
#include <stdio.h>
#include <stdbool.h>
]]

for _, name_t_members in ipairs(_ctx.typedefs) do
	local name, t, members = table.unpack(name_t_members)
	if t == 'struct' then
		print('void ' .. PREFIX .. name .. '(FILE *f, struct ' .. name .. ' *self) {')
		print(INDENT .. 'bool isdefault, isfirst = true; char *data;')
		print(INDENT .. 'fprintf(f, \"{\");')
		for _, name_type in ipairs(members) do
			local k, field_type = next(name_type)
			local indices = {}
			local limits = field_type'#'
			local typename = field_type'@'
			print(INDENT .. 'isdefault = true; data = (char *)&self->' .. k .. ';')
			print(INDENT .. 'for (int i = 0; i < sizeof(self->' .. k .. '); i++) {')
			print(INDENT:rep(2) .. 'if (data[i] != 0) {isdefault = false; break;}')
			print(INDENT .. '}') 
			print(INDENT .. 'if (!isdefault) {')
			print(INDENT:rep(2) .. 'if (!isfirst) fprintf(f, ","); else isfirst = false;')
			print(INDENT:rep(2) .. 'fprintf(f, "\\\"' .. k .. '\\\":");')
			for i, limit in ipairs(limits) do
				local index = INDICES[i]
				if typename == 'char' and i == #limits then
					print(INDENT:rep(i+1) .. 'fprintf(f, "\\\"%s\\\"", self->' .. field_type(k, indices) .. ');')
				else
					indices[i] = index
					print(INDENT:rep(i+1) .. 'fprintf(f, "[");')
					print(INDENT:rep(i+1) .. 'for(int ' .. index .. ' = 0; ' .. index .. ' < ' .. limits[i] .. '; ' .. index .. '++) {')
				end
			end

			if typename ~= 'char' then
				local itemname = 'self->' .. field_type(k, indices)
				local serializer = SERIALIZERS[typename]
				if serializer then
					print(INDENT:rep(#limits+2) .. serializer:format(itemname))
				elseif isenum(typename) then
					print(INDENT:rep(#limits+2) .. SERIALIZERS.int:format(itemname))
				else
					print(INDENT:rep(#limits+2) .. PREFIX .. typename .. '(f, &' .. itemname .. ');')
				end
			end

			for i = #limits, 1, -1 do
				if typename ~= 'char' or i ~= #limits then
					print(INDENT:rep(i+2) .. 'if (' .. INDICES[i] .. ' < ' .. limits[i] .. '-1) fprintf(f, ",");' )
					print(INDENT:rep(i+1) .. '}')
					print(INDENT:rep(i+1) .. 'fprintf(f, "]");')
				end
			end

			print(INDENT .. '};')
		end
		print(INDENT .. 'fprintf(f, "}");')
		print('}')
		print()
	end
end
