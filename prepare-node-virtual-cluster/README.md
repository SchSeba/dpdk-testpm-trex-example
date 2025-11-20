# Virtual Cluster Preparation and GitHub Runners Setup

Production-ready Ansible playbooks for preparing hypervisor nodes and deploying GitHub Actions self-hosted runners for SR-IOV network projects.

## 📋 Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Security Best Practices](#security-best-practices)
- [Quick Start](#quick-start)
- [Detailed Setup](#detailed-setup)
- [Usage](#usage)
- [Configuration](#configuration)
- [Libvirt Storage Pool](#libvirt-storage-pool)
- [Troubleshooting](#troubleshooting)
- [Maintenance](#maintenance)

## 🔍 Overview

This project provides two main playbooks:

1. **prepare-server.yaml**: Prepares hypervisor nodes with required software (QEMU, Go, kubectl, kcli, etc.)
2. **install-gh-runners.yaml**: Deploys and configures GitHub Actions self-hosted runners

### Key Features

- ✅ Idempotent operations (safe to run multiple times)
- ✅ Secure credential management with ansible-vault
- ✅ Non-root runner execution
- ✅ Configurable versions for all software components
- ✅ Automatic retry logic for network operations
- ✅ Comprehensive error handling
- ✅ SELinux set to permissive (not disabled)
- ✅ Automatic cleanup of temporary files during playbook run

## 📦 Prerequisites

### Control Node (where you run Ansible)

- Ansible 2.9 or later
- Python 3.6+
- SSH access to target hypervisors

```bash
# Install Ansible on macOS
brew install ansible

# Install Ansible on RHEL/CentOS
sudo dnf install ansible

# Install Ansible on Ubuntu
sudo apt install ansible
```

### Target Nodes (Hypervisors)

- RHEL 8/9, CentOS Stream, or compatible Linux distribution
- Root SSH access
- Minimum 4 CPU cores (for QEMU compilation)
- 8GB RAM
- 50GB free disk space

## 🔒 Security Best Practices

### ⚠️ CRITICAL: Never Commit Secrets to Git

1. **Use ansible-vault for sensitive data**:
   ```bash
   # Create encrypted secrets file
   ansible-vault create secrets.yml
   
   # Edit encrypted file
   ansible-vault edit secrets.yml
   ```

2. **The `.gitignore` is configured to protect**:
   - `secrets.yml` (GitHub runner tokens and OpenShift credentials)
   - SSH keys
   - Vault password files

3. **Verify before committing**:
   ```bash
   # Check what will be committed
   git status
   git diff --staged
   
   # Ensure no secrets are included
   grep -r "ABADUOD" . --exclude-dir=.git
   ```

### 🛡️ Security Improvements Made

- GitHub runners run as dedicated `github-runner` user (not root)
- All secrets managed via ansible-vault encryption (GitHub tokens, OpenShift pull secrets)
- SELinux set to permissive instead of disabled
- File permissions properly restricted (0600 for secrets)
- No logging of sensitive variables (`no_log: true`)
- OpenShift pull secret is optional and only created if defined in secrets.yml

## 🚀 Quick Start

### 1. Clone and Setup

```bash
cd prepare-node-virtual-cluster
cp secrets.yml.example secrets.yml
```

### 2. Configure Inventory

Edit `inventory.ini`:

```ini
[hypervisors]
hypervisor1 ansible_ssh_host=192.168.1.10 ansible_ssh_user=root uid=1
hypervisor2 ansible_ssh_host=192.168.1.11 ansible_ssh_user=root uid=2
```

**Important**: `uid` must be unique per host and is used to differentiate runners.

### 3. Configure Secrets

```bash
ansible-vault create secrets.yml
```

Add your GitHub runner tokens:

```yaml
---
runner_tokens:
  operator: "YOUR_OPERATOR_TOKEN_HERE"
  cni: "YOUR_CNI_TOKEN_HERE"
  device-plugin: "YOUR_DEVICE_PLUGIN_TOKEN_HERE"
  webhook: "YOUR_WEBHOOK_TOKEN_HERE"
  ib: "YOUR_IB_TOKEN_HERE"
```

**Note**: GitHub runner tokens expire after 1 hour. Generate them just before running the playbook.

### 4. Run Playbooks (IMPORTANT: Order Matters!)

```bash
# Step 1: Prepare hypervisors (creates SSH keys, installs software)
ansible-playbook prepare-server.yaml

# Step 2: Install GitHub runners (requires step 1 to be complete)
ansible-playbook install-gh-runners.yaml -e @secrets.yml --ask-vault-pass
```

**⚠️ Critical**: Always run `prepare-server.yaml` BEFORE `install-gh-runners.yaml`. The runners require:
- SSH keys for kcli VM creation
- Proper PATH configuration  
- All software dependencies installed

## 📖 Detailed Setup

### Step 1: Generate GitHub Runner Tokens

For each repository, you need to generate a registration token:

1. Go to your GitHub repository
2. Navigate to **Settings** → **Actions** → **Runners**
3. Click **"New self-hosted runner"**
4. Copy the token from the configuration command
5. Add it to your `secrets.yml` under the appropriate `key_name`

Example mapping:
- `operator` → sriov-network-operator repository
- `cni` → sriov-cni repository
- `device-plugin` → sriov-network-device-plugin repository
- `webhook` → network-resources-injector repository
- `ib` → ib-sriov-cni repository

### Step 2: OpenShift Pull Secret (Optional)

If you need to pull OpenShift images:

1. Download your pull secret from [cloud.redhat.com](https://cloud.redhat.com/openshift/install/pull-secret)
2. Add it to your `secrets.yml` file:

```bash
ansible-vault edit secrets.yml
```

Add the `openshift_pull_secret` variable and paste the entire JSON string as-is:

```yaml
openshift_pull_secret: '{"auths":{"cloud.openshift.com":{"auth":"...","email":"..."},"quay.io":{"auth":"...","email":"..."},"registry.connect.redhat.com":{"auth":"...","email":"..."},"registry.redhat.io":{"auth":"...","email":"..."}}}'
```

Just copy the entire JSON output from the Red Hat console and paste it as a single-quoted string. See `secrets.yml.example` for a template.

### Step 3: Customize Configuration

Edit `group_vars/all.yml` to customize:

```yaml
# Software versions
go_version: "1.24.6"
qemu_version: "9.2.2"
kubectl_version: "v1.34.2"

# Runner configuration
runner_user: "github-runner"

# Runner definitions (add/remove as needed)
runner_configurations:
  - name: "my-runner"
    key_name: "operator"
    tag: "my-tag"
    id: "250"
    subnet: "192.168.125"
    url: "https://github.com/myorg/myrepo"
```

## 💻 Usage

### Prepare Hypervisors

```bash
# Run with verbose output
ansible-playbook prepare-server.yaml -v

# Run for specific hosts
ansible-playbook prepare-server.yaml --limit hypervisor1

# Check what would change (dry-run)
ansible-playbook prepare-server.yaml --check --diff
```

### Install GitHub Runners

```bash
# Standard installation
ansible-playbook install-gh-runners.yaml -e @secrets.yml --ask-vault-pass

# Use vault password file (store .vault_pass securely!)
ansible-playbook install-gh-runners.yaml -e @secrets.yml --vault-password-file .vault_pass

# Install only specific runners using tags
ansible-playbook install-gh-runners.yaml -e @secrets.yml --ask-vault-pass --tags setup,config
```

### Available Tags

For `install-gh-runners.yaml`:

- `setup` - Create directories and users
- `download` - Download runner packages
- `install` - Extract and install runners
- `config` - Configure runners with GitHub
- `service` - Install and start services
- `verify` - Verify runner status
- `cleanup` - Remove temporary files

Example:
```bash
# Only verify runner status
ansible-playbook install-gh-runners.yaml --tags verify
```

## ⚙️ Configuration

### Version Management

All software versions are defined in `group_vars/all.yml`:

```yaml
go_version: "1.24.6"        # Golang version
qemu_version: "9.2.2"        # QEMU version
kubectl_version: "v1.34.2"   # kubectl version
```

## 🗄️ Libvirt Storage Pool

### Automatic Configuration

The playbook automatically configures the default libvirt storage pool required for VM images. This resolves the common error:

```
Image centos9stream not Added because Pool default not found
```

### What Gets Configured

- ✅ Default storage pool at `/var/lib/libvirt/images`
- ✅ Automatic pool creation if missing
- ✅ Pool autostart on system boot
- ✅ Handles inactive pools automatically

### Customizing Storage Location

Edit `group_vars/all.yml`:

```yaml
libvirt_default_pool_path: "/data/libvirt/images"  # Use larger disk
libvirt_default_pool_name: "default"
```

### Verification

```bash
# On hypervisor
virsh pool-list --all

# Should show:
#  Name      State    Autostart
# ----------------------------------
#  default   active   yes
```

### Detailed Documentation

See [LIBVIRT_STORAGE_POOL.md](LIBVIRT_STORAGE_POOL.md) for:
- Detailed configuration options
- Troubleshooting steps
- Multiple pool setup
- Capacity planning
- NFS storage configuration

### Runner Configuration

Each runner is defined with:

- `name`: Runner identifier
- `key_name`: Token key in `secrets.yml`
- `tag`: Label for runner selection in workflows
- `id`: Unique numeric identifier
- `subnet`: Virtual network subnet
- `url`: GitHub repository URL

### Ansible Configuration

The `ansible.cfg` file includes:

- Performance optimizations (pipelining, forks)
- SSH connection settings
- Fact caching for faster execution
- Colored output
- Logging to `ansible.log`

## 🔧 Troubleshooting

### Common Issues

#### 1. "No usable public key found" Error (kcli)

**Problem**: `No usable public key found, which is required for the deployment. Create one using ssh-keygen`

**Solution**: This means the GitHub runner doesn't have an SSH key. Fix by:

```bash
# Run prepare-server.yaml to create SSH keys
ansible-playbook prepare-server.yaml

# Then run install-gh-runners.yaml
ansible-playbook install-gh-runners.yaml -e @secrets.yml --ask-vault-pass
```

If you already ran the playbooks but still get this error, **restart the runner services**:

```bash
# On each hypervisor
ssh root@hypervisor
systemctl restart actions.runner.*.service

# Or via Ansible
ansible hypervisors -m shell -a "systemctl restart 'actions.runner.*.service'"
```

**Verify the SSH key exists**:
```bash
ssh root@hypervisor
ls -la /home/github-runner/.ssh/
# Should show: id_rsa (0600) and id_rsa.pub (0644)
```

#### 2. "Pool default not found" Error

**Problem**: `Image centos9stream not Added because Pool default not found`

**Solution**: The playbook now automatically configures the libvirt storage pool. Simply run:

```bash
ansible-playbook prepare-server.yaml
```

To verify the pool was created:
```bash
# On hypervisor
ssh root@hypervisor_ip
virsh pool-list --all
virsh pool-info default
```

#### 3. QEMU Compilation Fails

**Problem**: "found no usable tomli"

**Solution**: The playbook now automatically installs Python dependencies. If it still fails:

```bash
# On target host
sudo pip3 install ninja tomli
```

#### 4. GitHub Runner Token Expired

**Problem**: "Failed to configure runner: Invalid token"

**Solution**: GitHub runner tokens expire after 1 hour. Generate fresh tokens:

1. Go to GitHub repository settings
2. Generate new runner token
3. Update `secrets.yml`:
   ```bash
   ansible-vault edit secrets.yml
   ```

#### 5. SSH Connection Timeout

**Problem**: "SSH timeout" or "Unreachable host"

**Solution**: 
```bash
# Test SSH manually
ssh root@hypervisor_ip

# Check inventory file
cat inventory.ini

# Verify SSH keys
ssh-add -l
```

#### 6. Permission Denied for Runner

**Problem**: Runner can't access libvirt or docker

**Solution**:
```bash
# On target host, verify groups
id github-runner

# Should show: groups=...,libvirt,docker

# If not, add manually
sudo usermod -aG libvirt,docker github-runner
```

#### 7. Idempotency Issues

**Problem**: Tasks report changes on every run

**Solution**: Check task status with `--check` mode:
```bash
ansible-playbook prepare-server.yaml --check --diff
```

### Debug Mode

Enable detailed debugging:

```bash
# Maximum verbosity
ansible-playbook prepare-server.yaml -vvvv

# Check connection to hosts
ansible hypervisors -m ping

# Gather facts
ansible hypervisors -m setup
```

### View Logs

```bash
# Ansible log (if logging enabled)
tail -f ansible.log

# Runner service logs on target host
sudo journalctl -u actions.runner.* -f

# Check runner status
sudo su - github-runner
cd ~/runners/runner-name-1
./svc.sh status
```

## 🔄 Maintenance

### Updating Software Versions

1. Edit `group_vars/all.yml`
2. Update version variables
3. Run playbook: `ansible-playbook prepare-server.yaml`

The playbook will detect version changes and reinstall only what's needed.

### Rotating GitHub Tokens

GitHub runner tokens should be rotated periodically:

```bash
# 1. Generate new tokens from GitHub
# 2. Update secrets
ansible-vault edit secrets.yml

# 3. Reconfigure runners
ansible-playbook install-gh-runners.yaml -e @secrets.yml --ask-vault-pass --tags config
```

### Removing Runners

To remove a runner:

```bash
# On target host
sudo su - github-runner
cd ~/runners/runner-name-1
./svc.sh stop
./svc.sh uninstall
./config.sh remove --token YOUR_REMOVAL_TOKEN
```

### Cleanup Old Artifacts

The playbook includes automatic cleanup:

- **During playbook run**: Cleans up old build artifacts and runs podman prune immediately
- **Daily cron job**: Podman system prune runs daily to free up disk space from unused containers/images
- **Old build artifacts**: Removes files in `/tmp` older than 7 days (QEMU, Go, runner archives)

Manual cleanup if needed:

```bash
# On target host
sudo podman system prune -a -f
sudo find /tmp -name "qemu-*.tar.xz" -o -name "go*.tar.gz" -mtime +7 -delete
```

### Backup Important Files

Regular backups of:

```bash
# Configuration
tar -czf backup-$(date +%Y%m%d).tar.gz \
  inventory.ini \
  group_vars/ \
  files/

# Exclude secrets (backup separately, securely)
# Never include secrets.yml in regular backups stored on shared systems
```

## 📚 Additional Resources

- [Ansible Documentation](https://docs.ansible.com/)
- [Ansible Vault](https://docs.ansible.com/ansible/latest/user_guide/vault.html)
- [GitHub Actions Self-Hosted Runners](https://docs.github.com/en/actions/hosting-your-own-runners)
- [SR-IOV Network Operator](https://github.com/k8snetworkplumbingwg/sriov-network-operator)

## 🤝 Contributing

When contributing:

1. Never commit secrets or credentials
2. Test changes with `--check` mode first
3. Ensure idempotency (safe to run multiple times)
4. Update documentation for new features
5. Follow Ansible best practices

## 📄 License

[Your License Here]

## 👥 Authors

[Your Name/Team]

---

**Last Updated**: 2025-11-19

**Ansible Version**: 2.9+

**Tested On**: RHEL 9.x, CentOS Stream 9
