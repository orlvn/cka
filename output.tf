output "instance_state" {
  value = "0: [${aws_instance.cka_cp[0].instance_state}] | 1: [${aws_instance.cka_worker[0].instance_state}] | 2: [${aws_instance.cka_worker[1].instance_state}]"
}
