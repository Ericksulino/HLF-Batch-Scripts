# HLF-Batch-Scripts

Scripts para modificação dinâmica de parâmetros de **batching** em canais do **Hyperledger Fabric**, com foco em ajustes relacionados ao serviço de ordenação (*ordering service*).

Este repositório reúne scripts em **Shell** que automatizam o processo de leitura, modificação, assinatura e atualização da configuração de um canal Fabric, permitindo alterar parâmetros importantes de desempenho, como:

- `BatchSize.value.max_message_count`
- `BatchTimeout.value.timeout`

## Objetivo

O propósito deste repositório é facilitar experimentos e ajustes operacionais em redes Hyperledger Fabric, evitando a execução manual de todas as etapas de atualização de configuração do canal.

Os scripts implementam o fluxo clássico de atualização de configuração do Fabric:

1. Busca do bloco de configuração atual do canal
2. Decodificação do bloco para JSON com `configtxlator`
3. Alteração dos parâmetros desejados com `jq`
4. Geração do `ConfigUpdate`
5. Encapsulamento da atualização em um `Envelope`
6. Assinatura da transação de atualização
7. Aplicação da nova configuração no canal
8. Verificação final dos valores atualizados

## Estrutura do Repositório

```bash
.
├── modify_batch_size.sh
├── modify_bacth_time_out.sh
└── modify_batch_params.sh
```

### Scripts disponíveis

#### `modify_batch_size.sh`
Altera apenas o parâmetro **Batch Size**, isto é, o valor de:

```bash
.channel_group.groups.Orderer.values.BatchSize.value.max_message_count
```

**Uso:**
```bash
./modify_batch_size.sh <novo_batch_size>
```

**Exemplo:**
```bash
./modify_batch_size.sh 50
```

---

#### `modify_bacth_time_out.sh`
Altera apenas o parâmetro **Batch Timeout**, isto é, o valor de:

```bash
.channel_group.groups.Orderer.values.BatchTimeout.value.timeout
```

**Uso:**
```bash
./modify_bacth_time_out.sh <novo_timeout>
```

**Exemplo:**
```bash
./modify_bacth_time_out.sh 2s
```

> Observação: o nome do arquivo está como `modify_bacth_time_out.sh`, com `bacth` em vez de `batch`.

---

#### `modify_batch_params.sh`
Altera simultaneamente:

- `BatchSize.value.max_message_count`
- `BatchTimeout.value.timeout`

**Uso:**
```bash
./modify_batch_params.sh <novo_batch_size> <novo_batch_timeout>
```

**Exemplo:**
```bash
./modify_batch_params.sh 50 2
```

Neste script, o timeout é montado internamente com sufixo `s`, resultando em algo como `2s`.

## Pré-requisitos

Antes de executar os scripts, é necessário que o ambiente possua:

- **Hyperledger Fabric** configurado e em funcionamento
- Container `cli` disponível e acessível via `docker exec`
- Ferramentas instaladas no container:
  - `peer`
  - `configtxlator`
  - `jq`
- Permissões administrativas para atualizar a configuração do canal
- Acesso aos certificados e MSPs necessários

## Configurações assumidas nos scripts

Os scripts foram escritos considerando um ambiente com valores fixos, como:

- Canal: `mychannel`
- Orderer: `orderer.example.com:7050`
- Container CLI: `cli`
- MSP do orderer admin: `OrdererMSP`

Além disso, os caminhos de certificados e MSP estão definidos diretamente no código, por exemplo:

```bash
CHANNEL_NAME="mychannel"
CORE_PEER_LOCALMSPID="OrdererMSP"
CORE_PEER_ADDRESS="orderer.example.com:7050"
```

Isso significa que, para outros ambientes, pode ser necessário adaptar:

- nome do canal
- nome do container CLI
- endereço do orderer
- caminhos de certificados TLS
- caminho do MSP administrativo

## Fluxo de funcionamento

De forma resumida, os scripts executam as seguintes etapas:

### 1. Buscar configuração atual do canal
É realizado o fetch do bloco de configuração com:

```bash
peer channel fetch config
```

### 2. Converter para JSON
O bloco é decodificado com `configtxlator` e processado com `jq`.

### 3. Alterar os parâmetros desejados
Os campos de configuração são atualizados diretamente no JSON.

### 4. Gerar o delta da configuração
O JSON original e o modificado são convertidos novamente para Protobuf, e o delta é calculado com:

```bash
configtxlator compute_update
```

### 5. Encapsular em envelope
O `ConfigUpdate` é inserido em um `Envelope` compatível com o Fabric.

### 6. Assinar a atualização
A transação é assinada com:

```bash
peer channel signconfigtx
```

### 7. Aplicar no canal
A atualização é enviada com:

```bash
peer channel update
```

### 8. Verificar os valores finais
Após a atualização, a configuração é buscada novamente para validar os novos valores.

## Exemplo de uso

### Alterar apenas o batch size
```bash
chmod +x modify_batch_size.sh
./modify_batch_size.sh 100
```

### Alterar apenas o batch timeout
```bash
chmod +x modify_bacth_time_out.sh
./modify_bacth_time_out.sh 3s
```

### Alterar ambos os parâmetros
```bash
chmod +x modify_batch_params.sh
./modify_batch_params.sh 100 3
```

## Casos de uso

Este repositório pode ser útil em cenários como:

- experimentos de desempenho em Hyperledger Fabric
- ajuste de throughput e latência
- avaliação do impacto de políticas de batching
- automação de testes com diferentes configurações do orderer
- pesquisa acadêmica sobre redes blockchain permissionadas

## Limitações atuais

Alguns pontos importantes sobre a implementação atual:

- os caminhos e variáveis estão **hardcoded**
- os scripts assumem um ambiente padrão baseado em `example.com`
- não há tratamento robusto de erros
- não há validação avançada dos argumentos recebidos
- o nome de um dos arquivos contém um erro de grafia (`bacth`)

## Melhorias futuras

Algumas evoluções possíveis para o projeto:

- parametrizar canal, orderer, MSP e caminhos de certificados
- adicionar tratamento de erros e logs mais detalhados
- validar formatos de entrada
- suportar múltiplos canais
- corrigir o nome do arquivo `modify_bacth_time_out.sh`
- adicionar integração com experimentos automatizados

## Contribuição

Contribuições são bem-vindas para melhorar a robustez, portabilidade e reutilização dos scripts.
