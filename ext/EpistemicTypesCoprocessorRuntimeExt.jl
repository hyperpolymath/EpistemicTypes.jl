# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

"""
    EpistemicTypesCoprocessorRuntimeExt

Package extension: reads a CoprocessorRuntime `LaunchReceipt` as an
`epi_status`, the same four-valued status EpistemicTypes gives a classifier
receipt.

It maps what a receipt already says. It does not verify anything, run a
launch, or add a check the receipt did not carry. `epi_status(::Receipt,
::ThresholdPolicy)` is unchanged; a `LaunchReceipt` has no thresholds, so its
method takes the receipt alone.

The mapping, by the receipt's `warrant`:

| `warrant`     | `epi_status`  | why                                                      |
|:------------- |:------------- |:-------------------------------------------------------- |
| `Knowledge`   | `:Factive`    | only if `host_may_claim(r)`: host standpoint and `sound` |
| `Knowledge`   | `:Belief`     | otherwise (device standpoint, or no soundness check ran) |
| `Belief`      | `:Belief`     | evidence, not promoted                                   |
| `WarrantOnly` | `:Collapsed`  | evidence recorded, no soundness assumed                  |
| `Unsound`     | `:SansFibre`  | the receipt is not to be relied on                       |

The `Factive` arm is exactly CoprocessorRuntime's own no-smuggling rule
(`host_may_claim`), so the two packages cannot disagree about when a launch
becomes a factive claim. A `Knowledge` receipt that fails that rule is
demoted to `:Belief`, never to a status that hides it: it is still evidence.

A `WarrantKind` instance this table does not cover is an `ArgumentError`, not
a default: a new warrant kind must be given a row.
"""
module EpistemicTypesCoprocessorRuntimeExt

import EpistemicTypes
import CoprocessorRuntime:
    LaunchReceipt, Knowledge, Belief, WarrantOnly, Unsound, host_may_claim

function EpistemicTypes.epi_status(r::LaunchReceipt)::Symbol
    w = r.warrant
    if w === Knowledge
        return host_may_claim(r) ? :Factive : :Belief
    elseif w === Belief
        return :Belief
    elseif w === WarrantOnly
        return :Collapsed
    elseif w === Unsound
        return :SansFibre
    end
    throw(ArgumentError("no epi_status for CoprocessorRuntime warrant $(w)"))
end

end # module
