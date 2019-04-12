
local textcase = SILE.require("packages/textcase").exports

-- Based on https://github.com/michal-h21/biblatex-iso690
-- which is under LaTeX Project Public License v1.3c
-- Copyright (C) 2011-2017 Michal Hoftich 2015-2017 Moritz Wemheuer 2016-2017 Dávid Lupták
local NBSP = "\u{00A0}"
local U = Bibliography.Utils

ISO690 = {
    Locale = {
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
    },
    --- Specifies default settings for options. Locale may override these defaults.
    --- Options may be also passed as a part of command, in which case they take ultimate precedence.
    --- Localized strings ending in underscore _ denote an abbreviation.
    Options = {
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
    },

    option = function(key, env)
        local locale = ISO690.Locale[SILE.settings.get("document.language")]
        return (env and env.cite and env.cite[key]) or (locale and locale[key]) or ISO690.Options[key]
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
        if not names then
            return names
        end
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
        -- TODO
        -- TODO
        -- TODO
        -- TODO
        -- TODO
        -- TODO
    end,

    -- Punctuation between title and subtitle
    subtitlePunct = function(_ENV)
        return ISO690.option("titleSubtitleDelimiter", _ENV)
    end,
    volume = function(_ENV)
        if not bib.volume then
            return nil
        end
        if bib.type == "article" or bib.type == "periodical" then
            if (ISO690.option("ShortNumeration", _ENV)) then
                return U.bold(bib.volume)
            else
                return U.combine(ISO690.option("jourvol_", _ENV), NBSP, bib.volume)
            end
        else
            -- volume of a book
            return U.combine(ISO690.option("volume_", _ENV), NBSP, bib.volume)
        end
    end,
    edition = function(_ENV)
        if not bib.edition then
            return nil
        elseif ISO690.isNumeral(bib.edition) then
            return U.combine(ISO690.makeEditionOrdinal(bib.edition), NBSP, ISO690.option("edition_", _ENV))
        else
            return textcase.uppercase(bib.edition)
        end
    end,
    pages = function(_ENV)
        if not bib.pages then
            return nil
        end
        if bib.type == "article" or bib.type == "periodical" then
            if (ISO690.option("ShortNumeration", _ENV)) then
                return bib.pages
            else
                return U.combine(ISO690.option("pages_", _ENV), " ", bib.pages)
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
    pagetotal = function(_ENV)
        if not bib.pagetotal then
            return nil
        end
        -- \mkbibbrackets{\mkmlpagetotal[bookpagination]{#1}}
        --return U.brackets(mkmlpagetotal[bookpagination]bib.pagetotal)


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
    number = function(_ENV)
        if not bib.number then
            return nil
        end
        if bib.type == "article" or bib.type == "periodical" then
            if (ISO690.option("ShortNumeration", _ENV)) then
                return U.parens(bib.number)
            else
                return U.combine(ISO690.option("number_", _ENV), " ", bib.number)
            end
        elseif bib.type == "patent" then
            return bib.number
        else
            return U.combine(ISO690.option("number_", _ENV), " ", bib.number)
        end
    end,
    url = function(_ENV)
        if not bib.url then
            return nil
        end
        if bib.urlyear then
            return U.combine(ISO690.option("urlalso", _ENV), ": ", U.url(bib.url))
        else
            return U.combine(ISO690.option("urlfrom", _ENV), ": ", U.url(bib.url))
        end
    end,
    doi = function(_ENV)
        if not bib.doi then
            return nil
        end
        -- TODO Could this somehow escape? Can DOI contain "]"? (It could if there was a correction...)
        return U.combine("DOI: \\href[src=https://doi.org/", bib.doi, "]{", bib.doi, "}")
    end,
    type = function(_ENV)
        if not bib.type then
            return nil
        end
        -- Can define some types to be translated, not sure how useful that is
        return ISO690.option("type_" .. bib.type, _ENV) or bib.type
    end,
    supervisor = function(_ENV)
        return U.combine(ISO690.option("bysupervisor", _ENV), " ", bib.supervisor)
    end,
    isbn = function(_ENV) return U.combine("ISBN ", bib.isbn) end,
    issn = function(_ENV) return U.combine("ISSN ", bib.isbn) end,
    isan = function(_ENV) return U.combine("ISAN ", bib.isan) end,
    ismn = function(_ENV) return U.combine("ISMN ", bib.ismn) end,
    isrn = function(_ENV) return U.combine("ISRN ", bib.isrn) end,
    iswc = function(_ENV) return U.combine("ISWC ", bib.iswc) end,
    urldate = function(_ENV)
        return U.brackets(ISO690.option("urlseen", _ENV), " ", bib.urlseen)
    end,
    chapter = function(_ENV)
        return U.combine(ISO690.option("chapter", _ENV), NBSP, bib.chapter, U.suffix("."))
    end,
    version = function(_ENV)
        if not bib.version then
            return nil
        elseif ISO690.isNumeral(bib.version) then
            return U.combine(ISO690.makeEditionOrdinal(bib.version), NBSP, ISO690.option("version", _ENV))
        else
            return textcase.uppercase(bib.version)
        end
    end,
    titleaddon = function(_ENV) return U.brackets(bib.titleaddon) end,
    booktitleaddon = function(_ENV) return U.brackets(bib.booktitleaddon) end,
    maintitleaddon = function(_ENV) return U.brackets(bib.maintitleaddon) end,

    --- \usebibmacro{editor}
    editor = function(_ENV)
        -- TODO: dunno how to implement this, not sure what it should do
        return bib.editor
    end,
    --- \usebibmacro{editor}
    author = function(_ENV)
        -- TODO: dunno how to implement this, not sure what it should do
        return bib.author
    end,
    namesPrimary = function(_ENV)
        local primary
        if ISO690.option("useauthor", _ENV) and bib.author then
            primary = ISO690.author
        else
            primary = ISO690.editor
        end
        return ISO690.combine(primary, U.unit(" "), U.brackets(bib.nameaddon))
    end,
    namesSubsidiary = function(_ENV)
        return U.combine(
                U.optional(ISO690.option("byeditor", _ENV), bib.editor),
                U.newunit,
                U.optional(ISO690.option("bytranslator", _ENV), bib.bytranslator))
    end,
    editorType = function(_ENV)
        return U.parens(bib.editortype)
    end,
    editortypedelim = " ",--todo needed?
    thesissupervisor = function(_ENV)
        if bib.supervisor then
            return U.combine(ISO690.option("bysupervisor", _ENV), U.unit(" "), ISO690.printNames(bib.supervisor))
        else
            return nil
        end
    end,

    titles = function(titleprefix, italic)
        return function(_ENV)
            local title = bib[titleprefix.."title"]
            local subtitle = bib[titleprefix.."subtitle"]
            if not title and not subtitle then
                return U.combine(U.unit(" "), U.brackets(bib[titleprefix.."titleaddon"]), U.newunit)
            end

            if italic then
                return U.combine(U.italic(title, U.unit(ISO690.option("titleSubtitleDelimiter", _ENV)), subtitle), U.unit(" "), U.brackets(bib[titleprefix.."titleaddon"]), U.newunit)
            end

            return U.combine(title, ISO690.option("titleSubtitleDelimiter", _ENV), subtitle, U.unit(" "), U.brackets(bib[titleprefix.."titleaddon"]), U.newunit)
        end
    end,
    volumePart = function(_ENV)
        if bib.volume then
            U.combine(ISO690.volume(_ENV), bib.part, U.unit(", "))
        else
            return nil
        end
    end,
    multiTitles = function(_ENV)
        if bib.maintitle == nil then
            if bib.booktitle == nil then
                return ISO690.titles("", true)
            else
                return U.combine(ISO690.titles("", true), ISO690.volumePart, ISO690.titles("titles"))
            end
        else
            return U.combine(ISO690.titles("main", true), ISO690.volumePart, ISO690.titles("titles"))
        end
    end,
    hostTitles = function(_ENV)
        if bib.maintitle == nil then
            if bib.booktitle == nil then
                return nil
            else
                return ISO690.titles("book", true)
            end
        else
            return ISO690.titles("main", true)
        end
    end,
    periodicalTitles = function(_ENV)
        return U.combine(
                ISO690.titles("", true), U.newunit,
                bib.issuetitle and (
                        ISO690.titles("issue")
                ) or (
                        bib.journaltitle and "" or ISO690.titles("journal")
                )
        )
    end,

    mediumType = function(_ENV)
        if bib.howpublished then
            return U.brackets(bib.howpublished)
        elseif bib.urlyear then
            return "[online]"
        else
            return nil
        end
    end,

    fulldate = function(_ENV)
        -- \printtext{\csname mkbibrangeiso8601\endcsname{\thefield{date}}}%
    end,
    date = function(_ENV)
        return bib.date --TODO
        -- \iffieldequalstr{endyear}{}%         <- "if date is an open range"
        --    {\printdate\mbox{\addnbspace}}%
        --    {\printdate}%
    end,
    locationPublisherDate = function(_ENV)
        return U.combine(ISO690.printList(bib.location),
                bib.publisher and U.backunit(ISO690.option("titleSubtitleDelimiter", _ENV)) or U.backunit(", "),
                ISO690.printList(bib.publisher), U.backunit(", "),
                ISO690.date, U.newunit)
    end,

    serialNumeration = function(_ENV)
        return U.combine(ISO690.volume(_ENV), ISO690.option("ShortNumeration", _ENV) and "" or U.backunit(", "), ISO690.number(_ENV))
    end,
    bookNumeration = function(_ENV)
        return U.combine(ISO690.volume(_ENV), U.backunit(", "), ISO690.chapter(_ENV))
    end,
    seriesAndNumber = function(_ENV)
        return U.combine(bib.series, U.backunit(", "), ISO690.number(_ENV))
    end,
    identifier = function(_ENV)
        if not ISO690.option("ShowISBN", _ENV) then
            return nil
        end
        return U.combine(
                ISO690.isan(_ENV), U.newunit,
                ISO690.isbn(_ENV), U.newunit,
                ISO690.ismn(_ENV), U.newunit,
                ISO690.isrn(_ENV), U.newunit,
                ISO690.issn(_ENV), U.newunit,
                ISO690.iswc(_ENV), U.newunit
        )
    end,
    fromDoi = function(_ENV)
        return U.combine(ISO690.option("urlfrom", _ENV), " ", ISO690.doi)
    end,
    fromEprint = function(_ENV)
        return U.combine(ISO690.option("urlfrom", _ENV), " ", bib.eprint)
    end,
    availabilityAccess = function(_ENV)
        if bib.doi == nil then
            if bib.eprint == nil then
                if ISO690.option("ShowURL", _ENV) then
                    return ISO690.url
                end
            else
                if ISO690.option("ShowEprint", _ENV) then
                    return ISO690.fromEprint
                end
            end
        else
            if ISO690.option("ShowDOI", _ENV) then
                return ISO690.fromDoi
            end
        end
        return nil
    end,
    location = function(_ENV)
        -- TODO This seems pretty weird
        if bib.library then
            return U.combine(ISO690.prepAt, bib.library)
        else
            return nil
        end
    end,

    prepIn = function(_ENV)
        return U.combine(ISO690.option("prepIn", _ENV), ISO690.option("intitlepunct", _ENV))
    end,
    prepAt = function(_ENV)
        return U.combine(ISO690.option("at", _ENV), ISO690.option("intitlepunct", _ENV))
    end
}

return {
    book = function(_ENV)
        return U.finalExpansion(U.combine(
                -- \usebibmacro{names:primary}\setunit{\labelnamepunct}\newblock
                ISO960.namesPrimary, ISO690.option("nameTitleDelimiter", _ENV), U.block,
                -- \usebibmacro{multi:titles}\setunit{\addspace}\usebibmacro{medium-type}\newunit\newblock
                ISO960.multiTitles, U.unit(" "), ISO960.mediumType, U.newunit, U.block,
                -- \printfield{edition}\newunit\newblock
                ISO960.edition, U.newunit, U.block,
                -- \usebibmacro{names:subsidiary}\newunit\newblock
                ISO960.namesSubsidiary, U.newunit, U.block,
                -- \usebibmacro{location+publisher+date}\newunit\printfield{version}\setunit{\addspace}\usebibmacro{urldate}\newunit\newblock
                ISO960.locationPublisherDate, U.newunit, ISO960.version, U.unit(" "), ISO960.urlDate, U.newunit, U.block,
                -- \usebibmacro{series+number}\newunit\newblock
                ISO960.seriesAndNumber, U.newunit, U.block,
                -- \usebibmacro{identifier}\newunit\newblock
                ISO960.identifier, U.newunit, U.block,
                -- \usebibmacro{availability+access}\newunit\newblock
                ISO960.availabilityAccess, U.newunit, U.block,
                -- \usebibmacro{location}\setunit{\addspace}\iftoggle{bbx:totalpages}{\printfield{pagetotal}}{}\newunit\newblock
                ISO960.location, U.unit(" "), totalPages --[[TODO]] and ISO960.pagetotal or nil, U.newunit, U.block,
                -- \printfield{note}\newunit\newblock
                ISO960.note, U.newunit, U.block,
                -- \setunit{\bibpagerefpunct}\newblock
                U.unit(ISO690.option("bibpagerefpunct", _ENV)), U.block,
                -- \usebibmacro{pageref}
                ISO960.pageref
        ), {_ENV})
    end,

    periodical = function(_ENV)
        return U.finalExpansion(U.combine(
                -- \usebibmacro{names:primary}\setunit{\labelnamepunct}\newblock
                ISO960.namesPrimary, ISO690.option("nameTitleDelimiter", _ENV), U.block,
                -- \usebibmacro{periodical:titles}\setunit{\addspace}\usebibmacro{medium-type}\newunit\newblock
                ISO960.periodicalTitles, U.unit(" "), ISO960.mediumType, U.newunit, U.block,
                -- \printfield{edition}\newunit\newblock
                ISO960.edition, U.newunit, U.block,
                -- \usebibmacro{location+publisher+date}\setunit*{\addcomma\addspace}\usebibmacro{serial:numeration}\setunit{\addspace}\usebibmacro{urldate}\newunit\newblock
                ISO960.locationPublisherDate, U.backunit(", "), ISO960.serialNumeration, U.unit(" "), ISO960.urlDate, U.newunit, U.block,
                -- \usebibmacro{identifier}\newunit\newblock
                ISO960.identifier, U.newunit, U.block,
                -- \usebibmacro{availability+access}\newunit\newblock
                ISO960.availabilityAccess, U.newunit, U.block,
                -- \usebibmacro{location}\newunit\newblock
                ISO960.location, U.newunit, U.block,
                -- \printfield{note}\newunit\newblock,
                ISO960.note, U.newunit, U.block,
                -- \setunit{\bibpagerefpunct}\newblock
                U.unit(ISO690.option("bibpagerefpunct", _ENV)), U.block,
                -- \usebibmacro{pageref}
                ISO960.pageref
        ), {_ENV})
    end,

    article = function(_ENV)
        return U.finalExpansion(U.combine(
                -- \usebibmacro{names:primary}\setunit{\labelnamepunct}\newblock
                ISO960.namesPrimary, ISO690.option("nameTitleDelimiter", _ENV), U.block,
                -- \usebibmacro{titles}{}{}\newunit\newblock
                ISO960.titles(""), U.newunit, U.block,
                -- \usebibmacro{titles}{journal}{emph}\setunit{\addspace}\usebibmacro{medium-type}\newunit\newblock
                ISO960.titles("journal", true), U.unit(" "), ISO960.mediumType, U.newunit, U.block,
                -- \printfield{edition}\newunit\newblock
                ISO960.edition, U.newunit, U.block,
                -- \usebibmacro{date}\setunit*{\addcomma\addspace}\usebibmacro{serial:numeration}\setunit{\bibpagespunct}\printfield{pages}\setunit{\addspace}\usebibmacro{urldate}\newunit\newblock
                ISO960.date, U.backunit(", "), ISO960.serialNumeration, U.unit(ISO690.option("bibpagespunct", _ENV)), ISO960.pages, U.unit(" "), ISO960.urldate, U.newunit, U.block,
                -- \usebibmacro{identifier}\newunit\newblock
                ISO960.identifier, U.newunit, U.block,
                -- \usebibmacro{availability+access}\newunit\newblock
                ISO960.availabilityAccess, U.newunit, U.block,
                -- \usebibmacro{location}\newunit\newblock
                ISO960.location, U.newunit, U.block,
                -- \printfield{note}\setunit{\bibpagerefpunct}\newblock
                ISO960.note, U.unit(ISO690.option("bibpagerefpunct", _ENV)), U.block,
                -- \usebibmacro{pageref}
                ISO960.pageref
        ), {_ENV})
    end,

    inbook = function(_ENV)
        return U.finalExpansion(U.combine(
                -- \usebibmacro{names:primary}\setunit{\labelnamepunct}\newblock
                ISO960.namesPrimary, ISO690.option("nameTitleDelimiter", _ENV), U.block,
                -- \usebibmacro{titles}{}{}\newunit\newblock
                ISO960.titles(""), U.newunit, U.block,
                -- \usebibmacro{in:}\printnames{bookauthor}\newunit\newblock
                ISO960.prepIn, ISO690.printNames(bib.bookauthor), U.newunit, U.block,
                -- \usebibmacro{host:titles}\setunit{\addspace}\usebibmacro{medium-type}\newunit\newblock
                ISO960.hostTitles, U.unit(" "), ISO960.mediumType, U.newunit, U.block,
                -- \printfield{edition}\newunit\newblock
                ISO960.edition, U.newunit, U.block,
                -- \usebibmacro{names:subsidiary}\newunit\newblock
                ISO960.namesSubsidiary, U.newunit, U.block,
                -- \usebibmacro{location+publisher+date}\setunit*{\addcomma\addspace}\usebibmacro{book:numeration}\setunit{\bibpagespunct}\printfield{pages}\newunit
                ISO960.locationPublisherDate, U.backunit(", "), ISO960.bookNumeration, U.unit(ISO690.option("bibpagespunct", _ENV)), ISO690.pages, U.newunit,
                -- \printfield{version}\setunit{\addspace}\usebibmacro{urldate}\newunit\newblock
                ISO690.version, U.unit(" "), ISO690.urldate, U.newunit, U.block,
                -- \usebibmacro{series+number}\newunit\newblock
                ISO690.seriesAndNumber, U.newunit, U.block,
                -- \usebibmacro{identifier}\newunit\newblock
                ISO960.identifier, U.newunit, U.block,
                -- \usebibmacro{availability+access}\newunit\newblock
                ISO960.availabilityAccess, U.newunit, U.block,
                -- \usebibmacro{location}\newunit\newblock
                ISO960.location, U.newunit, U.block,
                -- \printfield{note}\newunit\newblock
                ISO960.note, U.newunit, U.block,
                -- \setunit{\bibpagerefpunct}\newblock
                U.unit(ISO690.option("bibpagerefpunct", _ENV)), U.block,
                -- \usebibmacro{pageref}
                ISO960.pageref
        ), {_ENV})
    end,

    incollection = function(_ENV)
        return U.finalExpansion(U.combine(
        -- \usebibmacro{names:primary}\setunit{\labelnamepunct}\newblock
                ISO960.namesPrimary, ISO690.option("nameTitleDelimiter", _ENV), U.block,
        -- \usebibmacro{titles}{}{}\newunit\newblock
                ISO960.titles(""), U.newunit, U.block,
        -- \usebibmacro{in:}\usebibmacro{editor}\newunit\newblock
                ISO960.prepIn, ISO690.editor, U.newunit, U.block,
        -- \usebibmacro{host:titles}\setunit{\addspace}\usebibmacro{medium-type}\newunit\newblock
        -- \printfield{edition}\newunit\newblock
                ISO960.edition, U.newunit, U.block,
        -- \usebibmacro{names:subsidiary}\newunit\newblock
        -- \usebibmacro{location+publisher+date}\setunit*{\addcomma\addspace}\usebibmacro{book:numeration}\setunit{\bibpagespunct}\printfield{pages}\newunit
                ISO960.locationPublisherDate, TODOOO
        -- \printfield{version}\setunit{\addspace}\usebibmacro{urldate}\newunit\newblock
        -- \usebibmacro{series+number}\newunit\newblock
        -- \usebibmacro{identifier}\newunit\newblock
                ISO960.identifier, U.newunit, U.block,
        -- \usebibmacro{availability+access}\newunit\newblock
                ISO960.availabilityAccess, U.newunit, U.block,
        -- \usebibmacro{location}\newunit\newblock
                ISO960.location, U.newunit, U.block,
        -- \printfield{note}\newunit\newblock
                ISO960.note, U.newunit, U.block,
        -- \setunit{\bibpagerefpunct}\newblock
                U.unit(ISO690.option("bibpagerefpunct", _ENV)), U.block,
        -- \usebibmacro{pageref}
                ISO960.pageref
        ), {_ENV})
    end,

    online = function(_ENV)
        return U.finalExpansion(U.combine(
        -- \usebibmacro{names:primary}\setunit{\labelnamepunct}\newblock
                ISO960.namesPrimary, ISO690.option("nameTitleDelimiter", _ENV), U.block,
        -- \usebibmacro{multi:titles}\setunit{\addspace}\usebibmacro{medium-type}\newunit\newblock
        -- \printfield{edition}\newunit\newblock
                ISO960.edition, U.newunit, U.block,
        -- \usebibmacro{names:subsidiary}\newunit\newblock
        -- \usebibmacro{location+publisher+date}\newunit
                ISO960.locationPublisherDate, U.newunit,
        -- \printfield{version}\setunit{\addspace}\usebibmacro{urldate}\newunit\newblock
        -- \usebibmacro{series+number}\newunit\newblock
        -- \usebibmacro{identifier}\newunit\newblock
                ISO960.identifier, U.newunit, U.block,
        -- \usebibmacro{availability+access}\setunit{\addspace}\iftoggle{bbx:totalpages}
        --     {\printfield{pagetotal}}
        --     {}\printfield{note}\newunit\newblock
                ISO960.availabilityAccess, TODOOOOOOOOOOOOOOOOOOOOOOO
        -- \setunit{\bibpagerefpunct}\newblock
                U.unit(ISO690.option("bibpagerefpunct", _ENV)), U.block,
        -- \usebibmacro{pageref}
                ISO960.pageref
        ), {_ENV})
    end,

    thesis = function(_ENV)
        return U.finalExpansion(U.combine(
        -- \usebibmacro{names:primary}\setunit{\labelnamepunct}\newblock
                ISO960.namesPrimary, ISO690.option("nameTitleDelimiter", _ENV), U.block,
        -- \usebibmacro{titles}{}{emph}\setunit{\addspace}\usebibmacro{medium-type}\newunit\newblock
                ISO960.titles("", true), U.unit(" "), ISO960.mediumType, U.newunit, U.block,
        -- \usebibmacro{location+publisher+date}\newunit
                ISO960.locationPublisherDate, U.newunit,
        -- \printfield{version}\setunit{\addspace}\usebibmacro{urldate}\newunit\newblock
        -- \usebibmacro{identifier}\newunit\newblock
                ISO960.identifier, U.newunit, U.block,
        -- \iftoggle{bbx:thesisinfoinnotes}
        --     {}
        --     {\printfield{type}\newunit\newblock\printlist{institution}\newunit\newblock\usebibmacro{thesissupervisor}}\newunit\newblock
        -- \usebibmacro{availability+access}\setunit{\addspace}\iftoggle{bbx:totalpages}{\printfield{pagetotal}}{}\newunit\newblock
                ISO960.availabilityAccess, TODOOOO
        -- \iftoggle{bbx:thesisinfoinnotes}
        --     {\printfield{type}\newunit\newblock
        --     \printlist{institution}\newunit\newblock
        --     \usebibmacro{thesissupervisor}}
        --     {}\newunit\newblock
        -- \printfield{note}\newunit\newblock
                ISO960.note, U.newunit, U.block,
        -- \setunit{\bibpagerefpunct}\newblock
                U.unit(ISO690.option("bibpagerefpunct", _ENV)), U.block,
        -- \usebibmacro{pageref}
                ISO960.pageref
        ), {_ENV})
    end,

    patent = function(_ENV)
        return U.finalExpansion(U.combine(
        -- \usebibmacro{names:primary}\setunit{\labelnamepunct}\newblock
                ISO960.namesPrimary, ISO690.option("nameTitleDelimiter", _ENV), U.block,
        -- \usebibmacro{titles}{}{emph}\newunit\newblock
                ISO960.titles("", true), U.newunit, U.block,
        -- \usebibmacro{names:subsidiary}\newunit\newblock
                ISO960.namesSubsidiary, U.unit(" "), ISO960.mediumType, U.newunit, U.block,
        -- \printfield{classification}\newunit\newblock
                bib.classification, U.newunit, U.block,
        -- \printlist{location}\newunit\newblock
                ISO960.location, U.newunit, U.block,
        -- \iffieldundef{type}{}{\printfield{type}\setunit*{\addcomma\space}}\printfield{number}\newunit\newblock
        -- \usebibmacro{fulldate}\setunit{\addspace}\usebibmacro{urldate}\newunit\newblock
        -- \printfield{note}\newunit\newblock
                ISO960.note, U.newunit, U.block,
        -- \usebibmacro{availability+access}\newunit\newblock
                ISO960.availabilityAccess, U.newunit, U.block,
        -- \setunit{\bibpagerefpunct}\newblock
                U.unit(ISO690.option("bibpagerefpunct", _ENV)), U.block,
        -- \usebibmacro{pageref}
                ISO960.pageref
        ), {_ENV})
    end
}