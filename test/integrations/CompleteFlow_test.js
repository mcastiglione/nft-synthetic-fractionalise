const { expect } = require('chai');
const { deployments, ethers, getNamedAccounts } = require('hardhat');
const { getEventArgs } = require('../unit/helpers/events');
const UniswapV2Router02ABI = require('../../contracts/abis/UniswapV2Router02ABI.json');

async function getEvent(parameters, event, contract) {
  await expect(parameters).to.emit(contract, event);
  const args = await getEventArgs(parameters, event, contract);
  return args;
};

const parseAmount = (amount) => ethers.utils.parseEther(amount);
const parseReverse = (amount) => ethers.utils.formatEther(amount);

describe("Full flow test", function() {
  it('Test', async () => {
    await deployments.fixture(["synthetic_router"]);
    console.log('1');
    const namedAccounts = await getNamedAccounts();
    const { deployer } = namedAccounts;

    const nftInitialID = 0;
    const collectionAddress = '0x32cee14ffcc796bbd99d26b013231cf758e2ade8';

    const router = await ethers.getContract('SyntheticProtocolRouter');
    const uniswapAddress = await router.swapAddress();

    /*************************************
    * register 6 NFTs of same collection *
    *************************************/
     console.log('2');
    const nftIDs = [];
    
    async function registerMultipleNFT() {
      for(let i = nftInitialID; nftIDs.length < 6; i++) {
        console.log('i',i);
        nftIDs.push(i);
        await router.registerNFT(
          collectionAddress, i, 10, 5, ['My Collection', 'MYC', '']
        )
      }
    }
    console.log('3');
    await registerMultipleNFT();

    async function verifyAllSyntheticNFT() {
      for(let i = 0; i < nftIDs.length - 1; i++) {
        console.log('i', i);
        await router.verifyNFT(collectionAddress, nftIDs[i]);
      }
    }
    console.log('4');
    await verifyAllSyntheticNFT();
    console.log('5');
    // initialize the proxy contract
    const managerAddress = await router.getCollectionManagerAddress(collectionAddress);
    const manager = await ethers.getContractAt('SyntheticCollectionManager', managerAddress);
    console.log('6');
    const jotAddress = await manager.jotAddress();
    const jot = await ethers.getContractAt('Jot', jotAddress);
    console.log('7');
    const fundingTokenAddress = await manager.fundingTokenAddress();
    const fundingToken = await ethers.getContractAt('Jot', fundingTokenAddress);
    console.log('8');
    await fundingToken.approve(managerAddress, parseAmount('8'));
    console.log('9');
    /*******************************************************************
     * buy JOTs from same collection from different fractionalisations *
     ******************************************************************/
     console.log('10');

    async function buyJotTokensAll() {
      for(let i = 0; i < nftIDs.length - 1; i++) {
        await manager.buyJotTokens(nftIDs[i], parseAmount('1'));
      }
    }
    await buyJotTokensAll();
    console.log('11');
    
    /**************************************************
     * do some trading on quickswap, generating fees  *
     *************************************************/

     async function addLiquidity() {
      for(let i = 0; i < nftIDs.length - 1; i++) {
        console.log('addLiquidity', i);
        await manager.AddLiquidityToFuturePool(nftIDs[i], parseAmount('0.1'));
        await manager.addLiquidityToQuickswap(nftIDs[i], parseAmount('0.1'));
        
      }
    }
    await addLiquidity();

    console.log('after addLiquidity');

    await fundingToken.approve(uniswapAddress, parseAmount('100'));

    const UniswapV2Router02 = await ethers.getContractAt(UniswapV2Router02ABI, uniswapAddress);

    await UniswapV2Router02.swapTokensForExactTokens(
      parseAmount('1'), // uint amountOut
      parseAmount('1'), // uint amountInMax
      [ fundingTokenAddress, jotAddress ], // address[] calldata path
      managerAddress, // address to
      0 , // uint deadlin
    );

    async function claimLiquidityTokens() {
      for(let i = 0; i < nftIDs.length - 1; i++) {
        let liquidityTokens = manager.getLiquidityTokens(nftIDs[i]);
        await manager.claimLiquidityTokens(nftIDs[i], liquidityTokens);
      }
    }

    await claimLiquidityTokens();

    const perpetualPoolAddress = await manager.perpetualPoolLiteAddress();

    const perpetualPool = await ethers.getContractAt('PerpetualPoolLite', perpetualPoolAddress);


    await fundingToken.approve(perpetualPoolAddress, parseAmount('10'));
    perpetualPool["trade(int256)"](parseAmount('1'));
    perpetualPool["trade(int256)"](parseAmount('1'));
    perpetualPool["trade(int256)"](parseAmount('1'));
    perpetualPool["trade(int256)"](parseAmount('1'));
    perpetualPool["trade(int256)"](parseAmount('1'));
    perpetualPool["trade(int256)"](parseAmount('1'));


  });


});
