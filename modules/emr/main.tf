
resource "aws_emr_cluster" "spark" {
  count = var.enabled ? 1 : 0

  name          = "${var.project_name}-${var.environment}-emr-spark"
  release_label = var.release_label
  applications  = ["Spark"]

  service_role = aws_iam_role.emr_service[0].arn

  ec2_attributes {
    subnet_id                         = var.subnet_id
    instance_profile                  = aws_iam_instance_profile.emr_ec2[0].arn
    emr_managed_master_security_group = aws_security_group.emr_master[0].id
    emr_managed_slave_security_group  = aws_security_group.emr_worker[0].id
  }

  master_instance_group {
    instance_type  = "m4.large"
    instance_count = 1
  }

  step {
    name              = "sandbox-spark-data-processing"
    action_on_failure = "TERMINATE_CLUSTER"

    hadoop_jar_step {
      jar = "command-runner.jar"
      args = [
        "spark-submit",
        var.spark_script_s3_uri
      ]
    }
  }

  keep_job_flow_alive_when_no_steps = false

  tags = {
    Name        = "${var.project_name}-${var.environment}-emr-spark"
    Project     = var.project_name
    Environment = var.environment
  }

  depends_on = [
    aws_iam_role_policy_attachment.emr_service,
    aws_iam_role_policy_attachment.emr_ec2,
    aws_iam_role_policy.emr_s3_access
  ]
}
