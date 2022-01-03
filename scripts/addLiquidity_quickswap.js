const { expect } = require('chai');
const { ethers, network } = require('hardhat');

const parseAmount = (amount) => ethers.utils.parseEther(amount);

async function asyncCall() {

    /* address */
    [owner] = await ethers.getSigners();

    console.log(owner.address, 'owner');

    const fundingTokenAdress = '0x2ca48b8c2d574b282fdab69545646983a94a3286';
    const jotAdress = '0xCc1941F097e7df921303e788434aaBdd7eB3d19e';

    const fundingToken = await ethers.getContractAt('FundingMock', fundingTokenAdress);

    const fundingBalance = await fundingToken.balanceOf(owner.address);
    console.log(fundingBalance.toString())

    const jot = await ethers.getContractAt('Jot', jotAdress);

    const jotBalance = await jot.balanceOf(owner.address);
    console.log(jotBalance.toString());

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
