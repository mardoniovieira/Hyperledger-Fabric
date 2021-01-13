
echo "===================================================="
echo "---------- Limpando ambiente de execuções anteriores..."
docker stop $(docker ps -aq)
docker rm $(docker ps -aq)
docker network prune -f
docker volume prune -f
sudo systemctl restart docker.service
docker rmi -f $(docker images | grep dev-peer)
rm -rf channel-artifacts/ crypto-config/ chaincode/vendor/
rm chaincode/go.mod chaincode/go.sum chaincode/health
echo "---------- Ambiente limpo."
echo "===================================================="
echo ""
