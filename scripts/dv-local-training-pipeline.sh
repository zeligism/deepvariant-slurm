
module purge
module load parallel
module load singularity
source activate dv

set -x

if [ -z $NO_MAKE_EXAMPLES ]; then
  echo "### make_examples (training) ###"
  seq 0 $((NSHARDS-1)) | \
  parallel -j $(nproc) --eta --halt 2 --joblog "${LOG_DIR}/log" --res "${LOG_DIR}" \
      singularity exec --bind /scratch "$SIMG" \
        /opt/deepvariant/bin/make_examples \
          --mode training \
          --ref "$REF" \
          --reads "$BAM" \
          --examples "${OUTPUT_DIR}/examples/${SAMPLE}.training_set.with_label.tfrecord@${NSHARDS}.gz" \
          --truth_variants "$TRUTH_VCF" \
          ${TRUTH_BED:+--confident_regions "$TRUTH_BED"} \
          ${EXCLUDE_REGIONS:+--exclude_regions "$EXCLUDE_REGIONS"} \
          --task {}
  STATUS=$?

  echo "### make_examples (validation) ###"
  seq 0 $((NSHARDS-1)) | \
  parallel -j $(nproc) --eta --halt 2 --joblog "${LOG_DIR}/log" --res "${LOG_DIR}" \
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
fi

if [ -z $NO_SHUFFLE_EXAMPLES ]; then
  echo "### Shuffling Validation examples ###"
  time python ${SHUFFLE_SCRIPT_DIR}/shuffle_tfrecords_beam.py \
    --input_pattern_list="${OUTPUT_DIR}/examples/${SAMPLE}.validation_set.with_label.tfrecord-?????-of-$(printf '%05d' $NSHARDS).gz" \
    --output_pattern_prefix="${OUTPUT_DIR}/examples/${SAMPLE}.validation_set.with_label.shuffled" \
    --output_dataset_config_pbtxt="${OUTPUT_DIR}/examples/${SAMPLE}.validation_set.dataset_config.pbtxt" \
    --output_dataset_name="$SAMPLE" \
    --runner=DirectRunner

  echo "### Shuffling Training examples ###"
  time python ${SHUFFLE_SCRIPT_DIR}/shuffle_tfrecords_beam.py \
    --input_pattern_list="${OUTPUT_DIR}/examples/${SAMPLE}.training_set.with_label.tfrecord-?????-of-$(printf '%05d' $NSHARDS).gz" \
    --output_pattern_prefix="${OUTPUT_DIR}/examples/${SAMPLE}.training_set.with_label.shuffled" \
    --output_dataset_config_pbtxt="${OUTPUT_DIR}/examples/${SAMPLE}.training_set.dataset_config.pbtxt" \
    --output_dataset_name="$SAMPLE" \
    --runner=DirectRunner
fi

if [ -z $NO_MODEL_TRAIN ]; then
  echo "### model_train ###"
  time singularity exec ${SIMG_GPU:+--nv} --bind /scratch "${SIMG_GPU:-$SIMG}" \
    /opt/deepvariant/bin/model_train \
    --dataset_config_pbtxt="${OUTPUT_DIR}/examples/${SAMPLE}.training_set.dataset_config.pbtxt" \
    --train_dir="${LOG_DIR}/train.log" \
    --start_from_checkpoint="$PRETRAINED_MODEL" \
    --number_of_steps=$TRAIN_STEPS \
    --save_interval_secs=$SAVE_INTERVAL \
    --batch_size=$BATCH_SIZE \
    --learning_rate=$LEARNING_RATE
fi

if [ -z $NO_MODEL_EVAL ]; then
  echo "### model_eval ###"
  time singularity exec ${SIMG_GPU:+--nv} --bind /scratch "${SIMG_GPU:-$SIMG}" \
    /opt/deepvariant/bin/model_eval \
    --dataset_config_pbtxt="${OUTPUT_DIR}/examples/${SAMPLE}.validation_set.dataset_config.pbtxt" \
    --checkpoint_dir="${LOG_DIR}/train.log" \
    --batch_size=$BATCH_SIZE \
    --number_of_steps=$EVAL_STEPS \
    > "${LOG_DIR}/eval.log"
fi

set +x
return $STATUS
