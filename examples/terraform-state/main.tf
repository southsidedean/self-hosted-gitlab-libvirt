terraform {
  backend "http" {}
}

resource "terraform_data" "hello" {
  input = "Hello from GitLab-managed state!"
}
