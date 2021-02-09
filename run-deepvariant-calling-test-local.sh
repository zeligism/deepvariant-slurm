
SIMG="/scratch/aa5525/deepvariant/singularity_images/deepvariant-0.9.0.simg"

echo "(Running on test data.)"
test_dir="/scratch/aa5525/deepvariant/quickstart-testdata"
REF="${test_dir}/quickstart-testdata_ucsc.hg19.chr20.unittest.fasta"
BAM="${test_dir}/quickstart-testdata_NA12878_S1.chr20.10_10p1mb.bam"
CAPTURE_BED="${test_dir}/quickstart-testdata_test_nist.b37_chr20_100kbp_at_10mb.bed"

SAMPLE="test.local.calling"
NSHARDS=4

./deepvariant-calling.sh \
  --sample "$SAMPLE" \
  --simg "$SIMG" \
  --ref "$REF" \
  --bam "$BAM" \
  --regions "$CAPTURE_BED" \
  --num_shards $NSHARDS \
  --local
