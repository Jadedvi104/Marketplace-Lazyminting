const hre = require("hardhat")

async function main() {

  const addresses = {
    CoinContractAddr: "0x8d4E37E817ED2F9FeE78f436F013323C396930eb",
    NFTContractAddr: "0x1CF4BC48E8A40c01c80D943e31E9ee74C263858D",
    NFTPoolContractAddr: "0xBAe5cB37C063E8E88663AEa8878C06AE2a984Cb3",
    MarketContractAddr: "0x70D560c0162C9d04A587e47D51488d72dB2AD315",
    MinterAddr: "0x04954d7EB4ff1C8f95DC839550352927Ec058cbf"
  }

  const minterRole = hre.ethers.utils.id("MINTER_ROLE")
  console.log(minterRole,'>>>>>MINTER_ROLE');
  const marketRole = hre.ethers.utils.id("MARKET_ROLE")

  // const UNQSNFTPoolContract = await hre.ethers.getContractAt("UNQSPool", addresses.NFTPoolContractAddr);
  // await UNQSNFTPoolContract.grantRole(marketRole, addresses.MarketContractAddr);
  // console.log("Market Role has been granted to", addresses.MarketContractAddr);

  const NftCore = await hre.ethers.getContractAt("UNQSNFT", addresses.NFTPoolContractAddr);
  await NftCore.grantRole(minterRole, addresses.MinterAddr);
  console.log('Minter Role has been granted');

}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
