local BE = Bibliography.BibliographyElements

return {
    book = function(env)
        return
        BE.andAuthors, " ", env.bib.year, ". ", BE.italic(env.bib.title), ". ",
        BE.optional(BE.transEditor, ". "), env.bib.address, ": ", env.bib.publisher, "."
    end,

    article = function(env)
        return
        BE.andAuthors, ". ", env.bib.year, ". ", BE.quotes(env.bib.title, "."), " ",
        BE.italic(env.bib.journal), " ", BE.parens(env.bib.volume), env.bib.number,
        BE.optional(":", env.bib.pages)
    end
}