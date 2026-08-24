output "arn" {
  value = aws_ecs_task_definition.this.arn
}

output "family" {
  value = aws_ecs_task_definition.this.family
}

output "family_revision" {
  value = "${aws_ecs_task_definition.this.family}:${aws_ecs_task_definition.this.revision}"
}

output "revision" {
  value = aws_ecs_task_definition.this.revision
}
