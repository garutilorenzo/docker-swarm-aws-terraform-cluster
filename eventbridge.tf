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

resource "aws_cloudwatch_event_rule" "ec2_instance_terminate_lifecycle" {
  name        = "${local.common_prefix}-ec2-instance-terminate-lifecycle"
  description = "Capture EC2 Instance Terminate Lifecycle Action"

  event_pattern = jsonencode(
    {
      "source" : [
        "aws.autoscaling"
      ]
      "detail-type" : [
        "EC2 Instance-terminate Lifecycle Action"
      ],
      "detail" : {
        "AutoScalingGroupName" : [
          { "prefix" : "${local.common_prefix}-managers-asg" },
          { "prefix" : "${local.common_prefix}-workers-asg" }
        ]
      }
    }
  )

  tags = merge(
    local.global_tags,
    {
      "Name" = lower("${local.common_prefix}-ec2-instance-terminate-lifecycle")
    }
  )
}

resource "aws_cloudwatch_event_target" "ec2_spot_interruption_warn_sqs" {
  rule      = aws_cloudwatch_event_rule.ec2_spot_interruption_warn.name
  target_id = "SendToSQS"
  arn       = aws_sqs_queue.ec2_events_queue.arn
}

resource "aws_cloudwatch_event_target" "ec2_instance_terminate_sqs" {
  rule      = aws_cloudwatch_event_rule.ec2_instance_terminate_lifecycle.name
  target_id = "SendToSQS"
  arn       = aws_sqs_queue.ec2_events_queue.arn
}