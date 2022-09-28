const hre = require("hardhat")
const ethers = require("ethers");

async function main() {

  const addresses = {
    CoinContractAddr: "0x8d4E37E817ED2F9FeE78f436F013323C396930eb",
    NFTContractAddr: "0x53F33D5D581CDFc75ABA11336053E3fC58a20543",
    NFTPoolContractAddr: "0xBAe5cB37C063E8E88663AEa8878C06AE2a984Cb3",
    MarketContractAddr: "0x11a47058E312cbdf75F6c2f1528F3CC65c64b7cB",
    MinterAddr: "0x04954d7EB4ff1C8f95DC839550352927Ec058cbf",
    adminWallet: "0xf73E352Fd36f541C374D1E974F4D84DCD2628C87",
  }

  const minterRole = ethers.utils.id("MINTER_ROLE")
  const marketRole = ethers.utils.id("MARKET_ROLE")

  const UNQSNFTPoolContract = await hre.ethers.getContractAt("UNQSPool", addresses.NFTPoolContractAddr);
  const MartketContract = await hre.ethers.getContractAt("UNQSMarket", addresses.MarketContractAddr);
  const nftContract = await hre.ethers.getContractAt("UNQSNFT", addresses.NFTContractAddr);

  await MartketContract.updateNFTPool(addresses.NFTPoolContractAddr);
  await MartketContract.updateAdminWallet(addresses.adminWallet);
  await MartketContract.updateFeesRate(500);
  await MartketContract.updateAuctionFeesRate(500);

  await nftContract.setBaseUri('http://ipfs.com/');
  console.log('Done');
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
