# Copyright IBM Corp. 2019, 2026

module "under_test" {
  source = "../../"

  base_dir = "${path.module}/../src"
  template_vars = {
    name = "Josephine"
  }
}

output "result" {
  value = module.under_test
}
