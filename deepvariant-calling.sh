
set -a  # export all variables

MODE=calling

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
    --regions)  # Regions in which variants will be captured (optional)
    CAPTURE_BED="$2"; shift; shift;
    ;;
    --min_mapping_quality)  # Generate examples with this min mapping quality (optional)
    MIN_MAPPING_QUALITY="$2"; shift; shift;
    ;;

    --sample)  # Name of genome sample (default = sample)
    SAMPLE="$2"; shift; shift;
    ;;
    --num_shards)  # Number of shards (default = 4)
    NSHARDS="$2"; shift; shift;
    ;;
    --model)  # Path to DeepVariant model calling variants (default = wes model)
    MODEL="$2"; shift; shift;
    ;;
    --model_type)  # Type of DeepVariant model among: {wes,wgs,pacbio}
    MODEL_TYPE="$2"; shift; shift;
    ;;
    --output_dir)  # Output directory (default = output)
    OUTPUT_DIR="$2"; shift; shift;
    ;;
    --log_dir)  # Log directory (default = logs)
    LOG_DIR="$2"; shift; shift;
    ;;
    --gvcf)  # Flag to out gVCF files as well
    GVCF=true; shift;
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
MODEL_TYPE=${MODEL_TYPE:-"wes"}
MODEL=${MODEL:-"/opt/models/${MODEL_TYPE}/model.ckpt"}
MIN_MAPPING_QUALITY=${MIN_MAPPING_QUALITY:-10}

# Output of DeepVariant
OUTPUT_VCF="${OUTPUT_DIR}/${SAMPLE}.vcf.gz"
OUTPUT_GVCF="${OUTPUT_DIR}/${SAMPLE}.gvcf.gz"

# Intermediate results of DeepVariant
EXAMPLES="${OUTPUT_DIR}/examples/${SAMPLE}.examples.tfrecord@${NSHARDS}.gz"
CALL_VARIANTS_OUTPUT="${OUTPUT_DIR}/${SAMPLE}.call_variants_output.tfrecord.gz"
GVCF_TFRECORDS="${OUTPUT_DIR}/examples/${SAMPLE}.gvcf.tfrecord@${NSHARDS}.gz"

# If gVCF not specified, unset gVCF-related variables
[[ -z $GVCF ]] && unset GVCF_TFRECORDS && unset OUTPUT_GVCF

# Make output directories
mkdir -p "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}/examples"
mkdir -p "${LOG_DIR}"

if [[ "$RUN_LOCALLY" == true ]]
then
    source "$DV_DIR/dv-local-calling-pipeline.sh"
else
    # Submit SLURM jobs
    make_examples_jobid=$(
      sbatch --parsable --export=ALL \
             "$DV_DIR/dv-slurm-make-examples.sh"
      )
    call_variants_jobid=$(
      sbatch --parsable --export=ALL \
             --dependency=afterok:${make_examples_jobid} \
             "$DV_DIR/dv-slurm-call-variants.sh"
      )
    postprocess_variants_jobid=$(
      sbatch --parsable --export=ALL \
             --dependency=afterok:${call_variants_jobid} \
             "$DV_DIR/dv-slurm-postprocess-variants.sh"
      )
    echo "Submitted jobs:"
    [[ ! -z $make_examples_jobid ]] && echo " - dv-slurm-make-examples:${make_examples_jobid}"
    [[ ! -z $call_variants_jobid ]] && echo " - dv-slurm-call-variants:${call_variants_jobid}"
    [[ ! -z $postprocess_variants_jobid ]] && echo " - dv-slurm-postprocess_variants:${postprocess_variants_jobid}"
fi

set +a  # stop exporting all variables
