# ECR Repository for Preview Images
resource "aws_ecr_repository" "preview_app" {
  name                 = "${var.project_name}/preview-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.project_name}-preview-app"
  }
}

# ECR Lifecycle Policy - Keep only last 30 images
resource "aws_ecr_lifecycle_policy" "preview_app" {
  repository = aws_ecr_repository.preview_app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 30 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 30
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
