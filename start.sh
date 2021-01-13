
#---------------------------------------------------------
#---------------------------------------------------------
# TUTORIAL: Criando uma rede blockchain Hyperledger Fabric 2.2
# https://hyperledger-fabric.readthedocs.io/
#---------------------------------------------------------
#---------------------------------------------------------


#---------------------------------------------------------
### Baixar arquivos
# curl -sSL https://bit.ly/2ysbOFE | bash -s


function sleeping () {
  echo "-----------------------------------------------------------"
  echo "Sleeping $1 seconds."
  sleep $1
  echo "-----------------------------------------------------------"
}


sh clean.sh


export PATH=${PWD}/../bin:$PATH
export FABRIC_CFG_PATH=$PWD/../config/


echo "===================================================="
### Pre requisitos: ./configtx.yaml & ./crypto-config.yaml
echo "---------- Configuração inicial da rede:"

echo "---------- Gerando artefatos..."
cryptogen generate --config=./crypto-config.yaml

echo "---------- Criando bloco gênesis..."
configtxgen -configPath ./ -profile OrgsOrdererGenesis -channelID byfn-sys-channel -outputBlock ./channel-artifacts/genesis.block

echo "---------- Criando canal chamado mychannel..." ### Resulta na criação de um artefato "channel.tx"
export CHANNEL_NAME=mychannel
configtxgen -configPath ./ -profile OrgsChannel -outputCreateChannelTx ./channel-artifacts/channel.tx -channelID $CHANNEL_NAME

echo "---------- Definindo os anchor peers das organizações..."
configtxgen -configPath ./ -profile OrgsChannel -outputAnchorPeersUpdate ./channel-artifacts/Org1MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org1MSP

echo "---------- Configuração finalizada."
echo "===================================================="
echo ""

echo "===================================================="
### Pre requisitos: ./docker-compose-cli.yaml & ./base/docker-compose-base.yaml & ./base/peer-base.yaml
echo "---------- Docker Compose:"
docker-compose -f docker-compose-cli.yaml up -d
#docker-compose -f docker/docker-compose.yaml up -d
echo "---------- Conteiners levantados."
echo "===================================================="
echo ""

echo "===================================================="
echo "---------- Abrindo novo terminal para monitorar os logs de peer0.org1.example.com..."
gnome-terminal -x bash -c "docker logs -f peer0.org1.example.com"
echo "---------- Criando canal 'mychannel'..."
docker exec \
  -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp \
  -e CORE_PEER_ADDRESS=peer0.org1.example.com:7051 \
  -e CORE_PEER_LOCALMSPID="Org1MSP" \
  -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
  cli \
  peer channel create \
    -o orderer.example.com:7050 \
    -c mychannel \
    -f ./channel-artifacts/channel.tx \
    --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

echo "---------- Join peer0.org1.example.com to the channel..."
docker exec \
  -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp \
  -e CORE_PEER_ADDRESS=peer0.org1.example.com:7051 \
  -e CORE_PEER_LOCALMSPID="Org1MSP" \
  -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
  cli \
  peer channel join \
    -b mychannel.block

echo "---------- Canal criado."
echo "===================================================="
echo ""


echo "===================================================="
echo "---------- Definindo os anchor peers..."
docker exec \
  -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp \
  -e CORE_PEER_ADDRESS=peer0.org1.example.com:7051 \
  -e CORE_PEER_LOCALMSPID="Org1MSP" \
  -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
  cli \
  peer channel update \
    -o orderer.example.com:7050 \
    -c mychannel \
    -f ./channel-artifacts/Org1MSPanchors.tx \
    --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem

echo "---------- Anchor peers definidos."
echo "===================================================="
echo ""


echo "===================================================="
### Pre requisito: ./chaincode/health.go
echo "---------- Compilando chaincode..."
cd chaincode/
go mod init chaincode
#go get github.com/hyperledger/fabric-chaincode-go/shim
#go get github.com/hyperledger/fabric-protos-go/peer
go get github.com/hyperledger/fabric-contract-api-go
go mod vendor # comando para instalar as dependencias nos peer
go build health.go
cd ..
echo "---------- Chaincode compilado."
echo "===================================================="
echo ""


