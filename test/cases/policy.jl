@testset "policy — sample gates (evidence predicate E)" begin
    pol = ThresholdPolicy()

    @test passes_gates(good_warrant(), pol)

    # depth is the only gate with no permissive default: absent depth fails.
    @test !passes_gates(Warrant(boot_min = 0.99), pol)
    @test !passes_gates(Warrant(depth = 99, neg_leak = 0.0, chimera = false), pol)
    @test passes_gates(Warrant(depth = 100, neg_leak = 0.0, chimera = false), pol)

    # neg_leak and chimera are permissive when absent, blocking when bad.
    @test passes_gates(Warrant(depth = 500), pol)
    @test !passes_gates(Warrant(depth = 500, neg_leak = 0.5), pol)
    @test !passes_gates(Warrant(depth = 500, chimera = true), pol)
end

@testset "policy — highest warranted rank walks finest-first" begin
    pol = ThresholdPolicy()

    # DADA2 defaults: Species 0.98, Genus 0.88, Class 0.75, Division 0.70.
    @test highest_warranted_rank(SP_DADA2, Warrant(boot_min = 0.99), pol) == "Species"
    @test highest_warranted_rank(SP_DADA2, Warrant(boot_min = 0.90), pol) == "Genus"
    @test highest_warranted_rank(SP_DADA2, Warrant(boot_min = 0.80), pol) == "Class"
    @test highest_warranted_rank(SP_DADA2, Warrant(boot_min = 0.72), pol) == "Division"
    @test highest_warranted_rank(SP_DADA2, Warrant(boot_min = 0.10), pol) === nothing

    # No classifier evidence at all -> no rank.
    @test highest_warranted_rank(SP_DADA2, Warrant(depth = 500), pol) === nothing

    # vsearch needs BOTH identity and coverage.
    @test highest_warranted_rank(SP_VSEARCH, Warrant(id = 0.995, cov = 0.96), pol) == "Species"
    @test highest_warranted_rank(SP_VSEARCH, Warrant(id = 0.96, cov = 0.92), pol) == "Genus"
    @test highest_warranted_rank(SP_VSEARCH, Warrant(id = 0.995, cov = 0.10), pol) === nothing
    @test highest_warranted_rank(SP_VSEARCH, Warrant(id = 0.995), pol) === nothing

    # An unknown tool is never warranted, whatever the numbers say.
    unknown = Standpoint(tool = "handwave", tool_ver = "0", db_key = "pr2",
                         db_release = "5.0.0", params_hash = "sha256:0",
                         normalisation = "none")
    @test highest_warranted_rank(unknown, Warrant(boot_min = 1.0), pol) === nothing

    # The rank walk does not depend on the gates.
    @test highest_warranted_rank(SP_DADA2, Warrant(boot_min = 0.90, depth = 1), pol) == "Genus"
end
