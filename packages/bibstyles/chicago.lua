return {
    book = function(_ENV) return
    andAuthors, " ", bib.year, ". ", italic(bib.title), ". ",
    optional(transEditor, ". "), bib.address, ": ", bib.publisher, "."
    end,

    article = function(_ENV) return
    andAuthors, ". ", bib.year, ". ", quotes(bib.title, "."), " ",
    italic(bib.journal), " ", parens(bib.volume), bib.number,
    optional(":", bib.pages)
    end
}