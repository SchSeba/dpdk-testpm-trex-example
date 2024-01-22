# add runners to sriov projects

## prepare the node

### create inventory
under this folder create inventory.ini file.
uid are critical to numerate the runners

example:
```
[hypervisors]
hyper0 uid=2
hyper1 uid=1
```

### download the openshift secret

Download and copy the openshift pull secret to files/openshift_pull.json

### add github runners tokens

create an all.yml for the tokens under the group_vars

```yaml
keys:
  operator: "token"
  cni: "token"
  device-plugin: "token"
  webhook: "token"
```

### run the prepare host ansible

```bash
ansible-playbook -i inventory.ini prepare-server.yaml -vv
```


## install the runners

### run the github runners creation ansible playbook

```bash
ansible-playbook -i inventory.ini install-gh-runners.yaml  -vv
```