import json
import os
import re
import time
import uuid

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
    # O API Gateway HTTP API usa o formato de payload v2.
    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return response(400, {"error": "JSON invalido no corpo da requisicao"})

    name = (body.get("name") or "").strip()
    email = (body.get("email") or "").strip()
    phone = (body.get("phone") or "").strip()
    unit = (body.get("unit") or "").strip()
    campaign = (body.get("campaign") or "site-institucional").strip()

    # Nome, e-mail e telefone são obrigatórios.
    # Unidade/cidade é opcional, mas deve ter ao menos 2 caracteres se enviada.
    errors = []

    if not name or len(name) < 2:
        errors.append("nome invalido")

    if not email or not EMAIL_REGEX.match(email):
        errors.append("email invalido")

    if not phone or len(phone) < 8:
        errors.append("telefone invalido")

    if unit and len(unit) < 2:
        errors.append("unidade/cidade invalida")

    if errors:
        return response(400, {"error": "validacao falhou", "details": errors})

    lead_id = str(uuid.uuid4())

    item = {
        "lead_id": lead_id,
        "name": name,
        "email": email,
        "phone": phone,
        "campaign": campaign,
        "created_at": int(time.time()),
    }

    # Só inclui unidade/cidade na mensagem quando o campo foi preenchido.
    if unit:
        item["unit"] = unit

    # A Lambda de intake publica o lead na fila. A processadora grava
    # no DynamoDB e envia a notificação interna para a equipe.
    try:
        sqs.send_message(
            QueueUrl=QUEUE_URL,
            MessageBody=json.dumps(item, ensure_ascii=False),
        )
    except Exception as exc:  # noqa: BLE001
        print(f"Erro ao enviar para a fila SQS: {exc}")
        return response(500, {"error": "erro interno ao processar o lead"})

    return response(
        201,
        {
            "message": "lead recebido com sucesso",
            "lead_id": lead_id,
        },
    )
