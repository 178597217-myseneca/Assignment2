# Default tags
output "default_tags" {
  value = {
    "Owner" = "Aanchal"
    "App"   = "Web"
    "Project" = "CLO835"
  }
}

# Prefix to identify resources
output "prefix" {
   value     = "EC2-Kubernetes"
}
