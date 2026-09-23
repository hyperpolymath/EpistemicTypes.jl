# Shared fixtures for the EpistemicTypes behaviour suite.
#
# These mirror the worked example in the recovered thread: a Giardia ASV
# classified by DADA2 against PR2, with sample gates attached.

const SP_DADA2 = Standpoint(
    tool = "dada2", tool_ver = "1.28.0",
    db_key = "pr2", db_release = "5.0.0",
    params_hash = "sha256:0000", normalisation = "none",
)

const SP_VSEARCH = Standpoint(
    tool = "vsearch", tool_ver = "2.22.1",
    db_key = "pr2", db_release = "5.0.0",
    params_hash = "sha256:0000", normalisation = "none",
)

const Y_GIARDIA = ProjectionY(
    taxon = "Giardia", rank = "Genus",
    feature_id = "ASV0001", sample_id = "S01",
)

"A warrant that clears the sample gates, with a genus-level bootstrap."
good_warrant(; boot = 0.90) =
    Warrant(boot_min = boot, depth = 500, neg_leak = 0.0, chimera = false)
