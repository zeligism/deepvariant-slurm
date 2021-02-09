
SIMG="/scratch/aa5525/deepvariant/singularity_images/deepvariant-0.9.0.simg"
SIMG_GPU="/scratch/aa5525/deepvariant/singularity_images/deepvariant-0.8.0-gpu-tf-1.12.0-cuda-9.0.sif"

echo "(Running on test data.)"
test_dir="/scratch/aa5525/deepvariant-other/google/deepvariant/deepvariant/testdata"
REF="${test_dir}/ucsc.hg19.chr20.unittest.fasta.gz"
BAM="${test_dir}/NA12878_S1.chr20.10_10p1mb.bam"
TRUTH_BED="${test_dir}/test_nist.b37_chr20_100kbp_at_10mb.bed"
TRUTH_VCF="${test_dir}/test_nist.b37_chr20_100kbp_at_10mb.vcf.gz"  # chr20 10000000-10010000
EXCLUDE_REGIONS="chr20:10007000-10009999"
VALIDATION_REGIONS="chr20:10007000-10009999"
#EVALUATION_REGIONS="chr20:10009001-10009999"

SAMPLE="test.training"
MODEL_TYPE="wes"
NSHARDS=4

./deepvariant-training.sh \
  --simg "$SIMG" \
  --simg_gpu "$SIMG_GPU" \
  --sample "$SAMPLE" \
  --num_shards $NSHARDS \
  --model_type "$MODEL_TYPE" \
  --ref "$REF" \
  --bam "$BAM" \
  --truth_variants "$TRUTH_VCF" \
  --confident_regions "$TRUTH_BED" \
  --exclude_regions "$EXCLUDE_REGIONS" \
  --validation_regions "$VALIDATION_REGIONS"
