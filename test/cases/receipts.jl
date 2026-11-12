@testset "receipts: the digest binds the fibre" begin
    r = make_receipt(SP_DADA2, good_warrant(), Y_GIARDIA)

    @test r.v == "echo:v2"
    @test startswith(r.sig, "sha256:")
    @test verify_receipt(r)

    # The digest is over canon(k,w,y): change any leg and it must fail. It has
    # no key, so it detects accidental edits, not deliberate ones.
    edited_y = Receipt(;
        k = r.k,
        w = r.w,
        y = ProjectionY(
            taxon = "Cryptosporidium",
            rank = "Genus",
            feature_id = "ASV0001",
            sample_id = "S01",
        ),
        sig = r.sig,
    )
    @test !verify_receipt(edited_y)

    edited_w = Receipt(; k = r.k, w = good_warrant(boot = 0.10), y = r.y, sig = r.sig)
    @test !verify_receipt(edited_w)

    edited_k = Receipt(; k = SP_VSEARCH, w = r.w, y = r.y, sig = r.sig)
    @test !verify_receipt(edited_k)

    # Deterministic: same fibre, same digest.
    @test make_receipt(SP_DADA2, good_warrant(), Y_GIARDIA).sig == r.sig

    # b64url: no padding, no '+' or '/', so it survives a CSV cell.
    payload = r.sig[(length("sha256:")+1):end]
    @test !occursin('=', payload)
    @test !occursin('+', payload)
    @test !occursin('/', payload)
end

# The echo:v1 form a pre-v2 encoder wrote: raw JSON joined with '&' and '='.
const _J = EpistemicTypes.Epistemic.JSON3
v1_string(
    r,
) = "echo:v1?k=$(_J.write(r.k))&w=$(_J.write(r.w))&y=$(_J.write(r.y))&sig=$(r.sig)"

@testset "receipts: echo:v2 wire form round-trips" begin
    r = make_receipt(SP_DADA2, good_warrant(), Y_GIARDIA)
    s = encode_avec_fibre(r)

    @test startswith(s, "echo:v2?")
    back = parse_avec_fibre(s)

    @test back.v == "echo:v2"
    @test back.k == r.k
    @test back.w == r.w
    @test back.y == r.y
    @test back.sig == r.sig
    # The decoded receipt still verifies: the wire form is lossless.
    @test verify_receipt(back)

    # Version tag is enforced on the way in.
    @test_throws ErrorException parse_avec_fibre("echo:v3?k=1&w=2&y=3&sig=4")
    @test_throws ErrorException parse_avec_fibre("k=1&w=2&y=3&sig=4")
    # Each leg is required.
    @test_throws ErrorException parse_avec_fibre("echo:v2?k=%7B%7D&w=%7B%7D&y=%7B%7D")
    # A malformed escape fails loudly.
    @test_throws ArgumentError parse_avec_fibre("echo:v2?k=%7&w=x&y=x&sig=x")
end

@testset "receipts: '&', '=' and non-ASCII round-trip in echo:v2" begin
    y = ProjectionY(
        taxon = "Giardia & co = 100%",
        rank = "Genus",
        feature_id = "ASV0001",
        sample_id = "Süd-01",
    )
    r = make_receipt(SP_DADA2, good_warrant(), y)
    s = encode_avec_fibre(r)
    @test !occursin("Giardia & co", s)
    back = parse_avec_fibre(s)
    @test back.y == y
    @test verify_receipt(back)
end

@testset "receipts: echo:v1 strings are still read" begin
    r = make_receipt(SP_DADA2, good_warrant(), Y_GIARDIA)
    back = parse_avec_fibre(v1_string(r))
    @test back.v == "echo:v1"
    @test back.y == r.y
    @test verify_receipt(back)

    # The v1 limit is unchanged: a field holding '&' still fails loudly.
    y = ProjectionY(
        taxon = "Giardia & co",
        rank = "Genus",
        feature_id = "A",
        sample_id = "S",
    )
    @test_throws ArgumentError parse_avec_fibre(
        v1_string(make_receipt(SP_DADA2, good_warrant(), y)),
    )
end
