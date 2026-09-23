@testset "backends — CPU verifies in bulk; accelerators refuse by design" begin
    good = make_receipt(SP_DADA2, good_warrant(), Y_GIARDIA)
    bad  = Receipt(; k = good.k, w = good.w, y = good.y, sig = "sha256:wrong")

    @test bulk_verify!(CPUBackend(), [good, bad, good]) == [true, false, true]
    @test bulk_verify!(CPUBackend(), Receipt[]) == Bool[]

    # The TPU/NPU/VPU stubs exist to refuse, not to accelerate: per-row hashing
    # is not a dense-matmul workload. That refusal is the contract.
    for be in (TPUBackend(), NPUBackend(), VPUBackend())
        @test_throws ErrorException bulk_verify!(be, [good])
    end

    @test CPUBackend() isa ComputeBackend
    @test TPUBackend() isa ComputeBackend
end
