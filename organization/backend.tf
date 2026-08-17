####################################################################
# Remote state for the organization stack.
#
# GCS with object versioning on. GCS provides state locking natively,
# so two concurrent applies cannot both win. Versioning is what lets
# you recover from a bad apply, which matters more here than usual:
# the Port provider is create-and-override, so one wrong apply against
# the shared model can blank properties across every project at once.
#
# Create the bucket OUT OF BAND (it cannot bootstrap itself):
#
#   gsutil mb -p <PROJECT> -l us-central1 gs://mayo-port-idp-tfstate
#   gsutil versioning set on gs://mayo-port-idp-tfstate
#   gsutil uniformbucketlevelaccess set on gs://mayo-port-idp-tfstate
#
# Then fill in the bucket name below and run `terraform init`.
####################################################################

terraform {
  backend "gcs" {
    bucket = "REPLACE-ME-mayo-port-idp-tfstate"
    prefix = "organization"
  }
}
