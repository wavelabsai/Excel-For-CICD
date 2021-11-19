all:
  hosts:
    %{ for ip in agw0_ip ~} ${ip} %{ endfor ~}

  vars:
    eth0: %{ for ip in agw0_ip ~} "${ip}" %{ endfor ~}

    eth1: %{ for ip in agw1_ip ~} "${ip}" %{ endfor ~}