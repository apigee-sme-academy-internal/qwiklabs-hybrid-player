# qwiklabs-hybrid-player

## TODO:
[ ] provide logical and debug output for operations as required

[ ] 'harden' the script

[x] next step: deploy the ping proxy

[ ] repl env-create to ahr

[ ] probes for runtime and trace readiness
 
[ ] fix envsubst 0b file creation

[ ] for some vars like REGION, ZONE, make defaults if not defined

## Diagnostics
> WARNING: Especially if you want to use the script out-of-band, make a notice that the script switching Audit log of Apigee APIs to be logged in StackDriver. It is useful for capturing any transient error information of requests to the apigee.googleapis.com.


## Install Runtime

The `rewind.sh` script is self-containted. It works in a QwikLabs or a GCP project vanilla environment.

Just create an empty lab; clone this repo; setup PROJECT variable appropriately and execute the script.

Of course, a duration of the lab is not an ideal development environment. 

The plan is for us is to create a project in an experimental-gke folder and create our hybrid cluster and other course artifacts there. That will provide durability for our project. This script should work in any project with no or minimal configuration changes (ie, if you're not happy with a default region and zone or cluster node specification). Eventually we will add necessary parameters to an infocation script.

> __NOTE:__ In case of QwikLabs project, following command can be used to populate the PROJECT variable:
> ```
> export PROJECT=$(gcloud projects list --filter='project_id~qwiklabs-gcp' --format=value'(project_id)')
> ```

## Open a qwiklabs instance

?. TODO: [ ] a class in gsp

?. Activate CloudShell

## Set up github access
?. As ours is currently a private repo, configure ssh access key
```
mkdir -p ~/.ssh
vi ~/.ssh/id_github-sme
```
?. Insert your valid key

?. Configure ssh
```
cat <<EOT >> ~/.ssh/config
Host github.com-sme
    HostName github.com
    IdentityFile ~/.ssh/id_github
    User git
EOT
```
?. permissions
```
chmod 400 ~/.ssh/id_github-sme
chmod 400 ~/.ssh/config
```
?. ssh-agent configuration
```
eval `ssh-agent`
ssh-add ~/.ssh/id_github-sme
```

## Install Runtime

?. Clone the repo
```
git clone git@github.com:apigee-sme-academy-internal/qwiklabs-hybrid-player.git
```
?. Configure PLAYER_HOME and PATH
```
export PLAYER_HOME=~/qwiklabs-hybrid-player
export PATH=$PLAYER_HOME/bin:$PATH
```
?. Configure PROJECT variable
```
export PROJECT=$(gcloud projects list --filter='project_id~qwiklabs-gcp' --format=value'(project_id)')
```
?. Minimal Hybrid Runtime install steps
```
time rewind.sh | tee $HYBRID_HOME/rewind.log
```
?. Deploy test proxy
```
time $PLAYER_HOME/proxies/deploy.sh |  tee $HYBRID_HOME/deploy.log
```



## Test Request


You can use suppled ping proxy and proxies/deploy.sh script to upload simple test proxy to experiment with it.

To re-use the curl request verbatim, ie, copy-and-paste, this is a minumal setup that would populate environment variables used in the curl.


```
export PROJECT=$(gcloud projects list --filter='project_id~qwiklabs-gcp' --format=value'(project_id)')
gcloud config set project $PROJECT

export HYBRID_HOME=$PROJECT
export REGION=europe-west1

export RUNTIME_IP=$(gcloud compute addresses describe runtime-ip --region $REGION --format='value(address)')

export RUNTIME_HOST_ALIAS=api.exco.com
export RUNTIME_SSL_CERT=$HYBRID_HOME/exco-hybrid-crt.pem

curl --cacert $RUNTIME_SSL_CERT https://$RUNTIME_HOST_ALIAS/ping -v --resolve "$RUNTIME_HOST_ALIAS:443:$RUNTIME_IP" --http1.1
```


## Current issues: 

This is a 'happy path' processing. We might need to harden it.

After the runtime is configured and built, it takes more extra minutes for request to be processed successfully and even more minutes for UI to stop displaying forbidden access and even more minutes for proxy overview to reflect that the proxy was deployed successfully and even more minutes for the trace to 'stabilise'
