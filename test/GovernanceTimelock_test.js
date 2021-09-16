const { constants, expectEvent, expectRevert } = require('@openzeppelin/test-helpers');
const { expect } = require('chai');
const Enums = require('./helpers/enums');

const { runGovernorWorkflow } = require('./GovernorWorkflow.behavior');

const { shouldSupportInterfaces } = require('./introspection/SupportsInterface.behavior');

describe('GovernorTimelockControl', function () {
  const name = 'OZ-Governor';

  beforeEach(async function () {
    await deployments.fixture(['timelock_fixtures']);

    const { deployer } = await getNamedAccounts();
    voter = deployer;

    this.token = await ethers.getContract('ERC20VotesMock');
    this.timelock = await ethers.getContract('TimelockController');
    this.mock = await ethers.getContract('GovernorTimelockControlMock');
    this.receiver = await ethers.getContract('CallReceiverMock');
  });

  shouldSupportInterfaces(['ERC165', 'Governor', 'GovernorTimelock']);

  it('post deployment check', async function () {
    expect(await this.mock.name()).to.be.equal(name);
    expect(await this.mock.token()).to.be.equal(this.token.address);
    expect(String(await this.mock.votingDelay())).to.be.bignumber.equal('4');
    expect(String(await this.mock.votingPeriod())).to.be.bignumber.equal('16');
    expect(String(await this.mock.quorum(0))).to.be.bignumber.equal('0');

    expect(await this.mock.timelock()).to.be.equal(this.timelock.address);
  });

  describe('nominal', function () {
    beforeEach(async function () {
      this.settings = {
        proposal: [
          [this.receiver.address],
          [web3.utils.toWei('0')],
          [this.receiver.interface.encodeFunctionData('mockFunction', [])],
          '<proposal description>',
        ],
        voters: [{ voter: voter, support: Enums.VoteType.For }],
        steps: {
          queue: { delay: 3600 },
          // execute: { error: 'TimelockController: operation is not ready' },
        },
      };
    });

    afterEach(async function () {
      const timelockid = await this.timelock.hashOperationBatch(
        ...this.settings.proposal.slice(0, 3),
        web3.eth.abi.encodeParameter('bytes32', '0x0'),
        this.descriptionHash
      );

      await expect(this.receipts.propose).to.emit(this.mock, 'ProposalCreated');
      await expect(this.receipts.queue).to.emit(this.mock, 'ProposalQueued');
      await expect(this.receipts.queue).to.emit(this.timelock, 'CallScheduled');
      await expect(this.receipts.execute).to.emit(this.mock, 'ProposalExecuted');
      await expect(this.receipts.execute).to.emit(this.timelock, 'CallExecuted');
      await expect(this.receipts.execute).to.emit(this.receiver, 'MockFunctionCalled');
    });

    runGovernorWorkflow();
  });

  // describe('executed by other proposer', function () {
  //   beforeEach(async function () {
  //     this.settings = {
  //       proposal: [
  //         [this.receiver.address],
  //         [web3.utils.toWei('0')],
  //         [this.receiver.contract.methods.mockFunction().encodeABI()],
  //         '<proposal description>',
  //       ],
  //       voters: [{ voter: voter, support: Enums.VoteType.For }],
  //       steps: {
  //         queue: { delay: 3600 },
  //         execute: { enable: false },
  //       },
  //     };
  //   });
  //   afterEach(async function () {
  //     await this.timelock.executeBatch(...this.settings.proposal.slice(0, 3), '0x0', this.descriptionHash);

  //     expect(await this.mock.state(this.id)).to.be.bignumber.equal(Enums.ProposalState.Executed);

  //     await expectRevert(
  //       this.mock.execute(...this.settings.proposal.slice(0, -1), this.descriptionHash),
  //       'Governor: proposal not successful'
  //     );
  //   });
  //   runGovernorWorkflow();
  // });

  // describe('not queued', function () {
  //   beforeEach(async function () {
  //     this.settings = {
  //       proposal: [
  //         [this.receiver.address],
  //         [web3.utils.toWei('0')],
  //         [this.receiver.contract.methods.mockFunction().encodeABI()],
  //         '<proposal description>',
  //       ],
  //       voters: [{ voter: voter, support: Enums.VoteType.For }],
  //       steps: {
  //         queue: { enable: false },
  //         execute: { error: 'TimelockController: operation is not ready' },
  //       },
  //     };
  //   });
  //   afterEach(async function () {
  //     expect(await this.mock.state(this.id)).to.be.bignumber.equal(Enums.ProposalState.Succeeded);
  //   });
  //   runGovernorWorkflow();
  // });

  // describe('to early', function () {
  //   beforeEach(async function () {
  //     this.settings = {
  //       proposal: [
  //         [this.receiver.address],
  //         [web3.utils.toWei('0')],
  //         [this.receiver.contract.methods.mockFunction().encodeABI()],
  //         '<proposal description>',
  //       ],
  //       voters: [{ voter: voter, support: Enums.VoteType.For }],
  //       steps: {
  //         execute: { error: 'TimelockController: operation is not ready' },
  //       },
  //     };
  //   });
  //   afterEach(async function () {
  //     expect(await this.mock.state(this.id)).to.be.bignumber.equal(Enums.ProposalState.Queued);
  //   });
  //   runGovernorWorkflow();
  // });

  // describe('re-queue / re-execute', function () {
  //   beforeEach(async function () {
  //     this.settings = {
  //       proposal: [
  //         [this.receiver.address],
  //         [web3.utils.toWei('0')],
  //         [this.receiver.contract.methods.mockFunction().encodeABI()],
  //         '<proposal description>',
  //       ],
  //       voters: [{ voter: voter, support: Enums.VoteType.For }],
  //       steps: {
  //         queue: { delay: 3600 },
  //       },
  //     };
  //   });
  //   afterEach(async function () {
  //     expect(await this.mock.state(this.id)).to.be.bignumber.equal(Enums.ProposalState.Executed);

  //     await expectRevert(
  //       this.mock.queue(...this.settings.proposal.slice(0, -1), this.descriptionHash),
  //       'Governor: proposal not successful'
  //     );
  //     await expectRevert(
  //       this.mock.execute(...this.settings.proposal.slice(0, -1), this.descriptionHash),
  //       'Governor: proposal not successful'
  //     );
  //   });
  //   runGovernorWorkflow();
  // });

  // describe('cancel before queue prevents scheduling', function () {
  //   beforeEach(async function () {
  //     this.settings = {
  //       proposal: [
  //         [this.receiver.address],
  //         [web3.utils.toWei('0')],
  //         [this.receiver.contract.methods.mockFunction().encodeABI()],
  //         '<proposal description>',
  //       ],
  //       voters: [{ voter: voter, support: Enums.VoteType.For }],
  //       steps: {
  //         queue: { enable: false },
  //         execute: { enable: false },
  //       },
  //     };
  //   });
  //   afterEach(async function () {
  //     expect(await this.mock.state(this.id)).to.be.bignumber.equal(Enums.ProposalState.Succeeded);

  //     expectEvent(
  //       await this.mock.cancel(...this.settings.proposal.slice(0, -1), this.descriptionHash),
  //       'ProposalCanceled',
  //       { proposalId: this.id }
  //     );

  //     expect(await this.mock.state(this.id)).to.be.bignumber.equal(Enums.ProposalState.Canceled);

  //     await expectRevert(
  //       this.mock.queue(...this.settings.proposal.slice(0, -1), this.descriptionHash),
  //       'Governor: proposal not successful'
  //     );
  //   });
  //   runGovernorWorkflow();
  // });

  // describe('cancel after queue prevents execution', function () {
  //   beforeEach(async function () {
  //     this.settings = {
  //       proposal: [
  //         [this.receiver.address],
  //         [web3.utils.toWei('0')],
  //         [this.receiver.contract.methods.mockFunction().encodeABI()],
  //         '<proposal description>',
  //       ],
  //       voters: [{ voter: voter, support: Enums.VoteType.For }],
  //       steps: {
  //         queue: { delay: 3600 },
  //         execute: { enable: false },
  //       },
  //     };
  //   });
  //   afterEach(async function () {
  //     const timelockid = await this.timelock.hashOperationBatch(
  //       ...this.settings.proposal.slice(0, 3),
  //       '0x0',
  //       this.descriptionHash
  //     );

  //     expect(await this.mock.state(this.id)).to.be.bignumber.equal(Enums.ProposalState.Queued);

  //     const receipt = await this.mock.cancel(...this.settings.proposal.slice(0, -1), this.descriptionHash);
  //     expectEvent(receipt, 'ProposalCanceled', { proposalId: this.id });
  //     await expectEvent.inTransaction(receipt.receipt.transactionHash, this.timelock, 'Cancelled', { id: timelockid });

  //     expect(await this.mock.state(this.id)).to.be.bignumber.equal(Enums.ProposalState.Canceled);

  //     await expectRevert(
  //       this.mock.execute(...this.settings.proposal.slice(0, -1), this.descriptionHash),
  //       'Governor: proposal not successful'
  //     );
  //   });
  //   runGovernorWorkflow();
  // });

  // describe('updateTimelock', function () {
  //   beforeEach(async function () {
  //     this.newTimelock = await deployments.deploy('newTimelockController', {
  //       contract: 'TimelockController',
  //       from: deployer,
  //       args: [3600, [], []],
  //     });
  //   });

  //   it('protected', async function () {
  //     await expectRevert(this.mock.updateTimelock(this.newTimelock.address), 'Governor: onlyGovernance');
  //   });

  //   describe('using workflow', function () {
  //     beforeEach(async function () {
  //       this.settings = {
  //         proposal: [
  //           [this.mock.address],
  //           [web3.utils.toWei('0')],
  //           [this.mock.contract.methods.updateTimelock(this.newTimelock.address).encodeABI()],
  //           '<proposal description>',
  //         ],
  //         voters: [{ voter: voter, support: Enums.VoteType.For }],
  //         steps: {
  //           queue: { delay: 3600 },
  //         },
  //       };
  //     });
  //     afterEach(async function () {
  //       expectEvent(this.receipts.propose, 'ProposalCreated', { proposalId: this.id });
  //       expectEvent(this.receipts.execute, 'ProposalExecuted', { proposalId: this.id });
  //       expectEvent(this.receipts.execute, 'TimelockChange', {
  //         oldTimelock: this.timelock.address,
  //         newTimelock: this.newTimelock.address,
  //       });
  //       expect(await this.mock.timelock()).to.be.bignumber.equal(this.newTimelock.address);
  //     });
  //     runGovernorWorkflow();
  //   });
  // });
});
