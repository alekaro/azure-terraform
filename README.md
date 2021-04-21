# azure-terraform

## General informations

This project was created as a solution for exercise containing given scenario:

**Create manifests to launch simple static web-site environment on Azure Cloud:**

1. Create Azure Storage Account with private-only access
1. Copy local static web-site files to ASA
1. Create Virtual Machine Scale Set  using default Linux image with:
    * Script to install Apache web server
    * Script to copy static files from ASA into web root directory of Apache web server (Use Managed Identity with assigned role for every VM in scale set)
1. Create Managed virtual machine scale set
1. Set number of instances for auto-scaling: min=1, max=3
1. Add Gateway on top of scale set to have one point of entry

---

## Solution

### remote-state
> Separate storage account, not needed in case of exercise but helpful in providing communication between ASA and later defined VMSS (they can't be specified at the same time because we have to upload static web files into ASA)

### ASA (Azure Storage Account)
> Storage Account stores  `index.html` file needed in later scale set servers setup

### VMSS (Virtual Machine Scale Set)
> Linux OS virtual machine scale set with Application Gateway on top and Managed Identity based access to ASA described above.

---
## Launch instruction
1. in `/remote-state/`
```
terraform init
terraform apply
```
2. in `/ASA/`
```
terraform init -backend-config=../remote-state/backend-config.txt

terraform apply
```
3. in `/VMSS/`
* copy-paste corresponding values from `/remote-state/backend-config.txt` into `/VMSS/main.tf` in **terraform_remote_state** data block
```
terraform init
terraform apply
```