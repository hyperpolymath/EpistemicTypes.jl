module EpistemicTypes

# EpistemicTypes — per-row "claims with receipts" for taxonomic pipelines.
#
# The implementation is `src/core/Epistemic.jl`, restored from the design
# thread "Clades and Other Prompts" (2026-09-16). It matches the recovered
# source (docs/recovered/code-blocks/16-Epistemic.jl) apart from three
# marked changes:
#
#   RECOVERY FIX (2) — changes the code could not run without:
#     1. `using Base64` was missing, though `base64encode` is called.
#     2. `b64url` passed its replacement pairs as a TUPLE rather than
#        splatted, so `replace` threw MethodError on every receipt.
#
#   POST-RECOVERY FIX (1) — a wrong verdict, corrected and pinned by a test:
#     3. `can_merge` returned OK_COLLAPSE with `collapse_to === nothing` when
#        two releases of one database share no rank; it now refuses, as the
#        db-key branch always did.
#
#   No threshold, name, signature scheme or docstring was otherwise touched.
#   The inner module keeps its recovered name, `Epistemic`; this outer module
#   carries the package name.

# --- implementation ------------------------------------------------------

include("core/Epistemic.jl")

# The recovered module declares no `export`s of its own — it was written to be
# reached as `Epistemic.f`. Name each binding explicitly rather than adding
# exports to the recovered file, which is kept as recovered.
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
