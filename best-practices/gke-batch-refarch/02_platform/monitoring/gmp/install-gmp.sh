[[ ! "${PROJECT_ID}" ]] && echo -e "Please export PROJECT_ID variable (\e[95mexport PROJECT_ID=<YOUR POROJECT ID>\e[0m)\nExiting." && exit 0
echo -e "\e[95mPROJECT_ID is set to ${PROJECT_ID}\e[0m"

[[ ! "${REGION}" ]] && echo -e "Please export REGION variable (\e[95mexport REGION=<YOUR REGION, eg: us-central1>\e[0m)\nExiting." && exit 0
echo -e "\e[95mREGION is set to ${REGION}\e[0m"

kubectl apply -f gmp-kueue-monitoring.yaml && \
gcloud monitoring dashboards create --project=$PROJECT_ID --config-from-file=kueue-dashboard.json