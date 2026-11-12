module Epistemic

# Epistemic.jl
# -----------------------------------------------------------------------------
# PURPOSE
#   Per-row "claims with receipts" (a.k.a. fibres):
#   - Bind each visible taxon/rank to its origin witness (standpoint+warrant+projection) with a digest.
#   - Verify/emit receipts (echo:v2?k=&w=&y=&sig=...) that travel in CSV.
#   - Convert raw classifier scores + sample gates into a warranted claim at the right rank:
#       epi_status ∈ { :Factive, :Belief, :Collapsed, :SansFibre }
#   - Summarize residual evidence (named species candidates; "novel" only after contamination gates).
#   - Provide a safe "can_merge" check for cross-run analyses.
#
# PHILOSOPHY
#   This is not a stats/machine-learning module. It is a rigorous, fast,
#   per-row decision engine. Most functions are O(1) per row. Heavy
#   phylogenetics (IQ-TREE, EPA-ng), alignments (MAFFT), and denoising (DADA2)
#   live elsewhere. We annotate/verify their outputs and enforce safe claims.
#
#   Because the hot path here is trivial per row, specialized accelerators
#   (TPU/NPU/VPU) do not provide meaningful benefit. Still, we define a
#   pluggable "backend" interface to batch/parallelize verification where
#   useful, with a robust CPU backend and documented stubs for others.
# -----------------------------------------------------------------------------

using Dates
using JSON3
using SHA
using Base64   # RECOVERY FIX: base64encode is used below but was never imported
using Base: @kwdef

# -- Utilities ---------------------------------------------------------------

"""
  b64url(x::Vector{UInt8})::String

Base64url without padding, suitable for compact digests inside CSV.
"""
# RECOVERY FIX: the pairs were wrapped in a tuple — `replace(s, (a,b,c))` —
# but `replace(::AbstractString, ::Pair...)` takes them splatted, so this
# threw MethodError on every call. Parentheses removed; nothing else changed.
b64url(x) = replace(base64encode(x), '+'=>'-', '/'=>'_', '='=>"")

"""
  canon(k,w,y)::String

Canonical JSON representation (UTF-8, stable key order) that is signed.
We intentionally write an ordered NamedTuple (k,w,y) so keys are stable.
Floats are written as JSON numbers; if you require fixed-precision
rounding, enforce upstream before constructing `Warrant`.
"""
canon(k, w, y) = JSON3.write((k=k, w=w, y=y); allow_inf=false)

# -- Core Types --------------------------------------------------------------

@kwdef struct Standpoint
  tool::String               # "dada2" | "vsearch" | "consensus" | ...
  tool_ver::String           # "1.28.0" | ...
  db_key::String             # "pr2" | "silva" | "unite"
  db_release::String         # "5.0.0" | "138"
  params_hash::String        # "sha256:..." (hash of the taxonomy/step config)
  normalisation::String      # "none" | "rarefy" | "rss" | "css" | ...
end

@kwdef struct Warrant
  # Classifier evidence (one or more fields may be used depending on tool):
  boot_min::Union{Nothing,Float64} = nothing  # DADA2's genus/species bootstrap (0–1)
  id::Union{Nothing,Float64}       = nothing  # vsearch %identity (0–1)
  cov::Union{Nothing,Float64}      = nothing  # vsearch coverage (0–1)
  # Sample/run gates (evidence predicate E):
  depth::Union{Nothing,Int}        = nothing  # per-feature count in sample
  neg_leak::Union{Nothing,Float64} = nothing  # leakage fraction vs negative control
  chimera::Union{Nothing,Bool}     = nothing  # flagged chimera?
end

@kwdef struct ProjectionY
  taxon::String             # "Giardia"
  rank::String              # "Genus" | "Species" | ...
  feature_id::String        # ASV/OTU identifier
  sample_id::String         # if per-sample row
end

"""
Receipt

The portable witness ("fibre") that binds text to provenance and evidence.
Do not put derived status here; keep it raw. Derived fields (epi_status,
warranted_rank, residual info) are computed at load/analysis time.
"""
@kwdef struct Receipt
  v::String            = "echo:v2"  # wire-format version tag
  k::Standpoint
  w::Warrant
  y::ProjectionY
  sig::String          # "sha256:..." digest over canon(k,w,y); no key
end

