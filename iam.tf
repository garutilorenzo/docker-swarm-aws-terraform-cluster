resource "aws_iam_instance_profile" "docker_swarm_instance_profile" {
  name = "${var.common_prefix}-ec2-instance-profile--${var.environment}"
  role = aws_iam_role.docker_swarm_iam_role.name

  tags = merge(
    local.global_tags,
    {
      "Name" = lower("${var.common_prefix}-ec2-instance-profile--${var.environment}")
    }
  )
}

resource "aws_iam_role" "docker_swarm_iam_role" {
  name = "${var.common_prefix}-iam-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = merge(
    local.global_tags,
    {
      "Name" = lower("${var.common_prefix}-iam-role-${var.environment}")
    }
  )
}

resource "aws_iam_policy" "allow_secrets_manager" {
  name        = "${var.common_prefix}-secrets-manager-policy-${var.environment}"
  path        = "/"
  description = "Secrets Manager Policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:UpdateSecret",
          "secretsmanager:DeleteSecret",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets",
          "secretsmanager:CreateSecret",
          "secretsmanager:PutSecretValue"
        ],
        Resource = [
          "${aws_secretsmanager_secret.join_manager_secret.arn}",
          "${aws_secretsmanager_secret.join_worker_secret.arn}"
        ],
        Condition = {
          StringEquals = {
            for tag, value in local.global_tags : "aws:ResourceTag/${tag}" => value
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:ListSecrets"
        ],
        Resource = [
          "*"
        ],
      }
    ]
  })

  tags = merge(
    local.global_tags,
    {
      "Name" = lower("${var.common_prefix}-secrets-manager-policy-${var.environment}")
    }
  )
}

resource "aws_iam_role_policy_attachment" "attach_ssm_policy" {
  role       = aws_iam_role.docker_swarm_iam_role.name
  policy_arn = data.aws_iam_policy.AmazonSSMManagedInstanceCore.arn
}

resource "aws_iam_role_policy_attachment" "attach_ec2_ro_policy" {
  role       = aws_iam_role.docker_swarm_iam_role.name
  policy_arn = data.aws_iam_policy.AmazonEC2ReadOnlyAccess.arn
}

resource "aws_iam_role_policy_attachment" "attach_allow_secrets_manager_policy" {
  role       = aws_iam_role.docker_swarm_iam_role.name
  policy_arn = aws_iam_policy.allow_secrets_manager.arn
}
