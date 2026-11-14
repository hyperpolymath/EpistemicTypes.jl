# SPDX-License-Identifier: MPL-2.0
# Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath) <j.d.a.jewell@open.ac.uk>

using Test
using EpistemicTypes
using CoprocessorRuntime

ext = Base.get_extension(EpistemicTypes, :EpistemicTypesCoprocessorRuntimeExt)

# The mapping the extension must implement, written out in full so this file is a
# second statement of the table and not a restatement of the code. Key:
# (warrant, standpoint, sound) => epi_status.
const EXPECTED = Dict{Tuple{WarrantKind,Symbol,Bool},Symbol}(
    # Knowledge is Factive only when the host may claim it: host AND sound.
    (Knowledge, :host, true) => :Factive,
    (Knowledge, :host, false) => :Belief,
    (Knowledge, :device, true) => :Belief,   # never a host claim: no smuggling
    (Knowledge, :device, false) => :Belief,  # issue_receipt refuses to mint this
    # The other warrants do not depend on standpoint or soundness.
    (Belief, :host, true) => :Belief,
    (Belief, :host, false) => :Belief,
    (Belief, :device, true) => :Belief,
    (Belief, :device, false) => :Belief,
    (WarrantOnly, :host, true) => :Collapsed,
    (WarrantOnly, :host, false) => :Collapsed,
    (WarrantOnly, :device, true) => :Collapsed,
    (WarrantOnly, :device, false) => :Collapsed,
    (Unsound, :host, true) => :SansFibre,
    (Unsound, :host, false) => :SansFibre,
    (Unsound, :device, true) => :SansFibre,
    (Unsound, :device, false) => :SansFibre,
)

@testset "EpistemicTypes x CoprocessorRuntime receipt extension" begin
    @testset "the extension is loaded by having both packages" begin
        @test ext !== nothing
    end

    @testset "the table covers every warrant kind" begin
        # A WarrantKind added to CoprocessorRuntime fails here until it has a row.
        covered = Set(k[1] for k in keys(EXPECTED))
        @test covered == Set(instances(WarrantKind))
        @test length(EXPECTED) == 4 * 2 * 2
    end

    @testset "every (warrant, standpoint, sound) maps as stated" begin
        for ((w, standpoint, sound), want) in EXPECTED
            r = LaunchReceipt(UInt64(1), standpoint, w, "claim", sound)
            @test epi_status(r) === want
        end
    end

    @testset "Factive is exactly CoprocessorRuntime's host_may_claim" begin
        for ((w, standpoint, sound), _) in EXPECTED
            r = LaunchReceipt(UInt64(1), standpoint, w, "claim", sound)
            @test (epi_status(r) === :Factive) == host_may_claim(r)
        end
    end

    @testset "issued receipts map through the same table" begin
        s = open_session(NPUKind())
        @test epi_status(issue_receipt(s)) === :Collapsed  # default WarrantOnly
        @test epi_status(
            issue_receipt(s; standpoint = :host, warrant = Knowledge, sound = true),
        ) === :Factive
        @test epi_status(issue_receipt(s; warrant = Belief)) === :Belief
        @test epi_status(issue_receipt(s; warrant = Unsound)) === :SansFibre
        close_session!(s)
    end

    @testset "the classifier method is untouched" begin
        # The two-argument method still exists, and a LaunchReceipt does not
        # satisfy it: a runtime receipt carries no thresholds.
        @test hasmethod(epi_status, Tuple{Receipt,ThresholdPolicy})
        @test !hasmethod(epi_status, Tuple{LaunchReceipt,ThresholdPolicy})
    end

    @testset "an unmapped warrant is an error, not a default" begin
        # An out-of-range byte is the one way to build a WarrantKind this
        # table does not cover; the extension must refuse it, not guess.
        bogus = Base.bitcast(WarrantKind, UInt8(9))
        r = LaunchReceipt(UInt64(1), :host, bogus, "claim", true)
        @test_throws ArgumentError epi_status(r)
    end
end
