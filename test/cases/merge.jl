const PR2_RANKS =
    ["Domain", "Supergroup", "Division", "Class", "Order", "Family", "Genus", "Species"]
const SILVA_RANKS = ["Domain", "Phylum", "Class", "Order", "Family", "Genus", "Species"]

man(; norm = "none", key = "pr2", release = "5.0.0", ranks = PR2_RANKS) = Dict(
    "normalisation" => norm,
    "db" => Dict("key" => key, "release" => release, "ranks" => ranks),
)

@testset "merge: two runs of the same shape merge outright" begin
    @test can_merge(man(), man()).status == "OK"
    # A collapse rank is ignored when nothing differs.
    @test can_merge(man(), man(); collapse_to = "Genus").status == "OK"
end

@testset "merge: normalisation mismatch refuses" begin
    v = can_merge(man(norm = "rarefy"), man(norm = "rss"))
    @test v.status == "REFUSE"
    @test v.reason == "normalisation_mismatch"
    @test occursin("rarefy", v.details) && occursin("rss", v.details)

    # Opting out of the relative-abundance rule lets it past this gate.
    @test can_merge(
        man(norm = "rarefy"),
        man(norm = "rss");
        allow_relative_abundance_if_norm_equal = false,
    ).status == "OK"
end

@testset "merge: a database difference needs a caller-named collapse rank" begin
    # Rank names cannot show where two taxonomies still agree, so no rank is
    # inferred: without collapse_to the verdict refuses and names the mismatch.
    rel = can_merge(man(release = "5.0.0"), man(release = "4.14.0"))
    @test rel.status == "REFUSE"
    @test rel.reason == "collapse_rank_required"
    @test rel.details == "db_release_mismatch"

    key = can_merge(man(key = "pr2"), man(key = "silva", ranks = SILVA_RANKS))
    @test key.status == "REFUSE"
    @test key.reason == "collapse_rank_required"
    @test key.details == "db_key_mismatch"

    # With a rank both ladders carry, the merge collapses to it.
    rel_ok =
        can_merge(man(release = "5.0.0"), man(release = "4.14.0"); collapse_to = "Division")
    @test rel_ok.status == "OK_COLLAPSE"
    @test rel_ok.collapse_to == "Division"
    @test rel_ok.reason == "db_release_mismatch"

    key_ok = can_merge(
        man(key = "pr2"),
        man(key = "silva", ranks = SILVA_RANKS);
        collapse_to = "Genus",
    )
    @test key_ok.status == "OK_COLLAPSE"
    @test key_ok.collapse_to == "Genus"
    @test key_ok.reason == "db_key_mismatch"
end

@testset "merge: a collapse rank one ladder lacks refuses" begin
    # Supergroup is a PR2 rank only.
    v = can_merge(
        man(key = "pr2"),
        man(key = "silva", ranks = SILVA_RANKS);
        collapse_to = "Supergroup",
    )
    @test v.status == "REFUSE"
    @test v.reason == "collapse_rank_not_in_both"
    @test v.details == "Supergroup"

    # Ladders that share no rank can never collapse.
    none = can_merge(
        man(release = "5.0.0", ranks = ["Domain", "Genus"]),
        man(release = "4.14.0", ranks = ["Kingdom", "Species"]);
        collapse_to = "Genus",
    )
    @test none.status == "REFUSE"
    @test none.reason == "collapse_rank_not_in_both"
end

@testset "merge: lowest_common_rank returns the first rank of `a` that `b` carries" begin
    # On coarse-to-fine ladders that is the COARSEST shared rank. can_merge no
    # longer uses it; it is pinned so its documented behaviour cannot drift.
    @test lowest_common_rank(PR2_RANKS, SILVA_RANKS) == "Domain"
    @test lowest_common_rank(reverse(PR2_RANKS), reverse(SILVA_RANKS)) == "Species"
    @test lowest_common_rank(["Genus", "Species"], ["Species", "Genus"]) == "Genus"
    @test lowest_common_rank(["Genus"], ["Species"]) === nothing
    @test lowest_common_rank(String[], PR2_RANKS) === nothing
end
