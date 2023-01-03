terraform {
  required_version = ">= 0.12.8"

  # HACK: The "terraform test" experiment currently doesn't know how
  # to deal with test-specific dependencies, so this is here only to
  # support our "amazon-s3" test scenario. In a final version of
  # "terraform test" this should not be needed because terraform init
  # should know to install dependencies required for test scenarios too.
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}
