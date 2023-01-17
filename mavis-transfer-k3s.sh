#!/bin/bash
#判斷ssl 憑證正否存在
if [ -f "./tls.crt" ]; then


#1取得變數
for i in $(cat /opt/mavis/config/.env |grep "MASTER_KEYS\|SECRET_KEY\|GATEWAY_CLIENT_ID\|GATEWAY_CLIENT_SECRET\|POSTGRES_PASSWORD\|DOMAIN=");do export $i ;done

#2.備份原有的 Mavis 並關閉 Mavis

/bin/cp -r  /etc/systemd/system/mavis.service /etc/systemd/system/mavis.service.bk
/bin/cp -r  /opt/mavis /opt/mavis.bk 
/usr/bin/docker exec -i mavis-postgres bash -c "pg_dump -U psql mavis > /tmp/postgresql.dump"
/usr/bin/docker cp mavis-postgres:/tmp/postgresql.dump /tmp/

    #檢查是否有備份
   if [ -f "/etc/systemd/system/mavis.service.bk" ] &&  [ -d "/opt/mavis.bk" ] &&  [ -f "/tmp/postgresql.dump" ]; then

#22關閉 Mavis
systemctl stop mavis
sleep 10
#3.安裝新版本 Mavis
curl -sSL https://pentium-repo.s3.ap-northeast-1.amazonaws.com/release.mavis/version/1.2.0/install.sh | CHECK_ENV=False MASTER_KEYS=${MASTER_KEYS} SECRET_KEY=${SECRET_KEY} GATEWAY_CLIENT_ID=${GATEWAY_CLIENT_ID} GATEWAY_CLIENT_SECRET=${GATEWAY_CLIENT_SECRET} POSTGRES_PWD=${POSTGRES_PASSWORD} MAVIS_URL=${DOMAIN} bash

#4.刪除 Mavis 服務來停止對 database的存取
kubectl delete deploy -n pentium beat flower apiserver task-runner f2e ssh-proxy rdp-proxy
sleep 60
#5.database 還原
/usr/local/bin/kubectl  cp /tmp/postgresql.dump postgresql-0:/tmp/ -n pentium
sleep 15
/usr/local/bin/kubectl  exec -ti postgresql-0 -n pentium -- bash -c "PGPASSWORD=${POSTGRES_PASSWORD} psql -U psql postgres -c 'drop database mavis'"
sleep 15

/usr/local/bin/kubectl  exec -ti postgresql-0 -n pentium -- bash -c "PGPASSWORD=${POSTGRES_PASSWORD} psql -U psql postgres -c 'create database mavis'"

sleep 15

/usr/local/bin/kubectl exec -ti postgresql-0 -n pentium -- bash -c "PGPASSWORD=${POSTGRES_PASSWORD} psql -U psql mavis < /tmp/postgresql.dump "
sleep 15

#6.復原 Mavis 服務
/usr/local/bin/mavis-tool.sh upgrade-enviroment

#7 安裝完成
echo ###################################
echo   "deployment complete"

#check mavis service pod
sleep 10
/usr/local/bin/kubectl get pod -A




# 第二步驟備份失敗  
       else 
       echo "backup error"
       fi
else
    # 憑證不存在當前執行腳本目錄下
 echo "SSL Credentials do not exist in the current execution script directory"
fi
