const { expect } = require('chai');

describe('Stringify', async function () {
  beforeEach(async () => {
    // Using fixture from hardhat-deploy
    await deployments.fixture(['stringify_client_mock']);

    this.mock = await ethers.getContract('StringifyClientMock');
  });

  it('should convert uint to string', async () => {
    let string = await this.mock.uintToString(1000);

    expect(string).to.be.equal('1000');
  });

  it('should convert address to string', async () => {
    const { deployer } = await getNamedAccounts();
    let string = await this.mock.addressToString(deployer);

    expect(string).to.be.equal(deployer.slice(2).toLowerCase());
  });

  it('should convert string to bytes32', async () => {
    let phrase = 'some phrase for testing purposes';
    let bytes = ethers.utils.toUtf8Bytes(phrase);

    let bytes32 = await this.mock.stringToBytes32(phrase);

    expect(bytes32).to.be.equal(ethers.utils.hexlify(bytes));
  });
});
