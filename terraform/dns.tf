# DNS (Route53). 서버의 Elastic IP(공인 IP)를 도메인(A Record)과 자동으로 연결.
# [Data Source] 이미 AWS 콘솔에서 구매한 도메인 정보(Zone ID)를 조회.
# "example.com." 처럼 끝에 점(.)을 찍는 것이 정석.
data "aws_route53_zone" "selected" {
  name         = "nagibok-live-streaming.in."
  private_zone = false
}

# [Resource] A 레코드 생성 (mcu.도메인 -> 내 서버 IP)
resource "aws_route53_record" "mcu_dns" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "mcu.${data.aws_route53_zone.selected.name}" # 결과: mcu.nagibok-live-streaming.in
  type    = "A"                                            # A Record: 도메인 -> IPv4 주소 매핑
  ttl     = "300"                                          # Time To Live: 300초(5분) 동안 캐시 유지
  
  # 아까 만든 Elastic IP 리소스를 참조.
  # Terraform이 알아서 IP가 생성될 때까지 기다렸다가 DNS를 연결해줌. (의존성 관리)
  records = [aws_eip.mcu_eip.public_ip]
}