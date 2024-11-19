To build a new jupyter notebook image and use it for the RAG QSS:
1. Update the cloudbuild.yaml with the new image tag.

    The iamge tag should follow the pattern `sample-public-image-v<VERSION_NUMBER>-rag`.The prefix `sample-public-image-` is needed to so the images will internally be considered as vulnerability remediated and no more bugs will be filed for them.
2. Then in this path, run:

    `gcloud config set project ai-on-gke`

    `gcloud builds submit --config cloudbuild.yaml .`

    This will build and push the new image to the registry `us-central1-docker.pkg.dev/ai-on-gke/rag-on-gke`
3. Update the `notebook_image_tag` in `/applications/rag/main.tf` to the new image tag.
