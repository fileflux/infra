resource "aws_security_group" "cluster" {
  name        = var.aws_cluster_security_group_name
  description = "Cluster SG"
  vpc_id      = aws_vpc.main.id
  tags = {
    app = "s3"
  }
}

resource "aws_security_group_rule" "cluster_ingress" {
  type              = "ingress"
  count             = length(var.cluster_ingress_rules)
  from_port         = var.cluster_ingress_rules[count.index].from_port
  to_port           = var.cluster_ingress_rules[count.index].to_port
  protocol          = var.cluster_ingress_rules[count.index].protocol
  cidr_blocks       = [var.cluster_ingress_rules[count.index].cidr_block]
  description       = var.cluster_ingress_rules[count.index].description
  security_group_id = aws_security_group.cluster.id
}

resource "aws_security_group_rule" "cluster_egress" {
  type              = "egress"
  count             = length(var.cluster_egress_rules)
  from_port         = var.cluster_egress_rules[count.index].from_port
  to_port           = var.cluster_egress_rules[count.index].to_port
  protocol          = var.cluster_egress_rules[count.index].protocol
  cidr_blocks       = [var.cluster_egress_rules[count.index].cidr_block]
  description       = var.cluster_egress_rules[count.index].description
  security_group_id = aws_security_group.cluster.id
}

resource "aws_security_group" "node" {
  name        = var.aws_node_security_group_name
  description = "Node SG"
  vpc_id      = aws_vpc.main.id
  tags = {
    "karpenter.sh/discovery" = "${var.cluster_name}"
  }
}

resource "aws_security_group_rule" "node_egress" {
  type              = "egress"
  count             = length(var.node_egress_rules)
  from_port         = var.node_egress_rules[count.index].from_port
  to_port           = var.node_egress_rules[count.index].to_port
  protocol          = var.node_egress_rules[count.index].protocol
  cidr_blocks       = [var.node_egress_rules[count.index].cidr_block]
  description       = var.node_egress_rules[count.index].description
  security_group_id = aws_security_group.node.id
}

resource "aws_security_group_rule" "node_ingress" {
  type                     = "ingress"
  count                    = length(var.node_ingress_rules)
  from_port                = var.node_ingress_rules[count.index].from_port
  to_port                  = var.node_ingress_rules[count.index].to_port
  protocol                 = var.node_ingress_rules[count.index].protocol
  source_security_group_id = aws_security_group.cluster.id
  security_group_id        = aws_security_group.node.id
  description              = var.node_ingress_rules[count.index].description
}

resource "aws_security_group" "bastion_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "node_ssh_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    "karpenter.sh/discovery" = "${var.cluster_name}"
  }
}