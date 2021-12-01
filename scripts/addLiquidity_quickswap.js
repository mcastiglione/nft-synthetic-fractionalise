const { expect } = require('chai');
const { ethers, network } = require('hardhat');

const parseAmount = (amount) => ethers.utils.parseEther(amount);

async function asyncCall() {

    /* address */
    [owner] = await ethers.getSigners();

    const fundingTokenAdress = '0x2ca48b8c2d574b282fdab69545646983a94a3286';
    const jotAdress = '0x492012d2b3acc0acc987231b5d07593f6760a2c8';

    const fundingToken = await ethers.getContractAt('FundingMock', fundingTokenAdress);
    const jot = await ethers.getContractAt('Jot', jotAdress);

    const timestampLimit = 2638838254; // the timestamp this transaction will expire

    uniswapRouterAdress = '0x4CeBfcDA07A08B1C7169E5eb77AC117FF87EEae9';
    uniswapRouter = await ethers.getContractAt('UniSwapRouterMock', uniswapRouterAdress);
    
    await fundingToken.approve(uniswapRouterAdress, 1000000);

    await jot.approve(uniswapRouterAdress, parseAmount('1'));

    await uniswapRouter.addLiquidity(
      jotAdress,
      fundingTokenAdress, 
      parseAmount('1'), // take decimals into account
      1000000, // take decimals into account
      1,
      1, 
      owner.address,
      timestampLimit
    );
}

asyncCall();
