#!/bin/bash

export KAGGLE_CONFIG_DIR="/kaggle"
export HUGGINGFACE_TOKEN_DIR="/huggingface"
INFERENCE_SERVER="jetstream-maxtext"
BUCKET_NAME=""
MODEL_PATH=""

print_usage() {
    printf "Usage: $0 [ -b BUCKET_NAME ] [ -s INFERENCE_SERVER ] [ -m MODEL_PATH ] [ -n MODEL_NAME ] [ -h HUGGINGFACE ] [ -q QUANTIZE_WEIGHTS ] [ -t QUANTIZE_TYPE ] [ -v VERSION ] [ -i INPUT_DIRECTORY ] [ -o OUTPUT_DIRECTORY ]"
}

print_inference_server_unknown() {
    printf "Enter a valid inference server [ -s INFERENCE_SERVER ]"
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

download_huggingface_checkpoint() {
    MODEL_PATH=$1
    MODEL_NAME=$2

    INPUT_CKPT_DIR_LOCAL=/base/
    mkdir /base/
    huggingface-cli login --token $(cat ${HUGGINGFACE_TOKEN_DIR}/HUGGINGFACE_TOKEN)
    huggingface-cli download ${MODEL_PATH} --local-dir ${INPUT_CKPT_DIR_LOCAL}

    if [[ $MODEL_NAME == *"llama"* ]]; then
        if [[ $MODEL_NAME == "llama-2" ]]; then
            TOKENIZER_PATH=/base/tokenizer.model
            if [[ $MODEL_PATH != *"hf"* ]]; then
                HUGGINGFACE="False"
            fi
        else
            TOKENIZER_PATH=/base/original/tokenizer.model
        fi
    elif [[ $MODEL_NAME == *"gemma"* ]]; then
        TOKENIZER_PATH=/base/tokenizer.model
    else
        echo -e "Unclear of tokenizer.model for ${MODEL_NAME}. May have to manually upload."
    fi
}

convert_maxtext_checkpoint() {
    BUCKET_NAME=$1
    MODEL_NAME=$2
    VARIATION_NAME=$3
    MODEL_SIZE=$4
    MAXTEXT_VERSION=$5

    if [ -z $MAXTEXT_VERSION ]; then
        MAXTEXT_VERSION=jetstream-v0.2.2
    fi

    git clone https://github.com/google/maxtext.git

    # checkout stable MaxText commit
    cd maxtext
    git checkout ${MAXTEXT_VERSION}
    python3 -m pip install -r requirements.txt
    echo -e "\nCloned MaxText repository and completed installing requirements"

    python3 MaxText/convert_gemma_chkpt.py --base_model_path gs://${BUCKET_NAME}/base/${MODEL_NAME}_${VARIATION_NAME}/${VARIATION_NAME} --maxtext_model_path gs://${BUCKET_NAME}/final/scanned/${MODEL_NAME}_${VARIATION_NAME} --model_size ${MODEL_SIZE}
    echo -e "\nCompleted conversion of checkpoint to gs://${BUCKET_NAME}/final/scanned/${MODEL_NAME}_${VARIATION_NAME}"

    RUN_NAME=0

    python3 MaxText/generate_param_only_checkpoint.py MaxText/configs/base.yml force_unroll=true model_name=${MODEL_NAME}-${MODEL_SIZE} async_checkpointing=false run_name=${RUN_NAME} load_parameters_path=gs://${BUCKET_NAME}/final/scanned/${MODEL_NAME}_${VARIATION_NAME}/0/items base_output_directory=gs://${BUCKET_NAME}/final/unscanned/${MODEL_NAME}_${VARIATION_NAME}
    echo -e "\nCompleted unscanning checkpoint to gs://${BUCKET_NAME}/final/unscanned/${MODEL_NAME}_${VARIATION_NAME}/${RUN_NAME}/checkpoints/0/items"
}

convert_pytorch_checkpoint() {
    MODEL_PATH=$1
    MODEL_NAME=$2
    HUGGINGFACE=$3
    INPUT_CKPT_DIR=$4
    OUTPUT_CKPT_DIR=$5
    QUANTIZE_TYPE=$6
    QUANTIZE_WEIGHTS=$7
    PYTORCH_VERSION=$8

    if [ -z $PYTORCH_VERSION ]; then
        PYTORCH_VERSION=jetstream-v0.2.3
    fi

    CKPT_PATH="$(echo ${INPUT_CKPT_DIR} | awk -F'gs://' '{print $2}')"
    BUCKET_NAME="$(echo ${CKPT_PATH} | awk -F'/' '{print $1}')"

    TO_REPLACE=gs://${BUCKET_NAME}

    OUTPUT_CKPT_DIR_LOCAL=/pt-ckpt/

    git clone https://github.com/google/jetstream-pytorch.git

    # checkout stable Pytorch commit
    cd /jetstream-pytorch
    git checkout ${PYTORCH_VERSION}
    bash install_everything.sh
    echo -e "\nCloned JetStream PyTorch repository and completed installing requirements"

    echo -e "\nRunning conversion script to convert model weights. This can take a couple minutes..."

    if [ $HUGGINGFACE == "True" ]; then
        echo "Checkpoint weights are from HuggingFace"
        download_huggingface_checkpoint "$MODEL_PATH" "$MODEL_NAME"
    else
        HUGGINGFACE="False"

        # Example: 
        # the input checkpoint directory is gs://jetstream-checkpoints/llama-2-7b/base-checkpoint/
        # the local checkpoint directory will be /models/llama-2-7b/base-checkpoint/
        # INPUT_CKPT_DIR_LOCAL=${INPUT_CKPT_DIR/${TO_REPLACE}/${MODEL_PATH}}
        INPUT_CKPT_DIR_LOCAL=${INPUT_CKPT_DIR/${TO_REPLACE}/${MODEL_PATH}}
        TOKENIZER_PATH=${INPUT_CKPT_DIR_LOCAL}/tokenizer.model
    fi

    if [ -z $QUANTIZE_WEIGHTS ]; then
        QUANTIZE_WEIGHTS="False"
    fi

    # Possible quantizations:
    # 1. quantize_weights = False, we run without specifying quantize_type
    # 2. quantize_weights = True, we run without specifying quantize_type to use the default int8_per_channel
    # 3. quantize_weights = True, we run and specify quantize_type
    # We can use the same command for case #1 and #2, since both have quantize_weights set without needing to specify quantize_type

    echo -e "\n quantize weights: ${QUANTIZE_WEIGHTS}"
    if [ $QUANTIZE_WEIGHTS == "True" ]; then 
        # quantize_type is required, it will be set to the default value if not turned on
        if [ -n $QUANTIZE_TYPE ]; then
            python3 -m convert_checkpoints --model_name=${MODEL_NAME} --input_checkpoint_dir=${INPUT_CKPT_DIR_LOCAL} --output_checkpoint_dir=${OUTPUT_CKPT_DIR_LOCAL} --quantize_type=${QUANTIZE_TYPE} --quantize_weights=${QUANTIZE_WEIGHTS} --from_hf=${HUGGINGFACE}
        fi
    else
        # quantize_weights should be false, but if not the convert_checkpoints script will catch it
        python3 -m convert_checkpoints --model_name=${MODEL_NAME} --input_checkpoint_dir=${INPUT_CKPT_DIR_LOCAL} --output_checkpoint_dir=${OUTPUT_CKPT_DIR_LOCAL} --quantize_weights=${QUANTIZE_WEIGHTS} --from_hf=${HUGGINGFACE}
    fi
    
    echo -e "\nCompleted conversion of checkpoint to ${OUTPUT_CKPT_DIR_LOCAL}"
    echo -e "\nUploading converted checkpoint from local path ${OUTPUT_CKPT_DIR_LOCAL} to GSBucket ${OUTPUT_CKPT_DIR}"
    

    gcloud storage cp -r ${OUTPUT_CKPT_DIR_LOCAL}/* ${OUTPUT_CKPT_DIR}
    gcloud storage cp ${TOKENIZER_PATH} ${OUTPUT_CKPT_DIR}
    echo -e "\nCompleted uploading converted checkpoint from local path ${OUTPUT_CKPT_DIR_LOCAL} to GSBucket ${OUTPUT_CKPT_DIR}"
}


while getopts 'b:s:m:n:h:t:q:v:i:o:' flag; do
    case "${flag}" in
        b) BUCKET_NAME="$(echo ${OPTARG} | awk -F'=' '{print $2}')" ;;
        s) INFERENCE_SERVER="$(echo ${OPTARG} | awk -F'=' '{print $2}')" ;;
        m) MODEL_PATH="$(echo ${OPTARG} | awk -F'=' '{print $2}')" ;;
        n) MODEL_NAME="$(echo ${OPTARG} | awk -F'=' '{print $2}')" ;;
        h) HUGGINGFACE="$(echo ${OPTARG} | awk -F'=' '{print $2}')" ;;
        t) QUANTIZE_TYPE="$(echo ${OPTARG} | awk -F'=' '{print $2}')" ;;
        q) QUANTIZE_WEIGHTS="$(echo ${OPTARG} | awk -F'=' '{print $2}')" ;;
        v) VERSION="$(echo ${OPTARG} | awk -F'=' '{print $2}')" ;;
        i) INPUT_DIRECTORY="$(echo ${OPTARG} | awk -F'=' '{print $2}')" ;;
        o) OUTPUT_DIRECTORY="$(echo ${OPTARG} | awk -F'=' '{print $2}')" ;;
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
        convert_pytorch_checkpoint "$MODEL_PATH" "$MODEL_NAME" "$HUGGINGFACE" "$INPUT_DIRECTORY" "$OUTPUT_DIRECTORY" "$QUANTIZE_TYPE" "$QUANTIZE_WEIGHTS" "$VERSION"
        ;;
    *) print_inference_server_unknown
exit 1 ;;
esac