@testset "backends, CPU verifies in bulk" begin
    good = make_receipt(SP_DADA2, good_warrant(), Y_GIARDIA)
    bad = Receipt(; k = good.k, w = good.w, y = good.y, sig = "sha256:wrong")

    @test bulk_verify(CPUBackend(), [good, bad, good]) == [true, false, true]
    @test bulk_verify(CPUBackend(), Receipt[]) == Bool[]
    @test CPUBackend() isa ComputeBackend

    # The input is not modified, so the name has no '!'. The old name still
    # works, as a deprecated alias with the same result.
    @test (@test_deprecated bulk_verify!(CPUBackend(), [good, bad])) == [true, false]

    # The TPU/NPU/VPU stubs are gone: coprocessor contracts live in
    # CoprocessorRuntime.jl, not in this package.
    for name in (:TPUBackend, :NPUBackend, :VPUBackend)
        @test !isdefined(EpistemicTypes, name)
    end
end
