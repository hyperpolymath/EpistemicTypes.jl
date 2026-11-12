module EpistemicTypes

# EpistemicTypes — per-row "claims with receipts" for taxonomic pipelines.
#
# The implementation is `src/core/Epistemic.jl`, restored from the design
# thread "Clades and Other Prompts" (2026-09-16). It matches the recovered
# source (docs/recovered/code-blocks/16-Epistemic.jl) apart from seven
# marked changes:
#
#   RECOVERY FIX (2) — changes the code could not run without:
#     1. `using Base64` was missing, though `base64encode` is called.
#     2. `b64url` passed its replacement pairs as a TUPLE rather than
#        splatted, so `replace` threw MethodError on every receipt.
#
#   POST-RECOVERY FIXES (3), for wrong verdicts, each pinned by a test:
#     3. `can_merge` returned OK_COLLAPSE with `collapse_to === nothing` when
#        two releases of one database share no rank; it now refuses, as the
#        db-key branch always did.
#     4. `disambiguate_zero` read the feature's own count, which is 0 in a
#        zero cell, so it never returned true_absence. It now takes the
#        sample's library size and the new `ThresholdPolicy.sample_depth_min`.
#     5. `can_merge` collapsed a key or release mismatch to the coarsest
#        shared rank. The caller now names the rank (`collapse_to`), and the
#        verdict refuses until it does.
#
#   POST-RECOVERY CHANGES (2), to the interface:
#     6. Wire format echo:v2 percent-encodes every value, so a field holding
#        '&' round-trips. echo:v1 strings are still read.
#     7. The TPU/NPU/VPU stub backends are removed, and `bulk_verify!` is
#        renamed `bulk_verify` (the old name is deprecated).
#
#   Docstrings now say "digest", not "signature": `sig` has no key. No
#   threshold or digest scheme was otherwise touched.
#   The inner module keeps its recovered name, `Epistemic`; this outer module
#   carries the package name.

# --- implementation ------------------------------------------------------

include("core/Epistemic.jl")

# The recovered module declares no `export`s of its own — it was written to be
# reached as `Epistemic.f`. Name each binding explicitly rather than adding
# exports to the recovered file, which is kept as recovered.
using .Epistemic:
    Standpoint,
    Warrant,
    ProjectionY,
    Receipt,
    ThresholdPolicy,
    ResidualInfo,
    ZeroKind,
    make_receipt,
    verify_receipt,
    encode_avec_fibre,
    parse_avec_fibre,
    passes_gates,
    highest_warranted_rank,
    epi_status,
    disambiguate_zero,
    residual_info,
    can_merge,
    lowest_common_rank,
    ComputeBackend,
    CPUBackend,
    bulk_verify,
    bulk_verify!

# --- public API ----------------------------------------------------------

# Submodule, for callers who want the recovered namespace unflattened.
export Epistemic

# Core types (Standpoint / Warrant / ProjectionY are the "fibre"; Receipt
# binds them with a SHA-256 digest).
export Standpoint, Warrant, ProjectionY, Receipt, ThresholdPolicy, ResidualInfo, ZeroKind

# Receipt API — construct, verify, and the CSV-portable wire form.
export make_receipt, verify_receipt, encode_avec_fibre, parse_avec_fibre

# Policy, gates and the claim decision.
export passes_gates, highest_warranted_rank, epi_status, disambiguate_zero

# Residual evidence and cross-run safety.
export residual_info, can_merge, lowest_common_rank

# Backends. CPUBackend is the only one; `bulk_verify!` is a deprecated alias.
# Coprocessor contracts live in CoprocessorRuntime.jl, not here.
export ComputeBackend, CPUBackend, bulk_verify, bulk_verify!

end # module EpistemicTypes
