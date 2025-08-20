resource "aws_secretsmanager_secret" "join_secret" {
  name        = local.docker_swarm_secret_name
  description = "Docker swarm join tokens cluster name: ${var.cluster_name} environment: ${var.environment}"

  # Set to 0 for testing
  # recovery_window_in_days = 0

  tags = merge(
    local.global_tags,
    {
      "Name" = lower("${local.docker_swarm_secret_name}")
    }
  )
}

resource "aws_secretsmanager_secret" "docker_ca_ssl_secret" {
  name        = local.docker_ca_ssl_secret_name
  description = "SSL CA for Docker cluster name: ${var.cluster_name} environment: ${var.environment}"

  # Set to 0 for testing
  # recovery_window_in_days = 0

  tags = merge(
    local.global_tags,
    {
      "Name" = lower("${local.docker_ca_ssl_secret_name}")
    }
  )
}

resource "aws_secretsmanager_secret" "docker_client_ssl_secret" {
  name        = local.docker_client_ssl_secret_name
  description = "SSL Client certificate cluster name: ${var.cluster_name} environment: ${var.environment}"

  # Set to 0 for testing
  # recovery_window_in_days = 0

  tags = merge(
    local.global_tags,
    {
      "Name" = lower("${local.docker_client_ssl_secret_name}")
    }
  )
}

# Secret Policies

resource "aws_secretsmanager_secret_policy" "join_manager_secret_policy" {
  secret_arn = aws_secretsmanager_secret.join_secret.arn

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          AWS = "${aws_iam_role.docker_swarm_iam_role.arn}"
        },
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:UpdateSecret",
          "secretsmanager:DeleteSecret",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets",
          "secretsmanager:CreateSecret",
          "secretsmanager:PutSecretValue"
        ]
        Resource = [
          "${aws_secretsmanager_secret.join_secret.arn}"
        ]
      }
    ]
  })
}

resource "aws_secretsmanager_secret_policy" "docker_ca_ssl_secret_policy" {
  secret_arn = aws_secretsmanager_secret.docker_ca_ssl_secret.arn

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          AWS = "${aws_iam_role.docker_swarm_iam_role.arn}"
        },
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:UpdateSecret",
          "secretsmanager:DeleteSecret",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets",
          "secretsmanager:CreateSecret",
          "secretsmanager:PutSecretValue"
        ]
        Resource = [
          "${aws_secretsmanager_secret.docker_ca_ssl_secret.arn}"
        ]
      }
    ]
  })
}

resource "aws_secretsmanager_secret_policy" "docker_client_ssl_secret_policy" {
  secret_arn = aws_secretsmanager_secret.docker_client_ssl_secret.arn

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          AWS = "${aws_iam_role.docker_swarm_iam_role.arn}"
        },
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:UpdateSecret",
          "secretsmanager:DeleteSecret",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets",
          "secretsmanager:CreateSecret",
          "secretsmanager:PutSecretValue"
        ]
        Resource = [
          "${aws_secretsmanager_secret.docker_client_ssl_secret.arn}"
        ]
      }
    ]
  })
}