#!/bin/bash

# Verifica se um parâmetro foi fornecido
if [ -z "$1" ]; then
  echo "Usage: $0 <new_batch_size>"
  exit 1
fi

# Define o novo tamanho do lote
NEW_BATCH_SIZE=$1

# Define variáveis globais
CHANNEL_NAME="mychannel"
ORDERER_CA="/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem"
CORE_PEER_LOCALMSPID="OrdererMSP"
CORE_PEER_TLS_ROOTCERT_FILE="/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt"
CORE_PEER_MSPCONFIGPATH="/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/users/Admin@example.com/msp"
CORE_PEER_ADDRESS="orderer.example.com:7050"

# Passo 1: Busque a configuração mais recente
echo "Fetching current channel configuration..."
docker exec -e CHANNEL_NAME=$CHANNEL_NAME cli sh -c "peer channel fetch config config_block.pb -o orderer.example.com:7050 -c \$CHANNEL_NAME --tls --cafile $ORDERER_CA"

# Passo 2: Converta a configuração para JSON
echo "Converting configuration to JSON..."
docker exec cli sh -c 'configtxlator proto_decode --input config_block.pb --type common.Block | jq .data.data[0].payload.data.config > config.json'

# Passo 3: Verifique o valor atual
MAXBATCHSIZEPATH=".channel_group.groups.Orderer.values.BatchSize.value.max_message_count"
echo "Current Batch Size:"
docker exec -e MAXBATCHSIZEPATH=$MAXBATCHSIZEPATH cli sh -c 'jq "$MAXBATCHSIZEPATH" config.json'

# Passo 4: Atualizando o valor
echo "Updating Batch Size to $NEW_BATCH_SIZE..."
docker exec -e MAXBATCHSIZEPATH=$MAXBATCHSIZEPATH cli sh -c "jq \"$MAXBATCHSIZEPATH = $NEW_BATCH_SIZE\" config.json > modified_config.json"

# Verificar o conteúdo modificado
docker exec -e MAXBATCHSIZEPATH=$MAXBATCHSIZEPATH cli sh -c 'jq "$MAXBATCHSIZEPATH" modified_config.json'

# Passo 5: Convertendo JSON em ProtoBuf
echo "Converting JSON to ProtoBuf..."
docker exec cli sh -c 'configtxlator proto_encode --input config.json --type common.Config --output config.pb'
docker exec cli sh -c 'configtxlator proto_encode --input modified_config.json --type common.Config --output modified_config.pb'

# Passo 6: Cálculo do Delta
echo "Calculating Delta..."
docker exec -e CHANNEL_NAME=$CHANNEL_NAME cli sh -c 'configtxlator compute_update --channel_id $CHANNEL_NAME --original config.pb --updated modified_config.pb --output final_update.pb'

# Passo 7: Adicionando a atualização ao envelope
echo "Adding update to envelope..."
docker exec cli sh -c 'configtxlator proto_decode --input final_update.pb --type common.ConfigUpdate | jq . > final_update.json'
docker exec cli sh -c 'echo "{\"payload\":{\"header\":{\"channel_header\":{\"channel_id\":\"mychannel\", \"type\":2}},\"data\":{\"config_update\":"$(cat final_update.json)"}}}" | jq . > header_in_envelope.json'
docker exec cli sh -c 'configtxlator proto_encode --input header_in_envelope.json --type common.Envelope --output final_update_in_envelope.pb'

# Passo 8: Configurar Variáveis de Ambiente
export CORE_PEER_LOCALMSPID="OrdererMSP"
export CORE_PEER_TLS_ROOTCERT_FILE="/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt"
export CORE_PEER_MSPCONFIGPATH="/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/users/Admin@example.com/msp"
export CORE_PEER_ADDRESS="orderer.example.com:7050"
export CHANNEL_NAME="mychannel"
export ORDERER_CA="/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem"

# Passo 9: Assinar a Atualização
echo "Signing the configuration update..."
docker exec cli sh -c 'peer channel signconfigtx -f final_update_in_envelope.pb'

# Passo 10: Aplicar a Atualização
echo "Applying the update to the channel..."
docker exec -e CORE_PEER_LOCALMSPID=$CORE_PEER_LOCALMSPID \
    -e CORE_PEER_TLS_ROOTCERT_FILE=$CORE_PEER_TLS_ROOTCERT_FILE \
    -e CORE_PEER_MSPCONFIGPATH=$CORE_PEER_MSPCONFIGPATH \
    -e CORE_PEER_ADDRESS=$CORE_PEER_ADDRESS \
    -e CHANNEL_NAME=$CHANNEL_NAME \
    -e ORDERER_CA=$ORDERER_CA \
    cli sh -c 'peer channel update -f final_update_in_envelope.pb -c $CHANNEL_NAME -o orderer.example.com:7050 --tls --cafile $ORDERER_CA'

# Passo 11: Verificação
echo "Fetching updated channel configuration..."
docker exec -e CHANNEL_NAME=$CHANNEL_NAME cli sh -c "peer channel fetch config config_block.pb -o orderer.example.com:7050 -c \$CHANNEL_NAME --tls --cafile $ORDERER_CA"
docker exec cli sh -c 'configtxlator proto_decode --input config_block.pb --type common.Block | jq .data.data[0].payload.data.config > config.json'
echo "Updated Batch Size:"
docker exec -e MAXBATCHSIZEPATH=$MAXBATCHSIZEPATH cli sh -c 'jq "$MAXBATCHSIZEPATH" config.json'

echo "Batch size modification completed successfully."
