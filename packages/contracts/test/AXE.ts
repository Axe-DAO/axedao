import vwJson from './VestingWallet.json';

import { loadFixture, time, takeSnapshot } from '@nomicfoundation/hardhat-toolbox/network-helpers';
import { expect } from 'chai';
import { Typed, ZeroAddress } from 'ethers';
import { ethers } from 'hardhat';

import * as TEST from './constants';

// TODO full test coverage of all functions and attributes

describe('AXÉ Tests', function () {
  async function deployAxeTokenFixture() {
    const [owner, addr1, addr2] = await ethers.getSigners();

    const token = await ethers.deployContract('AXESource', [owner, owner]);

    const vAddress = await token.vestingWallet();
    const vestingWallet = new ethers.Contract(vAddress, vwJson.abi, owner);

    return { token, vestingWallet, owner, addr1, addr2 };
  }

  describe('Deployment and get/set functionality', function () {
    it('Should have name and symbol set correctly', async function () {
      const { token } = await loadFixture(deployAxeTokenFixture);
      expect(await token.name()).to.equal('Axé');
      expect(await token.symbol()).to.equal('AXÉ');
    });
    it('Should have only vesting amount as initial supply and max cap', async function () {
      const { token } = await loadFixture(deployAxeTokenFixture);
      expect(await token.totalSupply()).to.equal(ethers.parseUnits(TEST.AXE.VESTING_AMOUNT.toString()));
      expect(await token.MAX_SUPPLY()).to.equal(ethers.parseUnits(TEST.AXE.MAX_SUPPLY.toString()));
    });
    it('Should have owner and governor initialized', async function () {
      const { token, owner } = await loadFixture(deployAxeTokenFixture);
      expect(await token.governor()).to.equal(owner);
    });
    it('Should allow tax control', async function () {
      const { token, owner, addr1 } = await loadFixture(deployAxeTokenFixture);
      await expect(token.connect(addr1).setBuyTax(700))
        .to.be.revertedWithCustomError(token, 'GovernableUnauthorizedAccount')
        .withArgs(addr1.address);
      await expect(token.connect(addr1).setSellTax(900))
        .to.be.revertedWithCustomError(token, 'GovernableUnauthorizedAccount')
        .withArgs(addr1.address);
      await expect(token.connect(owner).setBuyTax(10001)).to.be.reverted;
      await expect(token.connect(owner).setSellTax(10001)).to.be.reverted;
      await expect(token.connect(owner).setBuyTax(900)).to.emit(token, 'BuyTaxChanged').withArgs(900);
      expect(await token.buyTax()).to.equal(900);
      await expect(token.connect(owner).setSellTax(3450)).to.emit(token, 'SellTaxChanged').withArgs(3450);
      expect(await token.sellTax()).to.equal(3450);
    });
    it('Should allow to set treasury', async function () {
      const { token, owner, addr1 } = await loadFixture(deployAxeTokenFixture);
      await expect(token.connect(addr1).setTreasury(addr1))
        .to.be.revertedWithCustomError(token, 'GovernableUnauthorizedAccount')
        .withArgs(addr1.address);
      await expect(token.connect(owner).setTreasury(ZeroAddress)).to.be.revertedWith('Treasury cannot be zero address');
      await expect(token.connect(owner).setTreasury(addr1)).to.emit(token, 'TreasuryChanged').withArgs(addr1);
    });
  });

  describe('Issuance', function () {
    it('Only Governor should be able to issue', async function () {
      const { token, addr1 } = await loadFixture(deployAxeTokenFixture);
      await expect(token.connect(addr1).issue(ethers.parseUnits('1000')))
        .to.be.revertedWithCustomError(token, 'GovernableUnauthorizedAccount')
        .withArgs(addr1.address);
    });
    it('Governor should be able to issue multiple times', async function () {
      const { token, owner } = await loadFixture(deployAxeTokenFixture);

      let issueAmount = ethers.parseUnits('1000');
      await expect(token.issue(issueAmount)).to.emit(token, 'AxeIssued').withArgs(issueAmount);
      expect(await token.balanceOf(owner)).to.equal(ethers.parseUnits('1000'));

      issueAmount = ethers.parseUnits('5005');
      await expect(token.issue(issueAmount)).to.emit(token, 'AxeIssued').withArgs(issueAmount);
      expect(await token.balanceOf(owner)).to.equal(ethers.parseUnits('6005'));
    });
    it('Issuance should not exceed MAX SUPPLY', async function () {
      const { token } = await loadFixture(deployAxeTokenFixture);
      const maxIssuance = TEST.AXE.MAX_SUPPLY - TEST.AXE.VESTING_AMOUNT;
      await token.issue(ethers.parseUnits(maxIssuance.toString()));
      await expect(token.issue(1)).to.be.revertedWithCustomError(token, 'ERC20ExceededCap');
    });
  });

  describe('Vesting', function () {
    it('Initial amount should be locked', async function () {
      const { token, vestingWallet } = await loadFixture(deployAxeTokenFixture);
      expect(await token.balanceOf(vestingWallet)).to.be.equal(ethers.parseUnits(TEST.AXE.VESTING_AMOUNT.toString()));
    });
    it('Vesting schedule should be working', async function () {
      const { token, vestingWallet, owner } = await loadFixture(deployAxeTokenFixture);
      // use a snapshot to roll back the time jumps
      const snapshot = await takeSnapshot();
      const releasable = await vestingWallet.releasable(Typed.address(token));
      expect(releasable).to.be.equal(0, 'Vesting should not have started yet');
      await time.increase(72000);
      await vestingWallet.release(Typed.address(token));
      expect(await token.balanceOf(owner)).to.be.greaterThan(0, 'Vesting should have started');
      time.increase(TEST.AXE.VESTING_DURATION);
      await vestingWallet.release(Typed.address(token));
      expect(await token.balanceOf(owner)).to.be.equal(
        ethers.parseUnits(TEST.AXE.VESTING_AMOUNT.toString()),
        'Should have fully vested',
      );
      await snapshot.restore();
    });
  });
});
