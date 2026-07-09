output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}

output "staging_url" {
  value = "http://${aws_lb.app.dns_name}:80"
}

output "production_url" {
  value = "http://${aws_lb.app.dns_name}:8080"
}

output "ci_user_name" {
  value = aws_iam_user.ci.name
}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

data "aws_caller_identity" "current" {}