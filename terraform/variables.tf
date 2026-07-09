variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "owner" {
  type    = string
  default = "wael"
}

variable "app_name" {
  type    = string
  default = "cicd-flask"
}

variable "container_port" {
  type    = number
  default = 3000
}