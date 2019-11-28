require('parser')

local _ctx = context()

local PREFIX = _ctx.prefix ..'_DESERIALIZE_'
local INDICES = {'i','j','k','i1','j1','k1','i2','j2','k2'}
local CONTEXT = 'struct ' .. PREFIX .. 'Context'
local INDENT = '  '
local DESERIALIZERS = {
	bool = '%s = strncmp(ctx->str + ctx->t[ctx->index].start, "true", 4) == 0;',
	char = '%s = strtol(ctx->str + ctx->t[ctx->index].start, NULL, 0);',
	int = '%s = strtol(ctx->str + ctx->t[ctx->index].start, NULL, 0);',
	float = '%s = strtod(ctx->str + ctx->t[ctx->index].start, 0);',
	double = '%s = strtod(ctx->str + ctx->t[ctx->index].start, 0);',
	int8_t = '%s = strtol(ctx->str + ctx->t[ctx->index].start, NULL, 0);',
	int16_t = '%s = strtol(ctx->str + ctx->t[ctx->index].start, NULL, 0);',
	int32_t = '%s = strtol(ctx->str + ctx->t[ctx->index].start, NULL, 0);',
	int64_t = '%s = strtol(ctx->str + ctx->t[ctx->index].start, NULL, 0);',
	uint8_t = '%s = strtoul(ctx->str + ctx->t[ctx->index].start, NULL, 0);',
	uint16_t = '%s = strtoul(ctx->str + ctx->t[ctx->index].start, NULL, 0);',
	uint32_t = '%s = strtoul(ctx->str + ctx->t[ctx->index].start, NULL, 0);',
	uint64_t = '%s = strtoul(ctx->str + ctx->t[ctx->index].start, NULL, 0);',
}

print((([[
/* Generated by deserialize.lua, do not edit by hand */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <stdbool.h>

#define ${PREFIX}JSMN_IMPLEMENTATION
#define ${PREFIX}JSMN_STATIC
#define ${PREFIX}JSMN_PARENT_LINKS
${JSMN}

enum ${PREFIX}Status {
  ${PREFIX}OK = 0,
  ${PREFIX}ERROR_READING_FILE = 1,
  ${PREFIX}BAD_ALLOCATION = 2,
  ${PREFIX}PARSING_ERROR = 3,
  ${PREFIX}WRONG_FIELD_TYPE = 4,
};

${CONTEXT} {
  ${PREFIX}jsmntok_t *t;
  int index;
  size_t ntokens;
  size_t nallocated;
  char *str;
	int parsing_error;
};

enum ${PREFIX}Status ${PREFIX}Load(FILE *f, ${CONTEXT} *ctx) {
	${PREFIX}jsmn_parser p;
	${PREFIX}jsmn_init(&p);
  if (!f) return ${PREFIX}ERROR_READING_FILE;
	int nallocated = 1;
  fseek(f, 0, SEEK_END);
  long fsize = ftell(f);
  fseek(f, 0, SEEK_SET);
  char *str = malloc(fsize + 1);
  if (!str) {
    return ${PREFIX}BAD_ALLOCATION;
  }
  size_t fresult = fread(str, 1, fsize, f);
  if (fresult != fsize) {
    free(str);
    return ${PREFIX}ERROR_READING_FILE;
  }
  str[fsize] = '\0';
  for (int i = 0; i < fsize; i++) {
    if (str[i] == ',' || str[i] == '[' || str[i] == '{' || str[i] == ':') {
      nallocated++;
    }
  }
	${PREFIX}jsmntok_t *t= malloc(nallocated * sizeof(${PREFIX}jsmntok_t));
  if (!t) {
    free(str);
    return ${PREFIX}BAD_ALLOCATION;
  }
  int ntokens = ${PREFIX}jsmn_parse(&p, str, fsize, t, nallocated);
  if (ntokens < 0) {
    ctx->parsing_error = ntokens;
    free(str);
    free(t);
    return ${PREFIX}PARSING_ERROR;
  }
  ctx->t = t;
	ctx->ntokens = ntokens;
  ctx->nallocated = nallocated;
  ctx->str = str;
	ctx->parsing_error = 0;
  return ${PREFIX}OK;
}

void ${PREFIX}Unload(${CONTEXT} *ctx) {
  free(ctx->t);
  free(ctx->str);
  ctx->t = NULL;
  ctx->str = NULL;
  ctx->index = 0;
  ctx->ntokens = 0;
	ctx->nallocated = 0;
}

static int ${PREFIX}StringEqual(const char *json, ${PREFIX}jsmntok_t *tok, const char *s) {
  int n = tok->end - tok->start;
  if (tok->type == ${PREFIX}JSMN_STRING && (int)strlen(s) == n && strncmp(json + tok->start, s, n) == 0) {
    return 0;
  }
  return -1;
}

static void ${PREFIX}IgnoreValue(${CONTEXT} *ctx) {
#ifdef ${PREFIX}DEBUG
  TraceLog(LOG_INFO, "Ignoring %d %d %.*s", ctx->index, ctx->t[ctx->index].type, ctx->t[ctx->index].end - ctx->t[ctx->index].start, ctx->str + ctx->t[ctx->index].start);
#endif
  int size;
  switch (ctx->t[++ctx->index].type) {
    case ${PREFIX}JSMN_UNDEFINED:
    case ${PREFIX}JSMN_STRING:
    case ${PREFIX}JSMN_PRIMITIVE:
      break;
    case ${PREFIX}JSMN_OBJECT:
      size = ctx->t[ctx->index].size;
      for (int i = 0; i < size; i++) {
        ++ctx->index;
        ${PREFIX}IgnoreValue(ctx);
      }
      break;
    case ${PREFIX}JSMN_ARRAY:
      size = ctx->t[ctx->index].size;
      for (int i = 0; i < size; i++) {
        ${PREFIX}IgnoreValue(ctx);
      }
      break;
  }
}
]]):gsub('%$%{[%w_]-%}', {
	['${JSMN}'] = require('jsmn')(PREFIX),
	['${PREFIX}'] = PREFIX,
	['${CONTEXT}'] = CONTEXT,
})))