echo "===================================================="
echo "---------- Instalando chaincode..."
echo "---------- Instalando chaincode no peer0.org1.example.com..."
docker exec \
  -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp \
  -e CORE_PEER_ADDRESS=peer0.org1.example.com:7051 \
  -e CORE_PEER_LOCALMSPID="Org1MSP" \
  -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
  cli \
  peer chaincode install \
    -n health \
    -v 1.0 \
    -p github.com/chaincode/
echo "---------- Chaincode instalado."
echo "===================================================="
echo ""


sleeping 2


echo "===================================================="
echo "---------- This will initialize the chaincode on the channel..."
docker exec \
  -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp \
  -e CORE_PEER_ADDRESS=peer0.org1.example.com:7051 \
  -e CORE_PEER_LOCALMSPID="Org1MSP" \
  -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
  cli \
  peer chaincode instantiate \
    -o orderer.example.com:7050 \
    --tls --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
    -C mychannel \
    -n health \
    -v 1.0 \
    -c '{"Args":["initLedger"]}' \
    -P "AND ('Org1MSP.peer')"
echo "---------- Chaincode initialized."
echo "===================================================="
echo ""


sleeping 3


echo "==========================================================="
echo "---------- [Invoke] peer0.org1.example.com chamando o método 'queryAllTransactions' do chaincode..."
docker exec \
  -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp \
  -e CORE_PEER_ADDRESS=peer0.org1.example.com:7051 \
  -e CORE_PEER_LOCALMSPID="Org1MSP" \
  -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
  cli \
  peer chaincode invoke \
    -o orderer.example.com:7050 \
    --tls true \
    --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
    -C mychannel \
    -n health \
    --peerAddresses peer0.org1.example.com:7051 \
    --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
    -c '{"Args":["queryAllTransactions"]}'
echo "---------- 'queryAllTransactions' executado."
echo "==========================================================="
echo ""


echo "==========================================================="
echo "---------- [Invoke] peer0.org1.example.com chamando o método 'createTransaction' do chaincode..."
docker exec \
  -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp \
  -e CORE_PEER_ADDRESS=peer0.org1.example.com:7051 \
  -e CORE_PEER_LOCALMSPID="Org1MSP" \
  -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
  cli \
  peer chaincode invoke \
    -o orderer.example.com:7050 \
    --tls true \
    --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
    -C mychannel \
    -n health \
    --peerAddresses peer0.org1.example.com:7051 \
    --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
    -c '{"Args":["createTransaction","Transaction5","tagDosDados","keyPubPacient123","keyPubDoctor321"]}'
echo "---------- 'createTransaction' executado."
echo "==========================================================="
echo ""


sleeping 2


echo "==========================================================="
echo "---------- [Invoke] peer0.org1.example.com chamando o método 'queryTransaction' do chaincode..."
docker exec \
  -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp \
  -e CORE_PEER_ADDRESS=peer0.org1.example.com:7051 \
  -e CORE_PEER_LOCALMSPID="Org1MSP" \
  -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
  cli \
  peer chaincode invoke \
    -o orderer.example.com:7050 \
    --tls true \
    --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
    -C mychannel \
    -n health \
    --peerAddresses peer0.org1.example.com:7051 \
    --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
    -c '{"Args":["queryTransaction","Transaction5"]}'
echo "---------- 'queryTransaction' executado."
echo "==========================================================="
echo ""


echo "==========================================================="
echo "---------- [Invoke] peer0.org1.example.com chamando o método 'queryAllTransactions' do chaincode..."
docker exec \
  -e CORE_PEER_MSPCONFIGPATH=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/users/Admin@org1.example.com/msp \
  -e CORE_PEER_ADDRESS=peer0.org1.example.com:7051 \
  -e CORE_PEER_LOCALMSPID="Org1MSP" \
  -e CORE_PEER_TLS_ROOTCERT_FILE=/opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
  cli \
  peer chaincode invoke \
    -o orderer.example.com:7050 \
    --tls true \
    --cafile /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/ordererOrganizations/example.com/orderers/orderer.example.com/msp/tlscacerts/tlsca.example.com-cert.pem \
    -C mychannel \
    -n health \
    --peerAddresses peer0.org1.example.com:7051 \
    --tlsRootCertFiles /opt/gopath/src/github.com/hyperledger/fabric/peer/crypto/peerOrganizations/org1.example.com/peers/peer0.org1.example.com/tls/ca.crt \
    -c '{"Args":["queryAllTransactions"]}'
echo "---------- 'queryAllTransactions' executado."
echo "==========================================================="
echo ""


