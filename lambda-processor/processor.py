import json
import os
import boto3

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["TABLE_NAME"])


def handler(event, context):
    for record in event.get("Records", []):
        item = json.loads(record["body"])
        try:
            table.put_item(Item=item)
        except Exception as exc:  # noqa: BLE001
            print(f"Erro ao gravar lead {item.get('lead_id')} no DynamoDB: {exc}")
            # Relança o erro: isso faz o SQS considerar a mensagem como
            # falha e tentar de novo. Depois de esgotar as tentativas
            # (redrive_policy.maxReceiveCount), a mensagem vai pra DLQ
            # automaticamente, sem perder o lead.
            raise
