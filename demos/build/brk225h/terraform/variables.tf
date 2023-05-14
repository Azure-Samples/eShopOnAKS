variable "location" {
  type    = string
  default = "westeurope"
}

variable "gh_token" {
  type      = string
  sensitive = true
}

variable "gh_organization" {
  type = string
}