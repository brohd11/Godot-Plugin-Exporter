## Markdown to renderable blocks, plus inline markdown to BBCode.
##
## Pure and static - no engine state, no plugin coupling - so the whole thing is testable headless
## and portable as is. Block segmentation only splits out what a RichTextLabel cannot draw itself:
## fenced code, standalone images and rules. Everything else stays prose and becomes BBCode.

const TYPE_TEXT = "text"
const TYPE_CODE = "code"
const TYPE_IMAGE = "image"
const TYPE_RULE = "rule"

const KEY_TYPE = "type"
const KEY_TEXT = "text"
const KEY_LANG = "lang"
const KEY_SRC = "src"
const KEY_ALT = "alt"

## Heading size as a ratio of the host's base font size. Ratios rather than pixels so headings
## track the editor's font size and scale, which is where fixed-size markdown previews fall apart.
const HEADING_RATIOS:Array[float] = [1.7, 1.45, 1.25, 1.15, 1.05, 1.0]

## Control chars stand in for already-converted spans while the rest of the line is processed.
## Markdown source will not contain them, so they can never collide with real text.
static var _STASH_OPEN := String.chr(1)
static var _STASH_CLOSE := String.chr(2)

static var _re_cache:Dictionary = {}


## Splits [param text] into an ordered Array of block dictionaries, each keyed by KEY_TYPE.
static func parse(text:String) -> Array:
	var blocks:Array = []
	var prose:Array[String] = []
	var code:Array[String] = []
	var fence := ""
	var lang := ""

	for line in text.replace("\r\n", "\n").split("\n"):
		if fence != "":
			if _closes_fence(line, fence):
				blocks.append(_code_block(code, lang))
				code.clear()
				fence = ""
				lang = ""
			else:
				code.append(line)
			continue

		var opened = _fence_opened(line)
		if not opened.is_empty():
			_flush_prose(prose, blocks)
			fence = opened[0]
			lang = opened[1]
			continue

		# A setext underline retroactively turns the line above it into a heading, so it has to be
		# tested before the rule check - "---" is both.
		var setext = _setext_level(line)
		if setext != 0 and not prose.is_empty() and prose[-1].strip_edges() != "":
			prose[-1] = "#".repeat(setext) + " " + prose[-1].strip_edges()
			continue

		if _is_rule(line):
			_flush_prose(prose, blocks)
			blocks.append({KEY_TYPE:TYPE_RULE})
			continue

		var image = _image_only(line)
		if not image.is_empty():
			_flush_prose(prose, blocks)
			blocks.append(image)
			continue

		prose.append(line)

	# An unterminated fence renders as code rather than swallowing the rest of the doc.
	if fence != "":
		blocks.append(_code_block(code, lang))
	_flush_prose(prose, blocks)

	return blocks


## Converts a prose block to BBCode. [param base_font_size] is the host's font size, which heading
## sizes are derived from. Structural only - no colors, the renderer owns those.
static func to_bbcode(text:String, base_font_size:int) -> String:
	var out:Array[String] = []
	for line in text.split("\n"):
		out.append(_line_to_bbcode(line, base_font_size))
	return "\n".join(out)


## Font size for an ATX heading level 1-6, given the host's base size.
static func heading_size(level:int, base_font_size:int) -> int:
	var ratio:float = HEADING_RATIOS[clampi(level, 1, HEADING_RATIOS.size()) - 1]
	return maxi(1, roundi(base_font_size * ratio))


## The first "# " heading in [param text], else an empty string.
static func first_heading(text:String) -> String:
	for line in text.replace("\r\n", "\n").split("\n"):
		var match_result = _re(r"^\s{0,3}#{1,6}\s+(.+?)\s*#*\s*$").search(line)
		if match_result:
			return _strip_inline_markers(match_result.get_string(1))
	return ""


#region blocks

static func _code_block(code:Array[String], lang:String) -> Dictionary:
	return {KEY_TYPE:TYPE_CODE, KEY_LANG:lang, KEY_TEXT:"\n".join(code)}


static func _flush_prose(prose:Array[String], blocks:Array) -> void:
	while not prose.is_empty() and prose[0].strip_edges() == "":
		prose.remove_at(0)
	while not prose.is_empty() and prose[-1].strip_edges() == "":
		prose.remove_at(prose.size() - 1)
	if prose.is_empty():
		return
	blocks.append({KEY_TYPE:TYPE_TEXT, KEY_TEXT:"\n".join(prose)})
	prose.clear()


## The opening fence run and its info string, or an empty Array when the line opens no fence.
static func _fence_opened(line:String) -> Array:
	var match_result = _re(r"^\s{0,3}(`{3,}|~{3,})\s*([^`\s]*)").search(line)
	if not match_result:
		return []
	return [match_result.get_string(1), match_result.get_string(2).to_lower()]


## A closing fence has to be at least as long as the one that opened it and carry nothing else.
static func _closes_fence(line:String, fence:String) -> bool:
	var stripped = line.strip_edges()
	if not stripped.begins_with(fence):
		return false
	return stripped.lstrip(fence[0]) == ""


## Setext heading level for an underline row, or 0.
static func _setext_level(line:String) -> int:
	var stripped = line.strip_edges()
	if stripped == "":
		return 0
	if stripped.lstrip("=") == "":
		return 1
	if stripped.lstrip("-") == "":
		return 2
	return 0


static func _is_rule(line:String) -> bool:
	var stripped = line.strip_edges().replace(" ", "")
	if stripped.length() < 3:
		return false
	for c in ["-", "*", "_"]:
		if stripped.lstrip(c) == "":
			return true
	return false


