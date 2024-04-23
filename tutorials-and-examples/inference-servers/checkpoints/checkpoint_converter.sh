#!/bin/bash

export KAGGLE_CONFIG_DIR="/kaggle"
INFERENCE_SERVER="jetstream-maxtext"
BUCKET_NAME=""
MODEL_PATH=""

print_usage() {
    printf "Usage: $0 [ -b BUCKET_NAME ] [ -i INFERENCE_SERVER ] [ -m MODEL_PATH ] [ -v VERSION ]"
}

print_inference_server_unknown() {
    printf "Enter a valid inference server [ -i INFERENCE_SERVER ]"
    printf "Valid options: jetstream-maxtext"
}

download_kaggle_checkpoint() {
    BUCKET_NAME=$1
    MODEL_NAME=$2
    VARIATION_NAME=$3
    MODEL_PATH=$4

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


while getopts 'b:i:m:' flag; do
    case "${flag}" in
        b) BUCKET_NAME="$(echo ${OPTARG} | awk -F'=' '{print $2}')" ;;
        i) INFERENCE_SERVER="$(echo ${OPTARG} | awk -F'=' '{print $2}')" ;;
        m) MODEL_PATH="$(echo ${OPTARG} | awk -F'=' '{print $2}')" ;;
        v) VERSION="$(echo ${OPTARG} | awk -F'=' '{print $2}')" ;;
        *) print_usage
    exit 1 ;;
    esac
done

if [ -z $BUCKET_NAME ]; then
    echo "BUCKET_NAME is empty, please provide a GSBucket"
    fi

if [ -z $MODEL_PATH ]; then
    echo "MODEL_PATH is empty, please provide the model path"
    fi

echo "Inference server is ${INFERENCE_SERVER}"
MODEL_NAME=$(echo ${MODEL_PATH} | awk -F'/' '{print $2}')
VARIATION_NAME=$(echo ${MODEL_PATH} | awk -F'/' '{print $4}')
MODEL_SIZE=$(echo ${VARIATION_NAME} | awk -F'-' '{print $1}')

case ${INFERENCE_SERVER} in 

    jetstream-maxtext)
        download_kaggle_checkpoint "$BUCKET_NAME" "$MODEL_NAME" "$VARIATION_NAME" "$MODEL_PATH"
        convert_maxtext_checkpoint "$BUCKET_NAME" "$MODEL_NAME" "$VARIATION_NAME" "$MODEL_SIZE" "$VERSION"
        ;;
    *) print_inference_server_unknown
exit 1 ;;
esac