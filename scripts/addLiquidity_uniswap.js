const { expect } = require('chai');
const { ethers, network } = require('hardhat');

const parseAmount = (amount) => ethers.utils.parseEther(amount);

async function asyncCall() {


    const fundingToken = await ethers.getContractAt('FundingMock', '0x2cA48b8c2d574b282FDAB69545646983A94a3286');
    const jot = await ethers.getContractAt('Jot', '0xC671d2E919cdCC1C17a80223e8BD6E9393A6Ca78');

    /* address */
    [owner] = await ethers.getSigners();

    const timestampLimit = 1638648281; // the timestamp this transaction will expire

    uniswapRouterAdress = '0x4CeBfcDA07A08B1C7169E5eb77AC117FF87EEae9';
    uniswapRouter = await ethers.getContractAt('UniswapRouter', uniswapRouterAdress);
    
    await fundingToken.approve(uniswapRouterAdress, 1000000);

    await jot.approve(uniswapRouterAdress, parseAmount('1'));

    await uniswapRouter.addLiquidity(
      jot.address,
      fundingToken.address, 
      parseAmount('1'), 
      1000000, 
      1,
      1, 
      owner.address,
      timestampLimit
    );
}

asyncCall();
