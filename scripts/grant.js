const hre = require("hardhat")
const ethers = require("ethers");

async function main() {

  const addresses = {
    CoinContractAddr: "0x8d4E37E817ED2F9FeE78f436F013323C396930eb",
    NFTContractAddr: "0x53F33D5D581CDFc75ABA11336053E3fC58a20543",
    NFTPoolContractAddr: "0xBAe5cB37C063E8E88663AEa8878C06AE2a984Cb3",
    MarketContractAddr: "0x1dD0EC72AEf13BF3492bA82a057d653c3EaA18D0",
    MinterAddr: "0x04954d7EB4ff1C8f95DC839550352927Ec058cbf"
  }

  const minterRole = ethers.utils.id("MINTER_ROLE")
  const marketRole = ethers.utils.id("MARKET_ROLE")

  const UNQSNFTPoolContract = await hre.ethers.getContractAt("UNQSPool", addresses.NFTPoolContractAddr);
  await UNQSNFTPoolContract.grantRole(marketRole, addresses.MarketContractAddr);
  console.log("Market Role has been granted to", addresses.MarketContractAddr);

}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
