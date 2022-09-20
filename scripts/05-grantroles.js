const hre = require("hardhat")
const ethers = require("ethers");

async function main() {

  const minterAddr = "0x04954d7EB4ff1C8f95DC839550352927Ec058cbf"
  const minterRole = ethers.utils.id("MINTER_ROLE")

  const UNQSCoin = await ethers.getContractAt("UNQSNFT", UNQSNFTContractAddr);
  const UNQSCoinContract = await grantRole(minterRole, minterAddr);

  console.log("Role has been granted to", minterAddr);

}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
