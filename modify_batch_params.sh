#!/bin/bash

# Verifica se os parâmetros foram fornecidos
if [ $# -ne 2 ]; then
  echo "Usage: $0 <new_max_message_count> <new_batch_timeout>"
  exit 1
fi

# Define os novos valores
NEW_MAX_MESSAGE_COUNT=$1
NEW_BATCH_TIMEOUT=$2

# Define variáveis globais
CHANNEL_NAME="mychannel"
ORDERER_CA="/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/tlsca/tlsca.example.com-cert.pem"
CORE_PEER_LOCALMSPID="OrdererMSP"
CORE_PEER_TLS_ROOTCERT_FILE="/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt"
CORE_PEER_MSPCONFIGPATH="/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/users/Admin@example.com/msp"
CORE_PEER_ADDRESS="orderer.example.com:7050"

# Função para verificar valores atuais
function check_current_values {
  echo "Fetching current channel configuration..."
  docker exec -e CHANNEL_NAME=$CHANNEL_NAME cli sh -c "peer channel fetch config config_block.pb -o orderer.example.com:7050 -c \$CHANNEL_NAME --tls --cafile $ORDERER_CA"

  echo "Converting configuration to JSON..."
  docker exec cli sh -c 'configtxlator proto_decode --input config_block.pb --type common.Block | jq .data.data[0].payload.data.config > config.json'

  echo "Current Max Message Count:"
  docker exec -e MAXBATCHSIZEPATH=".channel_group.groups.Orderer.values.BatchSize.value.max_message_count" cli sh -c 'jq "$MAXBATCHSIZEPATH" config.json'

  echo "Current Batch Timeout:"
  docker exec -e BATCHTIMEOUTPATH=".channel_group.groups.Orderer.values.BatchTimeout.value" cli sh -c 'jq "$BATCHTIMEOUTPATH" config.json'
}

# Função para aplicar as modificações
function apply_modifications {
  echo "Updating Max Message Count to $NEW_MAX_MESSAGE_COUNT..."
  docker exec cli sh -c "jq '.channel_group.groups.Orderer.values.BatchSize.value.max_message_count = $NEW_MAX_MESSAGE_COUNT' config.json > modified_config.json"

  echo "Updating Batch Timeout to $NEW_BATCH_TIMEOUT..."
  docker exec cli sh -c "jq '.channel_group.groups.Orderer.values.BatchTimeout.value.timeout = \"$NEW_BATCH_TIMEOUT\"' modified_config.json > final_modified_config.json"

  echo "Converting JSON to ProtoBuf..."
  docker exec cli sh -c 'configtxlator proto_encode --input config.json --type common.Config --output config.pb'
  docker exec cli sh -c 'configtxlator proto_encode --input final_modified_config.json --type common.Config --output modified_config.pb'

  echo "Calculating Delta..."
  docker exec -e CHANNEL_NAME=$CHANNEL_NAME cli sh -c 'configtxlator compute_update --channel_id $CHANNEL_NAME --original config.pb --updated modified_config.pb --output final_update.pb'

  echo "Adding update to envelope..."
  docker exec cli sh -c 'configtxlator proto_decode --input final_update.pb --type common.ConfigUpdate | jq . > final_update.json'
  docker exec cli sh -c 'echo "{\"payload\":{\"header\":{\"channel_header\":{\"channel_id\":\"mychannel\", \"type\":2}},\"data\":{\"config_update\":"$(cat final_update.json)"}}}" | jq . > header_in_envelope.json'
  docker exec cli sh -c 'configtxlator proto_encode --input header_in_envelope.json --type common.Envelope --output final_update_in_envelope.pb'
}

# Função para aplicar a atualização
function update_channel {
  echo "Signing the configuration update..."
  docker exec cli sh -c 'peer channel signconfigtx -f final_update_in_envelope.pb'

  echo "Applying the update to the channel..."
  docker exec -e CORE_PEER_LOCALMSPID=$CORE_PEER_LOCALMSPID \
      -e CORE_PEER_TLS_ROOTCERT_FILE=$CORE_PEER_TLS_ROOTCERT_FILE \
      -e CORE_PEER_MSPCONFIGPATH=$CORE_PEER_MSPCONFIGPATH \
      -e CORE_PEER_ADDRESS=$CORE_PEER_ADDRESS \
      -e CHANNEL_NAME=$CHANNEL_NAME \
      -e ORDERER_CA=$ORDERER_CA \
      cli sh -c 'peer channel update -f final_update_in_envelope.pb -c $CHANNEL_NAME -o orderer.example.com:7050 --tls --cafile $ORDERER_CA'
}

# Função para verificar valores atualizados
function check_updated_values {
  echo "Fetching updated channel configuration..."
  docker exec -e CHANNEL_NAME=$CHANNEL_NAME cli sh -c "peer channel fetch config config_block.pb -o orderer.example.com:7050 -c \$CHANNEL_NAME --tls --cafile $ORDERER_CA"
  docker exec cli sh -c 'configtxlator proto_decode --input config_block.pb --type common.Block | jq .data.data[0].payload.data.config > config.json'

  echo "Updated Max Message Count:"
  docker exec -e MAXBATCHSIZEPATH=".channel_group.groups.Orderer.values.BatchSize.value.max_message_count" cli sh -c 'jq "$MAXBATCHSIZEPATH" config.json'

  echo "Updated Batch Timeout:"
  docker exec -e BATCHTIMEOUTPATH=".channel_group.groups.Orderer.values.BatchTimeout.value" cli sh -c 'jq "$BATCHTIMEOUTPATH" config.json'
}

# Verificar valores atuais
check_current_values

# Aplicar modificações
apply_modifications

# Aplicar a atualização ao canal
update_channel

# Verificar valores atualizados
check_updated_values

echo "Batch size and batch timeout modification completed successfully."
