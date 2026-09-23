@testset "status — the four epi_status outcomes" begin
    pol = ThresholdPolicy()

    # :Factive — verifies, clears gates, and reaches a rank.
    factive = make_receipt(SP_DADA2, good_warrant(boot = 0.90), Y_GIARDIA)
    @test epi_status(factive, pol) == :Factive

    # :Belief — verifies and clears gates, but no rank threshold is met.
    belief = make_receipt(SP_DADA2, good_warrant(boot = 0.10), Y_GIARDIA)
    @test epi_status(belief, pol) == :Belief

    # :Collapsed — verifies, but the sample gates fail. Gates outrank the
    # classifier: a perfect bootstrap on a shallow sample is still collapsed.
    collapsed = make_receipt(SP_DADA2,
                             Warrant(boot_min = 0.99, depth = 3, neg_leak = 0.0, chimera = false),
                             Y_GIARDIA)
    @test epi_status(collapsed, pol) == :Collapsed

    # :SansFibre — the signature does not verify, so nothing else is asked.
    sans = Receipt(; k = factive.k, w = factive.w, y = factive.y, sig = "sha256:not-the-signature")
    @test epi_status(sans, pol) == :SansFibre
end

@testset "status — zero disambiguation turns on power, not on reads" begin
    pol = ThresholdPolicy()
    @test disambiguate_zero(Warrant(depth = 500), pol) === Val(:true_absence)
    @test disambiguate_zero(Warrant(depth = 100), pol) === Val(:true_absence)
    @test disambiguate_zero(Warrant(depth = 99), pol)  === Val(:undetected)
    @test disambiguate_zero(Warrant(), pol)            === Val(:undetected)
end

@testset "residuals — novel only after the contamination gate" begin
    pol = ThresholdPolicy()
    # Warranted at Genus, so species is the open residual.
    r = make_receipt(SP_DADA2, good_warrant(boot = 0.90), Y_GIARDIA)

    novel = residual_info(r; named_candidates_at_species = 0, gates_ok_for_novel = true)
    @test novel.status == :Factive
    @test novel.warranted_rank == "Genus"
    @test novel.residual_has_novel
    @test !novel.contam_flag
    @test !isempty(novel.novel_reasons)

    # Same evidence, contamination gate not passed: never novel, flagged instead.
    contam = residual_info(r; named_candidates_at_species = 0, gates_ok_for_novel = false)
    @test !contam.residual_has_novel
    @test contam.contam_flag
    @test !isempty(contam.contam_reasons)

    # A named candidate exists, so "novel" is not on the table either way.
    named = residual_info(r; named_candidates_at_species = 3, gates_ok_for_novel = true)
    @test !named.residual_has_novel
    @test !named.contam_flag
    @test named.residual_named_count == 3

    # Already at Species: there is no finer residual to claim.
    at_species = make_receipt(SP_DADA2, good_warrant(boot = 0.99), Y_GIARDIA)
    sp = residual_info(at_species; named_candidates_at_species = 0, gates_ok_for_novel = true)
    @test sp.warranted_rank == "Species"
    @test !sp.residual_has_novel

    # Not Factive: residuals never promote a claim the status refused.
    collapsed = make_receipt(SP_DADA2,
                             Warrant(boot_min = 0.99, depth = 3, neg_leak = 0.0, chimera = false),
                             Y_GIARDIA)
    co = residual_info(collapsed; named_candidates_at_species = 0, gates_ok_for_novel = true)
    @test co.status == :Collapsed
    @test !co.residual_has_novel
end
