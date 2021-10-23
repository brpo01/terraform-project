output "ext-alb-zone-id" {
    value = aws_lb.ext-alb.zone_id
}

output "ext-alb-dns-name" {
    value = aws_lb.ext-alb.dns_name
}

output "nginx_tgt_arn" {
    value = aws_lb_target_group.nginx-tgt.arn
}