#!/bin/bash -e
# hardhat node --fork https://rinkeby.infura.io/v3/75cc8cba22ab40b9bfa7406ae9b69a27
clear
echo "============================================"
echo "Starting fork Node"
echo "============================================"
echo ""

INFURA_API_KEY=`cat .env | grep INFURA_API_KEY | cut -d '=' -f 2`
if [ -z $INFURA_API_KEY ]; then
  echo "The variable INFURA_API_KEY in your .env file does not exist or is empty"
  echo ""
  exit
fi

echo ""
echo "What network would you like to connect to?"
echo "- - - - - - - - - - - - - - - - - - - - - - "
echo "1: mumbai"
echo "2: ropsten"
echo "3: rinkeby"
echo "- - - - - - - - - - - - - - - - - - - - - - "
echo "Select the number of the network to which you want to connect:"
read -e NETWORK_NUMBER

NODO_URL=""

if [ $NETWORK_NUMBER == 1 ]; then
  NODE_URL="https://polygon-mumbai.infura.io/v3/$INFURA_API_KEY"
elif [ $NETWORK_NUMBER == 2 ]; then
  NODE_URL="https://ropsten.infura.io/v3/$INFURA_API_KEY"
elif [ $NETWORK_NUMBER == 3 ]; then
  NODE_URL="https://rinkeby.infura.io/v3/$INFURA_API_KEY"
else
  echo "The execution could not be finished, you have chosen an invalid option"
  echo ""
  exit
fi

npx hardhat node --fork $NODE_URL

