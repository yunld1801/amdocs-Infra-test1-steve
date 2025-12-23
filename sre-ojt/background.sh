#!/bin/bash

# 1. 쿠버네티스 노드가 준비될 때까지 대기
launch.sh

# 2. 문제 상황 정의 (YAML 파일 생성)
cat <<EOF > /root/broken-sre.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sre-test-01-oom
  labels:
    app: stress-test
spec:
  replicas: 1
  selector:
    matchLabels:
      app: stress-test
  template:
    metadata:
      labels:
        app: stress-test
    spec:
      containers:
      - name: stress-container
        image: polinux/stress
        command: ["stress"]
        args: ["--vm", "1", "--vm-bytes", "250M", "--vm-hang", "1"]
        resources:
          limits:
            memory: "100Mi"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sre-test-02-probe
  labels:
    app: nginx-broken-probe
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-broken-probe
  template:
    metadata:
      labels:
        app: nginx-broken-probe
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
        livenessProbe:
          httpGet:
            path: /
            port: 8080 
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: sre-test-03-svc
spec:
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: web-app
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sre-test-03-app
  labels:
    app: web-server
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web-server
  template:
    metadata:
      labels:
        app: web-server
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
EOF

# 3. 고장난 파드 배포
kubectl apply -f /root/broken-sre.yaml

# 4. 로그 남기기
echo "Problems deployed at $(date)" >> /root/setup_log.txt
