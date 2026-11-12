variable "subscription_id" {
  description = "Azure-Abo, in dem das Cluster entsteht (az account show --query id -o tsv)."
  type        = string
}

variable "github_repo" {
  description = "Dein GitHub-Repo, dessen Pipeline ausrollen darf, als <organisation>/<repo>."
  type        = string
}

variable "name" {
  description = "Kurzname; daraus entstehen Ressourcengruppe und Clustername."
  type        = string
  default     = "schmales-cluster"
}

variable "region" {
  description = "Azure-Region."
  type        = string
  default     = "germanywestcentral"
}

variable "node_size" {
  description = "Größe der Rechner im Cluster."
  type        = string
  default     = "Standard_D4as_v7"
}

variable "node_count" {
  description = "Zahl der Rechner im Cluster."
  type        = number
  default     = 2
}
