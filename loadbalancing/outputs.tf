output "alb_dns_name" {
  value = aws_lb.ext-alb.dns_name
}

output "alb_target_group_arn" {
  value = aws_lb_target_group.nginx-tgt.arn
}

output "ext-alb-zone-id" {
    value = aws_lb.ext-alb.zone_id
}

output "ext-alb-dns-name" {
    value = aws_lb.ext-alb.dns_name
}

output "nginx_tgt_arn" {
    value = aws_lb_target_group.nginx-tgt.arn
}

output "wordpress_tgt_arn" {
    value = aws_lb_target_group.wordpress-tgt.arn
}

output "tooling_tgt_arn" {
    value = aws_lb_target_group.tooling-tgt.arn
}