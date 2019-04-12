local std = require("std")
local epnf = require("epnf")
local textcase = SILE.require("packages/textcase").exports

---------------------
--- BibTex Parser ---
---------------------

-- This parser is probably not complete, see
-- http://www.bibtex.org/Format/
-- http://www.fb10.uni-bremen.de/anglistik/langpro/bibliographies/jacobsen-bibtex.html
-- http://www.thefullwiki.org/BibTeX
-- for further details about the format

local ID = lpeg.C((SILE.parserBits.letter + SILE.parserBits.digit) ^ 1)
local identifier = (ID + lpeg.S(":-")) ^ 1

local balanced = lpeg.C { "{" * lpeg.P(" ") ^ 0 * lpeg.C(((1 - lpeg.S "{}") + lpeg.V(1)) ^ 0) * "}" } / function(...)
    t = { ... };
    return t[2]
end
local doubleq = lpeg.C(lpeg.P '"' * lpeg.C(((1 - lpeg.S '"\r\n\f\\') + (lpeg.P '\\' * 1)) ^ 0) * '"')

local bibtexparser = epnf.define(function(_ENV)
    local _ = WS ^ 0
    local sep = lpeg.S(",;") * _
    local myID = C(identifier + lpeg.P(1)) / function(t)
        return t
    end
    local value = balanced + doubleq + myID
    local pair = lpeg.Cg(myID * _ * "=" * _ * C(value)) * _ * sep ^ -1 / function(...)
        local t = { ... };
        return t[1], t[#t]
    end
    local list = lpeg.Cf(lpeg.Ct("") * pair ^ 0, rawset)

    START "document"
    document = (V "entry" + V "comment") ^ 1 * (-1 + E("Unexpected character at end of input"))
    comment = WS +
            (V "blockcomment" + (P("%") * (1 - lpeg.S("\r\n")) ^ 0 * lpeg.S("\r\n")) / function()
                return ""
            end) -- Don't bother telling me about comments
    blockcomment = P("@comment") + balanced / function()
        return ""
    end -- Don't bother telling me about comments
    entry = Ct(P("@") * Cg(myID, "type") * _ * P("{") * _ * Cg(myID, "label") * _ * sep * list * P("}") * _)
end)

--- Specifies which BibTex entries are recognized and which tags they should have.
--- Also specifies fallback types, when the reference style does not support some type.
--- Based on https://en.wikipedia.org/wiki/BibTeX
BibTexEntries = {
    --- An article from a journal or magazine.
    article = {
        required = { "author", "title", "journal", "year", "volume" },
        optional = { "number", "pages", "month", "doi", "note", "key" },
        fallback = "misc"
    },

    --- A book with an explicit publisher.
    book = {
        required = { {"author", "editor"}, "title", "publisher", "year" },
        optional = { {"volume", "number"}, "series", "address", "edition", "month", "note", "key", "url" },
        fallback = "misc"
    },

    --- A work that is printed and bound, but without a named publisher or sponsoring institution.
    booklet = {
        required = { "title" },
        optional = { "author", "howpublished", "address", "month", "year", "note", "key" },
        fallback = "inbook"
    },

    --- The same as inproceedings, included for Scribe compatibility.
    conference = {},

    --- A part of a book, usually untitled. May be a chapter (or section, etc.) and/or a range of pages.
    inbook = {
        required = { {"author", "editor"}, "title", {"chapter", "pages"}, "publisher", "year" },
        optional = { {"volume", "number"}, "series", "type", "address", "edition", "month", "note", "key" },
        fallback = "misc"
    },

    --- A part of a book having its own title.
    incollection = {
        required = { "author", "title", "booktitle", "publisher", "year" },
        optional = { "editor", {"volume", "number"}, "series", "type", "chapter", "pages", "address", "edition", "month", "note", "key" },
        fallback = "misc"
    },

    --- An article in a conference proceedings.
    inproceedings = {
        required = { "author", "title", "booktitle", "year" },
        optional = { "editor", {"volume", "number"}, "series", "pages", "address", "month", "organization", "publisher", "note", "key" },
        fallback = "incollection"
    },

    --- Technical documentation.
    manual = {
        required = { "title" },
        optional = { "author", "organization", "address", "edition", "month", "year", "note", "key" },
        fallback = "book"
    },

    --- A Master's thesis.
    mastersthesis = {
        required = { "author", "title", "school", "year" },
        optional = { "type", "address", "month", "note", "key" },
        fallback = "thesis"
    },

    --- For use when nothing else fits.
    misc = {
        required = {},
        optional = { "author", "title", "howpublished", "month", "year", "note", "key" },
        fallback = "book"
    },

    --- A Ph.D. thesis.
    phdthesis = {
        required = { "author", "title", "school", "year" },
        optional = { "type", "address", "month", "note", "key" },
        fallback = "thesis"
    },

    --- The proceedings of a conference.
    proceedings = {
        required = { "title", "year" },
        optional = { "editor", {"volume", "number"}, "series", "address", "month", "publisher", "organization", "note", "key" },
        fallback = "collection"
    },

    --- A report published by a school or other institution, usually numbered within a series.
    techreport = {
        required = { "author", "title", "institution", "year" },
        optional = { "type", "number", "address", "month", "note", "key" },
        fallback = "report"
    },

    --- A document having an author and title, but not formally published.
    unpublished = {
        required = { "author", "title", "note" },
        optional = { "month", "year", "key" },
        fallback = "book"
    },

    -- Roughly based on https://github.com/michal-h21/biblatex-iso690
    bookinbook = { fallback = "inbook" },
    suppbook = { fallback = "inbook" },
    collection = { fallback = "book" },
    suppcollection = { fallback = "incollection" },
    suppperiodical = { fallback = "article" },
    reference = { fallback = "collection" },
    inreference = { fallback = "incollection" },
    report = { fallback = "thesis" }
}
BibTexEntries.conference = BibTexEntries.inproceedings

--- Parse BibTex from given string
local function parseBibtex(content)
    local t = epnf.parsestring(bibtexparser, content)
    if not (t) or not (t[1]) or t.id ~= "document" then
        SU.error("Error parsing bibtex")
    end

    local entries = {}
    for i = 1, #t do
        if t[i].id == "entry" then
            local ent = t[i][1]

            local attribs = {}
            for k, v in pairs(ent[1]) do
                attribs[string.lower(k)] = v
            end

            entries[ent.label] = { type = ent.type, attributes = attribs }
        end
    end
    return entries
end

--------------------------------
--- Name parsing & splitting ---
--------------------------------

-- The following functions borrowed from Norman Ramsey's nbibtex, with permission.
-- https://www.cs.tufts.edu/~nr/nbibtex/

local function find_outside_braces(s, pat, i)
    local len = string.len(s)
    local j, k = string.find(s, pat, i)
    if not j then
        return j, k
    end
    local jb, kb = string.find(s, '%b{}', i)
    while jb and jb < j do
        --- scan past braces
        --- braces come first, so we search again after close brace
        local i2 = kb + 1
        j, k = string.find(s, pat, i2)
        if not j then
            return j, k
        end
        jb, kb = string.find(s, '%b{}', i2)
    end
    -- either pat precedes braces or there are no braces
    return string.find(s, pat, j) --- 2nd call needed to get captures
end

local function split(s, pat, find)
    --- return list of substrings separated by pat
    find = find or string.find -- could be find_outside_braces
    local len = string.len(s)
    local t = { }
    local insert = table.insert
    local i, j, k = 1, true
    while j and i <= len + 1 do
        j, k = string.find(s, pat, i)
        if j then
            insert(t, string.sub(s, i, j - 1))
            i = k + 1
        else
            insert(t, string.sub(s, i))
        end
    end
    return t
end

local function splitters(s, pat, find)
    --- return list of separators
    find = find or string.find -- could be find_outside_braces
    local t = { }
    local insert = table.insert
    local j, k = string.find(s, pat, 1)
    while j do
        insert(t, string.sub(s, j, k))
        j, k = string.find(s, pat, k + 1)
    end
    return t
end

local function namesplit(s)
    local t = split(s, '%s+[aA][nN][dD]%s+', find_outside_braces)
    local i = 2
    while i <= #t do
        while string.find(t[i], '^[aA][nN][dD]%s+') do
            t[i] = string.gsub(t[i], '^[aA][nN][dD]%s+', '')
            table.insert(t, i, '')
            i = i + 1
        end
        i = i + 1
    end
    return t
end

local sep_and_not_tie = '%-'
local sep_chars = sep_and_not_tie .. '%~'

local parse_name
do
    local white_sep = '[' .. sep_chars .. '%s]+'
    local white_comma_sep = '[' .. sep_chars .. '%s%,]+'
    local trailing_commas = '(,[' .. sep_chars .. '%s%,]*)$'
    local sep_char = '[' .. sep_chars .. ']'
    local leading_white_sep = '^' .. white_sep

    -- <name-parsing utilities>=
    function isVon(s)
        local lower = find_outside_braces(s, '%l') -- first nonbrace lowercase
        local letter = find_outside_braces(s, '%a') -- first nonbrace letter
        local bs, ebs, command = find_outside_braces(s, '%{%\\(%a+)') -- \xxx
        if lower and lower <= letter and lower <= (bs or lower) then
            return true
        elseif letter and letter <= (bs or letter) then
            return false
        elseif bs then
            if upper_specials[command] then
                return false
            elseif lower_specials[command] then
                return true
            else
                local close_brace = find_outside_braces(s, '%}', ebs + 1)
                lower = string.find(s, '%l') -- first nonbrace lowercase
                letter = string.find(s, '%a') -- first nonbrace letter
                return lower and lower <= letter
            end
        else
            return false
        end
    end

    -- Function [[text_char_count]] counts characters, but a
    -- special counts as one character. It is based on
    -- BibTeX's [[text.length]] function.
    function text_char_count(s)
        local n = 0
        local i, last = 1, string.len(s)
        while i <= last do
            local special, splast, sp = string.find(s, '(%b{})', i)
            if not special then
                return n + (last - i + 1)
            elseif string.find(sp, '^{\\') then
                n = n + (special - i + 1) -- by statute, it's a single character
                i = splast + 1
            else
                n = n + (splast - i + 1) - 2  -- don't count braces
                i = splast + 1
            end
        end
        return n
    end

    function parse_name(s, inter_token)
        if string.find(s, trailing_commas) then
            SU.error("Name '"..s.."' has one or more commas at the end")
        end
        s = string.gsub(s, trailing_commas, '')
        s = string.gsub(s, leading_white_sep, '')
        local tokens = split(s, white_comma_sep, find_outside_braces)
        local trailers = splitters(s, white_comma_sep, find_outside_braces)
        -- The string separating tokens is reduced to a single
        -- ``separator character.'' A comma always trumps other
        -- separator characters. Otherwise, if there's no comma,
        -- we take the first character, be it a separator or a
        -- space. (Patashnik considers that multiple such
        -- characters constitute ``silliness'' on the user's
        -- part.)
        -- <rewrite [[trailers]] to hold a single separator character each>=
        for i = 1, #trailers do
            local s = trailers[i]
            assert(string.len(s) > 0)
            if string.find(s, ',') then
                trailers[i] = ','
            else
                trailers[i] = string.sub(s, 1, 1)
            end
        end
        local commas = { } --- maps each comma to index of token the follows it
        for i, t in ipairs(trailers) do
            string.gsub(t, ',', function()
                table.insert(commas, i + 1)
            end)
        end
        local name = { }
        -- A name has up to four parts: the most general form is
        -- either ``First von Last, Junior'' or ``von Last,
        -- First, Junior'', but various vons and Juniors can be
        -- omitted. The name-parsing algorithm is baroque and is
        -- transliterated from the original BibTeX source, but
        -- the principle is clear: assign the full version of
        -- each part to the four fields [[ff]], [[vv]], [[ll]],
        -- and [[jj]]; and assign an abbreviated version of each
        -- part to the fields [[f]], [[v]], [[l]], and [[j]].
        -- <parse the name tokens and set fields of [[name]]>=
        local first_start, first_lim, last_lim, von_start, von_lim, jr_lim
        -- variables mark subsequences; if start == lim, sequence is empty
        local n = #tokens
        -- The von name, if any, goes from the first von token to
        -- the last von token, except the last name is entitled
        -- to at least one token. So to find the limit of the von
        -- name, we start just before the last token and wind
        -- down until we find a von token or we hit the von start
        -- (in which latter case there is no von name).
        -- <local parsing functions>=
        function divide_von_from_last()
            von_lim = last_lim - 1
            while von_lim > von_start and not isVon(tokens[von_lim - 1]) do
                von_lim = von_lim - 1
            end
        end

        local commacount = #commas
        if commacount == 0 then
            -- first von last jr
            von_start, first_start, last_lim, jr_lim = 1, 1, n + 1, n + 1
            -- OK, here's one form.
            --
            -- <parse first von last jr>=
            local got_von = false
            while von_start < last_lim - 1 do
                if isVon(tokens[von_start]) then
                    divide_von_from_last()
                    got_von = true
                    break
                else
                    von_start = von_start + 1
                end
            end
            if not got_von then
                -- there is no von name
                while von_start > 1 and string.find(trailers[von_start - 1], sep_and_not_tie) do
                    von_start = von_start - 1
                end
                von_lim = von_start
            end
            first_lim = von_start
        elseif commacount == 1 then
            -- von last jr, first
            von_start, last_lim, jr_lim, first_start, first_lim = 1, commas[1], commas[1], commas[1], n + 1
            divide_von_from_last()
        elseif commacount == 2 then
            -- von last, jr, first
            von_start, last_lim, jr_lim, first_start, first_lim = 1, commas[1], commas[2], commas[2], n + 1
            divide_von_from_last()
        else
            SU.error("Too many commas in name '"..s.."'")
        end
        -- <set fields of name based on [[first_start]] and friends>=
        -- We set long and short forms together; [[ss]] is the
        -- long form and [[s]] is the short form.
        -- <definition of function [[set_name]]>=
        local function set_name(start, lim, long, short)
            if start < lim then
                -- string concatenation is quadratic, but names are short
                -- An abbreviated token is the first letter of a token,
                -- except again we have to deal with the damned specials.
                -- <definition of [[abbrev]], for shortening a token>=
                local function abbrev(token)
                    local first_alpha, _, alpha = string.find(token, '(%a)')
                    local first_brace = string.find(token, '%{%\\')
                    if first_alpha and first_alpha <= (first_brace or first_alpha) then
                        return alpha
                    elseif first_brace then
                        local i, j, special = string.find(token, '(%b{})', first_brace)
                        if i then
                            return special
                        else
                            -- unbalanced braces
                            return string.sub(token, first_brace)
                        end
                    else
                        return ''
                    end
                end
                local ss = tokens[start]
                local s = abbrev(tokens[start])
                for i = start + 1, lim - 1 do
                    if inter_token then
                        ss = ss .. inter_token .. tokens[i]
                        s = s .. inter_token .. abbrev(tokens[i])
                    else
                        local ssep, nnext = trailers[i - 1], tokens[i]
                        local sep, next = ssep, abbrev(nnext)
                        -- Here is the default for a character between tokens:
                        -- a tie is the default space character between the last
                        -- two tokens of the name part, and between the first two
                        -- tokens if the first token is short enough; otherwise,
                        -- a space is the default.
                        -- <possibly adjust [[sep]] and [[ssep]] according to token position and size>=
                        if string.find(sep, sep_char) then
                            -- do nothing; sep is OK
                        elseif i == lim - 1 then
                            sep, ssep = '~', '~'
                        elseif i == start + 1 then
                            sep = text_char_count(s) < 3 and '~' or ' '
                            ssep = text_char_count(ss) < 3 and '~' or ' '
                        else
                            sep, ssep = ' ', ' '
                        end
                        ss = ss .. ssep .. nnext
                        s = s .. '.' .. sep .. next
                    end
                end
                name[long] = ss
                name[short] = s
            end
        end
        set_name(first_start, first_lim, 'ff', 'f')
        set_name(von_start, von_lim, 'vv', 'v')
        set_name(von_lim, last_lim, 'll', 'l')
        set_name(last_lim, jr_lim, 'jj', 'j')
        return name
    end
end

-- Thanks, Norman, for the above functions!

---------------------------
--- Bibliography global ---
---------------------------
-- Public programmatic API for this package
-- Stateless, pure in regards to other globals

Bibliography = {

    --- Functions which return array of strings to be concatenated.
    --- Defines styles of citation marks.
    CitationStyles = {
        AuthorYear = function(env)
            return Bibliography.BibliographyElements.andSurnames(3), " ", env.bib.year, Bibliography.BibliographyElements.optional(", ", env.cite.page)
        end,

        NumericByAppearance = function(env)
            return "["..env.referenceInfo.usedOrder .."]"
        end
    },

    --- Defines styles of bibliography entries and their default citing style.
    --- Populated lazily.
    loadBibliographyStyle = function (name)
        --- {
        ---  <bibliographyStyle> = (BibEnv) -> multiple strings or functions (bibliography item) -> string
        ---  default = same as above
        --- }
        return SILE.require("bibliography/bibstyles/" .. name)
    end,

    buildEnv = function (cite, bib, referenceInfo)
        local env = {}
        env.cite = cite
        env.bib = bib.attributes
        env.bibType = bib.type
        env.referenceInfo = referenceInfo
        return env
    end,

    --- Given citation key ({ "key" = <bibliography key:string>, ... additional arguments}),
    --- bibliography ({ <bibliography key> = <bib entry>, ... })
    --- and style ({ <bibliography type> = <{BibliographyElement, ...}>, ... }),
    --- produce a string which can be TeX-like typeset to get a citation mark
    produceCitation = function(cite, bibItem, citationStyle, referenceInfo)
        -- Capture multiple return values into a table
        local citationElements = { citationStyle(Bibliography.buildEnv(cite, bibItem, referenceInfo)) }
        return Bibliography._process(item.attributes, citationElements)
    end,

    --- Given citation key ({ "key" = <bibliography key:string>, ... additional arguments}),
    --- bibliography ({ <bibliography key> = <bib entry>, ... })
    --- and style ({ <bibliography type> = <{BibliographyElement, ...}>, ... }),
    --- produce a string which can be TeX-like typeset to get a reference
    produceReference = function(cite, bibItem, style, referenceInfo)
        local originalStyleName = textcase.lowercase(bibItem.type)

        local triedStyles = {}
        local styleName = originalStyleName
        local foundTypeStyle = nil
        while true do
            if triedStyles[styleName] then
                SU.error("Can't find style formatter for "..originalStyleName.." try specifying a different reference style")
            end
            triedStyles[styleName] = true
            foundTypeStyle = style[styleName]
            if foundTypeStyle ~= nil then
                break
            end

            -- Generate fallback style name
            local entry = BibTexEntries[styleName]
            styleName = entry and entry.fallback or "misc"
        end

        -- Capture multiple return values into a table
        local env = Bibliography.buildEnv(cite, bibItem, referenceInfo)
        local referenceElements = { foundTypeStyle(env) }
        return Bibliography._process(bibItem.attributes, referenceElements)
    end,

    _process = function(bib, t, dStart, dEnd)
        for i = 1, #t do
            if type(t[i]) == "function" then
                t[i] = t[i](bib)
            end
        end
        local res = SU.concat(t, "")
        if dStart or dEnd then
            if res ~= "" then
                return (dStart .. res .. dEnd)
            end
        else
            return res
        end
    end,

    -- Collection of functions (or functions which return functions) to be used when constructing
    -- a bibliographic citation string. The functions will be fed with bibliography item and options passed when citing (e.g. page, but this is not defined)
    BibliographyElements = {
        andAuthors = function(bib)
            local authors = namesplit(bib.author)
            if #authors == 1 then
                return parse_name(authors[1]).ll
            else
                for i = 1, #authors do
                    local author = parse_name(authors[i])
                    authors[i] = author.ll .. ", " .. author.f .. "."
                end
                return table.concat(authors, " and ")
            end
        end,

        -- Returns an author formatting function
        -- nameFormat: String consiting of arbitrary text and formatting sequences. Each name
        --             is formatted using this format string. Format sequences are surrounded by
        --			   { and } and are one of: f, l, v, j for shortened versions of first, last, von
        --			   or junior name, these letters twice for unshortened versions, or any of that
        --			   capitalized for capitalized version.
        -- joiner: String that goes between two names (default: and )
        -- lastJoiner: joiner, which is used between last two names (if max is not hit) (default: joiner)
        -- max: max amount of names to print (default: unlimited)
        -- maxTrail: string to append when some names are omitted due to max
        makeAuthors = function(nameFormat, joiner, lastJoiner, max, maxTrail)
            joiner = joiner or " and "
            lastJoiner = lastJoiner or joiner
            max = max or math.huge
            maxTrail = " et al."

            -- Array of strings and functions to invoke on names
            local nameFormatElements = {}
            local format = nil
            -- Create nameFormatElements from nameFormat
            for letter in SILE.utilities.splitUtf8(nameFormat) do
                if format == nil then
                    if letter == "{" then
                        format = ""
                    else
                        table.insert(nameFormatElements, letter)
                    end
                else
                    if letter == "}" then
                        local lowerFormat = string.lower(format)
                        local makeUppercase = lowerFormat ~= format
                        if #lowerFormat ~= 1 and #lowerFormat ~= 2 then
                            SU.error("bibliography: Name format has invalid length: " .. format .. " (in " .. nameFormat .. ")")
                        end
                        if #lowerFormat == 2 and lowerFormat[1] ~= lowerFormat[2] then
                            SU.error("bibliography: Two letter name format must use same letter: " .. format .. " (in " .. nameFormat .. ")")
                        end
                        if lowerFormat[1] ~= "f" and lowerFormat[1] ~= "l" and lowerFormat[1] ~= "v" and lowerFormat[1] ~= "j" then
                            SU.error("bibliography: Name format may only use letters \"flvj\": " .. format .. " (in " .. nameFormat .. ")")
                        end

                        table.insert(nameFormatElements, function(name)
                            local n = name[lowerFormat]
                            if makeUpperCase then
                                n = textcase.uppercase(n)
                            end
                            return n
                        end)
                    else
                        format = format .. letter
                    end
                end
            end

            return function(bib)
                local authors = namesplit(bib.author)
                local result = ""

                for i = 1, #authors do
                    -- handle max
                    if i > max then
                        result = result .. maxTrail
                        break
                    end

                    -- handle joiners
                    if i > 1 then
                        if i == #authors then
                            -- this is the last author
                            result = result .. lastJoiner
                        else
                            result = result .. joiner
                        end
                    end

                    -- add author
                    local author = authors[i]
                    for element in nameFormatElements do
                        if type(element) == "function" then
                            result = result .. element(author)
                        else
                            result = result .. element
                        end
                    end
                end

                return result
            end
        end,

        andSurnames = function(max)
            return function(bib)
                local authors = namesplit(bib.author)
                if #authors > max then
                    return parse_name(authors[1]).ll .. " et al."
                else
                    for i = 1, #authors do
                        authors[i] = parse_name(authors[i]).ll
                    end

                    local function commafy (t, andword)
                        -- also stolen from nbibtex
                        andword = andword or 'and'
                        if #t == 1 then
                            return t[1]
                        elseif #t == 2 then
                            return t[1] .. ' ' .. andword .. ' ' .. t[2]
                        else
                            local last = t[#t]
                            t[#t] = andword .. ' ' .. t[#t]
                            local answer = table.concat(t, ', ')
                            t[#t] = last
                            return answer
                        end
                    end

                    return commafy(authors)
                end
            end
        end,

        -- Function which returns "Edited by $editor, Translated by $translator",
        -- or part of that if these elements are not present
        transEditor = function(bib)
            local r = {}
            if bib.editor then
                r[#r + 1] = "Edited by " .. bib.editor
            end
            if bib.translator then
                r[#r + 1] = "Translated by " .. bib.translator
            end
            if #r then
                return table.concat(r, ", ")
            end
            return nil
        end,

        -- Function which wraps all elements in quotes, unless they are empty
        quotes = function(...)
            local t = { ... }
            return function(bib)
                return Bibliography._process(bib, t, "“", "”")
            end
        end,

        -- Function which makes all elements italic, unless they are empty
        italic = function(...)
            local t = { ... }
            return function(bib)
                return Bibliography._process(bib, t, "\\em{", "}")
            end
        end,

        -- Function which wraps all elements in parentheses "()", unless they are empty
        parens = function(...)
            local t = { ... }
            return function(bib)
                return Bibliography._process(bib, t, "(", ")")
            end
        end,

        -- Function which joins and returns all argument functions,
        -- unless one of the elemens is empty or nil, in which case returns empty string
        optional = function(...)
            local t = { n = select('#', ...), ... }
            return function(bib)
                for i = 1, t.n do
                    if type(t[i]) == "function" then
                        t[i] = t[i](bib)
                    end
                    if not t[i] or t[i] == "" then
                        return ""
                    end
                end
                return table.concat(t, "")
            end
        end
    },

    Utils = {
        --- Create an unit - element which, when combined through join() or optional(),
        --- will coalesce with its identical neighbors into one and will print only if something follows it.
        --- This is used for example to prevent double separators between optional fields:
        --- `field1, unit(", "), field2, unit(", "), field3`
        --- Unit may consist of multiple elements, which will be combined before coalescing.
        --- Equivalent to LaTeX \setunit
        unit = function(...)
            -- Note: this repeated pattern is needed, because Lua's handling of varargs is stupid: http://lua-users.org/wiki/VarargTheSecondClassCitizen
            return { kind = "unit", n = select('#', ...), ... }
        end,
        --- Similar to unit, but prints only when preceded by a non-nil, non-empty item.
        --- Equivalent to LaTeX \setunit*
        backunit = function(...)
            return { kind = "backunit", n = select('#', ...), ... }
        end,
        --- Like backunit, but does not do anything when the output already ends with given text
        suffix = function(...)
            return { kind = "suffix", n = select('#', ...), ... }
        end,
        --- Insert a paragraph separator as an unit
        block = { kind = "blockunit", "\\par", n = 1},
        --- Insert a default separator unit
        newunit = { kind = "unit", ". ", n = 1},

        --- Combine elements (units and strings) into one string.
        --- nils and empty strings are ignored and allow units to coalesce.
        combine = function(...)
            local t = { kind = "combine", n = select('#', ...), ... }
        end,

        --- Version of combine which returns nil if any of passed elements are nil or empty string
        optional = function(...)
            local t = { n = select('#', ...), ... }
            return { kind = "optional", Bibliography.Utils.combine(unpack(t, 1, t.n))}
        end,

        --- Surround function generator.
        --- Surround functions return passed in parameters prefixed with prefix and suffixed with suffix,
        --- unless some passed in elements are nil or empty, in which case it returns empty string.
        --- Empty prefix or suffix is allowed.
        makeSurround = function(prefix, suffix)
            return function(...)
                local t = { n = select('#', ...), ... }
                local combined = Bibliography.Utils.optional(unpack(t, 1, t.n))

                local pre
                if type(prefix) == "function" then
                    pre = prefix()
                else
                    pre = prefix
                end

                local suf
                if type(suffix) == "function" then
                    suf = suffix()
                else
                    suf = suffix
                end

                return {
                    kind = "surround",
                    prefix = pre,
                    suffix = suf,
                    combined
                }
            end
        end,

        finalExpansion = function(rootElement, parameters)

            local function contains(table, val)
                for i=1, #table do
                    if table[i] == val then
                        return true
                    end
                end
                return false
            end

            local function slice (source, from, to)
                local pos, new = 1, {}

                for i = from, to do
                    new[pos] = source[i]
                    pos = pos + 1
                end

                return new
            end

            local function endsWith(whole, suffix)
                local length = #suffix
                if length == 0 then
                    return true
                end
                local start0 = #whole - length
                if start0 < 0 then
                    return false
                end
                for i = 1,length do
                    if whole[start0 + i] ~= suffix[start0 + 1] then
                        return false
                    end
                end
                return true
            end

            local function appendItem(whole, item)
                whole[#whole + 1] = item
            end

            local function append(whole, suffix)
                for i=1,#suffix do
                    appendItem(whole, suffix[i])
                end
            end

            local function concat(whole)
                local result = ""
                for i=1,#whole do
                    result = result .. whole[i]
                end
                return result
            end

            local function applyUnits(tokens)
                if tokens.unit then
                    append(tokens, tokens.unit)
                    tokens.unit = nil
                end
                if tokens.blockunit then
                    append(tokens, tokens.blockunit)
                    tokens.blockunit = nil
                end
            end

            local elementKinds = { "unit", "backunit", "suffix", "blockunit", "combine", "optional", "surround"}

            local function expandElement(tokens, element, parameters)
                -- Expand function
                local originalElement = element
                local functionExpansions = 0
                while type(element) == "function" do
                    element = element(unpack(parameters))
                    functionExpansions = functionExpansions + 1
                    if functionExpansions > 50 then
                        SU.error("Cyclic function expansion of "..originalElement) -- TODO better debug
                    end
                end

                -- Remove empties
                if element == nil or element == "" then
                    return
                end

                -- Strings can be added as a tokens directly
                if type(element) == "string" then
                    applyUnits(tokens)
                    appendItem(tokens, element)
                    return
                end

                -- Process tables
                if type(element) == "table" then
                    local kind = element.kind
                    if not contains(elementKinds, kind) then
                        SU.error("Element has unrecognized kind: "..element)
                    end

                    local tableTokens = {}
                    local elementCount = element.n or #element
                    for i = 1, elementCount do
                        expandElement(tableTokens, element[i], parameters)
                    end

                    if kind == "unit" then
                        tokens.unit = tableTokens
                    elseif kind == "backunit" then
                        if not endsWith(tokens, tableTokens) then
                            append(tokens, tableTokens)
                        end
                    elseif kind == "suffix" then
                        if not endsWith(concat(tokens), concat(tableTokens)) then
                            append(tokens, tableTokens)
                        end
                    elseif kind == "blockunit" then
                        tokens.blockunit = tableTokens
                    elseif kind == "combine" then
                        applyUnits(tokens)
                        append(tokens, tableTokens)
                    elseif kind == "optional" then
                        if elementCount == #tableTokens then
                            applyUnits(tokens)
                            append(tokens, tableTokens)
                        end
                    elseif kind == "surround" then
                        if #tableTokens > 0 then
                            applyUnits(tokens)
                            if element.prefix ~= nil and element.prefix ~= "" then
                                appendItem(element.prefix)
                            end
                            append(tokens, tableTokens)
                            if element.suffix ~= nil and element.suffix ~= "" then
                                appendItem(element.suffix)
                            end
                        end
                    end

                    return
                end

                SU.error("Unrecognized type of element: "..element)
            end

            local tokens = {}
            expandElement(tokens, rootElement, parameters)
            return concat(tokens)
        end
    }
}

-- These are defined here, because they reference their neighbor variables and Lua does not like that
--- Surrounds elements with localized quotes
Bibliography.Utils.quotes = (function()
    -- This table of localized quotation marks is released into public domain (or as CC0),
    -- so that nobody has to type it out again, like I did
    -- From https://en.wikipedia.org/wiki/Quotation_mark#Summary_table
    local quotes = {
        af = {"“", "”"}, -- Afrikaans
        am = {"«", "»"}, -- Amharic
        ar = {"«", "»"}, -- Arabic
        az = {"«", "»"}, -- Azerbaijani
        be = {"«", "»"}, -- Belarusian
        bs = {"”", "”"}, -- Bosnian
        bg = {"„", "“"}, -- Bulgarian
        bo = {"《", "》"}, -- Tibetan
        ca = {"«", "»"}, -- Catalan
        cs = {"„", "“"}, -- Czech
        cy = {"‘", "’"}, -- Welsh
        da = {"»", "«"}, -- Danish
        de = {"„", "“"}, -- German (not Swiss, that is missing)
        el = {"«", "»"}, -- Greek
        en = {"“", "”"}, -- English (US, Canada, UK-alt)
        eo = {"“", "”"}, -- Esperanto
        es = {"«", "»"}, -- Spanish
        et = {"„", "“"}, -- Estonian
        eu = {"«", "»"}, -- Basque
        fa = {"«", "»"}, -- Persian
        fi = {"”", "”"}, -- Finnish
        fr = {"«", "»"}, -- French
        ga = {"“", "”"}, -- Irish
        gl = {"«", "»"}, -- Galician
        gd = {"‘", "’"}, -- Scottish Gaelic
        he = {"„", "”"}, -- Hebrew
        hi = {"“", "”"}, -- Hindi
        hr = {"„", "”"}, -- Croatian
        hu = {"„", "”"}, -- Hungarian
        hy = {"«", "»"}, -- Armenian
        ia = {"“", "”"}, -- Interlingua
        id = {"“", "”"}, -- Indonesian
        is = {"„", "“"}, -- Icelandic
        it = {"«", "»"}, -- Italian (Italian Swiss)
        ja = {"「", "」"}, -- Japanese
        ka = {"„", "“"}, -- Georgian
        kk = {"«", "»"}, -- Kazakh
        km = {"«", "»"}, -- Khmer
        ko = {"“", "”"}, -- Korean (south)
        lo = {"“", "”"}, -- Lao
        lt = {"„", "“"}, -- Lithuanian
        lv = {"“", "”"}, -- Latvian
        mk = {"„", "“"}, -- Macedonian
        mt = {"“", "”"}, -- Maltese
        mn = {"«", "»"}, -- Mongolian (Cyrilic script)
        nl = {"„", "”"}, -- Dutch
        no = {"«", "»"}, -- Norwegian
        oc = {"«", "»"}, -- Occitan
        pl = {"„", "”"}, -- Polish
        pt = {"“", "”"}, -- Portuguese (Brazil, Portugal-alt)
        ps = {"«", "»"}, -- Pashto
        ro = {"„", "”"}, -- Romanian
        rm = {"«", "»"}, -- Romansh
        ru = {"«", "»"}, -- Russian
        sk = {"„", "“"}, -- Slovak
        sl = {"„", "“"}, -- Slovene
        sq = {"„", "“"}, -- Albanian
        sr = {"„", "“"}, -- Serbian
        sv = {"”", "”"}, -- Swedish
        th = {"“", "”"}, -- Thai
        tr = {"“", "”"}, -- Turkish
        tl = {"“", "”"}, -- Tagalog (Filipino)
        ti = {"«", "»"}, -- Tigrinya
        uk = {"«", "»"}, -- Ukrainian
        ug = {"«", "»"}, -- Uyghur
        uz = {"«", "»"}, -- Uzbek
        vi = {"“", "”"}, -- Vietnamese
        zh = {"“", "”"}, -- Chinese (simplified)
    }
    local function q(i)
        -- To be evaluated at call time, so that it can fetch the correct language
        return function()
            return (quotes[SILE.settings.get("document.language")] or {"\"", "\""})[i]
        end
    end

    Bibliography.Utils.makeSurround(q(1), q(2))
end)()
--- Makes the elements italic
Bibliography.Utils.italic = Bibliography.Utils.makeSurround("\\em{", "}")
--- Makes the elements bold
Bibliography.Utils.bold = Bibliography.Utils.makeSurround("\\font[style=bold]{", "}")
--- Wraps the elements in round parentheses "()"
Bibliography.Utils.parens = Bibliography.Utils.makeSurround("(", ")")
--- Wraps the elements in square brackets "[]"
Bibliography.Utils.brackets = Bibliography.Utils.makeSurround("[", "]")
--- Make passed URL clickable
Bibliography.Utils.url = Bibliography.Utils.makeSurround("\\url{", "}")

---------------------
--- SILE Commands ---
---------------------
-- Public SILE API for the package
-- Stores its configuration in SILE.scratch.bibtex:
--  .bib = Loaded bibliography/ies
--  .bibstyle = Current style for references (bibliographic citations)
--  .citationstyle = Current style for citations (short marks which reference bibliographic citations)
--  .references = All citations that were made with \cite in this document
--  .referencesCount = Amount of references in .references. Used for references[].usedOrder

SILE.scratch.bibtex = { bib = {}, bibstyle = {}, references = {
    -- <key> = {
    --      usedOrder = <order in which this was first used>,
    --      referencePending = <whether this was cited since it was last used as a reference>
    -- }
}, referencesCount = 1 }

SILE.registerCommand("bibstyle", function(o, c)
    local ref = o.reference or c -- backward compatibility
    if ref then
        local bibStyle = Bibliography.loadBibliographyStyle(ref)
        if bibStyle == nil then
            SU.warn("bibstyle: reference style "..ref.." not found")
        else
            SILE.scratch.bibtex.bibstyle = bibStyle
        end
    end

    local cit = o.citation
    if cit then
        local citStyle = Bibliography.CitationStyles[cit]
        if citStyle == nil then
            SU.warn("bibstyle: citation style "..cit.." not found")
        else
            SILE.scratch.bibtex.citationstyle = citStyle
        end
    end
end)

SILE.call("bibstyle", { reference = "chicago", citation = "AuthorYear" }) -- Load some default

SILE.registerCommand("loadbibliography", function(o, c)
    local inlineContent = c and SU.contentToString(c) or nil
    if inlineContent == "" then
        inlineContent = nil
    end
    local fileContent = nil

    local fileName = o.file
    if fileName then
        fileName = SILE.resolveFile(fileName)
        local fh, e = io.open(fileName)
        if e then
            SU.error("Error reading bibliography file " ..fileName .. ": " .. e)
        end
        fileContent = fh:read("*all")
        fh:close()
    end

    if inlineContent == nil and fileContent == nil then
        SU.error("loadbibliography needs a file parameter or inline bib content")
    end

    local content = inlineContent or fileContent
    local bibtex = SILE.scratch.bibtex.bib
    local loadedBibtex = parseBibtex(content)

    for k, v in pairs(loadedBibtex) do
        if bibtex[k] then
            SU.warn("Skipping bibliography entry "..k.." from "..fileName..": already loaded")
        else
            bibtex[k] = v
        end
    end
end)

SILE.registerCommand("cite", function(o, c)
    o.key = o.key or c[1]

    local bibItem = SILE.scratch.bibtex.bib[o.key]
    if bibItem == nil then
        SU.warn("Unknown key in citation: " .. o)
        return
    end

    local reference = SILE.scratch.bibtex.references[o.key]
    if reference == nil then
        reference = { usedOrder = SILE.scratch.bibtex.referencesCount }
        SILE.scratch.bibtex.referencesCount = SILE.scratch.bibtex.referencesCount + 1
        SILE.scratch.bibtex.references[o.key] = reference
    end
    reference.referencePending = true

    local cite = Bibliography.produceCitation(o, bibItem, SILE.scratch.bibtex.citationstyle, reference)
    SILE.doTexlike(cite)
end)

SILE.registerCommand("reference", function(o, c)
    o.key = o.key or c[1]
    local bibItem = SILE.scratch.bibtex.bib[o.key]
    if bibItem == nil then
        SU.warn("Unknown key in reference: " .. o)
        return
    end

    local cite = Bibliography.produceReference(o, bibItem, SILE.scratch.bibtex.bibstyle, SILE.scratch.bibtex.references[o.key] or {})
    SILE.doTexlike(cite)
end)

SILE.registerCommand("references", function(o, c)
    SU.error("references not implemented yet")
    -- Produce whole bibliography
    -- \raggedright
    -- each bibliography entry should be prefixed by some numbering identification, probably
end)


---------------------
--- Documentation ---
---------------------
return { documentation = [[\begin{document}
The \code{bibliography} package creates citations and references (bibliographic citations).

\code{\\loadbibliography[file=bibliography.bib]} loads a BibTex bibliography file.
You can also supply the file content inline, but ensure that the content is properly escaped and does not contain any SILE commands.

\code{\\bibstyle[citation=AuthorYear, reference=chicago]} specifies a style to use for citations and references.
Available styles for citations are: \code{AuthorYear}.
Available styles for references are: \code{chicago}, \code{iso690}.

\code{\\cite{knuth}} inserts a citation, its content references a key from a loaded \code{.bib} entry.
Citation is styled according to the active citation style. Additional options can be passed, if the citation style
supports it, such as \code{page}.

\code{\\reference{knuth}} inserts a reference (bibliographic citation), styled according to the active reference style.
\end{document}]] }