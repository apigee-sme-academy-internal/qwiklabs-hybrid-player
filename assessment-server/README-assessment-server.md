
# assessment-server: QwikLabs Activity Tracking server

Nodejs/express application that serves Acivity Tracking requests backend implementation.


Two prerequisites:

- should be run as root, as an intent is to serve ports 80 or 443; 

- for that a compute instance that runs the server should have network tags:
```
gcloud compute instances add-tags lab-startup --tags http-server,https-server --zone us-west1-a
```


## Set up dev environment
```
sudo apt install -y nodejs npm
```

* It is useful to feed an environment so that AT functions can access it.
See serve.sh for an example.


## Sample ruby AT snippet to call the server
```
def step_i_check(handles, points)

  message = Net::HTTP.get('34.82.94.96', '/kubectl')

  ret_hash = { :done => false, :score => 0, :message => message }
  return ret_hash
end
```

