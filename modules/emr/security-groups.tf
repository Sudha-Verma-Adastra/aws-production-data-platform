
resource "aws_security_group" "emr_master" {
  count = var.enabled ? 1 : 0

  name        = "${var.project_name}-${var.environment}-emr-master-sg"
  description = "EMR primary node security group"
  vpc_id      = data.aws_subnet.selected.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-emr-master-sg"
  }
}

resource "aws_security_group" "emr_worker" {
  count = var.enabled ? 1 : 0

  name        = "${var.project_name}-${var.environment}-emr-worker-sg"
  description = "EMR worker security group"
  vpc_id      = data.aws_subnet.selected.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-emr-worker-sg"
  }
}

data "aws_subnet" "selected" {
  id = var.subnet_id
}

resource "aws_vpc_security_group_ingress_rule" "master_self" {
  count = var.enabled ? 1 : 0

  security_group_id            = aws_security_group.emr_master[0].id
  referenced_security_group_id = aws_security_group.emr_master[0].id
  ip_protocol                  = "-1"
  description                  = "Allow primary node internal communication"
}

resource "aws_vpc_security_group_ingress_rule" "worker_from_master" {
  count = var.enabled ? 1 : 0

  security_group_id            = aws_security_group.emr_worker[0].id
  referenced_security_group_id = aws_security_group.emr_master[0].id
  ip_protocol                  = "-1"
  description                  = "Allow cluster communication from primary"
}

resource "aws_vpc_security_group_ingress_rule" "worker_self" {
  count = var.enabled ? 1 : 0

  security_group_id            = aws_security_group.emr_worker[0].id
  referenced_security_group_id = aws_security_group.emr_worker[0].id
  ip_protocol                  = "-1"
  description                  = "Allow worker node internal communication"
}
