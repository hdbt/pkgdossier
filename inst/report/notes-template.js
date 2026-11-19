// The hand-written reading of a dossier. write_dossier_html() copies this file into the
// report folder once (or the notes file you pass); edit the copy there. Strings may
// hold inline HTML (<code>...</code>).
//
// findings  -- the changes a user of the baseline meets first, most reach x size first.
//   kind:  "code" (does old code still run), "estimate", "output", "time", "plot"
//   what:  one line, the change with its numbers ("Main estimate moves: 0.50 to 0.60")
//   why:   two to four plain sentences: what moved, by how much, why, and whether the
//          NEWS file says so
//   see:   the anchor of the evidence: a scenario id ("intro") or
//          "<scenario>-<step>" ("intro-estimate")
// scenarios -- per scenario id, two or three takeaways in plain sentences.
// method    -- run-specific caveats (dependency versions, what the scenarios do not
//              cover, a busy machine); the generic method notes are in the page.
window.NOTES = {
  findings: [
    // {kind: "estimate", see: "intro-estimate",
    //  what: "...", why: "..."}
  ],
  scenarios: {
    // intro: {takeaways: ["...", "..."]}
  },
  method: [
    // "Dependencies from the shared library; new users would get newer versions."
  ]
};
