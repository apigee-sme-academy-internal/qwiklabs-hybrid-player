#!/bin/bash

set -e

# v0.1

## prerequisites: git jq

if [ -z "$PROJECT" ]; then
    echo "Project variable PROJECT is required."
    exit 1
fi

echo "Set up environment variables and project id..."

export REGION=${REGION:-europe-west1}
export ZONE=${ZONE:-europe-west1-b}
export AX_REGION=${AX_REGION:-europe-west1}

export CLUSTER=hybrid-cluster

export HYBRID_VERSION=1.2.0
export HYBRID_TARBALL=apigeectl_linux_64.tar.gz
export HYBRID_HOME=~/$PROJECT

mkdir -p $HYBRID_HOME


export ORG=$PROJECT
export ENV=${ENV:-test}

gcloud config set project $PROJECT > /dev/null

function token { echo -n "$(gcloud config config-helper --force-auth-refresh | grep access_token | grep -o -E '[^ ]+$')" ; }
export -f token


# example: wait_for_ready "ready" 'cat ready.txt' "File is ready."
function wait_for_ready(){
    local status=$1
    local action=$2
    local message=$3

    while true; do
        local signal=$(eval "$action")
        if [ $(echo $status) = "$signal" ]; then
            echo -e "\n$message"
            break
        fi
        echo -n "."
        sleep 5
    done
}

function get_account() {
  ACCOUNT=$(gcloud config list --format='value(core.account)')
  gcloud iam service-accounts describe $ACCOUNT &> /dev/null
  if [ $? -eq 0 ] ; then
    echo "serviceAccount:$ACCOUNT"
    return
  fi
  echo "user:$ACCOUNT"
}


echo "Enabling required APIs..."

gcloud services enable compute.googleapis.com container.googleapis.com apigee.googleapis.com apigeeconnect.googleapis.com cloudresourcemanager.googleapis.com


echo "Enabling Audit Logs..."

export AUDITCONFIGS='[
    {
      "auditLogConfigs": [
        { "logType": "ADMIN_READ" },
        { "logType": "DATA_READ"  },
        { "logType": "DATA_WRITE" }
      ],
      "service": "apigee.googleapis.com"
    }
  ]'

gcloud projects get-iam-policy $PROJECT --format=json | jq .auditConfigs="$AUDITCONFIGS" > $HYBRID_HOME/iam-policy.json
gcloud projects set-iam-policy $PROJECT $HYBRID_HOME/iam-policy.json


#CLUSTER_EXISTS=$(gcloud container clusters list --project $PROJECT --zone $ZONE --filter='name=hybrid-cluster')
#if [ -z "CLUSTER_EXISTS" ]; then
echo "Forking cluster creation..."
    ## FORK: Create cluster
set +e
    gcloud container clusters create $CLUSTER --machine-type "n1-standard-4" --num-nodes "3" --cluster-version "1.14" --zone $ZONE --async
set -e
#fi

# create organization
curl -H "Authorization: Bearer $(token)" -H "Content-Type:application/json"  "https://apigee.googleapis.com/v1/organizations?parent=projects/$PROJECT" --data-binary @- <<EOT
{
    "name": "$PROJECT",
    "display_name": "$PROJECT",
    "description": "Qwiklab student org $PROJECT",
    "analyticsRegion": "$AX_REGION"
}
EOT

## JOIN: create org
wait_for_ready "\"$ORG\"" 'curl --silent -H "Authorization: Bearer $(token)" -H "Content-Type: application/json"  https://apigee.googleapis.com/v1/organizations/$ORG | jq ".name"' "Organization $ORG is created." 


 

# Create environment
curl -H "Authorization: Bearer $(token)" -H "Content-Type: application/json"  https://apigee.googleapis.com/v1/organizations/$PROJECT/environments --data-binary @- <<EOT
{
  "name": "$ENV",
  "description": "$ENV environment",
  "displayName": "$ENV"
}
EOT

## JOIN: env is created
wait_for_ready "\"$ENV\"" 'curl --silent -H "Authorization: Bearer $(token)" -H "Content-Type: application/json"  https://apigee.googleapis.com/v1/organizations/$ORG/environments/$ENV | jq ".name"' "Environment $ENV of Organization $ORG is created." 


## FORK-NOHUP-WAIT: ORGENV Hybrid Player Hook
export HPH_ORGENV_LOG=${HPH_ORGENV_LOG:-$HYBRID-HOME/hph-orgenv.log}
nohup bash <<EOS &> $HPH_ORGENV_LOG &
if [ ! -z "$HPH_ORGENV_CMD" ]; then
(
    if [ ! -z "$HPH_ORGENV_DIR" ]; then
        cd $HPH_ORGENV_DIR
    fi
    $HPH_ORGENV_CMD
)
fi
EOS
export HPH_ORGENV_PID=$!


