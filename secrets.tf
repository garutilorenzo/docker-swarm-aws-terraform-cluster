resource "aws_secretsmanager_secret" "join_secret" {
  name        = local.docker_swarm_secret_name
  description = "Docker swarm join manager token. Cluster name: ${var.cluster_name} environment: ${var.environment}"

  # TODO
  recovery_window_in_days = 0

  tags = merge(
    local.global_tags,
    {
      "Name" = lower("${local.docker_swarm_secret_name}")
    }
  )
}

# secret default values

# resource "aws_secretsmanager_secret_version" "join_secret_default" {
#   secret_id     = aws_secretsmanager_secret.join_secret.id
#   secret_string = jsondecode({
#     "defaultvalue" = var.default_secret_placeholder
#   })
# }

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