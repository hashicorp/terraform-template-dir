# Terraform Template Directory Module

This is a compute-only Terraform module (that is, a module that doesn't make
any remote API calls) which gathers all of the files under a particular
base directory and renders those which have a particular suffix as Terraform
template files.

```hcl
module "template_files" {
  source = "apparentlymart/dir/template"

  base_dir = "${path.module}/src"
  template_vars = {
    # Pass in any values that you wish to use in your templates.
    vpc_id = "vpc-abc123"
  }
}
```

The `files` output is a map from file paths relative to the base directory
to objects with the following attributes:

* `content_type`: A MIME type to use for the file.
* `content`: Literal content of the file, after rendering a template.
* `source_path`: Local filesystem location of a non-template file.
* `digests`: A map containing the results of applying various digest/hash
  algorithms to the file content.

`content` and `source_path` are mutually exclusive. `content` is set for
template files and contains the result of rendering the template. For
non-template files, `source_path` is set to the location of the file on local
disk, which avoids trying to load non-UTF-8 files such as images into memory.

The `digests` map for each file contains the following keys, whose values are
the result of applying the named hash function to the file contents:

* `md5`
* `sha1`
* `sha256`
* `base64sha256`
* `base512`
* `base64sha512`

## Template Files

By default, any file in the base directory whose filename ends in `.tmpl` is
interpreted as a template. You can override that suffix by setting the
variable `template_file_suffix` to any string that starts with a period and
is followed by one or more non-period characters.

The templates are interpreted as
[Terraform's string template syntax](https://www.terraform.io/docs/configuration/expressions.html#string-templates). Templates can use any of
[Terraform's built-in functions](https://www.terraform.io/docs/configuration/functions.html) except
[the `templatefile` function](https://www.terraform.io/docs/configuration/functions/templatefile.html),
which is what this module uses for template rendering internally.

Any file that does not have the template file suffix will be treated as a
static file, returning the local path to the source file.

## Content-Type Mapping

Content-Type values (`content_type` in the resulting objects) are selected
based on the suffixes of all of the discovered files.

The variable `file_types` is a mapping from filename suffixes (a dot followed
by at least one non-dot character) to `Content-Type` header values. The default
mapping includes a number of filetypes commonly used on static websites.

If the module encounters a file that has no suffix at all or whose suffix is not
in `file_types`, it will use the value of variable `default_file_type` as a
fallback, which itself defaults to `application/octet-stream`.

## Uploading Files to Amazon S3

A key use-case for this module is to produce content to upload into an Amazon S3
bucket, for example to use as a static website.

In your calling module, use
[`aws_s3_bucket_object` from the AWS provider](https://www.terraform.io/docs/providers/aws/r/s3_bucket_object.html)
with `for_each` to create an S3 object for each file:

```hcl
resource "aws_s3_bucket_object" "static_files" {
  for_each = module.template_files.files

  bucket       = "example"
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
```

## Uploading files to Google Cloud Storage

The pattern for uploading files to GCS is very similar to that for Amazon S3
above:

```hcl
resource "google_storage_bucket_object" "picture" {
  for_each = module.template_files.files

  bucket       = "example"
  name         = each.key
  content_type = each.value.content_type

  # The template_files module guarantees that only one of these two attributes
  # will be set for each file, depending on whether it is an in-memory template
  # rendering result or a static file on disk.
  source  = each.value.source_path
  content = each.value.content
}
```

## Requirements

This module requires Terraform v0.12.8 or later. It does not use any Terraform
providers, and does not declare any Terraform resources.

## Why not use the `template_dir` resource type?

The `template_dir` resource type was implemented as a pragmatic workaround for
various limitations in earlier versions of Terraform, but it's problematic
because it violates an assumption Terraform makes about resources: it
modifies local state on the system where Terraform is running, and thus
the result of the resource is not visible when running Terraform on other
hosts.

The `template_dir` resource type is no longer necessary from Terraform 0.12.8
onwards for most use-cases, because there's enough built-in functionality to
get similar results with no resources at all.

As well as this module being a better citizen in Terraform's workflow than
a `template_file` resource, it also allows a mixture of template and
non-template files in the same directory, and will only load into memory
and render the template files. For non-template files, it will just leave
them on disk where they are and return a local filesystem path to the original
location.

On the other hand, this module _does_ assume that its result will be used with
some other resource type that is able to deal with some files being rendered
strings in memory and other files being read directly from disk. This is true
for `aws_s3_bucket_object`, but not true for all resource types that might
work with arbitrary files.
