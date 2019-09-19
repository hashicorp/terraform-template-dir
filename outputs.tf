output "files" {
  value       = local.files
  description = "Map from relative file paths to objects describing all of the files. See the module README for more information."
}

output "files_on_disk" {
  value       = { for p, f in local.files : p => f if f.source_path != null }
  description = "A filtered version of the files output that includes only entries that point to static files on disk."
}

output "files_in_memory" {
  value       = { for p, f in local.files : p => f if f.content != null }
  description = "A filtered version of the files output that includes only entries that have rendered content in memory."
}
