# 1. Fetch latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-kernel-6.1-x86_64"]
  }
}

# 2. Application Load Balancer across Public Subnets
resource "aws_lb" "web" {
  name               = "ha-web-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  tags = { Name = "web-alb" }
}

# 3. Target Group with Health Checks
resource "aws_lb_target_group" "web" {
  name     = "ha-web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }

  tags = { Name = "web-target-group" }
}

# 4. ALB Listener
resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.web.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# 5. Launch Template for Auto Scaling Instances
resource "aws_launch_template" "web" {
  name_prefix   = "ha-web-lt-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = "t2.micro"

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.app.id]
  }

  user_data = base64encode(<<-EOF
              #!/bin/bash
              dnf update -y
              dnf install -y httpd
              systemctl start httpd
              systemctl enable httpd
              
              echo "<h1>Hello from HA Cloud Platform running on AWS!</h1>" > /var/www/html/index.html
              mkdir -p /var/www/html/health
              echo "OK" > /var/www/html/health/index.html
              EOF
  )
  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "ha-asg-instance" }
  }
}

# 6. Auto Scaling Group across Private Subnets
resource "aws_autoscaling_group" "web" {
  name_prefix         = "ha-asg-"
  desired_capacity    = 2
  max_size            = 6
  min_size            = 2
  vpc_zone_identifier = aws_subnet.private_app[*].id
  target_group_arns   = [aws_lb_target_group.web.arn]
  health_check_type   = "ELB"

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "ha-asg-worker"
    propagate_at_launch = true
  }
}