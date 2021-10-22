const { expect } = require('chai');
const { ethers, network } = require('hardhat');

async function asyncCall() {
  const pTokenAddress = '0x443bD195eC8Bb6960A1531bBa4836847364D94f5';
  //const pToken = ethers.getContractAt('PTokenLite', pTokenAddress);

  const pTokenFactory = await ethers.getContractFactory('PTokenLite');
  const contract = await pTokenFactory.attach(pTokenAddress);

  const FuturesProtocolParametersFactory = await ethers.getContractFactory('FuturesProtocolParameters');
  const FuturesProtocolParameters = await FuturesProtocolParametersFactory.attach(
    '0xa16F889Cc5a61D163b9a91Bf9857227B8c49825a'
  );

  let symbol = await FuturesProtocolParameters.symbol();

  console.log(symbol);
}

asyncCall();
