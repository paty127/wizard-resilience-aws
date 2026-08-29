#!/bin/bash
set -e

BUCKET="$1"
SITE_URL="$2"
BACKUP_FILE="bucket-policy-backup.json"

if [ -z "$BUCKET" ] || [ -z "$SITE_URL" ]; then
  echo "Uso: ./game-day-demo.sh <nome-do-bucket-primario> <url-do-cloudfront>"
  exit 1
fi

echo "==================================================="
echo "1) Salvando a policy atual do bucket (backup)..."
echo "==================================================="
aws s3api get-bucket-policy --bucket "$BUCKET" --query Policy --output text > "$BACKUP_FILE"
echo "Backup salvo em $BACKUP_FILE"

echo ""
echo "==================================================="
echo "2) Testando o site ANTES da falha (deve responder 200)"
echo "==================================================="
curl -s -o /dev/null -w "Status: %{http_code}\n" "$SITE_URL"

echo ""
echo "==================================================="
echo "3) Simulando falha: negando acesso ao bucket primario"
echo "==================================================="
cat > deny-policy.json << JSONEOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "GameDayDenyAll",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::${BUCKET}/*"
    }
  ]
}
JSONEOF
aws s3api put-bucket-policy --bucket "$BUCKET" --policy file://deny-policy.json
echo "Policy de bloqueio aplicada. O bucket primario agora nega acesso."

echo ""
echo "==================================================="
echo "4) Testando o site DURANTE a falha (aguardando propagar)..."
echo "==================================================="
echo "Aguardando 15s para o CloudFront detectar e fazer o failover..."
sleep 15
curl -s -o /dev/null -w "Status: %{http_code}\n" "$SITE_URL"
echo ""
echo ">>> Se aparecer 200 aqui, o failover funcionou! O site continua no ar"
echo ">>> mesmo com o bucket primario bloqueado."

echo ""
read -p "Pressione ENTER para restaurar o bucket primario e encerrar a simulacao..."

echo ""
echo "==================================================="
echo "5) Restaurando a policy original do bucket"
echo "==================================================="
aws s3api put-bucket-policy --bucket "$BUCKET" --policy "file://$BACKUP_FILE"
rm -f deny-policy.json
echo "Policy original restaurada. Bucket primario normalizado."
echo ""
echo "==================================================="
echo "Game Day concluido!"
echo "==================================================="
