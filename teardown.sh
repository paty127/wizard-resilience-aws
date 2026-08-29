#!/bin/bash

echo "==================================================="
echo "⚠️  INICIANDO TEARDOWN DA INFRAESTRUTURA WIZARD ⚠️"
echo "==================================================="
echo "Limpando recursos para garantir custo zero..."

# Comando para destruir toda a infraestrutura provisionada
terraform destroy -auto-approve

echo "==================================================="
echo "✅ TEARDOWN CONCLUÍDO! Infraestrutura destruída."
echo "==================================================="
