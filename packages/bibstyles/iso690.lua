
local textcase = SILE.require("packages/textcase").exports

-- Based on https://github.com/michal-h21/biblatex-iso690
-- which is under LaTeX Project Public License v1.3c
-- Copyright (C) 2011-2017 Michal Hoftich 2015-2017 Moritz Wemheuer 2016-2017 Dávid Lupták
local NBSP = "\u{00A0}"
local U = Bibliography.Utils

local Locale = {
    cs = {
        at = "v",
        bysupervisor = "vedoucí práce",
        urlfrom = "dostupné z",
        urlalso = "dostupné také z",
        titleSubtitleDelimiter = ": "
    },
    en = {
        at = "at",
        bysupervisor = "supervised by",
        urlfrom = "available from",
        urlalso = "available also from"
    },
    de = {
        at = "Standort",
        bysupervisor = "betreut von",
        urlfrom = "verfügbar unter",
        urlalso = "auch verfügbar unter"
    },
    pl = {
        at = "w",
        bysupervisor = "promotor",
        urlfrom = "dostępne z",
        urlalso = "dostępne także z"
    },
    sk = {
        at = "v",
        bysupervisor = "vedúci práce",
        urlfrom = "dostupné z",
        urlalso = "dostupné tiež z",
        titleSubtitleDelimiter = ": "
    }
}

--- Specifies default settings for options. Locale may override these defaults.
--- Options may be also passed as a part of command, in which case they take ultimate precedence.
--- Localized strings ending in underscore _ denote an abbreviation.
local Options = {
    -- Localization string fallback
    at = "at",
    bysupervisor = "supervised by",
    urlfrom = "available from",
    urlalso = "available also from",
    -- Delimiter between author names and title
    nameTitleDelimiter = ". ",
    -- Delimiter between work title and subtitle
    titleSubtitleDelimiter = " : ",
    --
    prepIn = "in",
    jourvol_ = "TODO",
    volume_ = "TODO",
    edition_ = "ed.",
    pages_ = "p.",
    number_ = "TODO",
    urlseen = "TODO",
    version = "TODO",

    byeditor = "edited by",
    bytranslator = "translated by",
    bibpagerefpunct = " ",
    bibpagespunct = "- ",
    -- Punctuation inserted after "In" or "At"
    intitlepunct = ": ",

    -- Enable space before colons?
    SpaceBeforeColon = true,
    -- Show URL field?
    ShowURL = true,
    -- Show ISBN field?
    ShowISBN = true,
    -- Show DOI field?
    ShowDOI = true,
    -- Show eprint field?
    ShowEprint = true,

    useauthor = true,

    --TODO will these be used?
    --TODO What does this do?
    ShortNumeration = false,
    ShowThesisInfo = true,
    maxnames=9,
    minnames=1,
    citetracker=true,
    autolang=other,
    date=year,
    urldate=iso,
    seconds=true,
}

