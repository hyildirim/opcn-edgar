OPCN (Openstack Private Cloud Networking) repo holds set of tools to make t-shooting Neutron easier.

E.D.G.A.R. stands for Electronic Data Gathering Automation Robot


edgar-parseLLDP
I use this script to collect LLDP information from each host.

- Plant the script on INFRA01 node (where ansible is used for deployment). 
   ```
   wget <link for script RAW URL)
   chmod +x edgar-parseLLDP
   ```
   
- Copy the script to each hosts in the Openstack cloud
```
cd /opt/rpc-openstack/openstack-ansible/playbooks
ansible hosts -m copy -a 'src=/root/edgar-parseLLDP dest=/root/edgar-parseLLDP mode=0755'
```

- Execute the script on each host, it may take up to a minute
```
ansible hosts -m shell -a "/root/edgar-parseLLDP"
```

- Collect the results
```
ansible hosts -m fetch -a 'src=/tmp/interfaceSummary.txt dest=/root/edgar/interfaceSummary/{{ inventory_hostname }}.txt flat=yes'
```

It is up to you do what to do with each result file. 




