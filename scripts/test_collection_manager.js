const { expect } = require('chai');
const { ethers, network } = require('hardhat');

async function asyncCall() {
    ;
    const nftAddress = '0xc015b280be8f0423bfd40f9b5a32a54490ff7085';
    const tokenId = '11';
    const collectionAddress = '0x24517EEAc57FF3D7C2a1827904a6cA405d30d06a';

    const manager = await ethers.getContractAt('SyntheticCollectionManager', collectionAddress)

    const routerAddress = await manager.syntheticProtocolRouterAddress();
    const router = await ethers.getContractAt('SyntheticProtocolRouter', routerAddress);

    console.log(await router.isSyntheticNFTCreated(nftAddress, tokenId));
    //const verified = await manager.isVerified(tokenId);
    //console.log(verified);
    //const originalID = await manager.getOriginalID('5');
    //await manager.buyback(tokenId);
    
    //console.log(originalID.toString());
}

asyncCall();