ISO690 = {
    option = function(key, env)
        local locale = Locale[SILE.settings.get("document.language")]
        return (env and env.cite and env.cite[key]) or (locale and locale[key]) or Options[key]
    end,
    -- BibLaTeX commands: http://mirror.utexas.edu/ctan/macros/latex/contrib/biblatex/doc/biblatex.pdf
    --- \ifnumeral
    isNumeral = function(text)
        -- Very simple check, whether the text consists of arabic or roman numerals, optionally surrounded by spaces
        return text and text:match("[ ]*[1234567890ivxlcdmIVXLCDM]+[ ]*") == text
    end,
    --- \ifnumerals
    isNumerals = function(text)
        -- Naive check, returns true when the text contains any numbers (arabic or roman)
        return text and text:match("[1234567890ivxlcdmIVXLCDM]+") ~= nil
    end,
    --- \mkbibordinal
    makeOrdinal = function(text)
        -- TODO WRONG FOR OTHER LANGUAGES
        return text.."."
    end,
    --- \mkbibordedition
    makeEditionOrdinal = function(text)
        return ISO690.makeOrdinal(text)
    end,
    --- \printnames
    printNames = function(names)
        return names
        -- TODO
        -- TODO
        -- TODO
        -- TODO
        -- TODO
        -- TODO
        -- TODO
        -- TODO
    end,
    --- \printlist
    printList = function(content)
        return content
        -- TODO
        -- TODO
        -- TODO
        -- TODO
        -- TODO
        -- TODO
    end,

    -- Punctuation between title and subtitle
    subtitlePunct = function(env)
        return ISO690.option("titleSubtitleDelimiter", env)
    end,
    volume = function(env)
        if not env.bib.volume then
            return nil
        end
        if env.bib.type == "article" or env.bib.type == "periodical" then
            if (ISO690.option("ShortNumeration", env)) then
                return U.bold(env.bib.volume)
            else
                return U.combine(ISO690.option("jourvol_", env), NBSP, env.bib.volume)
            end
        else
            -- volume of a book
            return U.combine(ISO690.option("volume_", env), NBSP, env.bib.volume)
        end
    end,
    edition = function(env)
        if not env.bib.edition then
            return nil
        elseif ISO690.isNumeral(env.bib.edition) then
            return U.combine(ISO690.makeEditionOrdinal(env.bib.edition), NBSP, ISO690.option("edition_", env))
        else
            return textcase.uppercase(env.bib.edition)
        end
    end,
    pages = function(env)
        if not env.bib.pages then
            return nil
        end
        if env.bib.type == "article" or env.bib.type == "periodical" then
            if (ISO690.option("ShortNumeration", env)) then
                return env.bib.pages
            else
                return U.combine(ISO690.option("pages_", env), " ", env.bib.pages)
            end
        else
            -- \mkmlpageprefix[bookpagination]{#1}

            -- % overriding pagination to use document main language
            --
            --\newrobustcmd*{\blx@imc@mkmlpageprefix}[1][pagination]{%
            --  \begingroup
            --  \def\blx@tempa{\blx@mkmlpageprefix{page}}%
            --  \iffieldundef{#1}
            --    {}
            --    {\iffieldequalstr{#1}{none}
            --       {\def\blx@tempa{\blx@mkmlpageprefix@i}}
            --       {\iffieldbibstring{#1}
            --          {\edef\blx@tempa{\blx@mkmlpageprefix{\thefield{#1}}}}
            --          {\blx@warning@entry{%
            --             Unknown pagination type '\strfield{#1}'}}}}%
            --  \@ifnextchar[%]
            --    {\blx@tempa}
            --    {\blx@tempa[\@firstofone]}}
            --
            --\protected\long\def\blx@mkmlpageprefix#1[#2]#3{%
            --  \ifnumeral{#3}
            --    {\mainsstring{#1}\ppspace}
            --    {\ifnumerals{#3}
            --       {\mainsstring{#1s}\ppspace}
            --       {\def\pno{\mainsstring{#1}}%
            --        \def\ppno{\mainsstring{#1s}}}}%
            --  \blx@mkmlpageprefix@i[#2]{#3}}
            --
            --\long\def\blx@mkmlpageprefix@i[#1]#2{#1{#2}\endgroup}
            --
            --\blx@regimcs{\mkmlpageprefix}
        end
    end,
    pagetotal = function(env)
        if not env.bib.pagetotal then
            return nil
        end
        -- \mkbibbrackets{\mkmlpagetotal[bookpagination]{#1}}
        --return U.brackets(mkmlpagetotal[bookpagination]env.bib.pagetotal)


        -- % overriding bookpagination to use document main language
        --
        --\newrobustcmd*{\blx@imc@mkmlpagetotal}[1][bookpagination]{%
        --  \begingroup
        --  \def\blx@tempa{\blx@mkmlpagetotal{page}}%
        --  \iffieldundef{#1}
        --    {}
        --    {\iffieldequalstr{#1}{none}
        --       {\def\blx@tempa{\blx@mkmlpagetotal@i}}
        --       {\iffieldbibstring{#1}
        --          {\edef\blx@tempa{\blx@mkmlpagetotal{\thefield{#1}}}}
        --          {\blx@warning@entry{%
        --             Unknown pagination type '\strfield{#1}'}}}}%
        --  \@ifnextchar[%]
        --    {\blx@tempa}
        --    {\blx@tempa[\@firstofone]}}
        --
        --\protected\long\def\blx@mkmlpagetotal#1[#2]#3{%
        --  \ifnumeral{#3}
        --    {\setbox\@tempboxa=\hbox{%
        --       \blx@tempcnta0#3\relax
        --       \ifnum\blx@tempcnta=\@ne
        --         \aftergroup\@firstoftwo
        --       \else
        --         \aftergroup\@secondoftwo
        --       \fi}%
        --     {#2{#3}\ppspace\mainsstring{#1}}
        --     {#2{#3}\ppspace\mainsstring{#1s}}}
        --    {\def\pno{\mainsstring{#1}}%
        --     \def\ppno{\mainsstring{#1s}}%
        --     #2{#3}}%
        --  \endgroup}
        --
        --\long\def\blx@mkmlpagetotal@i[#1]#2{#1{#2}\endgroup}
        --
        --\blx@regimcs{\mkmlpagetotal}
    end,
    number = function(env)
        if not env.bib.number then
            return nil
        end
        if env.bib.type == "article" or env.bib.type == "periodical" then
            if (ISO690.option("ShortNumeration", env)) then
                return U.parens(env.bib.number)
            else
                return U.combine(ISO690.option("number_", env), " ", env.bib.number)
            end
        elseif env.bib.type == "patent" then
            return env.bib.number
        else
            return U.combine(ISO690.option("number_", env), " ", env.bib.number)
        end
    end,
    url = function(env)
        if not env.bib.url then
            return nil
        end
        if env.bib.urlyear then
            return U.combine(ISO690.option("urlalso", env), ": ", U.url(env.bib.url))
        else
            return U.combine(ISO690.option("urlfrom", env), ": ", U.url(env.bib.url))
        end
    end,
    doi = function(env)
        if not env.bib.doi then
            return nil
        end
        -- TODO Could this somehow escape? Can DOI contain "]"? (It could if there was a correction...)
        return U.combine("DOI: \\href[src=https://doi.org/", env.bib.doi, "]{", env.bib.doi, "}")
    end,
    type = function(env)
        if not env.bib.type then
            return nil
        end
        -- Can define some types to be translated, not sure how useful that is
        return ISO690.option("type_" .. env.bib.type, env) or env.bib.type
    end,
    supervisor = function(env)
        return U.combine(ISO690.option("bysupervisor", env), " ", env.bib.supervisor)
    end,
    isbn = function(env) return U.combine("ISBN ", env.bib.isbn) end,
    issn = function(env) return U.combine("ISSN ", env.bib.isbn) end,
    isan = function(env) return U.combine("ISAN ", env.bib.isan) end,
    ismn = function(env) return U.combine("ISMN ", env.bib.ismn) end,
    isrn = function(env) return U.combine("ISRN ", env.bib.isrn) end,
    iswc = function(env) return U.combine("ISWC ", env.bib.iswc) end,
    urldate = function(env)
        return U.brackets(ISO690.option("urlseen", env), " ", env.bib.urlseen)
    end,
    chapter = function(env)
        return U.combine(ISO690.option("chapter", env), NBSP, env.bib.chapter, U.suffix("."))
    end,
    version = function(env)
        if not env.bib.version then
            return nil
        elseif ISO690.isNumeral(env.bib.version) then
            return U.combine(ISO690.makeEditionOrdinal(env.bib.version), NBSP, ISO690.option("version", env))
        else
            return textcase.uppercase(env.bib.version)
        end
    end,
    titleaddon = function(env) return U.brackets(env.bib.titleaddon) end,
    booktitleaddon = function(env) return U.brackets(env.bib.booktitleaddon) end,
    maintitleaddon = function(env) return U.brackets(env.bib.maintitleaddon) end,

    --- \usebibmacro{editor}
    editor = function(env)
        -- TODO: dunno how to implement this, not sure what it should do
        return env.bib.editor
    end,
    --- \usebibmacro{editor}
    author = function(env)
        -- TODO: dunno how to implement this, not sure what it should do
        return env.bib.author
    end,
    namesPrimary = function(env)
        local primary
        if ISO690.option("useauthor", env) and env.bib.author then
            primary = ISO690.author
        else
            primary = ISO690.editor
        end
        return ISO690.combine(primary, U.unit(" "), U.brackets(env.bib.nameaddon))
    end,
    namesSubsidiary = function(env)
        return U.combine(
                U.optional(ISO690.option("byeditor", env), env.bib.editor),
                U.newunit,
                U.optional(ISO690.option("bytranslator", env), env.bib.bytranslator))
    end,
    editorType = function(env)
        return U.parens(env.bib.editortype)
    end,
    editortypedelim = " ",--todo needed?
    thesissupervisor = function(env)
        if env.bib.supervisor then
            return U.combine(ISO690.option("bysupervisor", env), U.unit(" "), ISO690.printNames(env.bib.supervisor))
        else
            return nil
        end
    end,

    titles = function(titleprefix, italic)
        return function(env)
            local title = env.bib[titleprefix.."title"]
            local subtitle = env.bib[titleprefix.."subtitle"]
            if not title and not subtitle then
                return U.combine(U.unit(" "), U.brackets(env.bib[titleprefix.."titleaddon"]), U.newunit)
            end

            if italic then
                return U.combine(U.italic(title, U.unit(ISO690.option("titleSubtitleDelimiter", env)), subtitle), U.unit(" "), U.brackets(env.bib[titleprefix.."titleaddon"]), U.newunit)
            end

            return U.combine(title, ISO690.option("titleSubtitleDelimiter", env), subtitle, U.unit(" "), U.brackets(env.bib[titleprefix.."titleaddon"]), U.newunit)
        end
    end,
    volumePart = function(env)
        if env.bib.volume then
            U.combine(ISO690.volume(env), env.bib.part, U.unit(", "))
        else
            return nil
        end
    end,
    multiTitles = function(env)
        if env.bib.maintitle == nil then
            if env.bib.booktitle == nil then
                return ISO690.titles("", true)
            else
                return U.combine(ISO690.titles("", true), ISO690.volumePart, ISO690.titles("titles"))
            end
        else
            return U.combine(ISO690.titles("main", true), ISO690.volumePart, ISO690.titles("titles"))
        end
    end,
    hostTitles = function(env)
        if env.bib.maintitle == nil then
            if env.bib.booktitle == nil then
                return nil
            else
                return ISO690.titles("book", true)
            end
        else
            return ISO690.titles("main", true)
        end
    end,
    periodicalTitles = function(env)
        return U.combine(
                ISO690.titles("", true), U.newunit,
                env.bib.issuetitle and (
                        ISO690.titles("issue")
                ) or (
                        env.bib.journaltitle and "" or ISO690.titles("journal")
                )
        )
    end,

    mediumType = function(env)
        if env.bib.howpublished then
            return U.brackets(env.bib.howpublished)
        elseif env.bib.urlyear then
            return "[online]"
        else
            return nil
        end
    end,

    fulldate = function(env)
        -- \printtext{\csname mkbibrangeiso8601\endcsname{\thefield{date}}}%
    end,
    date = function(env)
        return env.bib.date --TODO
        -- \iffieldequalstr{endyear}{}%         <- "if date is an open range"
        --    {\printdate\mbox{\addnbspace}}%
        --    {\printdate}%
    end,
    locationPublisherDate = function(env)
        return U.combine(ISO690.printList(env.bib.location),
                env.bib.publisher and U.backunit(ISO690.option("titleSubtitleDelimiter", env)) or U.backunit(", "),
                ISO690.printList(env.bib.publisher), U.backunit(", "),
                ISO690.date, U.newunit)
    end,

    serialNumeration = function(env)
        return U.combine(ISO690.volume(env), ISO690.option("ShortNumeration", env) and "" or U.backunit(", "), ISO690.number(env))
    end,
    bookNumeration = function(env)
        return U.combine(ISO690.volume(env), U.backunit(", "), ISO690.chapter(env))
    end,
    seriesAndNumber = function(env)
        return U.combine(env.bib.series, U.backunit(", "), ISO690.number(env))
    end,
    identifier = function(env)
        if not ISO690.option("ShowISBN", env) then
            return nil
        end
        return U.combine(
                ISO690.isan(env), U.newunit,
                ISO690.isbn(env), U.newunit,
                ISO690.ismn(env), U.newunit,
                ISO690.isrn(env), U.newunit,
                ISO690.issn(env), U.newunit,
                ISO690.iswc(env), U.newunit
        )
    end,
    fromDoi = function(env)
        return U.combine(ISO690.option("urlfrom", env), " ", ISO690.doi)
    end,
    fromEprint = function(env)
        return U.combine(ISO690.option("urlfrom", env), " ", env.bib.eprint)
    end,
    availabilityAccess = function(env)
        if env.bib.doi == nil then
            if env.bib.eprint == nil then
                if ISO690.option("ShowURL", env) then
                    return ISO690.url
                end
            else
                if ISO690.option("ShowEprint", env) then
                    return ISO690.fromEprint
                end
            end
        else
            if ISO690.option("ShowDOI", env) then
                return ISO690.fromDoi
            end
        end
        return nil
    end,
    location = function(env)
        -- TODO This seems pretty weird
        if env.bib.library then
            return U.combine(ISO690.prepAt, env.bib.library)
        else
            return nil
        end
    end,

    prepIn = function(env)
        return U.combine(ISO690.option("prepIn", env), ISO690.option("intitlepunct", env))
    end,
    prepAt = function(env)
        return U.combine(ISO690.option("at", env), ISO690.option("intitlepunct", env))
    end
}

return {
    book = function(env)
        return U.finalExpansion(U.combine(
                -- \usebibmacro{names:primary}\setunit{\labelnamepunct}\newblock
                ISO690.namesPrimary, ISO690.option("nameTitleDelimiter", env), U.block,
                -- \usebibmacro{multi:titles}\setunit{\addspace}\usebibmacro{medium-type}\newunit\newblock
                ISO690.multiTitles, U.unit(" "), ISO690.mediumType, U.newunit, U.block,
                -- \printfield{edition}\newunit\newblock
                ISO690.edition, U.newunit, U.block,
                -- \usebibmacro{names:subsidiary}\newunit\newblock
                ISO690.namesSubsidiary, U.newunit, U.block,
                -- \usebibmacro{location+publisher+date}\newunit\printfield{version}\setunit{\addspace}\usebibmacro{urldate}\newunit\newblock
                ISO690.locationPublisherDate, U.newunit, ISO690.version, U.unit(" "), ISO690.urlDate, U.newunit, U.block,
                -- \usebibmacro{series+number}\newunit\newblock
                ISO690.seriesAndNumber, U.newunit, U.block,
                -- \usebibmacro{identifier}\newunit\newblock
                ISO690.identifier, U.newunit, U.block,
                -- \usebibmacro{availability+access}\newunit\newblock
                ISO690.availabilityAccess, U.newunit, U.block,
                -- \usebibmacro{location}\setunit{\addspace}\iftoggle{bbx:totalpages}{\printfield{pagetotal}}{}\newunit\newblock
                ISO690.location, U.unit(" "), totalPages --[[TODO]] and ISO690.pagetotal or nil, U.newunit, U.block,
                -- \printfield{note}\newunit\newblock
                ISO690.note, U.newunit, U.block,
                -- \setunit{\bibpagerefpunct}\newblock
                U.unit(ISO690.option("bibpagerefpunct", env)), U.block,
                -- \usebibmacro{pageref}
                ISO690.pageref
        ), {env})
    end,

    periodical = function(env)
        return U.finalExpansion(U.combine(
                -- \usebibmacro{names:primary}\setunit{\labelnamepunct}\newblock
                ISO690.namesPrimary, ISO690.option("nameTitleDelimiter", env), U.block,
                -- \usebibmacro{periodical:titles}\setunit{\addspace}\usebibmacro{medium-type}\newunit\newblock
                ISO690.periodicalTitles, U.unit(" "), ISO690.mediumType, U.newunit, U.block,
                -- \printfield{edition}\newunit\newblock
                ISO690.edition, U.newunit, U.block,
                -- \usebibmacro{location+publisher+date}\setunit*{\addcomma\addspace}\usebibmacro{serial:numeration}\setunit{\addspace}\usebibmacro{urldate}\newunit\newblock
                ISO690.locationPublisherDate, U.backunit(", "), ISO690.serialNumeration, U.unit(" "), ISO690.urlDate, U.newunit, U.block,
                -- \usebibmacro{identifier}\newunit\newblock
                ISO690.identifier, U.newunit, U.block,
                -- \usebibmacro{availability+access}\newunit\newblock
                ISO690.availabilityAccess, U.newunit, U.block,
                -- \usebibmacro{location}\newunit\newblock
                ISO690.location, U.newunit, U.block,
                -- \printfield{note}\newunit\newblock,
                ISO690.note, U.newunit, U.block,
                -- \setunit{\bibpagerefpunct}\newblock
                U.unit(ISO690.option("bibpagerefpunct", env)), U.block,
                -- \usebibmacro{pageref}
                ISO690.pageref
        ), {env})
    end,

    article = function(env)
        return U.finalExpansion(U.combine(
                -- \usebibmacro{names:primary}\setunit{\labelnamepunct}\newblock
                ISO690.namesPrimary, ISO690.option("nameTitleDelimiter", env), U.block,
                -- \usebibmacro{titles}{}{}\newunit\newblock
                ISO690.titles(""), U.newunit, U.block,
                -- \usebibmacro{titles}{journal}{emph}\setunit{\addspace}\usebibmacro{medium-type}\newunit\newblock
                ISO690.titles("journal", true), U.unit(" "), ISO690.mediumType, U.newunit, U.block,
                -- \printfield{edition}\newunit\newblock
                ISO690.edition, U.newunit, U.block,
                -- \usebibmacro{date}\setunit*{\addcomma\addspace}\usebibmacro{serial:numeration}\setunit{\bibpagespunct}\printfield{pages}\setunit{\addspace}\usebibmacro{urldate}\newunit\newblock
                ISO690.date, U.backunit(", "), ISO690.serialNumeration, U.unit(ISO690.option("bibpagespunct", env)), ISO690.pages, U.unit(" "), ISO690.urldate, U.newunit, U.block,
                -- \usebibmacro{identifier}\newunit\newblock
                ISO690.identifier, U.newunit, U.block,
                -- \usebibmacro{availability+access}\newunit\newblock
                ISO690.availabilityAccess, U.newunit, U.block,
                -- \usebibmacro{location}\newunit\newblock
                ISO690.location, U.newunit, U.block,
                -- \printfield{note}\setunit{\bibpagerefpunct}\newblock
                ISO690.note, U.unit(ISO690.option("bibpagerefpunct", env)), U.block,
                -- \usebibmacro{pageref}
                ISO690.pageref
        ), {env})
    end,

    inbook = function(env)
        return U.finalExpansion(U.combine(
                -- \usebibmacro{names:primary}\setunit{\labelnamepunct}\newblock
                ISO690.namesPrimary, ISO690.option("nameTitleDelimiter", env), U.block,
                -- \usebibmacro{titles}{}{}\newunit\newblock
                ISO690.titles(""), U.newunit, U.block,
                -- \usebibmacro{in:}\printnames{bookauthor}\newunit\newblock
                ISO690.prepIn, ISO690.printNames(env.bib.bookauthor), U.newunit, U.block,
                -- \usebibmacro{host:titles}\setunit{\addspace}\usebibmacro{medium-type}\newunit\newblock
                ISO690.hostTitles, U.unit(" "), ISO690.mediumType, U.newunit, U.block,
                -- \printfield{edition}\newunit\newblock
                ISO690.edition, U.newunit, U.block,
                -- \usebibmacro{names:subsidiary}\newunit\newblock
                ISO690.namesSubsidiary, U.newunit, U.block,
                -- \usebibmacro{location+publisher+date}\setunit*{\addcomma\addspace}\usebibmacro{book:numeration}\setunit{\bibpagespunct}\printfield{pages}\newunit
                ISO690.locationPublisherDate, U.backunit(", "), ISO690.bookNumeration, U.unit(ISO690.option("bibpagespunct", env)), ISO690.pages, U.newunit,
                -- \printfield{version}\setunit{\addspace}\usebibmacro{urldate}\newunit\newblock
                ISO690.version, U.unit(" "), ISO690.urldate, U.newunit, U.block,
                -- \usebibmacro{series+number}\newunit\newblock
                ISO690.seriesAndNumber, U.newunit, U.block,
                -- \usebibmacro{identifier}\newunit\newblock
                ISO690.identifier, U.newunit, U.block,
                -- \usebibmacro{availability+access}\newunit\newblock
                ISO690.availabilityAccess, U.newunit, U.block,
                -- \usebibmacro{location}\newunit\newblock
                ISO690.location, U.newunit, U.block,
                -- \printfield{note}\newunit\newblock
                ISO690.note, U.newunit, U.block,
                -- \setunit{\bibpagerefpunct}\newblock
                U.unit(ISO690.option("bibpagerefpunct", env)), U.block,
                -- \usebibmacro{pageref}
                ISO690.pageref
        ), {env})
    end,

    incollection = function(env)
        return U.finalExpansion(U.combine(
        -- \usebibmacro{names:primary}\setunit{\labelnamepunct}\newblock
                ISO690.namesPrimary, ISO690.option("nameTitleDelimiter", env), U.block,
        -- \usebibmacro{titles}{}{}\newunit\newblock
                ISO690.titles(""), U.newunit, U.block,
        -- \usebibmacro{in:}\usebibmacro{editor}\newunit\newblock
                ISO690.prepIn, ISO690.editor, U.newunit, U.block,
        -- \usebibmacro{host:titles}\setunit{\addspace}\usebibmacro{medium-type}\newunit\newblock
        -- \printfield{edition}\newunit\newblock
                ISO690.edition, U.newunit, U.block,
        -- \usebibmacro{names:subsidiary}\newunit\newblock
        -- \usebibmacro{location+publisher+date}\setunit*{\addcomma\addspace}\usebibmacro{book:numeration}\setunit{\bibpagespunct}\printfield{pages}\newunit
                ISO690.locationPublisherDate, U.backunit(", "), ISO690.bookNumeration, U.unit(ISO690.option("bibpagespunct", env)), ISO690.pages, U.newunit,
        -- \printfield{version}\setunit{\addspace}\usebibmacro{urldate}\newunit\newblock
        -- \usebibmacro{series+number}\newunit\newblock
        -- \usebibmacro{identifier}\newunit\newblock
                ISO690.identifier, U.newunit, U.block,
        -- \usebibmacro{availability+access}\newunit\newblock
                ISO690.availabilityAccess, U.newunit, U.block,
        -- \usebibmacro{location}\newunit\newblock
                ISO690.location, U.newunit, U.block,
        -- \printfield{note}\newunit\newblock
                ISO690.note, U.newunit, U.block,
        -- \setunit{\bibpagerefpunct}\newblock
                U.unit(ISO690.option("bibpagerefpunct", env)), U.block,
        -- \usebibmacro{pageref}
                ISO690.pageref
        ), {env})
    end,

    online = function(env)
        return U.finalExpansion(U.combine(
        -- \usebibmacro{names:primary}\setunit{\labelnamepunct}\newblock
                ISO690.namesPrimary, ISO690.option("nameTitleDelimiter", env), U.block,
        -- \usebibmacro{multi:titles}\setunit{\addspace}\usebibmacro{medium-type}\newunit\newblock
        -- \printfield{edition}\newunit\newblock
                ISO690.edition, U.newunit, U.block,
        -- \usebibmacro{names:subsidiary}\newunit\newblock
        -- \usebibmacro{location+publisher+date}\newunit
                ISO690.locationPublisherDate, U.newunit,
        -- \printfield{version}\setunit{\addspace}\usebibmacro{urldate}\newunit\newblock
        -- \usebibmacro{series+number}\newunit\newblock
        -- \usebibmacro{identifier}\newunit\newblock
                ISO690.identifier, U.newunit, U.block,
        -- \usebibmacro{availability+access}\setunit{\addspace}\iftoggle{bbx:totalpages}
        --     {\printfield{pagetotal}}
        --     {}\printfield{note}\newunit\newblock
                ISO690.availabilityAccess, U.unit(" "), totalPages --[[TODO]] and ISO690.pagetotal or nil, U.newunit, U.block,
        -- \setunit{\bibpagerefpunct}\newblock
                U.unit(ISO690.option("bibpagerefpunct", env)), U.block,
        -- \usebibmacro{pageref}
                ISO690.pageref
        ), {env})
    end,

    thesis = function(env)
        return U.finalExpansion(U.combine(
        -- \usebibmacro{names:primary}\setunit{\labelnamepunct}\newblock
                ISO690.namesPrimary, ISO690.option("nameTitleDelimiter", env), U.block,
        -- \usebibmacro{titles}{}{emph}\setunit{\addspace}\usebibmacro{medium-type}\newunit\newblock
                ISO690.titles("", true), U.unit(" "), ISO690.mediumType, U.newunit, U.block,
        -- \usebibmacro{location+publisher+date}\newunit
                ISO690.locationPublisherDate, U.newunit,
        -- \printfield{version}\setunit{\addspace}\usebibmacro{urldate}\newunit\newblock
        -- \usebibmacro{identifier}\newunit\newblock
                ISO690.identifier, U.newunit, U.block,
        -- \iftoggle{bbx:thesisinfoinnotes}
        --     {}
        --     {\printfield{type}\newunit\newblock\printlist{institution}\newunit\newblock\usebibmacro{thesissupervisor}}\newunit\newblock
        -- \usebibmacro{availability+access}\setunit{\addspace}\iftoggle{bbx:totalpages}{\printfield{pagetotal}}{}\newunit\newblock
                ISO690.availabilityAccess, U.unit(" "), totalPages --[[TODO]] and ISO690.pagetotal or nil, U.newunit, U.block,
        -- \iftoggle{bbx:thesisinfoinnotes}
        --     {\printfield{type}\newunit\newblock
        --     \printlist{institution}\newunit\newblock
        --     \usebibmacro{thesissupervisor}}
        --     {}\newunit\newblock
        -- \printfield{note}\newunit\newblock
                ISO690.note, U.newunit, U.block,
        -- \setunit{\bibpagerefpunct}\newblock
                U.unit(ISO690.option("bibpagerefpunct", env)), U.block,
        -- \usebibmacro{pageref}
                ISO690.pageref
        ), {env})
    end,

    patent = function(env)
        return U.finalExpansion(U.combine(
        -- \usebibmacro{names:primary}\setunit{\labelnamepunct}\newblock
                ISO690.namesPrimary, ISO690.option("nameTitleDelimiter", env), U.block,
        -- \usebibmacro{titles}{}{emph}\newunit\newblock
                ISO690.titles("", true), U.newunit, U.block,
        -- \usebibmacro{names:subsidiary}\newunit\newblock
                ISO690.namesSubsidiary, U.unit(" "), ISO690.mediumType, U.newunit, U.block,
        -- \printfield{classification}\newunit\newblock
                env.bib.classification, U.newunit, U.block,
        -- \printlist{location}\newunit\newblock
                ISO690.location, U.newunit, U.block,
        -- \iffieldundef{type}{}{\printfield{type}\setunit*{\addcomma\space}}\printfield{number}\newunit\newblock
        -- \usebibmacro{fulldate}\setunit{\addspace}\usebibmacro{urldate}\newunit\newblock
        -- \printfield{note}\newunit\newblock
                ISO690.note, U.newunit, U.block,
        -- \usebibmacro{availability+access}\newunit\newblock
                ISO690.availabilityAccess, U.newunit, U.block,
        -- \setunit{\bibpagerefpunct}\newblock
                U.unit(ISO690.option("bibpagerefpunct", env)), U.block,
        -- \usebibmacro{pageref}
                ISO690.pageref
        ), {env})
    end
}