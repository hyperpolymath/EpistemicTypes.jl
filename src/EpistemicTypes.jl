module EpistemicTypes

# EpistemicTypes — per-row "claims with receipts" for taxonomic pipelines.
#
# Forged from the hyperpolymath julia-library archetype (2026).
#
# RECOVERY NOTE
#   The substance of this package is `src/core/Epistemic.jl`, restored
#   VERBATIM from the Arena.ai thread "Clades and Other Prompts"
#   (2026-09-16) where it was written and never pushed. It is byte-identical
#   to the recovered source apart from TWO fixes, each marked `RECOVERY FIX`
#   at its site, and each of which the code could not run without:
#
#     1. `using Base64` was missing, though `base64encode` is called.
#     2. `b64url` passed its replacement pairs as a TUPLE rather than
#        splatted, so `replace` threw MethodError on every receipt.
#
#   Both are mechanical. No threshold, name, signature scheme or docstring
#   was touched. The code had clearly never been executed.
#
#   The module inside is named `Epistemic`, and the recovered file header
#   names its path as `src/core/Epistemic.jl`; both are preserved. This outer
#   module carries the package name that `Protoctist.jl` imports.
#
#   docs/recovered/ holds the unmodified extracts.

# --- implementation ------------------------------------------------------

include("core/Epistemic.jl")

# The recovered module declares no `export`s of its own — it was written to be
# reached as `Epistemic.f`. Name each binding explicitly rather than adding
# exports to the recovered file, which is kept verbatim.
using .Epistemic: Standpoint, Warrant, ProjectionY, Receipt, ThresholdPolicy,
                  ResidualInfo, ZeroKind,
                  make_receipt, verify_receipt, encode_avec_fibre, parse_avec_fibre,
                  passes_gates, highest_warranted_rank, epi_status, disambiguate_zero,
                  residual_info, can_merge, lowest_common_rank,
                  ComputeBackend, CPUBackend, TPUBackend, NPUBackend, VPUBackend,
                  bulk_verify!

# --- public API ----------------------------------------------------------

# Submodule, for callers who want the recovered namespace unflattened.
export Epistemic

# Core types (Standpoint / Warrant / ProjectionY are the "fibre"; Receipt
# binds them with a signature).
export Standpoint, Warrant, ProjectionY, Receipt, ThresholdPolicy, ResidualInfo, ZeroKind

# Receipt API — construct, verify, and the CSV-portable wire form.
export make_receipt, verify_receipt, encode_avec_fibre, parse_avec_fibre

# Policy, gates and the claim decision.
export passes_gates, highest_warranted_rank, epi_status, disambiguate_zero

# Residual evidence and cross-run safety.
export residual_info, can_merge, lowest_common_rank

# Backends. CPUBackend is the one you want; the others exist to refuse.
export ComputeBackend, CPUBackend, TPUBackend, NPUBackend, VPUBackend, bulk_verify!

end # module EpistemicTypes