# -- Receipt API -------------------------------------------------------------

"""
  make_receipt(k::Standpoint, w::Warrant, y::ProjectionY)::Receipt

Constructs a receipt and computes its digest (sha256 over canon(k,w,y)). The
digest has no key: it detects accidental edits, not deliberate ones.
"""
function make_receipt(k::Standpoint, w::Warrant, y::ProjectionY)::Receipt
  payload = canon(k, w, y)
  sig = "sha256:" * b64url(SHA.sha256(payload))
  Receipt(; k, w, y, sig)
end

"""
  verify_receipt(r::Receipt)::Bool

Verifies `r.sig` matches sha256 over canon(r.k, r.w, r.y).
If false, treat row as :SansFibre or flag in loaders.
"""
function verify_receipt(r::Receipt)::Bool
  payload = canon(r.k, r.w, r.y)
  computed = "sha256:" * b64url(SHA.sha256(payload))
  return computed == r.sig
end

# POST-RECOVERY CHANGE (6): wire format echo:v2. The recovered echo:v1 form
# joined raw JSON with '&' and '=', so a field holding '&' could not round-trip.
# echo:v2 percent-encodes every value (RFC 3986 unreserved bytes pass through).
# echo:v1 strings are still read exactly as before.
_is_unreserved(b::UInt8) =
  (UInt8('A') <= b <= UInt8('Z')) || (UInt8('a') <= b <= UInt8('z')) ||
  (UInt8('0') <= b <= UInt8('9')) || b in (UInt8('-'), UInt8('.'), UInt8('_'), UInt8('~'))

function _pct_encode(s::AbstractString)::String
  io = IOBuffer()
  for b in codeunits(s)
    _is_unreserved(b) ? write(io, b) : print(io, '%', uppercase(string(b; base=16, pad=2)))
  end
  return String(take!(io))
end

function _pct_decode(s::AbstractString)::String
  cu = codeunits(s)
  io = IOBuffer()
  i = 1
  while i <= length(cu)
    if cu[i] == UInt8('%')
      i + 2 <= length(cu) || throw(ArgumentError("truncated percent escape in fibre"))
      write(io, parse(UInt8, String(cu[i+1:i+2]); base=16))
      i += 3
    else
      write(io, cu[i])
      i += 1
    end
  end
  return String(take!(io))
end

"""
  encode_avec_fibre(r::Receipt)::String

URI-like compact value for a CSV column, with every value percent-encoded:
echo:v2?k=<json>&w=<json>&y=<json>&sig=<sha256_base64url>
"""
function encode_avec_fibre(r::Receipt)::String
  qk = _pct_encode(JSON3.write(r.k))
  qw = _pct_encode(JSON3.write(r.w))
  qy = _pct_encode(JSON3.write(r.y))
  return "echo:v2?k=$(qk)&w=$(qw)&y=$(qy)&sig=$(_pct_encode(r.sig))"
end

"""
  parse_avec_fibre(str)::Receipt

Parses a compact `avec_fibre` string (echo:v2, or the older echo:v1) back into
a Receipt whose `v` records the tag it was read from.
Note: We do not verify the digest here; call `verify_receipt` explicitly.
"""
function parse_avec_fibre(str::AbstractString)::Receipt
  tag = startswith(str, "echo:v2?") ? "echo:v2" :
        startswith(str, "echo:v1?") ? "echo:v1" :
        error("Bad fibre version or missing 'echo:v1'/'echo:v2' prefix")
  qs = split(str[9:end], '&')  # after "echo:vN?"
  kv = Dict{String,String}()
  for p in qs
    i = findfirst(==('='), p); i === nothing && continue
    k = p[1:i-1]; v = p[i+1:end]
    kv[k] = tag == "echo:v2" ? _pct_decode(v) : String(v)
  end
  haskey(kv, "k") || error("fibre missing k")
  haskey(kv, "w") || error("fibre missing w")
  haskey(kv, "y") || error("fibre missing y")
  haskey(kv, "sig") || error("fibre missing sig")

  k = JSON3.read(kv["k"], Standpoint)
  w = JSON3.read(kv["w"], Warrant)
  y = JSON3.read(kv["y"], ProjectionY)
  return Receipt(; v=tag, k, w, y, sig=kv["sig"])
end

# -- Policy and Gates --------------------------------------------------------

