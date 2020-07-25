
module purge
module load parallel
module load singularity
source activate dv

set -x

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

echo "### model_train ###"
time singularity exec ${SIMG_GPU:+--nv} --bind /scratch "${SIMG_GPU:-$SIMG}" \
  /opt/deepvariant/bin/model_train \
  --dataset_config_pbtxt="${OUTPUT_DIR}/examples/${SAMPLE}.training_set.dataset_config.pbtxt" \
  --train_dir="${LOG_DIR}/train.log" \
  --start_from_checkpoint="$PRETRAINED_MODEL" \
  --number_of_steps=50 \
  --save_interval_secs=300 \
  --batch_size=1 \
  --learning_rate=0.008

echo "### model_eval ###"
time singularity exec ${SIMG_GPU:+--nv} --bind /scratch "${SIMG_GPU:-$SIMG}" \
  /opt/deepvariant/bin/model_eval \
  --dataset_config_pbtxt="${OUTPUT_DIR}/examples/${SAMPLE}.validation_set.dataset_config.pbtxt" \
  --checkpoint_dir="${LOG_DIR}/train.log" \
  --batch_size=1 \
  --number_of_steps=50 \
  > "${LOG_DIR}/eval.log"

set +x
return $STATUS
