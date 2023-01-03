module "template_files" {
  source = "../../"

  base_dir = "${path.module}/../src"
  template_vars = {
    name = "Josephine"
  }
}

resource "aws_s3_bucket" "static_files" {
  bucket = "terraform-template-dir-test"

  # FIXME: The provider mock mechanism doesn't know how to represent this
  # not being present at all, so we'll define it here just to quiet that
  # limitation for now.
  timeouts {}
}

resource "aws_s3_object" "static_files" {
  for_each = module.template_files.files

  bucket       = aws_s3_bucket.static_files.bucket
  key          = each.key
  content_type = each.value.content_type

  # The template_files module guarantees that only one of these two attributes
  # will be set for each file, depending on whether it is an in-memory template
  # rendering result or a static file on disk.
  source  = each.value.source_path
  content = each.value.content

  # Unless the bucket has encryption enabled, the ETag of each object is an
  # MD5 hash of that object.
  etag = each.value.digests.md5
}
