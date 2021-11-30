const { expect } = require('chai');
const { ethers, network } = require('hardhat');

const parseAmount = (amount) => ethers.utils.parseEther(amount);

async function asyncCall() {

    /* address */
    [owner] = await ethers.getSigners();

    const jotPoolAddress = '0x91C2EB9FEdD4af2e514FDF8Bc4b57cd63ed108Bc';
    const jotAdress = '0x982a27d5599cd34342cdf558020262b9ba39eccb';

    const jotPool = await ethers.getContractAt('JotPool', jotPoolAddress);
    const jot = await ethers.getContractAt('Jot', jotAdress);

    console.log('Jot address', await jotPool.jot());
    await jot.approve(jotPoolAddress, parseAmount('1'))
    await jotPool.addLiquidity(parseAmount('1'));

    const position = await jotPool.getPosition();
    console.log(position.toString());

}

asyncCall();
