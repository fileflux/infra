provider "cloudflare" {
  email   = var.cloudflare_email
  api_key = var.cloudflare_api_key
}

resource "aws_acm_certificate" "s3_cert" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "s3"
  }
}

resource "cloudflare_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.s3_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = var.cloudflare_zone_id
  name    = each.value.name
  value   = trimsuffix(each.value.record, ".")
  type    = each.value.type
  ttl     = 1
  proxied = false
}

resource "aws_acm_certificate_validation" "s3_cert" {
  certificate_arn         = aws_acm_certificate.s3_cert.arn
  validation_record_fqdns = [for record in cloudflare_record.cert_validation : record.hostname]
}

resource "kubernetes_config_map" "tls_cert_configmap" {
  metadata {
    name      = "ssl"
    namespace = "s3"
  }

  data = {
    acm_certificate_arn = aws_acm_certificate.s3_cert.arn
  }
  depends_on = [kubernetes_namespace.s3]
}



resource "aws_acm_certificate" "grafana_cert" {
  domain_name       = var.grafana_domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "grafana"
  }
}

resource "cloudflare_record" "grafana_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.grafana_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = var.cloudflare_zone_id
  name    = each.value.name
  value   = trimsuffix(each.value.record, ".")
  type    = each.value.type
  ttl     = 1
  proxied = false
}

resource "aws_acm_certificate_validation" "grafana_cert" {
  certificate_arn         = aws_acm_certificate.grafana_cert.arn
  validation_record_fqdns = [for record in cloudflare_record.grafana_cert_validation : record.hostname]
}

resource "kubernetes_config_map" "grafana_cert_configmap" {
  metadata {
    name      = "grafana-tls"
    namespace = "monitoring"
  }

  data = {
    acm_certificate_arn = aws_acm_certificate.grafana_cert.arn
  }
  depends_on = [kubernetes_namespace.monitoring]
}
