resource "google_service_account" "pipeline" {
  account_id = "${var.metadata_name}-pipeline"
  project    = var.project
}

resource "google_project_iam_member" "container_admin" {
  project = var.project
  role    = "roles/container.admin"
  member  = "serviceAccount:${google_service_account.pipeline.email}"
}

resource "google_project_iam_member" "editor" {
  project = var.project
  role    = "roles/editor"
  member  = "serviceAccount:${google_service_account.pipeline.email}"
}

resource "tls_private_key" "pipeline" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "kubernetes_namespace" "pipeline" {
  provider = kubernetes.gke

  metadata {
    name = "kbst-pipeline"
  }

  # namespace metadata may change through the manifests
  # hence ignoring this for the terraform lifecycle
  lifecycle {
    ignore_changes = [metadata]
  }

  depends_on = [module.node_pool]
}

resource "kubernetes_secret" "pipeline" {
  metadata {
    name      = "${var.metadata_name}-pipeline-sshkey"
    namespace = kubernetes_namespace.pipeline.metadata[0].name
  }

  data = {
    id_rsa     = tls_private_key.pipeline.private_key_openssh
    id_rsa.pub = tls_private_key.pipeline.public_key_openssh
  }
}

resource "kubernetes_service_account" "pipeline" {
  metadata {
    name      = "kbst-pipeline"
    namespace = kubernetes_namespace.pipeline.metadata[0].name
    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.pipeline.email
    }
  }

  secret {
    name = kubernetes_secret.pipeline.metadata.0.name
  }
}