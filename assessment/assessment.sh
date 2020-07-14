#!/bin/bash

BASEDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )" 

source $BASEDIR/assessment.env

check=$1

function token { 
  local access_token; 
  access_token="$(gcloud config config-helper --force-auth-refresh 2>/dev/null | grep access_token | grep -o -E '[^ ]+$')"; 
  if [ -z "$access_token" ]; then
    gcloud auth activate-service-account $PROJECT_SERVICE_ACCOUNT --key-file=$PROJECT_SERVICE_ACCOUNT_KEY_FILE 2>/dev/null ;
    access_token="$(gcloud config config-helper --force-auth-refresh | grep access_token | grep -o -E '[^ ]+$')"; 
  fi;  
  echo "$access_token";  
}
export -f token


if [ "$check" == "check-proxy" ]; then

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
    prefix=$2
    expected=$3

    response=$(kubectl -n apigee get secret)

    if [[ "$response" == *"$expected"* ]]; then
#      message="Well done!"
message=$response
      echo "{ \"done\": true, \"score\": 10, \"message\": \"$message\" }"

    else
      echo "{ \"done\": false, \"score\": 0, \"message\": \"Try harder\"}"
    fi
fi
