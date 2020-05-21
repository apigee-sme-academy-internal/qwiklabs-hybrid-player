# qwiklabs-hybrid-player

## TODO:
[ ] provide logical and debug output for operations as required

[ ] 'harden' the script

[ ] next step: deploy the ping proxy


## Install Runtime

The `rewind.sh` script is self-containted. It works in a qwiklabs vanilla environment.

Just create an empty lab; clone this repo; execute the script.

Of course, a duration of the lab is not an ideal development environment. 

The plan is for us is to create a project in an experimental-gke folder and create our hybrid cluster and other course artifacts there. That will provide durability for our project. This script should work in any project with no or minimal configuration changes (ie, if you're not happy with a default region and zone or cluster node specification). Eventually we will add necessary parameters to an infocation script.


```
bin/rewind.sh | tee /tmp/rewind.log
```



## Test Request


Help yourself to create a simple [or complex] proxy and deploy it.

To re-use the curl request verbatim, ie, copy-and-paste, this is a minumal setup that would populate environment variables used in the curl.


```
export PROJECT=$(gcloud projects list --filter='project_id~qwiklabs-gcp' --format=value'(project_id)')
gcloud config set project $PROJECT

export HYBRID_HOME=$PWD
export REGION=europe-west1

export RUNTIME_IP=$(gcloud compute addresses describe runtime-ip --region $REGION --format='value(address)')

export RUNTIME_HOST_ALIAS=api.exco.com
export RUNTIME_SSL_CERT=$HYBRID_HOME/exco-hybrid-crt.pem

curl --cacert $RUNTIME_SSL_CERT https://$RUNTIME_HOST_ALIAS/ping -v --resolve "$RUNTIME_HOST_ALIAS:443:$RUNTIME_IP" --http1.1
```


## Current issues: 

This is a 'happy path' processing. We might need to harden it.

After the runtime is configured and built, it takes more extra minutes for request to be processed successfully and even more minutes for UI to stop displaying forbidden access and even more minutes for proxy overview to reflect that the proxy was deployed successfully and even more minutes for the trace to 'stabilise'
