const PR2_RANKS = ["Domain", "Supergroup", "Division", "Class", "Order", "Family", "Genus", "Species"]
const SILVA_RANKS = ["Domain", "Phylum", "Class", "Order", "Family", "Genus", "Species"]

man(; norm = "none", key = "pr2", release = "5.0.0", ranks = PR2_RANKS) =
    Dict("normalisation" => norm, "db" => Dict("key" => key, "release" => release, "ranks" => ranks))

@testset "merge — two runs of the same shape merge outright" begin
    @test can_merge(man(), man()).status == "OK"
end

@testset "merge — normalisation mismatch refuses" begin
    v = can_merge(man(norm = "rarefy"), man(norm = "rss"))
    @test v.status == "REFUSE"
    @test v.reason == "normalisation_mismatch"
    @test occursin("rarefy", v.details) && occursin("rss", v.details)

    # Opting out of the relative-abundance rule lets it past this gate.
    @test can_merge(man(norm = "rarefy"), man(norm = "rss");
                    allow_relative_abundance_if_norm_equal = false).status == "OK"
end

@testset "merge — database differences collapse rather than refuse" begin
    # Same DB, different release: collapse to a shared rank.
    rel = can_merge(man(release = "5.0.0"), man(release = "4.14.0"))
    @test rel.status == "OK_COLLAPSE"
    @test rel.reason == "db_release_mismatch"
    @test rel.collapse_to == "Domain"

    # Different DB key: collapse across the two ladders.
    key = can_merge(man(key = "pr2", ranks = PR2_RANKS),
                    man(key = "silva", ranks = SILVA_RANKS))
    @test key.status == "OK_COLLAPSE"
    @test key.reason == "db_key_mismatch"
    @test key.collapse_to == "Domain"

    # No shared rank at all: refuse.
    none = can_merge(man(key = "pr2", ranks = ["Domain"]),
                     man(key = "unite", ranks = ["Kingdom"]))
    @test none.status == "REFUSE"
    @test none.reason == "no_common_rank"
end

@testset "merge — lowest_common_rank scans the FIRST ladder in its own order" begin
    # The docstring says "finest rank in both"; the implementation returns the
    # first entry of `a` present in `b`. With coarse-first ladders (as PR2 and
    # SILVA are written above) that is the COARSEST shared rank, which is the
    # conservative answer a collapse wants — but it is order-dependent, not a
    # finest-rank search. Pinned here so the behaviour cannot drift silently.
    @test lowest_common_rank(PR2_RANKS, SILVA_RANKS) == "Domain"
    @test lowest_common_rank(reverse(PR2_RANKS), reverse(SILVA_RANKS)) == "Species"
    @test lowest_common_rank(["Genus", "Species"], ["Species", "Genus"]) == "Genus"
    @test lowest_common_rank(["Genus"], ["Species"]) === nothing
    @test lowest_common_rank(String[], PR2_RANKS) === nothing
end
