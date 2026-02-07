# security.tf

# 1. 보안 그룹(Security Group) 생성
resource "aws_security_group" "mcu_sg" {
  name        = "kurento-mcu-sg"
  description = "Security Group for Kurento Media Server"
  vpc_id      = aws_vpc.main.id 

  # [Inbound 1] SSH 접속 (관리자용)
  ingress {
    description = "SSH from My IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # 실무에선 특정 IP로 제한 필요.
  }

  # [Inbound 2] HTTP/HTTPS (웹 서버 및 시그널링용)
  ingress {
    description = "HTTP Web Server"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    description = "HTTPS Web Server"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # [Inbound 3] WebRTC 미디어 포트 (핵심!)
  # Kurento 설정(WebRtcEndpoint.conf.ini)과 맞춰야 함
  # IANA 권장 동적 포트 범위: 49152 ~ 65535
  ingress {
    description = "WebRTC Media UDP Range"
    from_port   = 49152
    to_port     = 65535
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"] # WebRTC는 P2P라 상대방 IP를 특정할 수 없음
  }

  # [Inbound 4] STUN/TURN 서버용 포트 (Coturn)
  # RFC 5766 표준 포트
  ingress {
    description = "STUN/TURN Server"
    from_port   = 3478
    to_port     = 3478
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    description = "STUN/TURN Server UDP"
    from_port   = 3478
    to_port     = 3478
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # [Outbound] 모든 트래픽 허용 (패키지 설치, 외부 통신 등)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # 모든 프로토콜
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "kurento-mcu-sg"
  }
}