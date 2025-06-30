# s3-operator-configs
This Terraform template will create AWS service account, and other required configurations for the S3 Operator. You need following:

* AWS CLI tools installed and logged in
* OC CLI tools installed and logged in
* ROSA CLI tools installed and logged in
* ROSA Cluster ID (see instructions below)
* Red Hat API token (see instructions below)

Check your cluster ID:
```bash
[rosa@bastion s3-operator-configs]$ rosa list clusters
ID                                NAME        STATE  TOPOLOGY
2jntan7xx8jblso9xxrls2boxd31rass  rosa-xxxx  ready  Hosted CP
```

Check your token once you have logged in by using ROSA CLI (you can also fetch it from the Red Hat cloud console):
```bash
[rosa@bastion s3-operator-configs]$ cat ~/.config/ocm/ocm.json | grep refresh_token
  "refresh_token": "xxxxxxxxxxxxxxxxIgOiAiSldUIiwia2lkIiA6ICI0NzQzYTkzMC03YmJiLTRkZGQtOTgzMS00ODcxNGRlZDc0YjUifQ.eyJpYXQiOjE3NTEyODEzMjksImp0aSI6IjliMWNmNmFjLTdlOTktNDxxxxxxxxxxxxxxxxxxxxxxIsImlzcyI6Imh0dHBzOi8vc3NvLnJlZGhhdC5jb20vYXV0aC9yZWFsbXMvcmVkaGF0LWVxxxxxxxxxxxxiaHR0cHM6Ly9zc28ucmVkaGFxxxxxxxxxxxxxxxxxxxYWxtcy9yZWRoYXQtZXh0ZXJuYWwiLCJzdWIiOiJmOjUyOGQ3NmZmLWY3MDgtNDNlZC04Y2Q1LWZlMTZmNGZlMGNlNjpyaHBkcy1jbG91ZCIsInR5cCI6Ik9mZmxpbmUiLCJhenAiOiJjbG91ZC1zZXJ2aWNlcyIsIm5vbmNlIjoiOWQ1N2ViYzktOWI3My00NxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxWEtZDk2My00Y2UzLWIxZTMtZDQ0YWQ2YjNhNzgxIiwic2NvcGUiOiJvcGVuaWQgYXBpLmlhbS5zZXJ2aWNlX2FjY291bnRzIG9mZmxpbmVfYWNjZXNzIn0.go8r4L1b3GtoUKfm9PRz-v_doI5c_Y1bWg4tkTJJdsq6e1YYAuwrO3eigzMo1xxxxxxxxxxxxxxxxxxxxxxxxxxx",
```