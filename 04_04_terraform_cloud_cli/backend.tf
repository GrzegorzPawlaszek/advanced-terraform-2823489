terraform {
  backend "remote" {
    organization = "learning-terraform-ln"

    workspaces {
      name = "cli-workspace"
    }
  }
}
