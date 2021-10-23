output "bastion_launch_template" {
    value = aws_launch_template.bastion-launch-template.id
}

output "nginx_launch_template" {
    value = aws_launch_template.nginx-launch-template.id
}

output "wordpress_launch_template" {
    value = aws_launch_template.wordpress-launch-template.id
}

output "tooling_launch_template" {
    value = aws_launch_template.tooling-launch-template.id
}