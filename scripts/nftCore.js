const hre = require("hardhat")


async function main() {

  const addresses = {
    UNQSCoinContractAddr: "",
    UNQSNFTContractAddr: "",
    UNQSNFTPoolContractAddr: "",
    UNQSMarketContractAddr: "",
    MinterAddr: "0x04954d7EB4ff1C8f95DC839550352927Ec058cbf"
  }

  const adminRole = hre.ethers.utils.id("DEFAULT_ADMIN_ROLE")
  const minterRole = hre.ethers.utils.id("MINTER_ROLE")

  const UNQSNFT = await hre.ethers.getContractFactory("UNQSNFT")
  const deploy = await UNQSNFT.deploy()
  await deploy.deployed()
  console.log("UNQSNFT deployed to:", deploy.address)

  await deploy.grantRole(minterRole, addresses.MinterAddr);
  // await deploy.grantRole(adminRole, addresses.MinterAddr);
  console.log("UNQSNFT has granted role to:", addresses.MinterAddr)

  await hre.run("verify:verify", {
      address: deploy.address,
  })
  console.log("Contract is verified.")

 
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
