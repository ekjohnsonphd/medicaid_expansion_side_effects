// A0 portrait poster, three columns. Written for this project because the
// Quarto poster extensions need network access to install.
//
// Panels are level-2 headings (## in the .qmd). Typst flows the body through
// the columns automatically; #colbreak() in a {=typst} block forces a break.

#let navy   = rgb("#22303F")
#let treat  = rgb("#00706A")
#let ctrl   = rgb("#C77D0A")
#let warm   = rgb("#6C757D")
#let light  = rgb("#CCD3D9")
#let pale   = rgb("#EDF3F8")

#let poster(
  title: none, subtitle: none, authors: (), venue: none,
  takeaway: none, takeaway-sub: none,
  cols: 3, gutter: 22mm, doc,
) = {
  // The takeaway banner must span all three columns, so it lives in the page
  // footer rather than in the flowed body.
  set page(paper: "a0", margin: (x: 26mm, top: 24mm, bottom: 116mm),
    footer: if takeaway != none {
      block(width: 100%)[
        #line(length: 100%, stroke: 4pt + rgb("#00706A"))
        #v(7mm)
        #align(center)[
          #text(size: 44pt, weight: "bold", fill: rgb("#22303F"))[#takeaway]
          #v(5mm)
          #if takeaway-sub != none {
            text(size: 29pt, fill: rgb("#6C757D"))[#takeaway-sub]
          }
        ]
      ]
    },
    footer-descent: 0mm)
  set text(font: ("Helvetica", "Arial"), size: 29pt, fill: navy, lang: "en")
  set par(justify: false, leading: 0.62em)
  set block(spacing: 1.05em)

  // ---- header ----
  align(center)[
    #text(size: 86pt, weight: "bold")[#title]
    #v(7mm)
    #if subtitle != none { text(size: 42pt, fill: warm)[#subtitle] }
    #v(10mm)
    #if authors.len() > 0 { text(size: 36pt)[#authors.join(", ")] }
    #v(4mm)
    #if venue != none { text(size: 27pt, fill: warm)[#venue] }
  ]
  v(7mm)
  line(length: 100%, stroke: 4pt + treat)
  v(9mm)

  // ---- panel headings ----
  // Pandoc shifts headings up by one when the document has a YAML title, so
  // `##` in the .qmd arrives here as level 1 and `###` as level 2.
  show heading.where(level: 1): it => block(above: 9mm, below: 5mm, width: 100%)[
    #line(length: 100%, stroke: 2.5pt + light)
    #v(4mm)
    #text(size: 38pt, weight: "bold", fill: navy)[#it.body]
  ]
  // `###` in the .qmd marks the highlighted panel.
  show heading.where(level: 2): it => block(above: 9mm, below: 5mm, width: 100%)[
    #line(length: 100%, stroke: 5pt + treat)
    #v(4mm)
    #text(size: 38pt, weight: "bold", fill: treat)[#it.body]
  ]

  show figure: it => align(center, it.body)          // no captions or numbering
  show table: set text(size: 26pt)
  set table(stroke: none, inset: (x: 5pt, y: 4pt))

  // strong text in the project's blue, so numbers pop without extra markup
  show strong: it => text(fill: treat, weight: "bold")[#it.body]

  columns(cols, gutter: gutter, doc)
}

// Small grey caption text, used under figures.
#let note(body) = block(width: 100%, above: 5mm, below: 6mm,
  text(size: 23pt, fill: rgb("#6C757D"))[#body])
