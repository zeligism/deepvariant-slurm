
set -a  # export all variables

MODE=training
TFRECORDS_SHUFFLER_LINK="https://raw.githubusercontent.com/google/deepvariant/r0.9/tools/shuffle_tfrecords_beam.py"
INCEPTION_V3_LINK="http://download.tensorflow.org/models/inception_v3_2016_08_28.tar.gz"

# DeepVariant's directory and the jobs directory
DEEPVARIANT_DIR="${SCRATCH}/deepvariant"
DV_DIR="${DEEPVARIANT_DIR}/scripts"

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
    --pretrained_model)
    # Path to pretrained model to start training from (overrides model_type)
    PRETRAINED_MODEL="$2"; shift; shift;
    ;;
    --train_steps)
    # Number of training steps
    TRAIN_STEPS="$2"; shift; shift;
    ;;
    --eval_steps)
    # Number of evaluation/validation steps
    EVAL_STEPS="$2"; shift; shift;
    ;;
    --save_interval)
    # Save interval of training model (per second)
    SAVE_INTERVAL="$2"; shift; shift;
    ;;
    --batch_size)
    BATCH_SIZE="$2"; shift; shift;
    ;;
    --learning_rate)
    LEARNING_RATE="$2"; shift; shift;
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

    --no_examples)
    NO_MAKE_EXAMPLES=true; shift;
    ;;
    --no_shuffle)
    NO_SHUFFLE_EXAMPLES=true; shift;
    ;;
    --no_train)
    NO_MODEL_TRAIN=true; shift;
    ;;
    --no_eval)
    NO_MODEL_EVAL=true; shift;
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

# Default model parameters
TRAIN_STEPS=${TRAIN_STEPS:-1000}
EVAL_STEPS=${EVAL_STEPS:-100}
SAVE_INTERVAL=${SAVE_INTERVAL:-300}
BATCH_SIZE=${BATCH_SIZE:-4}  # 512
LEARNING_RATE=${LEARNING_RATE:-0.008}

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

# Set pre-trained model path, if not given
if [ -z $PRETRAINED_MODEL ]; then
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
fi

if [ "$RUN_LOCALLY" == true ]; then
  source "$DV_DIR/dv-local-training-pipeline.sh"
else
  # Make examples for training and validation set
  if [ -z $NO_MAKE_EXAMPLES ]; then
    make_examples_training_jobid=$(
      sbatch --parsable --export=ALL "$DV_DIR/dv-slurm-make-examples-training.sh"
    )
    make_examples_validation_jobid=$(
      sbatch --parsable --export=ALL "$DV_DIR/dv-slurm-make-examples-validation.sh"
    )
  fi
  # Shuffle training and validation examples
  if [ -z $NO_SHUFFLE_EXAMPLES ]; then
    shuffle_examples_training_jobid=$(
      sbatch --parsable --export=ALL \
             --dependency=afterok:${make_examples_training_jobid} \
              "$DV_DIR/dv-slurm-shuffle-examples-training.sh"
    )
    shuffle_examples_validation_jobid=$(
      sbatch --parsable --export=ALL \
             --dependency=afterok:${make_examples_validation_jobid} \
             "$DV_DIR/dv-slurm-shuffle-examples-validation.sh"
    )
  fi
  # Train model on training set and evaluate it as well on validation set
  if [ -z $NO_MODEL_TRAIN ]; then
    model_train_jobid=$(
      sbatch --parsable --export=ALL \
             --dependency=afterok:${shuffle_examples_training_jobid} \
             "$DV_DIR/dv-slurm-model-train.sh"
      )
  fi
  if [ -z $NO_MODEL_EVAL ]; then
    model_eval_jobid=$(
      sbatch --parsable --export=ALL \
             --dependency=afterok:${shuffle_examples_validation_jobid} \
             "$DV_DIR/dv-slurm-model-eval.sh"
      )
  fi

  echo "Submitted jobs:"
  [[ ! -z $make_examples_training_jobid ]] && echo " - dv-slurm-make-examples-training:${make_examples_training_jobid}"
  [[ ! -z $make_examples_validation_jobid ]] && echo " - dv-slurm-make-examples-validation:${make_examples_validation_jobid}"
  [[ ! -z $shuffle_examples_training_jobid ]] && echo " - dv-slurm-shuffle-examples-training:${shuffle_examples_training_jobid}"
  [[ ! -z $shuffle_examples_validation_jobid ]] && echo " - dv-slurm-shuffle-examples-validation:${shuffle_examples_validation_jobid}"
  [[ ! -z $model_train_jobid ]] && echo " - dv-slurm-model-train:${model_train_jobid}"
  [[ ! -z $model_eval_jobid ]] && echo " - dv-slurm-model-eval:${model_eval_jobid}"
fi

set +a  # stop exporting all variables
