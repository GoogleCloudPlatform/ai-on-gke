#!/bin/bash

export KAGGLE_CONFIG_DIR="/kaggle"
INFERENCE_SERVER="jetstream-maxtext"
BUCKET_NAME=""
MODEL_PATH=""

print_usage() {
    printf "Usage: $0 [ -b BUCKET_NAME ] [ -i INFERENCE_SERVER ] [ -m MODEL_PATH ] [ -q QUANTIZE ] [ -v VERSION ] [ -1 EXTRA_PARAM_1 ] [ -2 EXTRA_PARAM_2 ]"
}

print_inference_server_unknown() {
    printf "Enter a valid inference server [ -i INFERENCE_SERVER ]"
    printf "Valid options: jetstream-maxtext, jetstream-pytorch"
}

check_gsbucket() {
    BUCKET_NAME=$1
    if [ -z $BUCKET_NAME ]; then
        echo "BUCKET_NAME is empty, please provide a GSBucket"
    fi
}

check_model_path() {
    MODEL_PATH=$1
    if [ -z $MODEL_PATH ]; then
        echo "MODEL_PATH is empty, please provide the model path"
    fi
}

download_kaggle_checkpoint() {
    BUCKET_NAME=$1
    MODEL_PATH=$2
    export MODEL_NAME=$(echo ${MODEL_PATH} | awk -F'/' '{print $2}')
    export VARIATION_NAME=$(echo ${MODEL_PATH} | awk -F'/' '{print $4}')
    export MODEL_SIZE=$(echo ${VARIATION_NAME} | awk -F'-' '{print $1}')

    mkdir -p /data/${MODEL_NAME}_${VARIATION_NAME}
    kaggle models instances versions download ${MODEL_PATH} --untar -p /data/${MODEL_NAME}_${VARIATION_NAME}
    echo -e "\nCompleted extraction to /data/${MODEL_NAME}_${VARIATION_NAME}"

    gcloud storage rsync --recursive --no-clobber /data/${MODEL_NAME}_${VARIATION_NAME} gs://${BUCKET_NAME}/base/${MODEL_NAME}_${VARIATION_NAME}
    echo -e "\nCompleted copy of data to gs://${BUCKET_NAME}/base/${MODEL_NAME}_${VARIATION_NAME}"
}

convert_maxtext_checkpoint() {
    BUCKET_NAME=$1
    MODEL_NAME=$2
    VARIATION_NAME=$3
    MODEL_SIZE=$4
    MAXTEXT_VERSION=$5

    if [ -z $MAXTEXT_VERSION ]; then
        MAXTEXT_VERSION=jetstream-v0.2.0
    fi

    git clone https://github.com/google/maxtext.git

    # checkout stable MaxText commit
    cd maxtext
    git checkout ${MAXTEXT_VERSION}
    python3 -m pip install -r requirements.txt
    echo -e "\Cloned MaxText repository and completed installing requirements"

    python3 MaxText/convert_gemma_chkpt.py --base_model_path gs://${BUCKET_NAME}/base/${MODEL_NAME}_${VARIATION_NAME}/${VARIATION_NAME} --maxtext_model_path gs://${BUCKET_NAME}/final/scanned/${MODEL_NAME}_${VARIATION_NAME} --model_size ${MODEL_SIZE}
    echo -e "\nCompleted conversion of checkpoint to gs://${BUCKET_NAME}/final/scanned/${MODEL_NAME}_${VARIATION_NAME}"

    RUN_NAME=0

    python3 MaxText/generate_param_only_checkpoint.py MaxText/configs/base.yml force_unroll=true model_name=${MODEL_NAME}-${MODEL_SIZE} async_checkpointing=false run_name=${RUN_NAME} load_parameters_path=gs://${BUCKET_NAME}/final/scanned/${MODEL_NAME}_${VARIATION_NAME}/0/items base_output_directory=gs://${BUCKET_NAME}/final/unscanned/${MODEL_NAME}_${VARIATION_NAME}
    echo -e "\nCompleted unscanning checkpoint to gs://${BUCKET_NAME}/final/unscanned/${MODEL_NAME}_${VARIATION_NAME}/${RUN_NAME}/checkpoints/0/items"
}

