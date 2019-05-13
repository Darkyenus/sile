local std = require("std")
local textcase = SILE.require("packages/textcase").exports

---------------------------
--- Bibliography global ---
---------------------------
-- Public programmatic API for this package
-- Stateless, pure in regards to other globals

Bibliography = {
    --- Available engines, that provide citations and bibliographies
    --- User can provide additional engines
    --- Loaded via \loadbibliography[id=engineName]
    Engines = {
        --[[
        engineName = function (options) {
            return {
                -- Called when the bibliography entry is first cited
                -- Returns tex-like string, AST table, or nil if this engine doesn't know this key
                citation = function(key, options)
                    return <author>..""..<year>
                end,
                -- Called when creating bibliography for bibliography entry
                -- Returns tex-like string, AST table, or nil if this engine doesn't know this key
                -- Second return is an string to sort by in full bibliography
                bibliography = function(key, options)
                    return <author>.." "..<name>.." "..<year>
                end
            }
        }
        ]]
    },

    --- Add given engine to the pool of available engines
    loadEngine = function(name, engine)
        engine = engine or SILE.require("packages/bibengines/"..name)
        Bibliography.Engines[name] = engine
        return engine
    end,

    --- Creates an engine from the engine pool, possibly loading that engine first
    createEngine = function(name, options)
        local constructor = Bibliography.Engines[name]
        if constructor == nil then
            constructor = Bibliography.loadEngine(name)
        end

        if type(constructor) == "table" then
            return constructor
        elseif type(constructor) == "function" then
            return constructor(options)
        else
            SU.error("Bibliography engine '"..name.."' is invalid: "..type(constructor))
        end
    end,

    --- Given citation key and citing options, produce an AST
    --- which can be typeset to get a citation mark
    produceCitation = function(engines, key, options)
        if #engines == 0 then
            SU.error("Can't cite '"..key.."', no engines loaded")
        end
        for _, engine in pairs(engines) do
            local citation = engine.citation(key, options)
            if citation ~= nil then
                if type(citation) == "string" then
                    citation = SILE.texlikeToAST(citation)
                end
                if type(citation) ~= "table" then
                    SU.error("Invalid citation produced for '"..key.."': "..tostring(citation), "bug")
                end
                return citation
            end
        end

        SU.error("Can't cite '"..key.."', not in any bibliography")
    end,

    --- Given citation key and citing options, produce an AST
    --- which can be typeset to get a bibliography entry
    produceBibliography = function(engines, key, options)
        if #engines == 0 then
            SU.error("Can't create bibliography for '"..key.."', no engines loaded")
        end
        for _, engine in pairs(engines) do
            local citation, sortKey = engine.bibliography(key, options)
            if citation ~= nil then
                if type(citation) == "string" then
                    citation = SILE.texlikeToAST(citation)
                end
                if type(citation) ~= "table" then
                    SU.error("Invalid citation produced for '"..key.."': "..tostring(citation), "bug")
                end
                return citation, sortKey
            end
        end

        SU.error("Can't create bibliography for '"..key.."', not in any bibliography engine")
    end,
}

---------------------
--- SILE Commands ---
---------------------
-- Public SILE API for the package
-- Stores its configuration in SILE.scratch.bibliography:
SILE.scratch.bibliography = {
    -- Loaded engines
    engines = {},
    -- All citations that were made with \cite in this document
    references = {
    -- <key> = {
    --      usedOrder = <order in which this was first used>,
    --      referencePending = <whether this was cited since it was last used as a reference>
    -- }
    },
    -- Amount of references in .references. Used for references[].usedOrder
    referencesCount = 0
}

SILE.registerCommand("loadbibliography", function(options, content)
    local engineName = content and SU.contentToString(content)
    local engine = Bibliography.createEngine(engineName, options)

    local biby = SILE.scratch.bibliography
    biby.engines[#biby.engines + 1] = engine
end, "\\loadbibliography[engineOptions]{engineName}")

SILE.registerCommand("cite", function(options, content)
    local key = options.key or SU.contentToString(content)
    local biby = SILE.scratch.bibliography

    local reference = biby.references[key]
    local usedOrder
    if reference == nil then
        usedOrder = biby.referencesCount + 1
        reference = { usedOrder = usedOrder }
        biby.references[key] = reference
        biby.referencesCount = usedOrder
    else
        usedOrder = reference.usedOrder
    end

    options.usedOrder = options.usedOrder or reference.usedOrder

    local citation = Bibliography.produceCitation(biby.engines, key, options)
    SILE.process(citation)
end)

SILE.registerCommand("reference", function(options, content)
    local key = options.key or SU.contentToString(content)
    local biby = SILE.scratch.bibliography

    local bibliography = Bibliography.produceBibliography(biby.engines, key, options)
    SILE.call("raggedright", {}, function()
        SILE.process(bibliography)
    end)
end)

SILE.registerCommand("references", function(options, _)
    local biby = SILE.scratch.bibliography

    local entries = {}
    for k, v in pairs(biby.references) do
        local ast, sortKey = Bibliography.produceBibliography(biby.engines, k, options)
        entries[v.usedOrder] = { key = k, ast = ast, sortKey = { sortKey, v.usedOrder } }
    end

    -- Sorting by sortKey and usedOrder to get a stable sort
    table.sort(entries, function (a, b)
        local aK = a.sortKey
        local bK = b.sortKey
        for i = 1, #aK do
            if aK[i] ~= bK[i] then
                if aK[i] == nil then
                    return true
                end
                if aK[i] < bK[i] then
                    return true
                end
            end
        end
        return false
    end)


    SILE.settings.temporarily(function ()
        SILE.settings.set("document.lskip", SILE.nodefactory.newGlue({width = SILE.length.parse("1.8em")}))
        local indentGlue = SILE.nodefactory.newGlue({width = SILE.length.parse("-1.8em")})
        SILE.settings.set("current.parindent", indentGlue)
        SILE.settings.set("document.parindent", indentGlue)
        for _, entry in pairs(entries) do
            SILE.process(entry.ast)
            SILE.typesetter:endline()
        end
    end)
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