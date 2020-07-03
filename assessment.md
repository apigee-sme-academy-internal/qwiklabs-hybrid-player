# Activity Tracking for Apigee Hybrid Tech Academy

## Activity Tracking: environment

There are three components of the Activity Tracking assessment solution:

- assessment.yaml file
that contains snippets of ruby code that performs step assessment

- assessment.sh file
that is a script that know how to assess Apigee Hybrid steps

- assessment.env file that sets up environment for the script to execute

The assessment is executed at vm called lab-startup
The assessment is performed in the context of student account.
The gcloud/*.googleapis.com interactions are done using qwiklabs project service account.
The api runtime endpoint and certificates (if required) ares passed via _ALIAS variables

The variables that are used currently are:
```
PROJECT
PROJECT_SERVICE_ACCOUNT
PROJECT_SERVICE_ACCOUNT_KEY_FILE
PATH=$PATH:/snap/bin ## to point at gcloud location
export ORG=$PROJECT
export ENV=
RUNTIME_HOST_ALIAS
```

Depending on how we define environment, we shall configure components above appropriately.

A setup script shall:
* copy assessment.sh script from qwiklabs-rewind-player to student's $HOME directory ~/assessment
* configure and populate 
~/assessment/assessment.env
* copy certs into ~/assessment or as appropriate.

As the same time, assessment.yaml should be developed/generated and imported to the lab github repo.

`assessment.env` sample file
```
export PROJECT='qwiklabs-gcp-02-5c4f32a17f60'
export PROJECT_SERVICE_ACCOUNT='qwiklabs-gcp-02-5c4f32a17f60@qwiklabs-gcp-02-5c4f32a17f60.iam.gserviceaccount.com'
export PROJECT_SERVICE_ACCOUNT_KEY_FILE=$BASEDIR/key.json


#echo $PROJECT_SERVICE_ACCOUNT_JSON > $PROJECT_SERVICE_ACCOUNT_KEY_FILE
## test
# gcloud auth activate-service-account $PROJECT_SERVICE_ACCOUNT --key-file=$PROJECT_SERVICE_ACCOUNT_KEY_FILE

source $BASEDIR/certs.env

export PATH=$PATH:/snap/bin

export ORG=$PROJECT
export ENV=test
```


`assessment.sh` sample file
```
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
fi
 
 
if [ "$check" == "curl-proxy" ]; then
    prefix=$2
    expected=$3

    response=$(curl --silent https://$RUNTIME_HOST_ALIAS/$prefix --http1.1)

    if [[ "$response" == *"$expected"* ]]; then
      message="Well done!"
      echo "{ \"done\": true, \"score\": 10, \"message\": \"$message\" }"

    else
      echo "{ \"done\": false, \"score\": 0, \"message\": \"Try harder\"}"
    fi

fi
```

`assessment.yaml | code` sample code
```
## Activity Tracking: proxy exists
# deploy ping proxy

def step_i_check(handles, points)
    gce = handles[:ComputeV1]
    ssh = handles[:SSH]
    ret_hash = { :done => false, :score => 0 }
    resp=gce.list_instances(filter: 'name = "lab-startup"')
    if resp && !resp.items.blank? && resp.items.count > 0
        instance = resp.items.first
        nn = instance.network_interfaces
        nat_ip = nn[0].access_configs[0].nat_ip
        ret_string = ssh.ssh_exec nat_ip, 'bash ~/assessment/assessment.sh check-proxy ping'
        ret_hash = JSON.parse(ret_string, :symbolize_names => true)
# ret_hash = { :done => false, :score => 0, :message => ret_hash }
    end
    return ret_hash
end




## Activity Tracking: curl proxy
def step_i_check(handles, points)
    gce = handles[:ComputeV1]
    ssh = handles[:SSH]
    ret_hash = { :done => false, :score => 0 }
    resp=gce.list_instances(filter: 'name = "lab-startup"')
    if resp && !resp.items.blank? && resp.items.count > 0
        instance = resp.items.first
        nn = instance.network_interfaces
        nat_ip = nn[0].access_configs[0].nat_ip
        ret_string = ssh.ssh_exec nat_ip, 'bash ~/assessment/assessment.sh curl-proxy ping pong'
        ret_hash = JSON.parse(ret_string, :symbolize_names => true)
# ret_hash = { :done => false, :score => 0, :message => ret_hash }
    end
    return ret_hash
end
```
