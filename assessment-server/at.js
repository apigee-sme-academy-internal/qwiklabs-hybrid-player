const { promisify } = require('util');
const exec = promisify(require('child_process').exec)

module.exports.date = async function date () {
  const date = await exec('date')
  return date.stdout
};


module.exports.kubectl = async function envVar () {
  const date = await exec('bash ~/assessment/assessment.sh kubectl-check "kubectl get pods"')
console.log(date)
  return date.stdout
};
