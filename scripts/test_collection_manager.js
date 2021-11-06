const { expect } = require('chai');
const { ethers, network } = require('hardhat');

const UniswapV2PairABI = require('../contracts/abis/UniswapV2PairABI.json');

const parseAmount = (amount) => ethers.utils.parseEther(amount);

async function asyncCall() {
    const nftAddress = '0xc015b280be8f0423bfd40f9b5a32a54490ff7085';
    const tokenId = '11';
    const collectionAddress = '0xA5737471B825435cb1ffDA15Ff8166b3a72A1949';
      
    const TX = await router.registerNFT(NFT, nftID, parseAmount('10000'), parseAmount('1'), [
    'My Collection',
    'MYC',
    '',
    ]);
    
    await expect(TX).to.emit(router, 'TokenRegistered');
    const ARGS = await getEventArgs(TX, 'TokenRegistered', router);
    tokenID = ARGS.syntheticTokenId;
    
    // verify NFT
    await router.verifyNFT(NFT, tokenID);
    
    await manager.withdrawJotTokens(tokenID, parseAmount('3000'));

    const requiredAmount = await manager.buybackRequiredAmount(tokenID);

    // Mint and approve funding to buy 500 jots
    // Now mint and approve 1000 jots 5000 funding tokens
    await fundingToken.mint(owner.address, requiredAmount.buybackAmount);
    await fundingToken.approve(managerAddress, requiredAmount.buybackAmount);
    
    // Now exit protocol
    await manager.buyback(tokenID);


}


asyncCall();
