# ARCTIQ MISSION 

## Project Description

This project focuses on deploying individual GKE cluster using Terraform and autmating an application deployment
using Gitlab CI/CD pipeline. This project contains following

- Create GKE cluster
- Helm chart for k8s application deployment
- Python-flask application deployment
- Gitlab automation


## Requirements

To run this project following should be installed locally:

- Terrafor >=v1.3.2
- Google Cloud SDK >=405.0.0
- Git version >=2.38.0
- Python >=3.8.10
- Docker version >=20.10.10, build b485636 (for testing locally)
- Helm >=v3.10.1 (For testing locally)
- GCP
- Gitlab


## Bringing a GKE cluster UP

arctiq-gke folder contains 2 seperate modules for deploying gke cluster. One for production and another for staging.

Both of them contains the following configuration files:

- provider.tf
- vpc.tf
- subnets.tf
- router.tf
- nat.tf
- firewall.tf
- kubernetes.tf
- node-pools.tf


provider.tf contains the GCP project information and the GCS bucket that contains the tfstate files. Change the project ID and gcs bucket as required.

```
provider "google" {
    project = "GKE_CLUSTER_PROJECT_ID"
    region  = "us-central1"
}

terraform {
  backend "gcs" {
    bucket = "GKE_CLUSTER_TF_BUCKET"
    prefix = "terraform/state"
  }
  required_providers {
    google = {
        source  = "hashicorp/google"
        version = "~> 4.0"
    }
  }
}
```

vpc.tf, subnets.tf, router.tf, nat.tf, firewall.tf contain the network information for the GKE cluster. Modify it as required.


kubernets.tf and node-pools.tf are responsible for creating the control pane and node pools for the GKE cluster. Change location to deploy the GKE cluster in either region or in a zone.

```
resource "google_container_cluster" "GKE_CLUSTER_NAME" {
  name                     = "GKE_CLUSTER_NAME"
  location                 = "GKE_CLUSTER_REGION"
  remove_default_node_pool = true
  initial_node_count       =   1
  network                  = google_compute_network.main.self_link
  subnetwork               = google_compute_subnetwork.private.self_link
  logging_service          = "logging.googleapis.com/kubernetes"
  monitoring_service       = "monitoring.googleapis.com/kubernetes"
  networking_mode          = "VPC_NATIVE" 

  node_locations = [
    "us-central1-a",
    "us-central1-b"
  ]

  addons_config {
    http_load_balancing {
        disabled = true
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
  }
  
  release_channel {
    channel = "REGULAR"
  }

  workload_identity_config {
    workload_pool = "arctiq-mission-prod-3368.svc.id.goog"
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "k8s-pod-range"
    services_secondary_range_name = "k8s-service-range"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }
}
```

node-pools.tf containes the nodes in a cluster. Modify the file as per your requirement of the nodes. It also contains the service account with permission |
for pulling from container registry and communicate with cloud plateform.

```
resource "google_service_account" "kubernetes" {
  account_id = "kubernetes"
}

resource "google_container_node_pool" "general" {
  name       = "general"
  cluster    = google_container_cluster.production.id
  node_count = 2

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    preemptible  = false
    machine_type = "e2-small"

    labels = {
      role = "general"
    }

    service_account = google_service_account.kubernetes.email
    oauth_scopes = [
        "https://www.googleapis.com/auth/cloud-platform",
        "https://www.googleapis.com/auth/devstorage.read_only",

    ]
  }
}
```

To bring a GKE cluster following commands needs to run from the respective arctiq-mission-prod or arctiq-mission-staging folder

###### For authenticationg with GCP account
```
gcloud auth application-default login
```

###### Bringing up the GKE cluster
```
terraform apply
```

It will take about 20-30 min to create all the resources and bring the gke cluster up

###### Connecting to GKE cluster
Once terraform creates all resources, you can check the status of a cluster by first connecting to the cluster

```
 gcloud container clusters get-credentials GKE_CLUSTER_NAME --region GKE_CLUSTER_REGION --project GKE_CLUSTER_PROJECT_ID
```

After that run following to get the list of cluster to verify that GKE cluster creation is completed

```
k get nodes
```

## Python-flask application

In the project a simple 'Hello World' python-flask is build and deployed using Gitlab CI/CD

app.py contais the code for application.

```
import os

from flask import Flask

app = Flask(__name__)


@app.route('/')
def hello_world():
    target = os.environ.get('TARGET', 'Arctiq')
    return 'Hello {}!\n'.format(target)


if __name__ == "__main__":
    app.run(debug=True, host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))

```


## Gitlab CI/CD

.gitlab-ci.yml contains the stages and jobs for the fully automated CICD pipeline.

It contains different stages for Gitlab to go through. Following are the stages:

```
stages:
  - test
  - build
  - deploy feature
  - automated feature testing
  - deploy staging
  - automated testing
  - deploy production
```

