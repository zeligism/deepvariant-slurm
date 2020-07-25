#!/bin/bash
#SBATCH --job-name=dv-model-eval
#SBATCH --output=dv-slurm-model-eval-%j.out
#SBATCH --error=dv-slurm-model-eval-%j.err
#SBATCH --time=1:00:00
#SBATCH --mem=100G
#SBATCH --cpus-per-task=4
#SBATCH --partition=nvidia
#SBATCH --gres=gpu:1

echo ""
echo "### model_eval ###"
echo "date: $(date)"
echo "node: $(hostname)"
echo "current dir: $(pwd)"
echo "----------------------------------"
module purge
module load singularity

time singularity exec ${SIMG_GPU:+--nv} --bind /scratch "${SIMG_GPU:-$SIMG}" \
  /opt/deepvariant/bin/model_eval \
  --dataset_config_pbtxt="${OUTPUT_DIR}/examples/${SAMPLE}.validation_set.dataset_config.pbtxt" \
  --checkpoint_dir="${LOG_DIR}/train.log" \
  --batch_size=1 \
  --number_of_steps=50 \
  > "${LOG_DIR}/eval.log"
STATUS=$?
set +x
