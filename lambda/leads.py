import json
import os
import re
import uuid
import time
import boto3

sqs = boto3.client("sqs")
QUEUE_URL = os.environ["QUEUE_URL"]

EMAIL_REGEX = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")

CORS_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
}


def response(status_code, body_dict):
    return {
        "statusCode": status_code,
        "headers": {**CORS_HEADERS, "Content-Type": "application/json"},
        "body": json.dumps(body_dict, ensure_ascii=False),
    }


def handler(event, context):
    # API Gateway HTTP API (payload v2) manda o corpo em event["body"]
    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return response(400, {"error": "JSON invalido no corpo da requisicao"})

    name = (body.get("name") or "").strip()
    email = (body.get("email") or "").strip()
    phone = (body.get("phone") or "").strip()
    campaign = (body.get("campaign") or "site-institucional").strip()

        name = (body.get("name") or "").strip()
    email = (body.get("email") or "").strip()
    phone = (body.get("phone") or "").strip()
    unit = (body.get("unit") or "").strip()
    campaign = (body.get("campaign") or "site-institucional").strip()

    # --- Validação de payload ---
    errors = []
    if not name or len(name) < 2:
        errors.append("nome invalido")
    if not email or not EMAIL_REGEX.match(email):
        errors.append("email invalido")
    if not phone or len(phone) < 8:
        errors.append("telefone invalido")
    if not unit or len(unit) < 2:
        errors.append("unidade/cidade invalida")

    if errors:
        return response(400, {"error": "validacao falhou", "details": errors})

    lead_id = str(uuid.uuid4())
    item = {
        "lead_id": lead_id,
        "name": name,
        "email": email,
        "phone": phone,
        "unit": unit,
        "campaign": campaign,
        "created_at": int(time.time()),
    }
    # Não grava direto no DynamoDB: manda pra fila SQS. Um processador
    # separado (lambda-processor) consome a fila e grava no banco. Isso
    # desacopla a recepção do lead da gravação, e se o processamento falhar
    # repetidamente a mensagem cai automaticamente na Dead Letter Queue
    # (DLQ) pra investigação, sem perder o lead.
    try:
        sqs.send_message(QueueUrl=QUEUE_URL, MessageBody=json.dumps(item, ensure_ascii=False))
    except Exception as exc:  # noqa: BLE001 - queremos responder 500 controlado
        print(f"Erro ao enviar para a fila SQS: {exc}")
        return response(500, {"error": "erro interno ao processar o lead"})

    return response(201, {"message": "lead recebido com sucesso", "lead_id": lead_id})
