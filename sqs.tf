resource "aws_sqs_queue" "ec2_events_queue" {
  name                      = "${local.common_prefix}-ec2-events-queue"
  sqs_managed_sse_enabled   = true
  message_retention_seconds = 7200

  tags = merge(
    local.global_tags,
    {
      "Name" = lower("${local.common_prefix}-ec2-events-queue")
    }
  )
}

resource "aws_sqs_queue_policy" "ec2_events_queue_policy" {
  queue_url = aws_sqs_queue.ec2_events_queue.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "events.amazonaws.com"
        },
        Action = "sqs:SendMessage",
        Resource = [
          "${aws_sqs_queue.ec2_events_queue.arn}",
          "${aws_cloudwatch_event_rule.ec2_spot_interruption_warn.arn}"
        ]
      },
      {
        Effect = "Allow",
        Principal = {
          Service = "events.amazonaws.com"
        },
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = [
          "${aws_iam_role.docker_swarm_iam_role.arn}",
        ]
      }
    ]
  })
}