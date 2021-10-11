const { expect } = require('chai');
const { ethers, network } = require('hardhat');


async function asyncCall() {

    const managerAddress = '0x5c776F96D62ebedCD54912d624fADc230242311f';
    //const pToken = ethers.getContractAt('PTokenLite', pTokenAddress);

    const managerFactory = await ethers.getContractFactory('SyntheticCollectionManager');
    const manager = await managerFactory.attach(managerAddress);

    let response = await manager.exitProtocol.gasLimit(3);
    console.log(response);

}

asyncCall();