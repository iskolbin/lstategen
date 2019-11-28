local function jsmn(prefix)
	return ([[
/*
 * MIT License
 *
 * Copyright (c) 2010 Serge Zaitsev
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
#ifndef JSMN_H
#define JSMN_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifdef JSMN_STATIC
#define JSMN_API static
#else
#define JSMN_API extern
#endif

/**
 * JSON type identifier. Basic types are:
 * 	o Object
 * 	o Array
 * 	o String
 * 	o Other primitive: number, boolean (true/false) or null
 */
typedef enum {
  JSMN_UNDEFINED = 0,
  JSMN_OBJECT = 1,
  JSMN_ARRAY = 2,
  JSMN_STRING = 3,
  JSMN_PRIMITIVE = 4
} jsmntype_t;

enum jsmnerr {
  /* Not enough tokens were provided */
  JSMN_ERROR_NOMEM = -1,
  /* Invalid character inside JSON string */
  JSMN_ERROR_INVAL = -2,
  /* The string is not a full JSON packet, more bytes expected */
  JSMN_ERROR_PART = -3
};

/**
 * JSON token description.
 * type		type (object, array, string etc.)
 * start	start position in JSON data string
 * end		end position in JSON data string
 */
typedef struct {
  jsmntype_t type;
  int start;
  int end;
  int size;
#ifdef JSMN_PARENT_LINKS
  int parent;
#endif
} jsmntok_t;

/**
 * JSON parser. Contains an array of token blocks available. Also stores
 * the string being parsed now and current position in that string.
 */
typedef struct {
  unsigned int pos;     /* offset in the JSON string */
  unsigned int toknext; /* next token to allocate */
  int toksuper;         /* superior token node, e.g. parent object or array */
} jsmn_parser;

/**
 * Create JSON parser over an array of tokens
 */
JSMN_API void jsmn_init(jsmn_parser *parser);

/**
 * Run JSON parser. It parses a JSON data string into and array of tokens, each
 * describing
 * a single JSON object.
 */
JSMN_API int jsmn_parse(jsmn_parser *parser, const char *js, const size_t len,
                        jsmntok_t *tokens, const unsigned int num_tokens);

#ifndef JSMN_HEADER
/**
 * Allocates a fresh unused token from the token pool.
 */
static jsmntok_t *jsmn_alloc_token(jsmn_parser *parser, jsmntok_t *tokens,
                                   const size_t num_tokens) {
  jsmntok_t *tok;
  if (parser->toknext >= num_tokens) {
    return NULL;
  }
  tok = &tokens[parser->toknext++];
  tok->start = tok->end = -1;
  tok->size = 0;
#ifdef JSMN_PARENT_LINKS
  tok->parent = -1;
#endif
  return tok;
}

/**
 * Fills token type and boundaries.
 */
static void jsmn_fill_token(jsmntok_t *token, const jsmntype_t type,
                            const int start, const int end) {
  token->type = type;
  token->start = start;
  token->end = end;
  token->size = 0;
}

/**
 * Fills next available token with JSON primitive.
 */
static int jsmn_parse_primitive(jsmn_parser *parser, const char *js,
                                const size_t len, jsmntok_t *tokens,
                                const size_t num_tokens) {
  jsmntok_t *token;
  int start;

  start = parser->pos;

  for (; parser->pos < len && js[parser->pos] != '\0'; parser->pos++) {
    switch (js[parser->pos]) {
#ifndef JSMN_STRICT
    /* In strict mode primitive must be followed by "," or "}" or "]" */
    case ':':
#endif
    case '\t':
    case '\r':
    case '\n':
    case ' ':
    case ',':
    case ']':
    case '}':
      goto found;
    default:
                   /* to quiet a warning from gcc*/
      break;
    }
    if (js[parser->pos] < 32 || js[parser->pos] >= 127) {
      parser->pos = start;
      return JSMN_ERROR_INVAL;
    }
  }
#ifdef JSMN_STRICT
  /* In strict mode primitive must be followed by a comma/object/array */
  parser->pos = start;
  return JSMN_ERROR_PART;
#endif

found:
  if (tokens == NULL) {
    parser->pos--;
    return 0;
  }
  token = jsmn_alloc_token(parser, tokens, num_tokens);
  if (token == NULL) {
    parser->pos = start;
    return JSMN_ERROR_NOMEM;
  }
  jsmn_fill_token(token, JSMN_PRIMITIVE, start, parser->pos);
#ifdef JSMN_PARENT_LINKS
  token->parent = parser->toksuper;
#endif
  parser->pos--;
  return 0;
}

/**
 * Fills next token with JSON string.
 */
static int jsmn_parse_string(jsmn_parser *parser, const char *js,
                             const size_t len, jsmntok_t *tokens,
                             const size_t num_tokens) {
  jsmntok_t *token;

  int start = parser->pos;

  parser->pos++;

  /* Skip starting quote */
  for (; parser->pos < len && js[parser->pos] != '\0'; parser->pos++) {
    char c = js[parser->pos];

    /* Quote: end of string */
    if (c == '\"') {
      if (tokens == NULL) {
        return 0;
      }
      token = jsmn_alloc_token(parser, tokens, num_tokens);
      if (token == NULL) {
        parser->pos = start;
        return JSMN_ERROR_NOMEM;
      }
      jsmn_fill_token(token, JSMN_STRING, start + 1, parser->pos);
#ifdef JSMN_PARENT_LINKS
      token->parent = parser->toksuper;
#endif
      return 0;
    }

    /* Backslash: Quoted symbol expected */
    if (c == '\\' && parser->pos + 1 < len) {
      int i;
      parser->pos++;
      switch (js[parser->pos]) {
      /* Allowed escaped symbols */
      case '\"':
      case '/':
      case '\\':
      case 'b':
      case 'f':
      case 'r':
      case 'n':
      case 't':
        break;
      /* Allows escaped symbol \uXXXX */
      case 'u':
        parser->pos++;
        for (i = 0; i < 4 && parser->pos < len && js[parser->pos] != '\0';
             i++) {
          /* If it isn't a hex character we have an error */
          if (!((js[parser->pos] >= 48 && js[parser->pos] <= 57) ||   /* 0-9 */
                (js[parser->pos] >= 65 && js[parser->pos] <= 70) ||   /* A-F */
                (js[parser->pos] >= 97 && js[parser->pos] <= 102))) { /* a-f */
            parser->pos = start;
            return JSMN_ERROR_INVAL;
          }
          parser->pos++;
        }
        parser->pos--;
        break;
      /* Unexpected symbol */
      default:
        parser->pos = start;
        return JSMN_ERROR_INVAL;
      }
    }
  }
  parser->pos = start;
  return JSMN_ERROR_PART;
}

/**
 * Parse JSON string and fill tokens.
 */
JSMN_API int jsmn_parse(jsmn_parser *parser, const char *js, const size_t len,
                        jsmntok_t *tokens, const unsigned int num_tokens) {
  int r;
  int i;
  jsmntok_t *token;
  int count = parser->toknext;

  for (; parser->pos < len && js[parser->pos] != '\0'; parser->pos++) {
    char c;
    jsmntype_t type;

    c = js[parser->pos];
    switch (c) {
    case '{':
    case '[':
      count++;
      if (tokens == NULL) {
        break;
      }
      token = jsmn_alloc_token(parser, tokens, num_tokens);
      if (token == NULL) {
        return JSMN_ERROR_NOMEM;
      }
      if (parser->toksuper != -1) {
        jsmntok_t *t = &tokens[parser->toksuper];
#ifdef JSMN_STRICT
        /* In strict mode an object or array can't become a key */
        if (t->type == JSMN_OBJECT) {
          return JSMN_ERROR_INVAL;
        }
#endif
        t->size++;
#ifdef JSMN_PARENT_LINKS
        token->parent = parser->toksuper;
#endif
      }
      token->type = (c == '{' ? JSMN_OBJECT : JSMN_ARRAY);
      token->start = parser->pos;
      parser->toksuper = parser->toknext - 1;
      break;
    case '}':
    case ']':
      if (tokens == NULL) {
        break;
      }
      type = (c == '}' ? JSMN_OBJECT : JSMN_ARRAY);
#ifdef JSMN_PARENT_LINKS
      if (parser->toknext < 1) {
        return JSMN_ERROR_INVAL;
      }
      token = &tokens[parser->toknext - 1];
      for (;;) {
        if (token->start != -1 && token->end == -1) {
          if (token->type != type) {
            return JSMN_ERROR_INVAL;
          }
          token->end = parser->pos + 1;
          parser->toksuper = token->parent;
          break;
        }
        if (token->parent == -1) {
          if (token->type != type || parser->toksuper == -1) {
            return JSMN_ERROR_INVAL;
          }
          break;
        }
        token = &tokens[token->parent];
      }
#else
      for (i = parser->toknext - 1; i >= 0; i--) {
        token = &tokens[i];
        if (token->start != -1 && token->end == -1) {
          if (token->type != type) {
            return JSMN_ERROR_INVAL;
          }
          parser->toksuper = -1;
          token->end = parser->pos + 1;
          break;
        }
      }
      /* Error if unmatched closing bracket */
      if (i == -1) {
        return JSMN_ERROR_INVAL;
      }
      for (; i >= 0; i--) {
        token = &tokens[i];
        if (token->start != -1 && token->end == -1) {
          parser->toksuper = i;
          break;
        }
      }
#endif
      break;
    case '\"':
      r = jsmn_parse_string(parser, js, len, tokens, num_tokens);
      if (r < 0) {
        return r;
      }
      count++;
      if (parser->toksuper != -1 && tokens != NULL) {
        tokens[parser->toksuper].size++;
      }
      break;
    case '\t':
    case '\r':
    case '\n':
    case ' ':
      break;
    case ':':
      parser->toksuper = parser->toknext - 1;
      break;
    case ',':
      if (tokens != NULL && parser->toksuper != -1 &&
          tokens[parser->toksuper].type != JSMN_ARRAY &&
          tokens[parser->toksuper].type != JSMN_OBJECT) {
#ifdef JSMN_PARENT_LINKS
        parser->toksuper = tokens[parser->toksuper].parent;
#else
        for (i = parser->toknext - 1; i >= 0; i--) {
          if (tokens[i].type == JSMN_ARRAY || tokens[i].type == JSMN_OBJECT) {
            if (tokens[i].start != -1 && tokens[i].end == -1) {
              parser->toksuper = i;
              break;
            }
          }
        }
#endif
      }
      break;
#ifdef JSMN_STRICT
    /* In strict mode primitives are: numbers and booleans */
    case '-':
    case '0':
    case '1':
    case '2':
    case '3':
    case '4':
    case '5':
    case '6':
    case '7':
    case '8':
    case '9':
    case 't':
    case 'f':
    case 'n':
      /* And they must not be keys of the object */
      if (tokens != NULL && parser->toksuper != -1) {
        const jsmntok_t *t = &tokens[parser->toksuper];
        if (t->type == JSMN_OBJECT ||
            (t->type == JSMN_STRING && t->size != 0)) {
          return JSMN_ERROR_INVAL;
        }
      }
#else
    /* In non-strict mode every unquoted value is a primitive */
    default:
#endif
      r = jsmn_parse_primitive(parser, js, len, tokens, num_tokens);
      if (r < 0) {
        return r;
      }
      count++;
      if (parser->toksuper != -1 && tokens != NULL) {
        tokens[parser->toksuper].size++;
      }
      break;

#ifdef JSMN_STRICT
    /* Unexpected char in strict mode */
    default:
      return JSMN_ERROR_INVAL;
#endif
    }
  }

  if (tokens != NULL) {
    for (i = parser->toknext - 1; i >= 0; i--) {
      /* Unmatched opened object or array */
      if (tokens[i].start != -1 && tokens[i].end == -1) {
        return JSMN_ERROR_PART;
      }
    }
  }

  return count;
}

/**
 * Creates a new parser based over a given buffer with an array of tokens
 * available.
 */
JSMN_API void jsmn_init(jsmn_parser *parser) {
  parser->pos = 0;
  parser->toknext = 0;
  parser->toksuper = -1;
}

#endif /* JSMN_HEADER */

#ifdef __cplusplus
}
#endif

#endif /* JSMN_H */
]]):gsub('JSMN_', prefix .. 'JSMN_'):gsub('jsmn', prefix .. 'jsmn')
end

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
	['${JSMN}'] = jsmn(PREFIX),
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
