const hre = require("hardhat")
const ethers = require("ethers");


async function main() {
  const _name = "Blue Wolf NFT"
  const _symbol = "UNQSNFT"


  const addresses = {
    UNQSCoinContractAddr: "",
    UNQSNFTContractAddr: "0xD737723D86fe32F64282b9142d4AE14b75D8CE6F",
    UNQSNFTPoolContractAddr: "",
    UNQSMarketContractAddr: "",
    MinterAddr: "0x04954d7EB4ff1C8f95DC839550352927Ec058cbf"
  }

  const minterRole = ethers.utils.id("MINTER_ROLE")

  const UNQSNFT = await hre.ethers.getContractFactory("UNQSNFT")
  const deploy = await UNQSNFT.deploy()
  await deploy.deployed()
  console.log("UNQSNFT deployed to:", deploy.address)

  await deploy.grantRole(minterRole, addresses.MinterAddr);
  console.log("UNQSNFT has granted role to:", addresses.MinterAddr)

  try {
    await hre.run("verify:verify", {
      address: deploy.address,
      contract: "contracts/UNQSNFT.sol:UNQSNFT",
    })
  } catch (error) {
    console.log(error)
  }
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
