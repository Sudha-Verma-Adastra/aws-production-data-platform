
data "aws_iam_policy_document" "emr_service_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["elasticmapreduce.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "emr_service" {
  count = var.enabled ? 1 : 0

  name               = "${var.project_name}-${var.environment}-emr-service"
  assume_role_policy = data.aws_iam_policy_document.emr_service_assume_role.json
}

resource "aws_iam_role_policy_attachment" "emr_service" {
  count = var.enabled ? 1 : 0

  role       = aws_iam_role.emr_service[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceRole"
}

data "aws_iam_policy_document" "emr_ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "emr_ec2" {
  count = var.enabled ? 1 : 0

  name               = "${var.project_name}-${var.environment}-emr-ec2"
  assume_role_policy = data.aws_iam_policy_document.emr_ec2_assume_role.json
}

resource "aws_iam_role_policy_attachment" "emr_ec2" {
  count = var.enabled ? 1 : 0

  role       = aws_iam_role.emr_ec2[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceforEC2Role"
}

resource "aws_iam_instance_profile" "emr_ec2" {
  count = var.enabled ? 1 : 0

  name = "${var.project_name}-${var.environment}-emr-instance-profile"
  role = aws_iam_role.emr_ec2[0].name
}

data "aws_iam_policy_document" "emr_s3_access" {
  statement {
    sid       = "ListDataLakeBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [var.data_lake_bucket_arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["raw/*", "emr-processed/*"]
    }
  }

  statement {
    sid    = "ReadRawData"
    effect = "Allow"

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "${var.data_lake_bucket_arn}/raw/*"
    ]
  }

  statement {
    sid    = "WriteSparkOutput"
    effect = "Allow"

    actions = [
      "s3:PutObject",
      "s3:AbortMultipartUpload"
    ]

    resources = [
      "${var.data_lake_bucket_arn}/emr-processed/*"
    ]
  }
}

resource "aws_iam_role_policy" "emr_s3_access" {
  count = var.enabled ? 1 : 0

  name   = "${var.project_name}-${var.environment}-emr-s3-access"
  role   = aws_iam_role.emr_ec2[0].id
  policy = data.aws_iam_policy_document.emr_s3_access.json
}