convert_pytorch_checkpoint() {
    MODEL_PATH=$1
    INPUT_CKPT_DIR=$2
    OUTPUT_CKPT_DIR=$3
    QUANTIZE=$4
    PYTORCH_VERSION=$5
    JETSTREAM_VERSION=v0.2.0

    if [ -z $PYTORCH_VERSION ]; then
        PYTORCH_VERSION=jetstream-v0.2.0
    fi

    CKPT_PATH="$(echo ${INPUT_CKPT_DIR} | awk -F'gs://' '{print $2}')"
    BUCKET_NAME="$(echo ${CKPT_PATH} | awk -F'/' '{print $1}')"

    TO_REPLACE=gs://${BUCKET_NAME}
    INPUT_CKPT_DIR_LOCAL=${INPUT_CKPT_DIR/${TO_REPLACE}/${MODEL_PATH}}
    OUTPUT_CKPT_DIR_LOCAL=/pt-ckpt/

    if [ -z $QUANTIZE ]; then
        QUANTIZE="False"
    fi

    git clone https://github.com/google/JetStream.git
    git clone https://github.com/google/jetstream-pytorch.git
    cd JetStream
    git checkout ${JETSTREAM_VERSION}
    pip install -e

    # checkout stable Pytorch commit
    cd ../jetstream-pytorch
    git checkout ${PYTORCH_VERSION}
    bash install_everything.sh
    export PYTHONPATH=$PYTHONPATH:$(pwd)/deps/xla/experimental/torch_xla2:$(pwd)/JetStream:$(pwd)

    echo -e "\nRunning conversion script to convert model weights. This can take a couple minutes..."
    python3 -m convert_checkpoints --input_checkpoint_dir=${INPUT_CKPT_DIR_LOCAL} --output_checkpoint_dir=${OUTPUT_CKPT_DIR_LOCAL} --quantize=${QUANTIZE}
    
    echo -e "\nCompleted conversion of checkpoint to ${OUTPUT_CKPT_DIR_LOCAL}"
    echo -e "\nUploading converted checkpoint from local path ${OUTPUT_CKPT_DIR_LOCAL} to GSBucket ${OUTPUT_CKPT_DIR}"

    gcloud storage cp -r ${OUTPUT_CKPT_DIR_LOCAL}/* ${OUTPUT_CKPT_DIR}
    echo -e "\nCompleted uploading converted checkpoint from local path ${OUTPUT_CKPT_DIR_LOCAL} to GSBucket ${OUTPUT_CKPT_DIR}"
}


while getopts 'b:i:m:q:v:1:2:' flag; do
    case "${flag}" in
        b) BUCKET_NAME="$(echo ${OPTARG} | awk -F'=' '{print $2}')" ;;
        i) INFERENCE_SERVER="$(echo ${OPTARG} | awk -F'=' '{print $2}')" ;;
        m) MODEL_PATH="$(echo ${OPTARG} | awk -F'=' '{print $2}')" ;;
        q) QUANTIZE="$(echo ${OPTARG} | awk -F'=' '{print $2}')" ;;
        v) VERSION="$(echo ${OPTARG} | awk -F'=' '{print $2}')" ;;
        1) EXTRA_PARAM_1="$(echo ${OPTARG} | awk -F'=' '{print $2}')" ;;
        2) EXTRA_PARAM_2="$(echo ${OPTARG} | awk -F'=' '{print $2}')" ;;
        *) print_usage
    exit 1 ;;
    esac
done

echo "Inference server is ${INFERENCE_SERVER}"

case ${INFERENCE_SERVER} in 

    jetstream-maxtext)
        check_gsbucket "$BUCKET_NAME"
        check_model_path "$MODEL_PATH"
        download_kaggle_checkpoint "$BUCKET_NAME" "$MODEL_PATH"
        convert_maxtext_checkpoint "$BUCKET_NAME" "$MODEL_NAME" "$VARIATION_NAME" "$MODEL_SIZE" "$VERSION"
        ;;
    jetstream-pytorch)
    check_model_path "$MODEL_PATH"
        convert_pytorch_checkpoint "$MODEL_PATH" "$EXTRA_PARAM_1" "$EXTRA_PARAM_2" "$QUANTIZE" "$VERSION"
        ;;
    *) print_inference_server_unknown
exit 1 ;;
esac