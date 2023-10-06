terraform {
 backend "gcs" {
   bucket  = "umeshkumhar"
   prefix  = "platform/state"
 }
}