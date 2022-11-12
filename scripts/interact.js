const hre = require("hardhat")
const ethers = require("ethers");


async function main() {

  const marketRole = ethers.utils.id("MARKET_ROLE")
  const marketAddr = "0x3afb953FF281661A0386acd3792a574547ab2c07"
  const nftAddr = "0xcfe81db08a75CdA49320f5a07ABce092B3dd39B6"
  const aviAddr = "0xFcF3c57F4FF25B3EaBEba12D32401b2fA10C0CDD"

  const adminRole = "0x0000000000000000000000000000000000000000000000000000000000000000"
  const minterRole = "0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6"

  // const NftCore = await hre.ethers.getContractAt("UNQSMarketEth", marketAddr);
  const NftCore = await hre.ethers.getContractAt("UNQSNFT", nftAddr);

  const grant1 = await NftCore.grantRole(adminRole, aviAddr);
  grant1.wait(1);
  const grant2 = await NftCore.grantRole(minterRole, aviAddr);
  grant2.wait(1);

  console.log('Finish');





}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})