"""
ThresholdPolicy

Rank thresholds for tools. You can construct this from YAML/JSON at startup.
Example defaults follow the common practice for DADA2/vsearch (tune per DB/locus).
"""
@kwdef struct ThresholdPolicy
  dada2_by_rank::Dict{String,Float64} = Dict("Species"=>0.98, "Genus"=>0.88, "Class"=>0.75, "Division"=>0.70)
  vsearch_by_rank::Dict{String,NamedTuple} = Dict(
    "Species"=>(id=0.99, cov=0.95),
    "Genus"  =>(id=0.95, cov=0.90),
    "Division"=>(id=0.85, cov=0.80)
  )
  depth_min::Int = 100            # minimal per-feature count for any positive claim
  neg_leak_max::Float64 = 0.005   # maximal allowed negative-control leakage (fraction)
  # POST-RECOVERY FIX (4): the sample read total (library size) at which a
  # zero cell counts as an absence. No default: the right value depends on
  # the locus and the study, so disambiguate_zero refuses until it is set.
  sample_depth_min::Union{Nothing,Int} = nothing
end

"""
  passes_gates(w::Warrant, pol::ThresholdPolicy)::Bool

Implements evidence predicate E: sample-level gates (depth/leak/chimera).
Extend here to include replicates, blacklists, placement sanity, etc.
"""
function passes_gates(w::Warrant, pol::ThresholdPolicy)::Bool
  (w.depth !== nothing && w.depth ≥ pol.depth_min) &&
  (w.neg_leak === nothing || w.neg_leak ≤ pol.neg_leak_max) &&
  (w.chimera === nothing || w.chimera == false)
end

"""
  highest_warranted_rank(k::Standpoint, w::Warrant, pol::ThresholdPolicy)::Union{Nothing,String}

Finds the finest (lowest) rank at which the classifier meets the configured threshold.
Note: Does not check gates; combine with `passes_gates` before promoting a claim.
"""
function highest_warranted_rank(k::Standpoint, w::Warrant, pol::ThresholdPolicy)::Union{Nothing,String}
  if k.tool == "dada2" && w.boot_min !== nothing
    for r in ("Species","Genus","Class","Division")
      thr = get(pol.dada2_by_rank, r, 2.0)
      if w.boot_min ≥ thr; return r; end
    end
  elseif k.tool == "vsearch" && w.id !== nothing && w.cov !== nothing
    for r in ("Species","Genus","Division")
      thr = get(pol.vsearch_by_rank, r, nothing)
      if thr !== nothing && w.id ≥ thr.id && w.cov ≥ thr.cov; return r; end
    end
  end
  return nothing
end

# -- Epistemic Status and Residuals -----------------------------------------

"""
  epi_status(r::Receipt, pol::ThresholdPolicy)::Symbol

Returns one of:
  :Factive     - positive claim warranted at (possibly demoted) rank
  :Belief      - measurable evidence but not promoted (below thresholds)
  :Collapsed   - insufficient or failed gates; residue exists but no positive claim
  :SansFibre   - receipt cannot be verified; treat as unverifiable
"""
function epi_status(r::Receipt, pol::ThresholdPolicy)::Symbol
  if !verify_receipt(r); return :SansFibre; end
  if !passes_gates(r.w, pol); return :Collapsed; end
  wr = highest_warranted_rank(r.k, r.w, pol)
  return wr === nothing ? :Belief : :Factive
end

"""
  ZeroKind

true_absence   - adequate power/gates to support absence
undetected     - inadequate power (e.g., low depth) to conclude absence
"""
const ZeroKind = Union{Val{:true_absence},Val{:undetected}}

"""
  disambiguate_zero(sample_depth::Integer, pol::ThresholdPolicy)::ZeroKind

Maps a zero cell (no reads for this feature in this sample) to either
true_absence or undetected. `sample_depth` is the sample's total read count
(library size). It is not the feature's count, which is zero in a zero cell.
Throws ArgumentError when `pol.sample_depth_min` is not set.
"""
# POST-RECOVERY FIX (4): the recovered method took a Warrant and compared
# `w.depth` with `depth_min`. Both are per-feature (see Warrant and
# ThresholdPolicy), and a zero cell's per-feature count is 0, so the method
# could never return true_absence for a real zero cell. It now takes the
# sample's library size and compares it with `sample_depth_min`. The original
# method is unchanged in docs/recovered/code-blocks/16-Epistemic.jl.
function disambiguate_zero(sample_depth::Integer, pol::ThresholdPolicy)::ZeroKind
  sample_depth ≥ 0 || throw(ArgumentError("sample_depth must be non-negative, got $sample_depth"))
  needed = pol.sample_depth_min
  needed === nothing && throw(ArgumentError(
    "ThresholdPolicy.sample_depth_min is not set; choose the library size at which a zero counts as an absence"))
  return sample_depth ≥ needed ? Val(:true_absence) : Val(:undetected)
