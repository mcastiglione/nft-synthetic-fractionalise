const { expect } = require('chai');
const { ethers, network } = require('hardhat');

const parseAmount = (amount) => ethers.utils.parseEther(amount);

async function asyncCall() {
    const ownerAddress = '';
    const collectionAddress = '';

    const manager = await ethers.getContractAt('SyntheticCollectionManager', collectionAddress)

    const perpetualPoolLiteAddress = manager.perpetualPoolLiteAddress();

    const perpetualPool = await ethers.getContractAt('PerpetualPoolLite', perpetualPoolLiteAddress);

    const addresses  = await perpetualPool.getAddresses();

    const lTokenAddress = addresses[1];

    const lToken = await ethers.getContractAt('ERC20', lTokenAddress);

    const lShares = await lToken.balanceOf(ownerAddress);

    const totalLShares = await lToken.totalSupply();
}

asyncCall();
