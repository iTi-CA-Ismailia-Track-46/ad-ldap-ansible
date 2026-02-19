scp -r ./* kerolos@192.168.171.131:./servers_ad
ssh kerolos@192.168.171.131 "cd servers_ad && ansible-playbook playbook.yaml --vault-password-file pass_vault_file"
##--start-at-task='join ad'
