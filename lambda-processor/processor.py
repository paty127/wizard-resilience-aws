import json
import os
import boto3

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["TABLE_NAME"])

# O SES é utilizado na região primária, onde o e-mail da equipe foi verificado.
ses = boto3.client("ses", region_name=os.environ.get("SES_REGION", "us-east-1"))
SENDER_EMAIL = os.environ.get("SES_SENDER_EMAIL")
TEAM_EMAIL = os.environ.get("TEAM_NOTIFICATION_EMAIL")


def send_team_notification(item):
    # Envia somente a notificação interna para a equipe.
    # Remetente e destinatário são o mesmo endereço verificado,
    # portanto funciona mesmo enquanto o SES estiver em sandbox.
    try:
        ses.send_email(
            Source=SENDER_EMAIL,
            Destination={"ToAddresses": [TEAM_EMAIL]},
            Message={
                "Subject": {"Data": f"Novo lead recebido: {item['name']}"},
                "Body": {
                    "Text": {
                        "Data": (
                            f"Novo lead capturado.\n\n"
                            f"Nome: {item['name']}\n"
                            f"E-mail: {item['email']}\n"
                            f"Telefone: {item['phone']}\n"
                            f"Unidade/cidade: {item.get('unit', '-')}\n"
                            f"Campanha: {item['campaign']}\n"
                            f"Lead ID: {item['lead_id']}"
                        )
                    }
                },
            },
        )
    except Exception as exc:  # noqa: BLE001
        print(f"Aviso: nao foi possivel enviar notificacao interna: {exc}")


def handler(event, context):
    for record in event.get("Records", []):
        item = json.loads(record["body"])

        try:
            table.put_item(Item=item)
        except Exception as exc:  # noqa: BLE001
            print(f"Erro ao gravar lead {item.get('lead_id')} no DynamoDB: {exc}")
            # Relança para que o SQS tente novamente e, após o limite,
            # encaminhe a mensagem para a DLQ.
            raise

        # A equipe só é notificada depois que o lead foi gravado.
        # Uma falha no e-mail não causa reprocessamento nem perda do lead.
        send_team_notification(item)