#!/bin/bash
#SBATCH --job-name=dv-make-examples-validation
#SBATCH --output=dv-slurm-make-examples-validation-%j.out
#SBATCH --error=dv-slurm-make-examples-validation-%j.err
#SBATCH --time=2:00:00
#SBATCH --mem=100G
#SBATCH --cpus-per-task=8

echo ""
echo "### make_examples (validation) ###"
echo "date: $(date)"
echo "node: $(hostname)"
echo "current dir: $(pwd)"
echo "----------------------------------"
module purge
module load parallel
module load singularity

set -x
seq 0 $((NSHARDS-1)) | \
parallel -j $SLURM_CPUS_PER_TASK --eta --halt 2 --joblog "${LOG_DIR}/log" --res "${LOG_DIR}" \
    singularity exec --bind /scratch "$SIMG" \
      /opt/deepvariant/bin/make_examples \
        --mode training \
        --ref "$REF" \
        --reads "$BAM" \
        --examples "${OUTPUT_DIR}/examples/${SAMPLE}.validation_set.with_label.tfrecord@${NSHARDS}.gz" \
        --truth_variants "$TRUTH_VCF" \
        ${VALIDATION_REGIONS:+--regions "$VALIDATION_REGIONS"} \
        ${TRUTH_BED:+--confident_regions "$TRUTH_BED"} \
        --task {}
STATUS=$?
set +x
