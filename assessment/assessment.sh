#!/bin/bash

exec 1> >(tee >(logger -t $(basename $0)))
exec 2> >(tee >(logger -s -t $(basename $0)))

BASEDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" 

source $BASEDIR/assessment.env

check=$1

function token { 
  local access_token; 
  access_token="$(gcloud config config-helper --force-auth-refresh 2>/dev/null | grep access_token | grep -o -E '[^ ]+$')"; 
  if [ -z "$access_token" ]; then
    gcloud auth activate-service-account --key-file=<(echo ${PROJECT_SERVICE_ACCOUNT_JSON}) 2>/dev/null;
    gcloud container clusters get-credentials hybrid-cluster --zone=$CLUSTER_ZONE 2>/dev/null;
    access_token="$(gcloud config config-helper --force-auth-refresh | grep access_token | grep -o -E '[^ ]+$')"; 
  fi;  
  echo "$access_token";  
}
export -f token


function check_org_ready() {

    local response=$(curl --silent -H "Authorization: Bearer $(token)" https://apigee.googleapis.com/v1/organizations/$ORG)

    local ret=$(echo $response | jq --raw-output ".name")

    [[ "$ret" == "$ORG" ]]
    echo $?
}


function check_env_ready() {

    local response=$(curl --silent -H "Authorization: Bearer $(token)" https://apigee.googleapis.com/v1/organizations/$ORG/environments/$ENV)
    local ret=$(echo $response | jq --raw-output ".name")

    [[ "$ret" == "$ENV" ]]
    echo $?
}



if [ "$check" == "check-org-ready" ]; then

    check_result=$(check_org_ready)
    if [[ $check_result -eq 0 ]]; then

      message="Well done!"
      echo "{ \"done\": true, \"score\": 10, \"message\": \"Org is READY\" }"

    else
      echo "{ \"done\": false, \"score\": 0, \"message\": \"Org is NOT READY\"}"
    fi

elif [ "$check" == "check-lab-ready" ]; then

    score=0
    total=2


    if [[ `check_org_ready` -eq 0 ]]; then let score++; fi
    if [[  `check_env_ready` -eq 0 ]]; then let score++; fi

    if [[ $score -eq $total ]]; then

      echo "{ \"done\": true, \"score\": 10, \"message\": \"The Lab is Ready\" }"

    else
      echo "{ \"done\": false, \"score\": 0, \"message\": \"Setting up your lab: $score out of $total...\"}"
    fi





elif [ "$check" == "check-proxy" ]; then

export API=$2
export REV=1
 
export API_BUNDLE=${API}_rev${REV}_`date +'%Y_%m_%d'`.zip
 
# get list of proxies
response=$(curl --silent -H "Authorization: Bearer $(token)" https://apigee.googleapis.com/v1/organizations/$ORG/apis)


    ret=$(echo $response | jq ".proxies[] | select(.name == \"$API\")")


    if [[ ! -z "$ret" ]]; then



      message="Well done on creating proxy $API"
      echo "{ \"done\": true, \"score\": 14, \"message\": \"$message\" }"

    else
      echo "{ \"done\": false, \"score\": 0, \"message\": \"Cannot find proxy $API\"}"
    fi
elif [ "$check" == "curl-proxy" ]; then
    prefix=$2
    expected=$3

    response=$(curl --silent https://$RUNTIME_HOST_ALIAS/$prefix --http1.1)

    if [[ "$response" == *"$expected"* ]]; then
      message="Well done!"
      echo "{ \"done\": true, \"score\": 10, \"message\": \"$message\" }"

    else
      echo "{ \"done\": false, \"score\": 0, \"message\": \"Try harder\"}"
    fi

elif [ "$check" == "kubectl-check" ]; then
    cmd=`eval echo "$2"`
    expected=`eval echo "$3"`

    # auth guard
    token=$(token)
    
    response=`$cmd`

    if [[ "$response" == *"$expected"* ]]; then
      message="Well Done!"
      cat <<EOT
{ 
  "done": true, 
  "score": 10,
  "message": "$message"
}
EOT

    else
      cat <<EOT
{ 
  "done": false,
  "score": 0,
  "message": "Try harder!"
}
EOT
    fi
fi
