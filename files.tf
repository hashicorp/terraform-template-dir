locals {
  all_file_paths = fileset(var.base_dir, "**")
  static_file_paths = toset([
    for p in local.all_file_paths : p
    if length(p) < length(var.template_file_suffix) || substr(p, length(p) - length(var.template_file_suffix), length(var.template_file_suffix)) != var.template_file_suffix
  ])
  template_file_paths = {
    for p in local.all_file_paths :
    substr(p, 0, length(p) - length(var.template_file_suffix)) => p
    if ! contains(local.static_file_paths, p)
  }

  template_file_contents = {
    for p, sp in local.template_file_paths : p => templatefile("${var.base_dir}/${sp}", var.template_vars)
  }
  static_file_local_paths = {
    for p in local.static_file_paths : p => "${var.base_dir}/${p}"
  }

  output_file_paths = setunion(keys(local.template_file_paths), local.static_file_paths)

  file_suffix_matches = {
    for p in local.output_file_paths : p => regexall("\\.[^\\.]+\\z", length(regexall("\\.gz$", p)) > 0 ? replace(p, ".gz", "") : p)
  }
  file_suffixes = {
    for p, ms in local.file_suffix_matches : p => length(ms) > 0 ? ms[0] : ""
  }
  file_types = {
    for p in local.output_file_paths : p => lookup(var.file_types, local.file_suffixes[p], var.default_file_type)
  }

  files = merge(
    {
      for p in keys(local.template_file_paths) : p => {
        content_type     = local.file_types[p]
        content_encoding = length(regexall("\\.gz$", p)) > 0 ? "gzip" : null
        source_path      = tostring(null)
        content          = local.template_file_contents[p]
        digests = tomap({
          md5          = md5(local.template_file_contents[p])
          sha1         = sha1(local.template_file_contents[p])
          sha256       = sha256(local.template_file_contents[p])
          sha512       = sha512(local.template_file_contents[p])
          base64sha256 = base64sha256(local.template_file_contents[p])
          base64sha512 = base64sha512(local.template_file_contents[p])
        })
      }
    },
    {
      for p in local.static_file_paths : p => {
        content_type     = local.file_types[p]
        content_encoding = length(regexall("\\.gz$", p)) > 0 ? "gzip" : null
        source_path      = local.static_file_local_paths[p]
        content          = tostring(null)
        digests = tomap({
          md5          = filemd5(local.static_file_local_paths[p])
          sha1         = filesha1(local.static_file_local_paths[p])
          sha256       = filesha256(local.static_file_local_paths[p])
          sha512       = filesha512(local.static_file_local_paths[p])
          base64sha256 = filebase64sha256(local.static_file_local_paths[p])
          base64sha512 = filebase64sha512(local.static_file_local_paths[p])
        })
      }
    },
  )
  /*files = {
    for p in local.output_file_paths : p => {
      content_type = local.file_types[p]
      source_path  = lookup(local.static_file_local_paths, p, null)
      content      = lookup(local.template_file_contents, p, null)
    }
  }*/
}
