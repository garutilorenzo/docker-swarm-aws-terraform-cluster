resource "aws_secretsmanager_secret" "join_manager_secret" {
  name        = local.docker_swarm_join_manager_secret_name
  description = "Docker swarm join manager token. Cluster name: ${var.cluster_name} environment: ${var.environment}"

  tags = merge(
    local.global_tags,
    {
      "Name" = lower("${local.docker_swarm_join_manager_secret_name}")
    }
  )
}

resource "aws_secretsmanager_secret" "join_worker_secret" {
  name        = local.docker_swarm_join_worker_secret_name
  description = "Docker swarm join worker token. Cluster name: ${var.cluster_name} environment: ${var.environment}"

  tags = merge(
    local.global_tags,
    {
      "Name" = lower("${local.docker_swarm_join_worker_secret_name}")
    }
  )
}

# secret default values

resource "aws_secretsmanager_secret_version" "join_manager_default" {
  secret_id     = aws_secretsmanager_secret.join_manager_secret.id
  secret_string = var.default_secret_placeholder
}

resource "aws_secretsmanager_secret_version" "join_worker_default" {
  secret_id     = aws_secretsmanager_secret.join_worker_secret.id
  secret_string = var.default_secret_placeholder
}

# Secret Policies

resource "aws_secretsmanager_secret_policy" "join_manager_secret_policy" {
  secret_arn = aws_secretsmanager_secret.join_manager_secret.arn

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
          "${aws_secretsmanager_secret.join_manager_secret.arn}"
        ]
      }
    ]
  })
}

resource "aws_secretsmanager_secret_policy" "join_worker_secret_policy" {
  secret_arn = aws_secretsmanager_secret.join_worker_secret.arn

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
          "${aws_secretsmanager_secret.join_worker_secret.arn}"
        ]
      }
    ]
  })
}