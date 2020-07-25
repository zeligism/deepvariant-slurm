
set -a  # export all variables

MODE=training
TFRECORDS_SHUFFLER_LINK="https://raw.githubusercontent.com/google/deepvariant/r0.9/tools/shuffle_tfrecords_beam.py"
INCEPTION_V3_LINK="http://download.tensorflow.org/models/inception_v3_2016_08_28.tar.gz"

DEEPVARIANT_DIR="${SCRATCH}/deepvariant"
mkdir -p "$DEEPVARIANT_DIR"

# Handle args (no positional args)
while [[ $# -gt 0 ]]
do
  case "$1" in
    --simg)  # Singularity image of DeepVariant (REQUIRED)
    SIMG="$2"; shift; shift;
    ;;
    --simg_gpu)  # Singularity image of DeepVariant-GPU (optional)
    SIMG_GPU="$2"; shift; shift;
    ;;
    -r|--ref)  # Reference genome / FASTA file (REQUIRED)
    REF="$2"; shift; shift;
    ;;
    -b|--bam)  # BAM file (REQUIRED)
    BAM="$2"; shift; shift;
    ;;
    --truth_variants)  # The true variants file, used for training/validation
    TRUTH_VCF="$2"; shift; shift;
    ;;
    --confident_regions)  # The regions containing high-confidence variants
    TRUTH_BED="$2"; shift; shift;
    ;;
    --exclude_regions)  # The regions excluded from training
    EXCLUDE_REGIONS="$2"; shift; shift;
    ;;
    --validation_regions)  # The regions used for validation
    VALIDATION_REGIONS="$2"; shift; shift;
    ;;
    --evaluation_regions)  # The regions used for evaluation
    EVALUATION_REGIONS="$2"; shift; shift;
    ;;

    --sample)  # Name of genome sample (default = sample)
    SAMPLE="$2"; shift; shift;
    ;;
    --num_shards)  # Number of shards (default = 4)
    NSHARDS="$2"; shift; shift;
    ;;
    --model_type)
    # Type of model to start training from, among: {inception_v3,wes,wgs,pacbio}
    MODEL_TYPE="$2"; shift; shift;
    ;;
    --output_dir)  # Output directory (default = output)
    OUTPUT_DIR="$2"; shift; shift;
    ;;
    --log_dir)  # Log directory (default = logs)
    LOG_DIR="$2"; shift; shift;
    ;;
    --local)  # Whether to run model locally or on compute nodes
    RUN_LOCALLY=true; shift;
    ;;
    *)
    echo "Couldn't process arg: $1"; shift;
    ;;
  esac
done

# Setting default values for optional args
SAMPLE=${SAMPLE:-"sample"}
OUTPUT_DIR=${OUTPUT_DIR:-"${DEEPVARIANT_DIR}/output"}
LOG_DIR=${LOG_DIR:-"${DEEPVARIANT_DIR}/logs"}
NSHARDS=${NSHARDS:-$(nproc)}
MODEL_TYPE=${MODEL_TYPE:-"inception_v3"}

# Make output directories
mkdir -p "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}/examples"
mkdir -p "${LOG_DIR}"
mkdir -p "${LOG_DIR}/train.log"

# Define directories used for training
SHUFFLE_SCRIPT_DIR="${DEEPVARIANT_DIR}/tfrecords_shuffler"
INCEPTION_DIR="${DEEPVARIANT_DIR}/inception_v3"

# Get TFRecords shuffler
mkdir -p "$SHUFFLE_SCRIPT_DIR"
if [ -f "${SHUFFLE_SCRIPT_DIR}/shuffle_tfrecords_beam.py" ]; then
  echo "# Found shuffle_tfrecords_beam.py in ${SHUFFLE_SCRIPT_DIR}/shuffle_tfrecords_beam.py"
else
  echo "# Downloading TFRecords shuffler in dir '${SHUFFLE_SCRIPT_DIR}'."
  wget  "$TFRECORDS_SHUFFLER_LINK" -O "${SHUFFLE_SCRIPT_DIR}/shuffle_tfrecords_beam.py"
fi

# Clean up existing training/validation files.
rm -f "${OUTPUT_DIR}/examples/${SAMPLE}.training_set.*"
rm -f "${OUTPUT_DIR}/examples/${SAMPLE}.validation_set.*"

# Set pre-trained model path
if [ $MODEL_TYPE == "inception_v3" ]; then
  PRETRAINED_MODEL="${INCEPTION_DIR}/inception_v3.ckpt"
else
  PRETRAINED_MODEL="/opt/models/${MODEL_TYPE}/model.ckpt"
fi

# Download Inception v3 if required.
if [ $MODEL_TYPE == "inception_v3" ]; then
  mkdir -p "$INCEPTION_DIR"
  if [ -f "$PRETRAINED_MODEL" ]; then
    echo "# Found Inception v3 model at $INCEPTION_MODEL"
  else
    wget "$INCEPTION_V3_LINK" -O "${INCEPTION_DIR}/inception_v3.tar.gz"
    tar -zxvf "${INCEPTION_DIR}/inception_v3.tar.gz" -C "$INCEPTION_DIR"
    # $PRETRAINED_MODEL should now be pointing to the extracted file (.../inception_v3.ckpt)
    rm "${INCEPTION_DIR}/inception_v3.tar.gz"
  fi
fi

if [[ "$RUN_LOCALLY" == true ]]
then
    source ./dv-local-training-pipeline.sh
else
    # Make examples for training and validation set
    make_examples_training_jobid=$(
      sbatch --parsable --export=ALL dv-slurm-make-examples-training.sh)
    make_examples_validation_jobid=$(
      sbatch --parsable --export=ALL dv-slurm-make-examples-validation.sh)
    # Shuffle training and validation examples
    shuffle_examples_training_jobid=$(
      sbatch --parsable --export=ALL --dependency=afterok:${make_examples_training_jobid} dv-slurm-shuffle-examples-training.sh)
    shuffle_examples_validation_jobid=$(
      sbatch --parsable --export=ALL --dependency=afterok:${make_examples_validation_jobid} dv-slurm-shuffle-examples-validation.sh)
    # Train model on training set and evaluate it as well on validation set
    model_train_jobid=$(
      sbatch --parsable --export=ALL --dependency=afterok:${shuffle_examples_training_jobid} dv-slurm-model-train.sh)
    model_eval_jobid=$(
      sbatch --parsable --export=ALL --dependency=afterok:${shuffle_examples_validation_jobid} dv-slurm-model-eval.sh)

    echo "Submitted jobs:"
    [[ ! -z $make_examples_training_jobid ]] && echo " - dv-slurm-make-examples-training:${make_examples_training_jobid}"
    [[ ! -z $make_examples_validation_jobid ]] && echo " - dv-slurm-make-examples-validation:${make_examples_validation_jobid}"
    [[ ! -z $shuffle_examples_training_jobid ]] && echo " - dv-slurm-shuffle-examples-training:${shuffle_examples_training_jobid}"
    [[ ! -z $shuffle_examples_validation_jobid ]] && echo " - dv-slurm-shuffle-examples-validation:${shuffle_examples_validation_jobid}"
    [[ ! -z $model_train_jobid ]] && echo " - dv-slurm-model-train:${model_train_jobid}"
    [[ ! -z $model_eval_jobid ]] && echo " - dv-slurm-model-eval:${model_eval_jobid}"
fi

set +a  # stop exporting all variables
