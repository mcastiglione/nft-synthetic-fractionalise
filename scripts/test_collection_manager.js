const { expect } = require('chai');
const { ethers, network } = require('hardhat');

async function asyncCall() {
    const routerAddress = '0x2d7Dcb0d747b77579BBD41f36Acaf681136221F1';
    const nftAddress = '0x9782f3ff4e5294877d199fa0fdf1cc78b79bf91c';
    const tokenId = '38';

    const routerFactory = await ethers.getContractFactory('SyntheticProtocolRouter');
    const router = await routerFactory.attach(routerAddress);

    //const collectionAddress = await router.getCollectionManagerAddress(nftAddress);
    const collectionAddress = '0xf07b8F49b43329270811CF75A5dA7538fa456E29';

    const collectionManagerFactory = await ethers.getContractFactory('SyntheticCollectionManager');

    const manager = await collectionManagerFactory.attach(collectionAddress);
    //const verified = await manager.isVerified(tokenId);
    //console.log(verified);
    const originalID = await manager.getOriginalID('5');
    console.log(originalID.toString());
}

asyncCall();
