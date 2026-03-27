# Tasks

## TODO

- [x] Create the docmgr ticket scaffold and initial deployment docs
- [x] Audit the repo to identify the real deployment flow and blocking external inputs
- [ ] Confirm deployment inputs and defaults with the operator
- [ ] Create a deployment-ready `terraform.tfvars` locally
- [ ] Run `terraform init`
- [ ] Run `terraform apply`
- [ ] Create or update the DNS record for the app hostname
- [ ] Watch cloud-init complete successfully on the server
- [ ] Fetch kubeconfig and verify the K3s node is Ready
- [ ] Verify Argo CD bootstrapped and the `demo-stack` application is healthy
- [ ] Verify HTTPS reaches the demo application successfully
- [ ] Record final outputs, validation results, and follow-up risks