for _, name_t_members in ipairs(_ctx.typedefs) do
	local name, t, members = table.unpack(name_t_members)
	if t == 'struct' then
		local keys = {}
		local shift = ''
		for k in pairs(members) do
			keys[#keys+1] = k
		end
		table.sort(keys)
		print('int ' .. PREFIX .. name .. '(' .. CONTEXT .. ' *ctx, struct ' .. name .. ' *self) {')
		print('#ifdef ' .. PREFIX .. 'DEBUG')
		print(INDENT .. 'TraceLog(LOG_INFO, "%d %d %.*s", ctx->index, ctx->t[ctx->index].type, ctx->t[ctx->index].end - ctx->t[ctx->index].start, ctx->str + ctx->t[ctx->index].start);')
		print('#endif')
		print(INDENT:rep(1) .. 'if (ctx->t[ctx->index].type != ' .. PREFIX .. 'JSMN_OBJECT) return ' .. PREFIX .. 'WRONG_FIELD_TYPE;')
		print(INDENT:rep(1) .. 'int nkeys = ctx->t[ctx->index].size;')
		print(INDENT:rep(1) .. 'for (int i = 0; i < nkeys; i++) {')
		print(INDENT:rep(2) .. 'int keyindex = ++ctx->index;')
		for i, k in ipairs(keys) do 
			print(INDENT:rep(2) .. 'if (' .. PREFIX .. 'StringEqual(ctx->str, &ctx->t[keyindex], "' .. k ..'") == 0) {')
			local limits = members[k]'#'
			local typename = members[k]'@'
			local indices = {}

			for i, limit in ipairs(limits) do
				local index = INDICES[i]
				print(INDENT:rep(i+2) .. 'int max_t_' .. index .. ' = ctx->t[++ctx->index].size;')
				print(INDENT:rep(i+2) .. 'int max_' .. index .. ' = max_t_' .. index .. ' < ' .. limits[i] .. ' ? max_t_' .. index .. ' : ' .. limits[i] .. ';')
				if typename == 'char' and i == #limits then
					print(INDENT:rep(i+2) .. 'if (ctx->t[ctx->index].type == ' .. PREFIX .. 'JSMN_STRING) {')
					print(INDENT:rep(i+3) .. 'max_' .. index .. ' = ctx->t[ctx->index].end - ctx->t[ctx->index].start;')
					print(INDENT:rep(i+3) .. 'if (max_' .. index .. ' > ' .. limits[i] ..' - 1) max_' .. index .. ' = ' .. limits[i] .. ' - 1;')
					print(INDENT:rep(i+3) .. 'strncpy(self->' .. members[k](k, indices) ..', ctx->str + ctx->t[ctx->index].start, max_' .. index .. ');')
					print(INDENT:rep(i+2) .. '} else return ' .. PREFIX .. 'WRONG_FIELD_TYPE;')
				else
					indices[i] = index
					print(INDENT:rep(i+2) .. 'if (ctx->t[ctx->index].type != ' .. PREFIX .. 'JSMN_ARRAY) return ' .. PREFIX .. 'WRONG_FIELD_TYPE;')
					print(INDENT:rep(i+2) .. 'for(int ' .. index .. ' = 0; ' .. index .. ' < max_' .. index .. '; ' .. index .. '++) {')
				end
			end

			if typename ~= 'char' then
				local indent = INDENT:rep(#limits+3)
				local itemname = 'self->' .. members[k](k, indices)
				local deserializer = DESERIALIZERS[typename]
				print(indent .. 'ctx->index++;')
				if deserializer then
					print(indent .. deserializer:format(itemname))
				elseif isenum(typename) then
					print(indent .. DESERIALIZERS.int:format(itemname))
				else
					print(indent .. 'if (' .. PREFIX .. typename .. '(ctx, &' .. itemname .. ') != 0) return ' .. PREFIX .. 'WRONG_FIELD_TYPE;')
				end
			end

			for i = #limits, 1, -1 do
				if typename ~= 'char' or i ~= #limits then
					local index = INDICES[i]
					print(INDENT:rep(i+2) .. '}')
					print(INDENT:rep(i+2) .. 'for (int ' .. index .. ' = max_' .. index .. '; ' .. index .. ' < max_t_' .. index .. '; ' .. index .. '++) ctx->index++;')
				end
			end

			print(INDENT:rep(2) .. '} else')
		end
		print(INDENT:rep(2) .. PREFIX .. 'IgnoreValue(ctx);')
		print(INDENT .. '}')
		print(INDENT .. 'return 0;')
		print('}')
		print()
	end
end