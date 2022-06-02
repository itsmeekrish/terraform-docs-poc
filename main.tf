resource "aws_s3_bucket" "poc_codebuild_artifact" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_acl" "poc_codebuild_artifact_acl" {
  bucket = aws_s3_bucket.poc_codebuild_artifact.id
  acl    = "public-read-write"
}

resource "aws_iam_role" "codebuild_role" {
  name = "codebuild_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codebuild_role_policy" {
  role = "${aws_iam_role.codebuild_role.name}"
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Resource": [
        "*"
      ],
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:CreateNetworkInterface",
        "ec2:DescribeDhcpOptions",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DeleteNetworkInterface",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeVpcs"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "ec2:CreateNetworkInterfacePermission",
      "Resource": "arn:aws:ec2:us-east-2:649042102676:network-interface/*",
      "Condition": {
        "StringEquals": {
          "ec2:Subnet": [
              "${aws_subnet.default_az1.arn}",
              "${aws_subnet.default_az2.arn}"
          ],
          "ec2:AuthorizedService": "codebuild.amazonaws.com"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "${aws_s3_bucket.poc_codebuild_artifact.arn}",
        "${aws_s3_bucket.poc_codebuild_artifact.arn}/*"
      ]
    }
  ]
}
POLICY
}

resource "aws_vpc" "codebuild" {
    cidr_block = "10.0.0.0/16"
    enable_dns_support = true #gives you an internal domain name
    enable_dns_hostnames = true #gives you an internal host name
    enable_classiclink = false
    instance_tenancy = "default"
}

resource "aws_subnet" "default_az1" {
  vpc_id     = aws_vpc.codebuild.id
  cidr_block = "10.0.1.0/28"
  availability_zone = "us-east-2a"
}

resource "aws_subnet" "default_az2" {
  depends_on = [
    aws_vpc.codebuild,
  ]

  vpc_id     = aws_vpc.codebuild.id
  cidr_block = "10.0.2.0/28"

  availability_zone = "us-east-2b"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "igw" {
    vpc_id = "${aws_vpc.codebuild.id}"
    depends_on = [
    aws_vpc.codebuild,
    ]
}

resource "aws_route_table" "IG_route_table" {
  depends_on = [
    aws_vpc.codebuild,
    aws_internet_gateway.igw,
  ]

  vpc_id = aws_vpc.codebuild.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

# associate route table to public subnet
resource "aws_route_table_association" "associate_routetable_to_default_az2" {
  depends_on = [
    aws_subnet.default_az2,
    aws_route_table.IG_route_table,
  ]
  subnet_id      = aws_subnet.default_az2.id
  route_table_id = aws_route_table.IG_route_table.id
}

resource "aws_eip" "elastic_ip" {
  vpc      = true
}

resource "aws_nat_gateway" "mynatgw" {
  depends_on = [
    aws_subnet.default_az2,
    aws_eip.elastic_ip,
  ]
  allocation_id = aws_eip.elastic_ip.id
  subnet_id     = aws_subnet.default_az2.id

  tags = {
    Name = "nat-gateway"
  }
}

resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.codebuild.id
  depends_on = [aws_vpc.codebuild, aws_nat_gateway.mynatgw]


  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.mynatgw.id
  }
}



resource "aws_route_table_association" "associate_routetable_to_default_az1" {
  depends_on = [
    aws_subnet.default_az1,
    aws_route_table.route_table,
  ]
  subnet_id      = aws_subnet.default_az1.id
  route_table_id = aws_route_table.route_table.id
}

resource "aws_security_group" "codebuild_sg" {
    vpc_id = "${aws_vpc.codebuild.id}"
    
    ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        description = "SSH"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {
        description = "https"
        from_port   = 443    
        to_port     = 443
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks =  ["0.0.0.0/0"]
    }
}

resource "aws_codebuild_source_credential" "personal_token" {
  auth_type   = "PERSONAL_ACCESS_TOKEN"
  server_type = "GITHUB"
  token       = var.GITHUB_PERSONAL_TOKEN
}

resource "aws_codebuild_project" "poc_codebuild" {
  name          = "poc-codebuild"
  description   = "poc for codebuild"
  build_timeout = "5"
  service_role  = "${aws_iam_role.codebuild_role.arn}"

  artifacts {
    type = "S3"
    location = "${aws_s3_bucket.poc_codebuild_artifact.bucket}"
    namespace_type = "NONE"
    packaging = "NONE"
    path = "build"
  } 

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:1.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
  }

  logs_config {
    cloudwatch_logs {
      group_name = "codebuild"
      stream_name = "poc-codebuild"
    }

    s3_logs {
      status   = "ENABLED"
      location = "${aws_s3_bucket.poc_codebuild_artifact.id}/build-log"
    }
  }

  source {
    type            = "GITHUB"
    location        = "https://github.com/Krish6987/poc-codebuild.git"
    git_clone_depth = 1
  }

  vpc_config {
    vpc_id = aws_vpc.codebuild.id

    subnets = [
      aws_subnet.default_az1.id,
      aws_subnet.default_az2.id
    ]

    security_group_ids = [
      aws_security_group.codebuild_sg.id
    ]
  }

  tags = {
    "Environment" = "Test"
  }
}

resource "aws_codebuild_webhook" "poc_codebuild_webook" {
  project_name = aws_codebuild_project.poc_codebuild.name
  build_type   = "BUILD"
  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PUSH"
    }
  }
}