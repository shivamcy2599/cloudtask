provider "aws" {
  version = "~> 2.0"
region = "ap-south-1"
profile = "Shiva1"

}
variable "key_name" {
  default = "task_key"
}

resource "tls_private_key" "ec2_private_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

module "key_pair" {
  source = "terraform-aws-modules/key-pair/aws"

  key_name   = "task_key"
  public_key = tls_private_key.ec2_private_key.public_key_openssh
}





//creating security group

resource "aws_security_group" "allow_tls" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = "vpc-3484985c"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_tls"
  }
}




//Launching EC2 instance using above key and SG

resource "aws_instance" "test" {
ami = "ami-0447a12f28fddb066"
instance_type = "t2.micro"
key_name = "task1"
security_groups = ["${aws_security_group.allow_tls.id}"]
subnet_id = "subnet-5df6f335"
tags = {
 Name = "taskos_1"
  }
}



// Creating EBS volume

resource "aws_ebs_volume" "task_pd" {
  availability_zone = aws_instance.test.availability_zone
  size              = 1
tags = {
    Name = "task_pd"
  }
}


// Attaching the EBS volume

resource "aws_volume_attachment" "attach" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.task_pd.id
  instance_id = aws_instance.test.id
  force_detach = true
}


// attaching to ec2 instance


resource "null_resource" "pd_mount"  {
depends_on = [
    aws_volume_attachment.attach,
  ]
connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/This PC/Downloads/task1.pem")
    host     = aws_instance.test.public_ip
  }

provisioner "remote-exec"{
   
       inline = [
         
          "sudo yum install httpd php git -y",
	  "sudo systemctl start httpd",
	  "sudo systemctl enable httpd",
          "sudo mkfs.ext4  /dev/xvdf",
          "sudo rm -rf /var/www/html/*",
          "sudo mount  /dev/xvdf  /var/www/html",
          "sudo git clone https://github.com/shivamcy2599/cloudtask.git /html_repo",
	  "sudo cp -r /html_repo/* /var/www/html",
	  "sudo rm -rf /html_repo"
         ]
 
    }
}




// Creating S3 Bucket

resource "aws_s3_bucket" "xyz" {
  bucket = "taskcloudone"
  acl    = "public-read"
  versioning {
 enabled = true
 } 

tags = {
    Name = "my bucket one"
  }
}
//creating S3 bucket_object




resource "aws_s3_bucket_object" "object1" {
  bucket = aws_s3_bucket.xyz.bucket
  key    = "My_Image"
  acl = "public-read"
  source= "C:/Users/This PC/Downloads/terra.png"
  depends_on = [ aws_s3_bucket.xyz ]
  
}

locals {
  s3_origin_id = "myS3Origin"
}
resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "Some comment"
}
resource "aws_cloudfront_distribution" "s3_distribution" {
origin {
    domain_name = aws_s3_bucket.xyz.bucket_regional_domain_name
    origin_id   = local.s3_origin_id
s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }
enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "My_Image"
default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD",  "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id
forwarded_values {
      query_string = false
cookies {
        forward = "none"
      }
    }
viewer_protocol_policy = "allow-all"
 min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  
  }
price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA", "GB", "DE"]
    }
  }

  tags = {
    Environment = "production"
  }

viewer_certificate {
    cloudfront_default_certificate = true
  }

connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/This PC/Downloads/task1.pem")
    host     = aws_instance.test.public_ip
  }
}
