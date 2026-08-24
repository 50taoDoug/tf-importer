output "arn" {
  value = aws_lambda_function.this.arn
}

output "id" {
  value = aws_lambda_function.this.id
}

output "invoke_arn" {
  value = aws_lambda_function.this.invoke_arn
}

output "qualified_arn" {
  value = aws_lambda_function.this.qualified_arn
}

output "version" {
  value = aws_lambda_function.this.version
}
