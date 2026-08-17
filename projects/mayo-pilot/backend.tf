terraform {
  backend "gcs" {
    bucket = "REPLACE-ME-mayo-port-idp-tfstate"
    prefix = "projects/mayo-pilot"
  }
}
