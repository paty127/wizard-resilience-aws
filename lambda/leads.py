import json
import os
import re
import uuid
import time
import boto3

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["TABLE_NAME"])

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
    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return response(400, {"error": "JSON invalido no corpo da requisicao"})

    name = (body.get("name") or "").strip()
    email = (body.get("email") or "").strip()
    phone = (body.get("phone") or "").strip()
    campaign = (body.get("campaign") or "site-institucional").strip()

    errors = []
    if not name or len(name) < 2:
        errors.append("nome invalido")
    if not email or not EMAIL_REGEX.match(email):
        errors.append("email invalido")
    if not phone or len(phone) < 8:
        errors.append("telefone invalido")

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

    try:
        table.put_item(Item=item)
    except Exception as exc:
        print(f"Erro ao gravar no DynamoDB: {exc}")
        return response(500, {"error": "erro interno ao salvar o lead"})

    return response(201, {"message": "lead recebido com sucesso", "lead_id": lead_id})
