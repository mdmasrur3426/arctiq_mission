#!/bin/bash
if [[ "${1}" == "prod" ]];
then
	gcloud container clusters get-credentials production --zone us-central1-a --project arctiq-mission-prod-3368
	echo ${1}
elif [[ "${1}" == "staging" ]];
then
	gcloud container clusters get-credentials staging --zone us-central1-a --project arctiq-mission-staging-72622
	echo ${1}
else
	echo "Wrong Variable"
	echo "Production: ${0} prod"
	echo "Staging: ${0} staging"
fi
