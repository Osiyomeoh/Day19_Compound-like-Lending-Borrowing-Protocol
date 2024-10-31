import { time, loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import hre from "hardhat";

describe("CToken", function () {
  async function deployCTokenFixture() {
    const [owner, borrower] = await hre.ethers.getSigners();

    // Deploy a mock underlying ERC20 token
    const Token = await hre.ethers.getContractFactory("MockERC20");
    const underlying = await Token.deploy("Underlying Token", "UTK", 18, hre.ethers.parseEther("10000"));

    // Deploy the CToken contract with the underlying token address
    const CToken = await hre.ethers.getContractFactory("CToken");
    const cToken = await CToken.deploy(underlying);

    // Initial mint to the owner for testing purposes
    await underlying.transfer(owner, hre.ethers.parseEther("1000"));

    return { cToken, underlying, owner, borrower };
  }

  describe("Deployment", function () {
    it("Should set the correct underlying token", async function () {
      const { cToken, underlying } = await loadFixture(deployCTokenFixture);
      expect(await cToken.underlying()).to.equal(underlying);
    });
  });

  describe("Minting", function () {
    it("Should mint cTokens correctly and update balances", async function () {
      const { cToken, underlying, owner } = await loadFixture(deployCTokenFixture);
      const amount = hre.ethers.parseEther("100");

      // Approve CToken to spend owner's underlying tokens and mint cTokens
      await underlying.connect(owner).approve(cToken, amount);
      await cToken.connect(owner).mint(amount);

      // Calculate the expected cToken amount
     // const amount: bigint = hre.ethers.parseEther("100");
      const exchangeRate: bigint = await cToken.exchangeRate(); // Assuming exchangeRate() returns a bigint
      const cTokenAmount = (amount * BigInt(1e18)) / exchangeRate;// Update this to call exchangeRate() if necessary

      // Validate cToken balance and reduced underlying balance for owner
      const cTokenBalance = await cToken.balanceOf(owner.address);
      expect(cTokenBalance).to.equal(cTokenAmount); // Check if cTokens are correctly minted
      expect(await underlying.balanceOf(owner.address)).to.equal(hre.ethers.parseEther("9900")); // Owner's underlying balance after minting
    });
  });

  describe("Redeeming", function () {
    it("Should redeem cTokens correctly and update balances", async function () {
      const { cToken, underlying, owner } = await loadFixture(deployCTokenFixture);
      const mintAmount = hre.ethers.parseEther("100");

      // Mint cTokens by depositing underlying asset
      await underlying.connect(owner).approve(cToken, mintAmount);
      await cToken.connect(owner).mint(mintAmount);

      const cTokenBalance = await cToken.balanceOf(owner.address);
      // Redeem cTokens back to the underlying asset
      await cToken.connect(owner).redeem(cTokenBalance);

      // Verify owner’s cToken balance is 0 and underlying balance is restored
      expect(await cToken.balanceOf(owner.address)).to.equal(0); // Owner should have no cTokens now

      // Calculate the expected underlying amount to redeem
      const exchangeRate: bigint = await cToken.exchangeRate(); 
      const underlyingAmount = (cTokenBalance *  exchangeRate) / BigInt(1e18); // Use exchangeRate for calculation
      expect(await underlying.balanceOf(owner.address)).to.equal(hre.ethers.parseEther("10000")); // Update this based on how much was redeemed
    });
  });

  describe("Borrowing and Repayment", function () {
    it("Should allow borrowing and repayment, updating balances correctly", async function () {
      const { cToken, underlying, borrower, owner } = await loadFixture(deployCTokenFixture);
      const mintAmount = hre.ethers.parseEther("200"); // Owner mints cTokens to add collateral
      const borrowAmount = hre.ethers.parseEther("50");

      // Mint some collateral cTokens for owner to allow borrowing
      await underlying.connect(owner).approve(cToken, mintAmount);
      await cToken.connect(owner).mint(mintAmount);

      // Borrow underlying token
      await cToken.connect(borrower).borrow(borrowAmount);
      expect(await underlying.balanceOf(borrower.address)).to.equal(borrowAmount); // Borrower should have borrowed amount
      expect(await cToken.borrowBalances(borrower.address)).to.equal(borrowAmount); // Borrower's borrow balance should reflect

      // Repay the borrowed amount
      await underlying.connect(borrower).approve(cToken, borrowAmount);
      await cToken.connect(borrower).repayBorrow(borrowAmount);

      // Check that borrow balance is cleared after repayment
      expect(await cToken.borrowBalances(borrower.address)).to.equal(0); // Borrower should have no debt now
      expect(await underlying.balanceOf(borrower.address)).to.equal(0); // Borrower should have no underlying balance left after repayment
    });
  });
});
