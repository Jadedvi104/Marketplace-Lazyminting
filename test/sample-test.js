const { expect } = require("chai");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

describe("Token contract", function () {
  async function deployTokenFixture() {
    // Get the ContractFactory and Signers here.
    const Market = await ethers.getContractFactory("UNQSMarket");
    const MarketEth = await ethers.getContractFactory("UNQSMarketEth");
    const NftCore = await ethers.getContractFactory("UNQSNFT");
    const UNQSPool = await ethers.getContractFactory("UNQSPool");
    const Coin = await ethers.getContractFactory("UNQSCoin");

    const [owner, addr1, addr2, addr3, addr4] = await ethers.getSigners();

    const marketRole = ethers.utils.id("MARKET_ROLE");
    const hash1 = ethers.utils.id("hash1");
    const hash2 = ethers.utils.id("hash2");

    const UniqMarket = await Market.deploy();
    const UniqMarketEth = await MarketEth.deploy();
    const UniqNftCore = await NftCore.deploy();
    const UniqPool = await UNQSPool.deploy();
    const UniqCoin = await Coin.deploy();

    await UniqMarket.deployed();
    await UniqMarketEth.deployed();
    await UniqNftCore.deployed();
    await UniqPool.deployed();
    await UniqCoin.deployed();

    const mintAmount = ethers.utils.parseEther("10.0");
    const listingPrice = ethers.utils.parseEther("1.0");
    const plusAmount = ethers.utils.parseEther("1.1");

    await UniqPool.connect(owner).grantRole(marketRole, UniqMarket.address);
    await UniqPool.connect(owner).grantRole(marketRole, UniqMarketEth.address);

    await UniqMarket.connect(owner).updateNFTPool(UniqPool.address);
    await UniqMarketEth.connect(owner).updateNFTPool(UniqPool.address);

    await UniqMarket.connect(owner).updateAdminWallet(addr3.address);
    await UniqMarketEth.connect(owner).updateAdminWallet(addr3.address);

    await UniqCoin.connect(owner).mint(addr1.address, mintAmount);
    await UniqCoin.connect(owner).mint(addr2.address, mintAmount);

    await UniqCoin.connect(addr1).approve(UniqMarket.address, mintAmount);
    await UniqCoin.connect(addr2).approve(UniqMarket.address, mintAmount);

    await UniqNftCore.connect(owner).safeMint(addr1.address);
    await UniqNftCore.connect(owner).safeMint(addr2.address);

    await UniqNftCore.connect(owner).setupAdminWallet(addr3.address);

    await UniqNftCore.connect(addr1).setApprovalForAll(
      UniqMarket.address,
      true
    );
    await UniqNftCore.connect(addr1).setApprovalForAll(
      UniqMarketEth.address,
      true
    );
    await UniqNftCore.connect(addr2).setApprovalForAll(
      UniqMarket.address,
      true
    );
    await UniqNftCore.connect(addr2).setApprovalForAll(
      UniqMarketEth.address,
      true
    );

    return {
      UniqMarket,
      UniqMarketEth,
      UniqNftCore,
      UniqPool,
      UniqCoin,
      owner,
      addr1,
      addr2,
      addr3,
      addr4,
      mintAmount,
      marketRole,
      listingPrice,
      plusAmount,
    };
  }

  describe("Deployment", function () {
    it("Should have coin", async function () {
      const { UniqCoin, owner, addr1, addr2, mintAmount } = await loadFixture(
        deployTokenFixture
      );

      expect(await UniqCoin.balanceOf(addr1.address)).to.equal(mintAmount);
      expect(await UniqCoin.balanceOf(addr2.address)).to.equal(mintAmount);
    });

    it("Should approve", async function () {
      const { UniqCoin, UniqMarket, owner, addr1, addr2, mintAmount } =
        await loadFixture(deployTokenFixture);

      expect(
        await UniqCoin.allowance(addr1.address, UniqMarket.address)
      ).to.equal(mintAmount);
      expect(
        await UniqCoin.allowance(addr2.address, UniqMarket.address)
      ).to.equal(mintAmount);
    });

    it("Should have role", async function () {
      const {
        UniqPool,
        UniqMarket,
        UniqMarketEth,
        marketRole,
        owner,
        addr1,
        addr2,
        mintAmount,
      } = await loadFixture(deployTokenFixture);

      expect(await UniqPool.hasRole(marketRole, UniqMarket.address)).to.equal(
        true
      );
      expect(
        await UniqPool.hasRole(marketRole, UniqMarketEth.address)
      ).to.equal(true);
    });

    it("Should have NFT", async function () {
      const {
        UniqPool,
        UniqMarket,
        UniqMarketEth,
        UniqNftCore,
        marketRole,
        owner,
        addr1,
        addr2,
        mintAmount,
      } = await loadFixture(deployTokenFixture);

      expect(await UniqNftCore.balanceOf(addr1.address)).to.equal(1);
      expect(await UniqNftCore.balanceOf(addr2.address)).to.equal(1);
    });

    it("Should set approve for all", async function () {
      const {
        UniqPool,
        UniqMarket,
        UniqMarketEth,
        UniqNftCore,
        marketRole,
        owner,
        addr1,
        addr2,
        mintAmount,
      } = await loadFixture(deployTokenFixture);

      expect(
        await UniqNftCore.isApprovedForAll(addr1.address, UniqMarket.address)
      ).to.equal(true);
      expect(
        await UniqNftCore.isApprovedForAll(addr1.address, UniqMarketEth.address)
      ).to.equal(true);
      expect(
        await UniqNftCore.isApprovedForAll(addr2.address, UniqMarket.address)
      ).to.equal(true);
      expect(
        await UniqNftCore.isApprovedForAll(addr2.address, UniqMarketEth.address)
      ).to.equal(true);
    });
  });

  describe("Buy/Sell/Cancel", function () {
    it("Create Order in Market", async function () {
      const {
        UniqPool,
        UniqMarket,
        UniqMarketEth,
        UniqNftCore,
        marketRole,
        owner,
        addr1,
        addr2,
        mintAmount,
        listingPrice,
      } = await loadFixture(deployTokenFixture);

      await expect(
        UniqMarketEth.connect(addr1).createOrder(
          UniqNftCore.address,
          0,
          listingPrice
        )
      ).to.emit(UniqMarketEth, "OrderCreated");

      await expect(
        UniqMarketEth.connect(addr2).createOrder(
          UniqNftCore.address,
          1,
          listingPrice
        )
      ).to.emit(UniqMarketEth, "OrderCreated");
    });

    it("Buy order in Market", async function () {
      const {
        UniqPool,
        UniqMarket,
        UniqMarketEth,
        UniqNftCore,
        marketRole,
        owner,
        addr1,
        addr2,
        addr4,
        mintAmount,
        listingPrice,
      } = await loadFixture(deployTokenFixture);

      await UniqMarketEth.connect(addr1).createOrder(
        UniqNftCore.address,
        0,
        listingPrice
      );

      await expect(
        UniqMarketEth.connect(addr4).buyOrder(1, { value: listingPrice })
      ).to.emit(UniqMarketEth, "OrderSuccessful");
    });

    it("Cancel order in Market", async function () {
      const {
        UniqPool,
        UniqMarket,
        UniqMarketEth,
        UniqNftCore,
        marketRole,
        owner,
        addr1,
        addr2,
        addr4,
        mintAmount,
        listingPrice,
      } = await loadFixture(deployTokenFixture);

      await UniqMarketEth.connect(addr1).createOrder(
        UniqNftCore.address,
        0,
        listingPrice
      );

      await expect(UniqMarketEth.connect(addr1).cancelOrder(1)).to.emit(
        UniqMarketEth,
        "OrderCanceled"
      );
    });
  });

  describe("Auction", function () {
    it("Create Auction in Market", async function () {
      const {
        UniqPool,
        UniqMarket,
        UniqMarketEth,
        UniqNftCore,
        marketRole,
        owner,
        addr1,
        addr2,
        mintAmount,
        listingPrice,
      } = await loadFixture(deployTokenFixture);

      await expect(
        UniqMarketEth.connect(addr1).startAuction(
          UniqNftCore.address,
          0,
          listingPrice,
          86400
        )
      ).to.emit(UniqMarketEth, "StartAuction");
    });

    it("Bid auction", async function () {
      const {
        UniqPool,
        UniqMarket,
        UniqMarketEth,
        UniqNftCore,
        marketRole,
        owner,
        addr1,
        addr2,
        addr4,
        mintAmount,
        listingPrice,
        plusAmount,
      } = await loadFixture(deployTokenFixture);

      await UniqMarketEth.connect(addr1).startAuction(
        UniqNftCore.address,
        0,
        listingPrice,
        86400
      );

      await UniqMarketEth.connect(addr4).bid(1, { value: plusAmount });
      await UniqMarketEth.connect(addr2).bid(1, { value: ethers.utils.parseEther("1.2") });
      await UniqMarketEth.connect(addr4).bid(1, { value: ethers.utils.parseEther("1.3") });

      await expect(await UniqMarketEth.provider.getBalance(UniqMarketEth.address)).to.equal(
        ethers.utils.parseEther("2.5")
      );

    });


    it("End auction", async function () {
      const {
        UniqPool,
        UniqMarket,
        UniqMarketEth,
        UniqNftCore,
        marketRole,
        owner,
        addr1,
        addr2,
        addr4,
        mintAmount,
        listingPrice,
        plusAmount,
      } = await loadFixture(deployTokenFixture);

      await UniqMarketEth.connect(addr1).startAuction(
        UniqNftCore.address,
        0,
        listingPrice,
        86400
      );

      await UniqMarketEth.connect(addr4).bid(1, { value: plusAmount });
      await UniqMarketEth.connect(addr2).bid(1, { value: ethers.utils.parseEther("1.2") });
      await UniqMarketEth.connect(addr4).bid(1, { value: ethers.utils.parseEther("1.3") });

      await network.provider.send("evm_increaseTime", [100_000]);

      await expect(await UniqMarketEth.connect(addr4).end(1)).to.emit(
        UniqMarketEth, "End"
      );
      await expect(await UniqNftCore.connect(addr4).ownerOf(0)).to.equal(
        addr4.address
      );
      await expect(await UniqMarketEth.connect(addr2).bidderWithdraw(1)).to.emit(
        UniqMarketEth, "Withdraw"
      );

    });

  });


});
