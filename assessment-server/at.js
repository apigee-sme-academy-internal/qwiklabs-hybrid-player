const { promisify } = require('util');
const exec = promisify(require('child_process').exec)

const got = require("got");
const AdmZip = require('adm-zip');

module.exports.checkproxypolicy = async function checkproxypolicy () {
    const token = await exec('gcloud auth print-access-token')

    org = "emea-cs-hybrid-demo2"
    env = "test"
    api = "ping"
    rev = 5;

    result = null;

    try {
        const response = await got(`https://apigee.googleapis.com/v1/organizations/${org}/apis/${api}/revisions/${rev}?format=bundle`, {
            headers: {
                'authorization': `Bearer ${token.stdout.trim()}`,
                'accept': 'application/zip'
            },
            responseType: 'buffer'
        })
        bundle = new AdmZip(response.body);

        // bundle.getEntries()

        policy = bundle.getEntry("apiproxy/policies/Assign-Message-1.xml");

        result = policy.getData().toString();
    } catch (error) {
        result = error.response.body;
    }

    return result;
};

  
module.exports.date = async function date () {
  const date = await exec('date')
  return date.stdout
};


module.exports.kubectl = async function kubectl () {
  const date = await exec('bash ~/assessment/assessment.sh kubectl-check "kubectl get pods"')
console.log(date)
  return date.stdout
};
