# network.tf

# 1. VPC 생성 (가상의 IDC 센터 구축)
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16" # 65,536개의 IP를 쓸 수 있는 대역폭 확보
  enable_dns_hostnames = true          # public DNS 호스트네임 자동 할당 (편의성)
  enable_dns_support   = true          # DNS 쿼리 지원

  tags = {
    Name = "kurento-vpc"
  }
}

# 2. Internet Gateway 생성 (외부 인터넷 회선 연결)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id # 위에서 만든 VPC에 갖다 붙임

  tags = {
    Name = "kurento-igw"
  }
}

# 3. Public Subnet 생성 (MCU 서버가 입주할 공간)
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.10.0/24"      # 10.0.10.1 ~ 254 사용 가능
  availability_zone       = "ap-northeast-2a"   # 가용 영역 지정 (서울 A존)
  map_public_ip_on_launch = true                # [중요] 여기에 서버 띄우면 자동으로 공인 IP 줌

  tags = {
    Name = "kurento-public-subnet"
  }
}

# 4. Route Table 생성 (네트워크 표지판 설치)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  # "모든 외부 트래픽(0.0.0.0/0)은 인터넷 게이트웨이(IGW)로 보내라"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "kurento-public-rt"
  }
}

# 5. Route Table Association (서브넷에 표지판 달기)
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}