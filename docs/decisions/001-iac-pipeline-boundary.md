# ADR-001: Draw a clear ownership boundary between Terraform and the pipeline

## Status
Accepted

## Context
Terraform provisions the ECS services. The CI/CD pipeline also modifies them —
it registers new task definition revisions and updates the running service on
every deploy. If both tools claim ownership of the task definition, they fight:
after a pipeline deploy, the next `terraform apply` sees drift and reverts the
service to its bootstrap image, erasing the deployment.

## Decision
- Terraform owns the **shape** of the infrastructure: cluster, ALB, target
  groups, listeners, IAM roles, ECR, and the **initial** ECS service + task
  definition.
- The pipeline owns the **running image**: it registers new task def revisions
  and updates the service.
- The service uses `lifecycle { ignore_changes = [task_definition, desired_count] }`
  so Terraform never reverts pipeline-driven changes.

## Consequences
- `terraform apply` and pipeline deploys coexist without conflict.
- The boundary is explicit and documented: infra shape vs running contents.
- Bootstrap requires a one-time initial image push before the first apply.