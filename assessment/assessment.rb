
# assessment.yaml | code

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
