const { expect } = require('chai');
const { ethers, network } = require('hardhat');
const { networkConfig } = require('../../helper-hardhat-config');

skip.if(network.tags.local).describe('LinkManager', async () => {
  describe('swap', async () => {
    it('should swap full balance of matic to link', async () => {
      const chainId = await getChainId();
      const linkManager = await ethers.getContract('LinkManager');
      const router = await ethers.getContractAt('IUniswapV2Router02', networkConfig[chainId].uniswapAddress);
      const linkTokenAddress = await linkManager.link();
      const maticTokenAddres = await linkManager.matic();
      const receiver = await linkManager.receiver();
      const linkToken = await ethers.getContractAt('IERC20', linkTokenAddress);
      const [owner] = await ethers.getSigners();
      const maticValue = ethers.utils.parseEther('0.01');
      const expectedTrades = await router.getAmountsOut(maticValue, [maticTokenAddres, linkTokenAddress]);

      console.log(`Sending ${maticValue} matic to LinkManager at ${linkManager.address}`);
      await owner.sendTransaction({ to: linkManager.address, value: maticValue });
      console.log(`Expecting to trade ${expectedTrades[0]} matic for ${expectedTrades[1]} link`);
      const balanceBefore = await linkToken.balanceOf(receiver);
      await expect(linkManager.swapToLink()).to.emit(linkManager, 'Swapped').withArgs(expectedTrades, receiver);

      expect(await linkManager.getBalance()).to.be.equal(0);
      const balanceAfter = await linkToken.balanceOf(receiver);
      expect(balanceAfter.sub(balanceBefore)).to.be.equal(expectedTrades[1]);
    });
  });
});
