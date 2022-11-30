# //////////////////////////////
# VARIABLES
# //////////////////////////////
variable "aws_access_key" {}

variable "aws_secret_key" {}

variable "bucket_name" {
  default = "red30-tfstate-gregp"
}

# //////////////////////////////
# PROVIDER
# //////////////////////////////
provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region = "us-east-2"
}

# //////////////////////////////
# TERRAFORM USER
# //////////////////////////////
data "aws_iam_user" "terraform" {
  # tu musimy podać nazwę usera, jaki jest stworzony na AWS
  user_name = "Learning_Terraform"
}

# //////////////////////////////
# S3 BUCKET
# //////////////////////////////
resource "aws_s3_bucket" "red30-tfremotestate-gregp" {
  bucket = var.bucket_name
  # umozliwia zniszczenie bucketa nawet jeśli zawiera jakieś dane
  force_destroy = true
  # dostęp tylko dla uprawnionych uzytkowników
  # ale ten zasób jest juz deprecated i jest nowy: aws_s3_bucket_versioning
  acl = "private"

  versioning {
    # dane są wersjonowane zamiast zostawać nadpisanymi
    enabled = true
  }

  # Grant read/write access to the terraform user
  policy = <<EOF
{
    "Version": "2008-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Principal": {
                "AWS": "${data.aws_iam_user.terraform.arn}"
            },
            "Action": "s3:*",
            "Resource": "arn:aws:s3:::${var.bucket_name}/*"
        }
    ]
}
EOF
}

# to jest ciekawe, bo ten zasób nadpisuje ustawienia dostępowe do S3, tak aby jakikolwiek publiczny dostęp był mozliwy tylko dla autoryzowanych uzytkowników, nawet gdyby ktoś przez przypadek dodał np. Politykę publicznego dostępu na odczyty
resource "aws_s3_bucket_public_access_block" "red30-tfremotestate-gregp" {
  bucket = aws_s3_bucket.red30-tfremotestate-gregp.id

  block_public_acls   = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}

# //////////////////////////////
# DYNAMODB TABLE
# //////////////////////////////
resource "aws_dynamodb_table" "tf_db_statelock" {
  # definiowana jest pojedyncza tabela z jednym atrybutem LockID o typie String - musi się on tak nazywać
  name           = "red30-tfstatelock"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

# //////////////////////////////
# IAM POLICY
# //////////////////////////////
resource "aws_iam_user_policy" "terraform_user_dbtable" {
  name = "terraform"
  user = data.aws_iam_user.terraform.user_name
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": ["dynamodb:*"],
            "Resource": [
                "${aws_dynamodb_table.tf_db_statelock.arn}"
            ]
        }
   ]
}

EOF
}