## An image block, but only when the image is alone on its line - inline images stay inline.
static func _image_only(line:String) -> Dictionary:
	var match_result = _re(r'^\s*!\[([^\]]*)\]\(\s*([^)\s]+)(?:\s+"[^"]*")?\s*\)\s*$').search(line)
	if not match_result:
		return {}
	return {KEY_TYPE:TYPE_IMAGE, KEY_SRC:match_result.get_string(2), KEY_ALT:match_result.get_string(1)}

#endregion

#region inline

static func _line_to_bbcode(line:String, base_font_size:int) -> String:
	var heading = _re(r"^\s{0,3}(#{1,6})\s+(.*?)\s*#*\s*$").search(line)
	if heading:
		var level = heading.get_string(1).length()
		var body = _inline(heading.get_string(2))
		return "[font_size=%d][b]%s[/b][/font_size]" % [heading_size(level, base_font_size), body]

	var quote_depth := 0
	var rest := line
	while true:
		var quote = _re(r"^\s{0,3}>\s?").search(rest)
		if not quote:
			break
		quote_depth += 1
		rest = rest.substr(quote.get_end())

	var body := ""
	var list = _re(r"^(\s*)(?:([-*+])|(\d+)[.)])\s+(.*)$").search(rest)
	if list:
		var indent = _indent_level(list.get_string(1))
		var marker = "• " if list.get_string(2) != "" else list.get_string(3) + ". "
		body = "[indent]".repeat(indent + 1) + marker + _inline(list.get_string(4))
		body += "[/indent]".repeat(indent + 1)
	else:
		body = _inline(rest)

	if quote_depth > 0:
		body = "[indent]".repeat(quote_depth) + "[i]" + body + "[/i]" + "[/indent]".repeat(quote_depth)
	return body


## Two spaces or one tab per list level, the widths markdown writers actually use.
static func _indent_level(indent:String) -> int:
	var width := 0
	for c in indent:
		width += 4 if c == "\t" else 1
	return width / 2


static func _inline(text:String) -> String:
	var stash:Array[String] = []
	text = _stash_code_spans(text, stash)
	text = _stash_links(text, stash)
	# Everything that survives is literal, so its brackets must not read as BBCode.
	text = text.replace("[", "[lb]")
	text = _emphasis(text)
	return _unstash(text, stash)


static func _stash_push(stash:Array[String], value:String) -> String:
	stash.append(value)
	return _STASH_OPEN + str(stash.size() - 1) + _STASH_CLOSE


static func _unstash(text:String, stash:Array[String]) -> String:
	for i in range(stash.size()):
		text = text.replace(_STASH_OPEN + str(i) + _STASH_CLOSE, stash[i])
	return text


## Backtick spans are stashed whole - nothing inside a code span is markdown.
static func _stash_code_spans(text:String, stash:Array[String]) -> String:
	var out := ""
	var i := 0
	var length := text.length()
	while i < length:
		if text[i] != "`":
			out += text[i]
			i += 1
			continue
		var run := 0
		while i + run < length and text[i + run] == "`":
			run += 1
		var ticks = "`".repeat(run)
		var close = text.find(ticks, i + run)
		if close == -1:
			out += ticks
			i += run
			continue
		var body = text.substr(i + run, close - (i + run))
		out += _stash_push(stash, "[code]" + body.replace("[", "[lb]") + "[/code]")
		i = close + run
	return out


## Only the url tags are stashed, so link text still picks up emphasis.
static func _stash_links(text:String, stash:Array[String]) -> String:
	var out := ""
	var pos := 0
	var re = _re(r'(!?)\[([^\]]*)\]\(\s*([^)\s]+)(?:\s+"[^"]*")?\s*\)')
	while true:
		var match_result = re.search(text, pos)
		if not match_result:
			break
		out += text.substr(pos, match_result.get_start() - pos)
		var label = match_result.get_string(2)
		if match_result.get_string(1) == "!":
			# An inline image cannot be drawn in a text run, so its alt text stands in for it.
			out += label
		else:
			out += _stash_push(stash, "[url=%s]" % match_result.get_string(3))
			out += label
			out += _stash_push(stash, "[/url]")
		pos = match_result.get_end()
	return out + text.substr(pos)


static func _emphasis(text:String) -> String:
	text = _re(r"~~(.+?)~~").sub(text, "[s]$1[/s]", true)
	# Triple runs first, or the bold and italic passes split them into crossed tags.
	text = _re(r"\*\*\*(.+?)\*\*\*").sub(text, "[b][i]$1[/i][/b]", true)
	text = _re(r"\*\*(.+?)\*\*").sub(text, "[b]$1[/b]", true)
	text = _re(r"(?<![\w\\])__(.+?)__(?!\w)").sub(text, "[b]$1[/b]", true)
	text = _re(r"\*([^*\n]+)\*").sub(text, "[i]$1[/i]", true)
	# Word-boundary guarded, or every snake_case identifier in the prose turns italic.
	text = _re(r"(?<![\w\\])_([^_\n]+)_(?!\w)").sub(text, "[i]$1[/i]", true)
	return text


## Heading text with its inline markers removed, for titles and other plain-text uses.
static func _strip_inline_markers(text:String) -> String:
	text = _re(r"!?\[([^\]]*)\]\([^)]*\)").sub(text, "$1", true)
	text = text.replace("**", "").replace("__", "").replace("`", "")
	return text.strip_edges()


static func _re(pattern:String) -> RegEx:
	var re = _re_cache.get(pattern)
	if re == null:
		re = RegEx.create_from_string(pattern)
		_re_cache[pattern] = re
	return re

#endregion
