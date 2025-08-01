resource "aws_iam_instance_profile" "docker_swarm_instance_profile" {
  name = "${local.common_prefix}-ec2-instance-profile"
  role = aws_iam_role.docker_swarm_iam_role.name

  tags = merge(
    local.global_tags,
    {
      "Name" = lower("${local.common_prefix}-ec2-instance-profile")
    }
  )
}

resource "aws_iam_role" "docker_swarm_iam_role" {
  name = "${local.common_prefix}-iam-role"

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
      "Name" = lower("${local.common_prefix}-iam-role")
    }
  )
}

resource "aws_iam_policy" "allow_secrets_manager" {
  name        = "${local.common_prefix}-secrets-manager-policy"
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
          "${aws_secretsmanager_secret.join_secret.arn}"
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
      "Name" = lower("${local.common_prefix}-secrets-manager-policy")
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

resource "aws_iam_role" "notification_asg_iam_role" {
  name = "${local.common_prefix}-notification-asg-iam-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "autoscaling.amazonaws.com"
        }
      },
    ]
  })

  tags = merge(
    local.global_tags,
    {
      "Name" = lower("${local.common_prefix}-notification-asg-iam-role")
    }
  )
}

resource "aws_iam_role_policy_attachment" "attach_asg_notification_policy" {
  role       = aws_iam_role.docker_swarm_iam_role.name
  policy_arn = data.aws_iam_policy.AutoScalingNotificationAccessRole.arn
}