#!/bin/bash
#SBATCH --job-name=dv-shuffle-examples-training
#SBATCH --output=dv-slurm-shuffle-examples-training-%j.out
#SBATCH --error=dv-slurm-shuffle-examples-training-%j.err
#SBATCH --time=2:00:00
#SBATCH --mem=100G
#SBATCH --cpus-per-task=8
#SBATCH --mail-type=ALL
#SBATCH --mail-user=aa5525@nyu.edu

echo ""
echo "### shuffle_examples (training) ###"
echo "date: $(date)"
echo "node: $(hostname)"
echo "current dir: $(pwd)"
echo "----------------------------------"
source activate dv

set -x
time python ${SHUFFLE_SCRIPT_DIR}/shuffle_tfrecords_beam.py \
  --input_pattern_list="${OUTPUT_DIR}/examples/${SAMPLE}.training_set.with_label.tfrecord-?????-of-$(printf '%05d' $NSHARDS).gz" \
  --output_pattern_prefix="${OUTPUT_DIR}/examples/${SAMPLE}.training_set.with_label.shuffled" \
  --output_dataset_config_pbtxt="${OUTPUT_DIR}/examples/${SAMPLE}.training_set.dataset_config.pbtxt" \
  --output_dataset_name="$SAMPLE" \
  --runner=DirectRunner
STATUS=$?
set +x
