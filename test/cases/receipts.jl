@testset "receipts — signature binds the fibre" begin
    r = make_receipt(SP_DADA2, good_warrant(), Y_GIARDIA)

    @test r.v == "echo:v1"
    @test startswith(r.sig, "sha256:")
    @test verify_receipt(r)

    # The signature is over canon(k,w,y): change any leg and it must fail.
    tampered_y = Receipt(; k = r.k, w = r.w,
                         y = ProjectionY(taxon = "Cryptosporidium", rank = "Genus",
                                         feature_id = "ASV0001", sample_id = "S01"),
                         sig = r.sig)
    @test !verify_receipt(tampered_y)

    tampered_w = Receipt(; k = r.k, w = good_warrant(boot = 0.10), y = r.y, sig = r.sig)
    @test !verify_receipt(tampered_w)

    tampered_k = Receipt(; k = SP_VSEARCH, w = r.w, y = r.y, sig = r.sig)
    @test !verify_receipt(tampered_k)

    # Deterministic: same fibre, same signature.
    @test make_receipt(SP_DADA2, good_warrant(), Y_GIARDIA).sig == r.sig

    # b64url: no padding, no '+' or '/' — it has to survive a CSV cell.
    payload = r.sig[(length("sha256:") + 1):end]
    @test !occursin('=', payload)
    @test !occursin('+', payload)
    @test !occursin('/', payload)
end

@testset "receipts — avec_fibre wire form round-trips" begin
    r = make_receipt(SP_DADA2, good_warrant(), Y_GIARDIA)
    s = encode_avec_fibre(r)

    @test startswith(s, "echo:v1?")
    back = parse_avec_fibre(s)

    @test back.k == r.k
    @test back.w == r.w
    @test back.y == r.y
    @test back.sig == r.sig
    # The decoded receipt still verifies — the wire form is lossless.
    @test verify_receipt(back)

    # Version tag is enforced on the way in.
    @test_throws ErrorException parse_avec_fibre("echo:v2?k=1&w=2&y=3&sig=4")
    @test_throws ErrorException parse_avec_fibre("k=1&w=2&y=3&sig=4")
    # Each leg is required.
    @test_throws ErrorException parse_avec_fibre("echo:v1?k={}&w={}&y={}")
end
