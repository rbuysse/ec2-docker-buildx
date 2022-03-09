# ec2-docker-buildx

Creates a buildx cluster on AWS to use in GHA workflows when qemu is too slow

Provides two actions:

**start**:

1. Creates two instances
2. Bootstraps the buildx cluster
3. Installs GHA runner software with the --ephemeral option

**stop**:

1. Terminates any instances whose name matches the label provided

Assumes you have two pre-builts AMIs

AMD runner: Docker installed

ARM runner: Docker installed and daemon exposed on port 2375

Steps to expose docker daemon:

```
sudo vi /etc/docker/daemon.json

{
  "hosts": ["unix:///var/run/docker.sock", "tcp://0.0.0.0:2375"]
}

sudo vi /lib/systemd/system/docker.service
ExecStart=/usr/bin/dockerd --containerd=/run/containerd/containerd.sock

sudo systemctl daemon-reload

sudo systemctl restart docker.service
``` 


# Action configuration

## Inputs:

  **action**:
    _start_ - deploy a new cluster.
    _stop_ - destroy a running cluster.

  **amd_ami_id**:
      AMI ID for the AMD instance. Should have docker installed.

  **amd_instance_type**:
      Instance Type for the AMD instance.

  **arm_ami_id**:
      AMI ID for the ARM instance. Should have Docker installed and daemon exposed on port 2375.

  **arm_instance_type**:
      Instance Type for the ARM instance

  **gh_personal_access_token**:
      GitHub Personal Access Token with "repo" permissions.

  **label**:
      Label applied to the created EC2 instances during creation.
      No effect during _start_.
      This is required when running the _stop_ action.

  **security_group_id**:
      Must allow outbound traffic to connect to GitHub.

  **subnet**:
      Subnet to apply to the instances

## Outputs:

**label**:
      Random value generated when creating a new cluster. This is used for job isolation.

# Example usage

```
name: GHA Buildx
on:
  - push
  - workflow_dispatch
jobs:
  start_cluster:
    name: Start buildx cluster
    runs-on: ubuntu-latest
    outputs:
      label: ${{ steps.start-buildx-cluster.outputs.label }}
    steps:
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ secrets.AWS_REGION }}

      - name: Start EC2 runners
        id: start-buildx-cluster
        uses: rbuysse/ec2-docker-buildx@v1
        with:
          action: start
          amd_ami_id: ${{ secrets.AMD_AMI_ID }}
          amd_instance_type: t2.nano
          arm_ami_id: ${{ secrets.ARM_AMI_ID }}
          arm_instance_type: t4g.nano
          gh_personal_access_token: ${{ secrets.GH_PERSONAL_ACCESS_TOKEN }}
          security_group_id: ${{ secrets.SECURITY_GROUP_ID }}
          subnet: ${{ secrets.SUBNET }}

  build_docker:
    name: Build docker
    needs: start_cluster
    runs-on: ${{ needs.start_cluster.outputs.label }}
    steps:
      - name: sup
        run: docker buildx ls

  stop_cluster:
    name: Stop buildx cluster
    needs:
      - start_cluster
      - build_docker
    runs-on: ubuntu-latest
    if: ${{ always() }}
    steps:
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ secrets.AWS_REGION }}

      - name: Destroy cluster
        uses: rbuysse/ec2-docker-buildx@v1
        with:
          action: stop
          label: ${{ needs.start_cluster.outputs.label }}
```
