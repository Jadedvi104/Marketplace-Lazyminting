const hre = require("hardhat")


async function main() {

  const addresses = {
    UNQSCoinContractAddr: "",
    UNQSNFTContractAddr: "",
    UNQSNFTPoolContractAddr: "",
    UNQSMarketContractAddr: "",
    MinterAddr: "0x04954d7EB4ff1C8f95DC839550352927Ec058cbf",
    aviAddr: "0xFcF3c57F4FF25B3EaBEba12D32401b2fA10C0CDD"
  }

  const adminRole = "0x0000000000000000000000000000000000000000000000000000000000000000"
  const minterRole = "0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6"
  
  const UNQSNFT = await hre.ethers.getContractFactory("UNQSNFT");
  const deploy = await UNQSNFT.deploy();
  await deploy.deployed();
  console.log("UNQSNFT deployed to:", deploy.address);

  await deploy.deployTransaction.wait(5);

  await deploy.grantRole(minterRole, addresses.aviAddr);
  await deploy.grantRole(minterRole, addresses.MinterAddr);

  await deploy.grantRole(adminRole, addresses.aviAddr);
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
