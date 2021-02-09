
module purge
module load parallel
module load singularity

set -x

echo "### make_examples ###"
seq 0 $((NSHARDS-1)) | \
parallel -j 4 --eta --halt 2 --joblog "${LOG_DIR}/log" --res "${LOG_DIR}" \
    singularity exec --bind /scratch "$SIMG" \
      /opt/deepvariant/bin/make_examples \
        --mode calling \
        --ref "$REF" \
        --reads "$BAM" \
        --examples "$EXAMPLES" \
        --min_mapping_quality $MIN_MAPPING_QUALITY \
        ${CAPTURE_BED:+--regions "$CAPTURE_BED"} \
        ${GVCF_TFRECORDS:+--gvcf "$GVCF_TFRECORDS"} \
        ${GVCF_TFRECORDS:+--gvcf_gq_binsize 5} \
        --task {}
STATUS=$?

echo "### call_variants ###"
singularity exec ${SIMG_GPU:+--nv} --bind /scratch "${SIMG_GPU:-$SIMG}"  \
  /opt/deepvariant/bin/call_variants \
    --checkpoint "$MODEL" \
    --examples "$EXAMPLES" \
    --outfile "$CALL_VARIANTS_OUTPUT"
STATUS=$?

echo "### postprocess_variants ###"
singularity exec --bind /scratch "$SIMG" \
  /opt/deepvariant/bin/postprocess_variants \
    --ref "$REF" \
    --infile "$CALL_VARIANTS_OUTPUT" \
    --outfile "$OUTPUT_VCF" \
    ${GVCF_TFRECORDS:+--nonvariant_site_tfrecord_path "$GVCF_TFRECORDS"} \
    ${OUTPUT_GVCF:+--gvcf_outfile "$OUTPUT_GVCF"}
STATUS=$?

set +x
