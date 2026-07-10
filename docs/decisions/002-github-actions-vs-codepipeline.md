# ADR-002: Use GitHub Actions for the full pipeline (not CodePipeline)

## Status
Accepted

## Context
The pipeline could be built with GitHub Actions or with the AWS-native stack
(CodePipeline orchestrating CodeBuild + CodeDeploy). Both cover Source → Build →
Deploy with a manual approval gate. Running both is redundant.

## Decision
Build the entire pipeline in GitHub Actions: test, build/push to ECR, deploy to
ECS staging and production, with a GitHub Environment required-reviewer gate
before production.

## Consequences
- One tool, living next to the code, for the whole flow.
- Each stage maps cleanly onto a CodePipeline equivalent (documented in the
  README) so the AWS-native path is understood without being built.
- Authentication uses stored access keys for now; OIDC federation is the
  planned upgrade to remove long-lived credentials entirely.