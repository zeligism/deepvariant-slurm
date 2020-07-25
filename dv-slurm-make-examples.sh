#!/bin/bash
#SBATCH --job-name=dv-make-examples
#SBATCH --output=dv-slurm-make-examples-%j.out
#SBATCH --error=dv-slurm-make-examples-%j.err
#SBATCH --time=2:00:00
#SBATCH --mem=100G
#SBATCH --cpus-per-task=8

echo ""
echo "### make_examples ###"
echo "date: $(date)"
echo "node: $(hostname)"
echo "current dir: $(pwd)"
echo "----------------------------------"
module purge
module load parallel
module load singularity

# Make examples (tensors) from input files for DeepVariant.
# --examples: REQUIRED. Path to write the output (tf.Example protos in TFRecord format).
# --reads: REQUIRED. Aligned, sorted, indexed BAM file. Can provide mutiple comma-separated BAMs.
# --ref: REQUIRED. Genome reference. Must have FAI index. Supports text or gzipped refs.
# --mode: either `calling` or `training`.se_quality: Minimum base quality. This field indicates that we are
# --regions: space-separated regions to process (e.g. chr20:10-20) or path to BED/BEDPE.
# --min_base_quality: minimum base quality score for alternate alleles (default=10).
# --min_mapping_quality: Keep aligned reads that have MAPQ >= this integer (default=10).
# --gvcf_gq_binsize: Takes an int. Allows the merging of adjacent records that all have GQ values within a bin
#                    of the given size, and for each record emits the minimum GQ value seen within the bin.
set -x
seq 0 $((NSHARDS-1)) | \
parallel -j $SLURM_CPUS_PER_TASK --eta --halt 2 --joblog "${LOG_DIR}/log" --res "${LOG_DIR}" \
    singularity exec --bind /scratch "$SIMG" \
      /opt/deepvariant/bin/make_examples \
        --mode calling \
        --ref "$REF" \
        --reads "$BAM" \
        --examples "$EXAMPLES" \
        ${CAPTURE_BED:+--regions "$CAPTURE_BED"} \
        ${GVCF_TFRECORDS:+--gvcf "$GVCF_TFRECORDS"} \
        ${GVCF_TFRECORDS:+--gvcf_gq_binsize 5} \
        --task {}
STATUS=$?
set +x
