# {
#   "version": "0",
#   "id": "1e5527d7-bb36-4607-3370-4164db56a40e",
#   "detail-type": "EC2 Spot Instance Interruption Warning",
#   "source": "aws.ec2",
#   "account": "123456789012",
#   "time": "1970-01-01T00:00:00Z",
#   "region": "us-east-1",
#   "resources": ["arn:aws:ec2:us-east-1b:instance/i-0b662ef9931388ba0"],
#   "detail": {
#     "instance-id": "i-0b662ef9931388ba0",
#     "instance-action": "terminate"
#   }
# }

resource "aws_cloudwatch_event_rule" "ec2_spot_interruption_warn" {
  name        = "${local.common_prefix}-ec2-spot-interruption-warn"
  description = "Capture EC2 Spot Interruption warning"

  event_pattern = jsonencode({
    source      = ["aws.ec2"],
    detail-type = ["EC2 Spot Instance Interruption Warning"]
  })

  tags = merge(
    local.global_tags,
    {
      "Name" = lower("${local.common_prefix}-ec2-spot-interruption-warn")
    }
  )
}

resource "aws_cloudwatch_event_target" "ec2_spot_interruption_warn_sqs" {
  rule      = aws_cloudwatch_event_rule.ec2_spot_interruption_warn.name
  target_id = "SendToSQS"
  arn       = aws_sqs_queue.ec2_events_queue.arn
}

resource "aws_cloudwatch_event_rule" "ec2_instance_rebalance_recommendation" {
  name        = "${local.common_prefix}-ec2-instance-rebalance-recommendation"
  description = "Capture EC2 Instance Rebalance Recommendation"

  event_pattern = jsonencode({
    source      = ["aws.ec2"],
    detail-type = ["EC2 Instance Rebalance Recommendation"]
  })

  tags = merge(
    local.global_tags,
    {
      "Name" = lower("${local.common_prefix}-ec2-instance-rebalance-recommendation")
    }
  )
}

resource "aws_cloudwatch_event_target" "ec2_instance_rebalance_recommendation_sqs" {
  rule      = aws_cloudwatch_event_rule.ec2_instance_rebalance_recommendation.name
  target_id = "SendToSQS"
  arn       = aws_sqs_queue.ec2_events_queue.arn
}

resource "aws_cloudwatch_event_rule" "ec2_instance_state_change_notification" {
  name        = "${local.common_prefix}-ec2-instance-state-change-notification"
  description = "Capture EC2 Instance State-change Notification"

  event_pattern = jsonencode({
    source      = ["aws.ec2"],
    detail-type = ["EC2 Instance State-change Notification"]
  })

  tags = merge(
    local.global_tags,
    {
      "Name" = lower("${local.common_prefix}-ec2-instance-state-change-notification")
    }
  )
}

resource "aws_cloudwatch_event_target" "ec2_instance_state_change_notification_sqs" {
  rule      = aws_cloudwatch_event_rule.ec2_instance_state_change_notification.name
  target_id = "SendToSQS"
  arn       = aws_sqs_queue.ec2_events_queue.arn
}

resource "aws_cloudwatch_event_rule" "ec2_scheduled_change_notification" {
  name        = "${local.common_prefix}-ec2-scheduled-change-notification"
  description = "Capture EC2 Instance State-change Notification"

  event_pattern = jsonencode({
    source      = ["aws.health"],
    detail-type = ["AWS Health Event"]
    detail = {
      service           = ["EC2"],
      eventTypeCategory = ["scheduledChange"]
    }
  })

  tags = merge(
    local.global_tags,
    {
      "Name" = lower("${local.common_prefix}-ec2-scheduled-change-notification")
    }
  )
}

resource "aws_cloudwatch_event_target" "ec2_scheduled_change_notification_sqs" {
  rule      = aws_cloudwatch_event_rule.ec2_scheduled_change_notification.name
  target_id = "SendToSQS"
  arn       = aws_sqs_queue.ec2_events_queue.arn
}