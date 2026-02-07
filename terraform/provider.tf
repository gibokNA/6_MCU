# provider.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # 최신 안정 버전 사용
    }
  }
}

# AWS 리전 설정 
provider "aws" {
  region = "ap-northeast-2" 

  # [실무 Tip] 모든 리소스에 공통 태그를 달아 비용 추적/관리를 용이하게 함
  default_tags {
    tags = {
      Project     = "Kurento-MCU"
      Environment = "Production"
      Owner       = "nagibok"
    }
  }
}