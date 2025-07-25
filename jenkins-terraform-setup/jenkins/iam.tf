resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_iam_role" "jenkins" {
  name = "jenkins-role-${random_string.suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "jenkins_policy_attach" {
  name       = "jenkins-secretmanager"
  roles      = [aws_iam_role.jenkins.name]
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

resource "aws_iam_instance_profile" "jenkins_profile" {
  name = "jenkins-instance-profile-${random_string.suffix.result}"
  role = aws_iam_role.jenkins.name
}