Each stage corresponds to a job in the .gitlab-ci.yml file. A brief description of the stages are given below.

###### test stage

test stage contains lint_test and pytest job. They are for checking for stylistic or app logic error in the application code.

###### build stage

build stage contain task to dockerize the python-flask application, tag it and push it to GCP contaner registry.

Dockerfile contains the steps for building the application.

```
FROM python:3.8.0-slim
WORKDIR /app
ADD . /app
RUN pip install --upgrade pip
RUN pip install -r requirements.txt
CMD exec gunicorn app:app --bind 0.0.0.0:$PORT
```

###### Deploy feature and automated feature testing

Both of these stages are for deploying application on a temporary environment and testing the feature before it goes to staging and production

###### Stop feature
This a manual step for destroying the temporary environment.

```
stop_feature:
  image: google/cloud-sdk
  stage: deploy feature
  environment:
    name: feature/$CI_COMMIT_REF_NAME
    action: stop
  before_script:
   - echo "$STAGING_SERVICE_ACCOUNT_KEY" > key.json
   - gcloud auth activate-service-account --key-file=key.json
   - gcloud config set project $GCP_PROJECT_NAME_STAGING
   - gcloud config set container/cluster $GKE_CLUSTER_NAME_STAGING
   - gcloud config set compute/region us-central1
   - apt install curl
   - ./get_helm.sh
  script:
    - gcloud container clusters get-credentials $GKE_CLUSTER_NAME_STAGING --region us-central1 --project $GCP_PROJECT_NAME_STAGING
    - sed -i "s/<VERSION>/${CI_COMMIT_SHORT_SHA}/g" arctiq-helm/python-deployment/values.yaml
    - helm uninstall python-flask -n $FEATURE_NAMESPACE
  when: manual
```

###### Deploy staging and automated testing
In Deploy staging stage a google cloud sdk container is used to authenticate with the staging GKE cluster and use Helm Charts to deploy the python-flask application

```
deploy_stage:
  image: google/cloud-sdk:latest
  stage: deploy staging
  environment:
    name: staging
  before_script:
   - echo "$STAGING_SERVICE_ACCOUNT_KEY" > key.json
   - gcloud auth activate-service-account --key-file=key.json
   - gcloud config set project $GCP_PROJECT_NAME_STAGING
   - gcloud config set container/cluster $GKE_CLUSTER_NAME_STAGING
   - gcloud config set compute/region us-central1
   - apt install curl
   - ./get_helm.sh
  script:
    - gcloud container clusters get-credentials $GKE_CLUSTER_NAME_STAGING --region us-central1 --project $GCP_PROJECT_NAME_STAGING
    - sed -i "s/<VERSION>/${CI_COMMIT_SHORT_SHA}/g" arctiq-helm/python-deployment/values.yaml
    - helm upgrade python-flask -n $STAGING_NAMESPACE arctiq-helm/python-deployment
  only:
    - main
```

While automated testing stage is used for testing the aopplication after deployment.

```
test_stage:
  image: google/cloud-sdk
  stage: automated testing
  before_script:
   - echo "$STAGING_SERVICE_ACCOUNT_KEY" > key.json
   - gcloud auth activate-service-account --key-file=key.json
   - gcloud config set project $GCP_PROJECT_NAME_STAGING
   - gcloud config set container/cluster $GKE_CLUSTER_NAME_STAGING
   - gcloud config set compute/region us-central1
   - gcloud container clusters get-credentials $GKE_CLUSTER_NAME_STAGING --region us-central1 --project $GCP_PROJECT_NAME_STAGING
  script:
   - kubectl get svc -n $STAGING_NAMESPACE| awk '{print $4}' | grep -v "EXTERNAL-IP"| while read line; do curl "http://$line"; done | grep "Hello Arctiq!"
  only:
    - main
```

###### Deploy prod

if all the other stages passed, deploy prod stage is ready to deploy the application on production GKE cluster. A switch has been implemented here to manually deploy
on prodcution cluster

```
deploy_production:
  image: google/cloud-sdk
  stage: deploy production
  environment:
    name: production
  before_script:
   - echo "$PROD_SERVICE_ACCOUNT_KEY" > key.json
   - gcloud auth activate-service-account --key-file=key.json
   - gcloud config set project $GCP_PROJECT_NAME_PROD
   - gcloud config set container/cluster $GKE_CLUSTER_NAME_PROD
   - gcloud config set compute/region us-central1
   - apt install curl
   - ./get_helm.sh
  script:
    - gcloud container clusters get-credentials $GKE_CLUSTER_NAME_PROD --region us-central1 --project $GCP_PROJECT_NAME_PROD
    - sed -i "s/<VERSION>/${CI_COMMIT_SHORT_SHA}/g" arctiq-helm/python-deployment/values.yaml
    - helm upgrade python-flask -n $PROD_NAMESPACE arctiq-helm/python-deployment    
  only:
    - main
  when: manual
```