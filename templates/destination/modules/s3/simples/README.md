# `s3/simples` Module

Basic S3 bucket without versioning, custom encryption, replication, or an
additional policy. This profile matches the five buckets identified in the
canonical `prd` environment.

## Usage

```hcl
module "my_bucket" {
  source      = "../../../modules/s3/simples"
  bucket_name = "bucket-name"
  tags        = module.tags.tags
}
```
