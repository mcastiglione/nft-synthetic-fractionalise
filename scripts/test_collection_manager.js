const { expect } = require('chai');
const { ethers, network } = require('hardhat');

const UniswapV2PairABI = require('../contracts/abis/UniswapV2PairABI.json');

const parseAmount = (amount) => ethers.utils.parseEther(amount);

async function asyncCall() {
    const nftAddress = '0xc015b280be8f0423bfd40f9b5a32a54490ff7085';
    const tokenId = '11';
    const collectionAddress = '0xA5737471B825435cb1ffDA15Ff8166b3a72A1949';

    var manager = await ethers.getContractAt('SyntheticCollectionManager', collectionAddress)

    var poolAddress = await manager.poolAddress();

    var uniswapPair = await ethers.getContractAt(UniswapV2PairABI, poolAddress);

    const reserves = await uniswapPair.getReserves();

    console.log(reserves, 'reserves');

    var token0 = await uniswapPair.token0();
    var token1 = await uniswapPair.token1();

    console.log(token0, 'token0');
    console.log(token1, 'token1');

    const routerAddress = await manager.syntheticProtocolRouterAddress();

    console.log('routerAddress', routerAddress);
    var tokens = ['0xC671d2E919cdCC1C17a80223e8BD6E9393A6Ca78', '0x2cA48b8c2d574b282FDAB69545646983A94a3286'];

    tokens.sort();

    console.log('tokens', tokens);




}


asyncCall();