echo "Cluster creation..."
## JOIN: cluster
wait_for_ready "RUNNING" 'gcloud container clusters describe hybrid-cluster --zone $ZONE --format="value(status)"' 'The cluster is ready.'



gcloud container clusters get-credentials $CLUSTER --zone $ZONE

## FORK-NOHUP-WAIT: CLUSTER Hybrid Player Hook
export HPH_CLUSTER_LOG=${HPH_CLUSTER_LOG:-$HYBRID-HOME/hph-cluster.log}
nohup bash <<EOS &> $HPH_CLUSTER_LOG &
if [ ! -z "$HPH_CLUSTER_CMD" ]; then
(
    if [ ! -z "$HPH_CLUSTER_DIR" ]; then
        cd $HPH_CLUSTER_DIR
    fi
    $HPH_CLUSTER_CMD
)
fi
EOS
export HPH_CLUSTER_PID=$!

set +e
kubectl create clusterrolebinding cluster-admin-binding --clusterrole cluster-admin --user $(gcloud config get-value account)
set -e


(
cd $HYBRID_HOME
curl -LO https://storage.googleapis.com/apigee-public/apigee-hybrid-setup/$HYBRID_VERSION/$HYBRID_TARBALL

tar -xvf $HYBRID_HOME/$HYBRID_TARBALL
)


export APIGEECTL_HOME=$HYBRID_HOME/$(tar tf $HYBRID_HOME/$HYBRID_TARBALL | grep VERSION.txt | cut -d "/" -f 1)

export PATH=$APIGEECTL_HOME:$PATH

#
# runtime
#


# api endpoint router ip
set +e
RUNTIME_IP=$(gcloud compute addresses describe runtime-ip --region $REGION --format='value(address)')
set -e
if [ "$RUNTIME_IP" = "" ]; then
    gcloud compute addresses create runtime-ip --region $REGION
    RUNTIME_IP=$(gcloud compute addresses describe runtime-ip --region $REGION --format='value(address)')
fi
export RUNTIME_IP

export RUNTIME_HOST_ALIAS=${RUNTIME_HOST_ALIAS:-api.exco.com}
export RUNTIME_SSL_CERT=${RUNTIME_SSL_CERT:-$HYBRID_HOME/exco-hybrid-crt.pem}
export RUNTIME_SSL_KEY=${RUNTIME_SSL_KEY:-$HYBRID_HOME/exco-hybrid-key.pem}

if [[ ! -f "${RUNTIME_SSL_CERT}" ]] || [ ! -f "${RUNTIME_SSL_KEY}" ]; then
  echo "Using self-signed certificate for ${RUNTIME_HOST_ALIAS} ..."
  openssl req -x509 -out $RUNTIME_SSL_CERT -keyout $RUNTIME_SSL_KEY -newkey rsa:2048 -nodes -sha256 -subj '/CN=api.exco.com' -extensions EXT -config <( printf "[dn]\nCN=api.exco.com\n[req]\ndistinguished_name=dn\n[EXT]\nbasicConstraints=critical,CA:TRUE,pathlen:1\nsubjectAltName=DNS:api.exco.com\nkeyUsage=digitalSignature,keyCertSign\nextendedKeyUsage=serverAuth")
fi

#
# mart (to be ignored)
#

set +e
MART_IP=$(gcloud compute addresses describe mart-ip --region $REGION --format='value(address)')
set -e
if [ "$MART_IP" = "" ]; then
    gcloud compute addresses create mart-ip --region $REGION
    MART_IP=$(gcloud compute addresses describe mart-ip --region $REGION --format='value(address)')
fi
export MART_IP

export MART_HOST_ALIAS=${MART_HOST_ALIAS:-mart.exco.com}
export MART_SSL_CERT=${MART_SSL_CERT:-$RUNTIME_SSL_CERT}
export MART_SSL_KEY=${MART_SSL_KEY:-$RUNTIME_SSL_KEY}


## FORK-NOHUP-WAIT: IPS Hybrid Player Hook
export HPH_IPS_LOG=${HPH_IPS_LOG:-$HYBRID-HOME/hph-ips.log}
nohup bash <<EOS &> $HPH_IPS_LOG &
if [ ! -z "$HPH_IPS_CMD" ]; then
(
    if [ ! -z "$HPH_IPS_DIR" ]; then
        cd $HPH_IPS_DIR
    fi
    $HPH_IPS_CMD
)
fi
EOS
export HPH_IPS_PID=$! 