end

struct ResidualInfo
  warranted_rank::Union{Nothing,String}
  status::Symbol
  residual_named_count::Int
  residual_has_novel::Bool
  contam_flag::Bool
  novel_reasons::Vector{String}
  contam_reasons::Vector{String}

  # Explicit inner constructor (see Warrant on the sibling repos): dispatch
  # checks the types, new() stores, and no abstract interpretation of
  # convert(Vector{String}, ::AbstractArray) explores BitVector/range paths
  # that cannot occur. @kwdef's generated constructor had the same
  # exploration artifact, so the keyword form below is explicit too.
  ResidualInfo(
    warranted_rank::Union{Nothing,String},
    status::Symbol,
    residual_named_count::Int,
    residual_has_novel::Bool,
    contam_flag::Bool,
    novel_reasons::Vector{String},
    contam_reasons::Vector{String},
  ) = new(
    warranted_rank,
    status,
    residual_named_count,
    residual_has_novel,
    contam_flag,
    novel_reasons,
    contam_reasons,
  )
end
function ResidualInfo(;
  warranted_rank::Union{Nothing,String} = nothing,
  status::Symbol = :SansFibre,
  residual_named_count::Int = 0,
  residual_has_novel::Bool = false,
  contam_flag::Bool = false,
  novel_reasons::Vector{String} = String[],
  contam_reasons::Vector{String} = String[],
)
  return ResidualInfo(
    warranted_rank,
    status,
    residual_named_count,
    residual_has_novel,
    contam_flag,
    novel_reasons,
    contam_reasons,
  )
end

"""
  residual_info(r::Receipt; named_candidates_at_species::Int=0, gates_ok_for_novel::Bool=false)::ResidualInfo

Residual summary at the next finer rank:
- residual_named_count: how many named species candidates are plausible (e.g., from vsearch top hits above a consideration floor)
- residual_has_novel: only true if parent clade is warranted (epi_status :Factive at Genus+), no named species clears species threshold,
                      and contamination gates pass (represented here by `gates_ok_for_novel`)
"""
function residual_info(r::Receipt; named_candidates_at_species::Int=0, gates_ok_for_novel::Bool=false, pol::ThresholdPolicy=ThresholdPolicy())
  st = epi_status(r, pol)
  wr = highest_warranted_rank(r.k, r.w, pol)
  has_novel = false
  novel_reasons = String[]
  contam_flag = false
  contam_reasons = String[]

  # "novel" is permitted only if:
  # - parent clade is warranted (Factive at some rank >= Genus),
  # - species threshold fails (wr != "Species"),
  # - and contamination gates/heuristics pass (e.g., neg-control, prevalence, chimera, replicates, blacklist).
  if st == :Factive && wr != "Species"
    if named_candidates_at_species == 0 && gates_ok_for_novel
      has_novel = true
      push!(novel_reasons, "Species threshold failed; parent clade warranted; contamination checks passed.")
    elseif named_candidates_at_species == 0 && !gates_ok_for_novel
      # treat as underdetermined or contaminant based on caller flags
      contam_flag = true
      push!(contam_reasons, "Failed contamination gates; no named species clears species threshold.")
    end
  end

  ResidualInfo(; warranted_rank=wr, status=st, residual_named_count=named_candidates_at_species,
               residual_has_novel=has_novel, contam_flag, novel_reasons, contam_reasons)
end

# -- Merge Checker -----------------------------------------------------------

