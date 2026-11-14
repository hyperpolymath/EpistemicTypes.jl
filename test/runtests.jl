# EpistemicTypes — test entry point (julia-library archetype)
#
# Two suites, in this order:
#   1. Aqua package-shape gate — runs FIRST: a package that does not load
#      cleanly, whose deps are not compat-closed, or whose exports are
#      ambiguous is rejected before any behaviour test can pass.
#   2. Behaviour: every test/cases/*.jl is included, in name order.
#      00-fixtures.jl defines the shared fixtures; each other file pins the
#      decisions listed in docs/EXPLAINME.adoc ("Checking these claims").

using Test
using EpistemicTypes

@testset "EpistemicTypes — Aqua package shape" begin
    using Aqua
    Aqua.test_all(EpistemicTypes)
end

@testset "EpistemicTypes — behaviour" begin
    # NOTE: no `continue`/`break` inside a `for` inside @testset — Test's
    # loop-form detection re-parses the loop body at top level, where
    # `continue` is a ParseError. Filter with a guarded call instead.
    # (Measured trap, 2026-09-19 — see the Julia testing guide.)
    cases = joinpath(@__DIR__, "cases")
    if isdir(cases)
        for path in sort(readdir(cases, join = true))
            endswith(path, ".jl") && include(path)
        end
    end
end

# The CoprocessorRuntime receipt extension is tested in its own environment:
# CoprocessorRuntime is not in the General registry and is fetched by URL from a
# pinned commit through [sources], which needs Julia 1.11. It runs in a
# subprocess so this environment stays resolvable on 1.10. On older Julia, or
# with EPISTEMICTYPES_SKIP_EXT_TESTS=1, it is recorded as a visible Broken test,
# never skipped silently.
@testset "EpistemicTypes — CoprocessorRuntime receipt extension" begin
    ext_dir = joinpath(@__DIR__, "ext")
    if get(ENV, "EPISTEMICTYPES_SKIP_EXT_TESTS", "") == "1"
        @info "CoprocessorRuntime extension tests skipped: EPISTEMICTYPES_SKIP_EXT_TESTS=1"
        @test_skip false
    elseif VERSION < v"1.11"
        @info "CoprocessorRuntime extension tests need Julia 1.11 ([sources]); running Julia $VERSION"
        @test_skip false
    else
        # The directory is passed as an argument and read from ARGS, never
        # spliced into generated source: a path with a backslash, quote or `$`
        # is not valid inside a string literal.
        script = "import Pkg; Pkg.instantiate(); include(joinpath(ARGS[1], \"runtests.jl\"))"
        cmd = `$(Base.julia_cmd()) --startup-file=no --project=$ext_dir -e $script $ext_dir`
        # Pkg.test sets JULIA_LOAD_PATH for the sandbox it makes; the subprocess
        # must resolve its own environment, not inherit that one.
        @test success(
            pipeline(
                addenv(cmd, "JULIA_LOAD_PATH" => nothing);
                stdout = stdout,
                stderr = stderr,
            ),
        )
    end
end
