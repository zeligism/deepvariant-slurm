#!/bin/bash
#SBATCH --job-name=dv-model-train
#SBATCH --output=dv-slurm-model-train-%j.out
#SBATCH --error=dv-slurm-model-train-%j.err
#SBATCH --time=1:00:00
#SBATCH --mem=100G
#SBATCH --cpus-per-task=4
#SBATCH --partition=nvidia
#SBATCH --gres=gpu:1

echo ""
echo "### model_train ###"
echo "date: $(date)"
echo "node: $(hostname)"
echo "current dir: $(pwd)"
echo "----------------------------------"
module purge
module load singularity

time singularity exec ${SIMG_GPU:+--nv} --bind /scratch "${SIMG_GPU:-$SIMG}" \
  /opt/deepvariant/bin/model_train \
  --dataset_config_pbtxt="${OUTPUT_DIR}/examples/${SAMPLE}.training_set.dataset_config.pbtxt" \
  --train_dir="${LOG_DIR}/train.log" \
  --start_from_checkpoint="$PRETRAINED_MODEL" \
  --number_of_steps=50 \
  --save_interval_secs=300 \
  --batch_size=1 \
  --learning_rate=0.008
STATUS=$?
set +x
