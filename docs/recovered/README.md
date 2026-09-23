# Recovered source

Everything in this directory is **evidence**, not build input. It is the raw
material `src/` was restored from, kept so the restoration can be audited
against what was actually written.

## Where it came from

The work was done in an Arena.ai conversation titled **"Clades and Other
Prompts"** (id `01a0a9f1-d658-7865-9fd2-0aa633ea26d7`, created 2026-09-16) and
was never pushed to any forge. It was recovered on **2026-09-23** by sweeping
the full 449-conversation account index; Arena's own search matches
conversation *titles only*, never message bodies, which is why searching for
"Epistemic" or "Cladistics" there returned nothing.

## What is here

| Path | What it is |
|---|---|
| `code-blocks/*.jl` | All 23 Julia blocks from the thread, verbatim, in thread order. 1,607 lines total. |
| `DESIGN-SPEC-recovered.md` | The 14 prose passages specifying the design, extracted in order. |

## How `src/` relates to it

`src/core/Epistemic.jl` **is** `code-blocks/16-Epistemic.jl` — 398 lines,
byte-identical apart from **two** fixes, each marked `RECOVERY FIX` at its
site:

1. **`using Base64` was missing.** The module calls `base64encode`, so it
   could not have loaded as written.
2. **`b64url` passed its replacement pairs as a tuple** —
   `replace(s, ('+'=>'-', '/'=>'_', '='=>""))` — where
   `replace(::AbstractString, ::Pair...)` wants them splatted. It threw
   `MethodError` on every call, which is to say on every receipt, every
   signature and every status decision.

Together these mean **the recovered code had never been executed**. That is
worth knowing when reading it: the logic was reasoned out, not run. Both fixes
are mechanical and neither touches a name, a threshold, the signature scheme or
a docstring.

The smaller `*-Epistemic.jl` blocks (67–120 lines) are **earlier iterations of
the same module**, superseded by block 16. They are kept because they record
how the design moved, and because a few carry commentary that block 16 dropped.

Blocks that belong to the sibling packages rather than to this one:

* `01-evidence.jl` — `src/core/evidence.jl`, 99 lines
* `12-block.jl` — `AnalysisConfig`
* `18-block.jl` — `MemSpace`, from the MetaManifold discussion the thread grew out of
* `19-block.jl` — `Role`
* `21-block.jl` — a CUDA / KernelAbstractions sketch
* `22-block.jl` — the 20-line usage example that imports `Protoctist`,
  `EpistemicTypes` and `Cladistics` together; this is the clearest statement of
  how the family is meant to fit, and is what fixed this package's name.

## Known fragilities in the recovered code, left as written

These are real and are **deliberately not silently fixed** — they are pinned by
tests instead, so the behaviour cannot drift without someone noticing:

1. `encode_avec_fibre` joins raw JSON with `&` and `=`, and
   `parse_avec_fibre` splits on those characters. The docstring says values
   "are percent-encoded when embedded into CSV", but no encoding happens here.
   A taxon name containing `&` would break the round-trip.
2. `lowest_common_rank` is documented as returning "the finest rank that exists
   in both" but returns the first entry of its first argument found in the
   second — order-dependent, not a finest-rank search. With coarse-first
   ladders it returns the coarsest shared rank, which is the conservative
   answer a collapse wants, so the behaviour is defensible; the docstring is
   what is wrong.
