# this file is used for activity tracking, do not edit it manually
BASEDIR="$( cd "$( dirname "\${BASH_SOURCE[0]}" )" && pwd )"
export PATH="/snap/bin:\$PATH"
export PROJECT='${PROJECT}'
export CLUSTER='hybrid-cluster'
export CLUSTER_ZONE='${ZONE}'
export ORG='${PROJECT}'
export ENV='test'
export PROJECT_SERVICE_ACCOUNT_JSON='${PROJECT_SERVICE_ACCOUNT_JSON}'
source "\${BASEDIR}/certs.env"

export KUBECONFIG="${STUDENT_HOME}/assessment/config"
if [ ! -f "${KUBECONFIG}" ]; then gcloud container clusters get-credentials $CLUSTER --zone $CLUSTER_ZONE &>/dev/null ; fi