"""
  can_merge(manA::Dict, manB::Dict; collapse_to=nothing)::NamedTuple

Decides if two runs are safe to analyze together.
Returns one of:
  (status="OK",)
  (status="OK_COLLAPSE", collapse_to="Division", reason="db_release_mismatch")
  (status="REFUSE", reason="normalisation_mismatch", details="rarefy vs rss")
  (status="REFUSE", reason="collapse_rank_required", details="db_key_mismatch")
  (status="REFUSE", reason="collapse_rank_not_in_both", details="Supergroup")
Assumes manifests contain:
  man["normalisation"]          :: String
  man["db"]["key"]              :: String
  man["db"]["release"]          :: String
  man["db"]["ranks"]            :: Vector{String} (ordered, finest-last)

When the database key or release differs, the caller names the rank to
collapse to with `collapse_to`. Rank names alone cannot show where two
taxonomies still agree, so the rank is never inferred.
"""
function can_merge(manA::Dict, manB::Dict; collapse_to::Union{Nothing,AbstractString}=nothing,
                   allow_relative_abundance_if_norm_equal::Bool=true)
  # Normalisation mismatch blocks relative-abundance analysis
  if manA["normalisation"] != manB["normalisation"] && allow_relative_abundance_if_norm_equal
    return (status="REFUSE", reason="normalisation_mismatch", details="$(manA["normalisation"]) vs $(manB["normalisation"])")
  end
  # POST-RECOVERY FIX (5): the recovered code collapsed a key or release
  # mismatch to lowest_common_rank, which returns the COARSEST shared rank on
  # finest-last ladders ("Domain" for PR2 against SILVA). The earlier fix (3)
  # refused when the ladders share no rank. A shared rank name still does not
  # show where two releases' taxonomies agree, so the caller now names the
  # rank, and the verdict refuses until it does. The original lines are in
  # docs/recovered/code-blocks/16-Epistemic.jl.
  mismatch = manA["db"]["key"] != manB["db"]["key"] ? "db_key_mismatch" :
             manA["db"]["release"] != manB["db"]["release"] ? "db_release_mismatch" : nothing
  mismatch === nothing && return (status="OK",)
  collapse_to === nothing && return (status="REFUSE", reason="collapse_rank_required", details=mismatch)
  in_both = collapse_to in manA["db"]["ranks"] && collapse_to in manB["db"]["ranks"]
  in_both || return (status="REFUSE", reason="collapse_rank_not_in_both", details=String(collapse_to))
  return (status="OK_COLLAPSE", collapse_to=String(collapse_to), reason=mismatch)
end

"""
  lowest_common_rank(a::Vector{String}, b::Vector{String})::Union{Nothing,String}

Returns the first rank of `a` that `b` also carries, or `nothing`. On
coarse-to-fine (finest-last) ladders this is the COARSEST shared rank.
"""
function lowest_common_rank(a::Vector{String}, b::Vector{String})::Union{Nothing,String}
  s = Set(b)
  for r in a
    if r in s; return r; end
  end
  return nothing
end

# -- Backend Abstraction (lightweight) --------------------------------------
# Most of these functions are O(1) per row and trivially parallelizable on CPU.
# Specialized accelerators (TPU/NPU/VPU) do not fit well: this is not dense
# matmul or deep-learning inference. CPUBackend is the only backend.
#
# POST-RECOVERY CHANGE (7): the recovered TPU/NPU/VPU stub backends, which
# existed only to throw, are removed. Coprocessor contracts live in
# CoprocessorRuntime.jl and backend selection in AcceleratorGate.jl.

abstract type ComputeBackend end

"""
  CPUBackend

Default backend. Uses multi-threading where helpful.
"""
struct CPUBackend <: ComputeBackend end

"""
  bulk_verify(backend::CPUBackend, receipts::Vector{Receipt})::Vector{Bool}

Batch-verifies digests. Uses Threads.@threads for large vectors. It does not
modify `receipts`; the former name `bulk_verify!` is deprecated.
"""
function bulk_verify(::CPUBackend, receipts::Vector{Receipt})::Vector{Bool}
  n = length(receipts)
  out = Vector{Bool}(undef, n)
  # simple threaded loop; in practice, digest verification is already fast
  Threads.@threads for i in 1:n
    out[i] = verify_receipt(receipts[i])
  end
  return out
end

Base.@deprecate bulk_verify!(backend::CPUBackend, receipts::Vector{Receipt}) bulk_verify(backend, receipts) false

# -- End Module --------------------------------------------------------------

end # module Epistemic