#
# create SAs
#
export SA_DIR=$HYBRID_HOME/service-accounts
for c in apigee-cassandra apigee-logger apigee-mart apigee-metrics apigee-synchronizer apigee-udca; do

   C_VAR=$(echo $c | awk '{print toupper(substr($0, index($0,"-")+1)) "_SA"}')

    export $C_VAR=$SA_DIR/$PROJECT-$c.json
    echo y | $APIGEECTL_HOME/tools/create-service-account $c $SA_DIR
done





# setsync $SYNCHRONIZER_SA_ID
curl -X POST -H "Authorization: Bearer $(token)" -H "Content-Type:application/json" "https://apigee.googleapis.com/v1/organizations/$ORG:setSyncAuthorization" --data-binary @- <<EOF
{
    "identities": [  "serviceAccount:apigee-synchronizer@$PROJECT.iam.gserviceaccount.com" ]
}
EOF



# configure apigeeConnect 
ORG_PROPERTIES=$( curl --silent -X GET -H "Content-Type: application/json" -H "Authorization: Bearer $(token)" https://apigee.googleapis.com/v1/organizations/$ORG )

ORG_PROPERTIES=$( echo $ORG_PROPERTIES | jq ".properties.property |= (map(.name) | index(\"$PROPERTY\") ) as \$ix | if \$ix then .[\$ix][\"value\"]=\"$VALUE\" else . + [{name: \"features.mart.apigee.connect.enabled\", value:\"true\"}] end" )

curl --silent -X PUT -H "Content-Type: application/json" -H "Authorization: Bearer $(token)" https://apigee.googleapis.com/v1/organizations/$ORG --data-binary @- <<EOF
$ORG_PROPERTIES
EOF


# Apigee Connect Agent role to apigee-mart SA
gcloud projects add-iam-policy-binding $PROJECT --member serviceAccount:apigee-mart@$PROJECT.iam.gserviceaccount.com --role roles/apigeeconnect.Agent

# Apigee Organization Role
gcloud projects add-iam-policy-binding $PROJECT --member $(get_account) --role roles/apigee.admin

#

cat <<EOT >>envsubst > $HYBRID_HOME/runtime-config.yaml
gcp:
  region: $REGION
  projectID: $PROJECT

k8sCluster:
  name: $CLUSTER
  region: $REGION

org: $ORG

virtualhosts:
  - name: default
    hostAliases:
      - "$RUNTIME_HOST_ALIAS"
    sslCertPath: $RUNTIME_SSL_CERT
    sslKeyPath: $RUNTIME_SSL_KEY
    routingRules:
      - paths:
        - /
        env: $ENV

envs:
  - name: $ENV
    serviceAccountPaths:
      synchronizer: $SYNCHRONIZER_SA
      udca: $UDCA_SA

mart:
  hostAlias: "$MART_HOST_ALIAS"
  serviceAccountPath: $MART_SA
  sslCertPath: $MART_SSL_CERT
  sslKeyPath: $MART_SSL_KEY

connectAgent:
  enabled: true
  serviceAccountPath: $MART_SA

metrics:
  serviceAccountPath: $METRICS_SA

ingress:
  enableAccesslog: true
  runtime:
    loadBalancerIP: $RUNTIME_IP
  mart:
    loadBalancerIP: $MART_IP
EOT

(cd $APIGEECTL_HOME; apigeectl init -f $HYBRID_HOME/runtime-config.yaml)

wait_for_ready "0" '(cd $APIGEECTL_HOME; apigeectl check-ready  -f $HYBRID_HOME/runtime-config.yaml); echo $?' "apigeectl init: done."

(cd $APIGEECTL_HOME; apigeectl apply -f $HYBRID_HOME/runtime-config.yaml)

wait_for_ready "0" '(cd $APIGEECTL_HOME; apigeectl check-ready  -f $HYBRID_HOME/runtime-config.yaml); echo $?' "apigeectl apply: done."


## FORK-NOHUP-WAIT: RUNTIME Hybrid Player Hook
export HPH_RUNTIME_LOG=${HPH_RUNTIME_LOG:-$HYBRID-HOME/hph-runtime.log}
nohup bash <<EOS &> $HPH_RUNTIME_LOG &
if [ ! -z "$HPH_RUNTIME_CMD" ]; then
(
    if [ ! -z "$HPH_RUNTIME_DIR" ]; then
        cd $HPH_RUNTIME_DIR
    fi
    $HPH_RUNTIME_CMD
)
fi
EOS
export HPH_RUNTIME_PID=$!

# FORK-NOHUP-WAIT: JOIN all outstanding.
echo "Wait till hooks finish processing..."
wait
