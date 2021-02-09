
SIMG="/scratch/aa5525/deepvariant/singularity_images/deepvariant-0.9.0.simg"
SIMG_GPU="/scratch/aa5525/deepvariant/singularity_images/deepvariant-0.8.0-gpu-tf-1.12.0-cuda-9.0.sif"

echo "(Running on test data.)"
test_dir="/scratch/aa5525/deepvariant/quickstart-testdata"
REF="${test_dir}/quickstart-testdata_ucsc.hg19.chr20.unittest.fasta"
BAM="${test_dir}/quickstart-testdata_NA12878_S1.chr20.10_10p1mb.bam"
CAPTURE_BED="${test_dir}/quickstart-testdata_test_nist.b37_chr20_100kbp_at_10mb.bed"

SAMPLE="test.calling"

./deepvariant-calling.sh \
  --sample "$SAMPLE" \
  --simg "$SIMG" \
  --simg_gpu "$SIMG_GPU" \
  --ref "$REF" \
  --bam "$BAM" \
  --regions "$CAPTURE_BED" \
  --gvcf \
  --gpu
