# compute.tf

# 1. 최신 Ubuntu 22.04 AMI(이미지) 정보 가져오기
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical (Ubuntu 공식 배포자 ID)
}

# 2. SSH 접속용 Key Pair 자동 생성 (로컬 파일로 저장) 실무에선 기존에 만든거 import 하는식으로...
resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "kp" {
  key_name   = "kurento-key"       # AWS 콘솔에 등록될 이름
  public_key = tls_private_key.pk.public_key_openssh
}

resource "local_file" "ssh_key" {
  filename = "${path.module}/kurento-key.pem" # 현재 폴더에 키 파일 생성
  content  = tls_private_key.pk.private_key_pem
  file_permission = "0400" # 읽기 전용 권한 설정 (필수)
}

# 3. EC2 인스턴스 생성 (MCU 서버 본체)
resource "aws_instance" "mcu_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "c5.large" # 2 vCPU, 4GB RAM (비용 발생 주의!)

  subnet_id                   = aws_subnet.public.id     
  vpc_security_group_ids      = [aws_security_group.mcu_sg.id] 
  key_name                    = aws_key_pair.kp.key_name # 위에서 만든 키 페어 사용

  # 루트 볼륨(디스크) 설정
  root_block_device {
    volume_size = 30    # 30GB (Docker 이미지 및 로그 저장용 넉넉하게)
    volume_type = "gp3" # 최신 SSD 타입 (성능/비용 효율 좋음)
  }

  # [User Data] 서버 부팅 시 자동 실행할 스크립트 (Docker 미리 설치)
  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y ca-certificates curl gnupg lsb-release
              mkdir -p /etc/apt/keyrings
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
              echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
              $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
              apt-get update
              apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
              usermod -aG docker ubuntu
              EOF

  tags = {
    Name = "Kurento-MCU-Server"
  }
}

# 4. Elastic IP (고정 IP) 할당 및 연결
resource "aws_eip" "mcu_eip" {
  instance = aws_instance.mcu_server.id
  domain   = "vpc" # 최신 Terraform 버전에서는 'vpc = true' 대신 domain 사용

  tags = {
    Name = "Kurento-Static-IP"
  }
}

# 5. 접속 정보 출력 (Terraform 완료 후 보여줄 정보)
output "server_public_ip" {
  value = aws_eip.mcu_eip.public_ip
  description = "MCU 서버의 고정 공인 IP (접속 주소)"
}

output "ssh_command" {
  value = "ssh -i kurento-key.pem ubuntu@${aws_eip.mcu_eip.public_ip}"
  description = "SSH 접속 명령어"
}