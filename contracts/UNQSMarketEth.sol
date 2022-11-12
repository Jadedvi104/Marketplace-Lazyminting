// SPDX-License-Identifier:  Multiverse Expert
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface NFT_POOL {
    function depositNFT(
        address nftContract,
        uint256 tokenId,
        address ownner
    ) external;

    function transferNFT(
        address nftContract,
        address to,
        uint256 tokenId
    ) external;
}

interface INFT_CORE {
    function getRoyaltyInfo(uint256 _tokenId, uint256 _salePrice)
        external
        view
        returns (address, uint256);
}

contract UNQSMarketEth is ReentrancyGuard, Pausable, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _orderIds;
    Counters.Counter private _auctionIds;

    uint256 public auctionFees = 1000; //10,000 = 100%
    uint256 public feesRate = 425;

    address payable public adminWallet;
    address public nftPool;

    constructor() {
    }

    /************************** Structs *********************/

    struct Order {
        address nftContract;
        uint256 orderId;
        uint256 tokenId;
        address payable seller;
        address owner;
        uint256 price;
        bool listed;
        bool sold;
    }

    struct Auction {
        address nftContract;
        uint256 auctionId;
        uint256 tokenId;
        address payable seller;
        address owner;
        uint256 startPrice;
        bool started;
        bool ended;
        uint256 endAt;
        bool sold;
    }

    struct HighestBid {
        address highestBidder;
        uint256 bidAmount;
    }

    /************************** Mappings *********************/

    mapping(uint256 => Order) public idToOrder;
    mapping(uint256 => Auction) public idToAuction;
    mapping(uint256 => mapping(address => uint256)) public bidsToAuction;
    mapping(uint256 => HighestBid) public auctionHighestBid;
    mapping(address => bool) private isWhitelist;

    /************************** Events *********************/

    event OrderCreated(
        address nftContract,
        uint256 indexed orderId,
        uint256 tokenId,
        address seller,
        address owner,
        uint256 price,
        bool listed,
        bool sold
    );

    event OrderCanceled(
        uint256 orderId,
        uint256 tokenId,
        address seller,
        address owner,
        bool listed
    );

    event OrderSuccessful(
        uint256 orderId,
        uint256 tokenId,
        address seller,
        address owner,
        bool listed,
        bool sold
    );

    event StartAuction(
        address nftContract,
        uint256 auctionId,
        uint256 tokenId,
        address seller,
        address owner,
        uint256 startPrice,
        bool started,
        bool ended,
        uint256 endAt,
        bool sold
    );

    event Bid(uint256 auctionId, address indexed sender, uint256 amount);
    event End(uint256 auctionId, address winner, uint256 amount, bool ended);
    event Withdraw(address bidder, uint256 auctionId, uint256 amount);

    /******************* Setup Functions *********************/

    //@Admin if something happen Admin can call this function to pause txs
    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function updateNFTPool(address _nftPool)
        public
        onlyOwner
    {
        nftPool = _nftPool;
    }

    //@Admin call to set whitelists
    function setWhitelist(address whitelistAddress)
        public
        onlyOwner
    {
        require(
            !isWhitelist[whitelistAddress],
            "User already exist in whitelist"
        );
        isWhitelist[whitelistAddress] = true;
    }

    //@Admin call to update market fee
    function updateFeesRate(uint256 feeRate)
        public
        onlyOwner
    {
        // feeAmount will be / by 10000
        // if you want 5% feeRate should be 500
        feesRate = feeRate;
    }

    //@Admin call to update market fee
    function updateAdminWallet(address payable _adminWallet)
        public
        onlyOwner
    {
        // feeAmount will be / by 10000
        // if you want 5% feeRate should be 500
        adminWallet = _adminWallet;
    }

    //@Admin call to update auction fee
    function updateAuctionFeesRate(uint256 newRate)
        public
        onlyOwner
    {
        require(newRate >= 500);
        auctionFees = newRate;
    }

    // for frontend \\
    // Listing Items
    // Items info

    /* Places an item for sale on the marketplace */
    function createOrder(
        address nftContract,
        uint256 tokenId,
        uint256 price
    ) public nonReentrant {
        // set require ERC721 approve below
        require(price > 100, "Price must be at least 100 wei");
        _orderIds.increment();
        uint256 orderId = _orderIds.current();
        idToOrder[orderId] = Order(
            nftContract,
            orderId,
            tokenId,
            payable(msg.sender),
            nftPool,
            price,
            true,
            false
        );

        // tranfer NFT ownership to Market contract
        IERC721(nftContract).safeTransferFrom(msg.sender, nftPool, tokenId);
        NFT_POOL(nftPool).depositNFT(nftContract, tokenId, msg.sender);

        emit OrderCreated(
            nftContract,
            orderId,
            tokenId,
            msg.sender,
            nftPool,
            price,
            true,
            false
        );
    }

    /* Seller call this to cancel placed order */
    function cancelOrder(uint256 orderId) public {
        require(!idToOrder[orderId].sold, "Sold item");
        require(idToOrder[orderId].listed, "Item is not listed");
        // check if the caller is seller
        require(idToOrder[orderId].seller == msg.sender);

        //Transfer back to the real owner.
        NFT_POOL(nftPool).transferNFT(
            idToOrder[orderId].nftContract,
            msg.sender,
            idToOrder[orderId].tokenId
        );

        //update mapping info
        idToOrder[orderId].owner = msg.sender;
        idToOrder[orderId].seller = payable(address(0));
        idToOrder[orderId].listed = false;

        emit OrderCanceled(
            idToOrder[orderId].orderId,
            idToOrder[orderId].tokenId,
            address(0),
            msg.sender,
            false
        );
    }

    /* Creates the sale of a marketplace order */
    /* Transfers ownership of the order, as well as funds between parties */
    function buyOrder(uint256 orderId) public payable nonReentrant {
        require(!idToOrder[orderId].sold, "Status: Sold item");
        require(idToOrder[orderId].listed, "Status: It's not listed item");

        uint256 price = idToOrder[orderId].price;
        require(msg.value >= price, "not enough eth");
        uint256 tokenId = idToOrder[orderId].tokenId;

        (address creator, uint256 royaltyFee) = INFT_CORE(
            idToOrder[orderId].nftContract
        ).getRoyaltyInfo(tokenId, price);
        uint256 fee = (price * feesRate) / 10000;
        uint256 amount = (price - fee) - royaltyFee;

        //if not the whitelists, transfer fee to platform.
        if (!isWhitelist[msg.sender]) {
            (bool sentFee, ) = adminWallet.call{value: fee}("");
            require(sentFee, "Failed to send Ether");
        }

        //transfer Royalty amount
        (bool sent, ) = creator.call{value: royaltyFee}("");

        //Transfer price after fee to nft seller.
        (sent, ) = idToOrder[orderId].seller.call{value: amount}("");

        // call NFT pool to transfer the nft to buyer;
        NFT_POOL(nftPool).transferNFT(
            idToOrder[orderId].nftContract,
            msg.sender,
            tokenId
        );

        //update status of this orderId
        idToOrder[orderId].owner = msg.sender;
        idToOrder[orderId].sold = true;
        idToOrder[orderId].listed = false;

        emit OrderSuccessful(
            orderId,
            tokenId,
            address(0),
            msg.sender,
            false,
            true
        );
    }

    /******************* English Auction Functions *********************/

    //seller call this to start auction
    function startAuction(
        address nftContract,
        uint256 tokenId,
        uint256 startPrice,
        uint256 dateAmount
    ) external nonReentrant {
        _auctionIds.increment();
        uint256 auctionId = _auctionIds.current();

        //lock nft token to the pool
        IERC721(nftContract).transferFrom(msg.sender, nftPool, tokenId);

        //declare the end time.
        uint256 endAt = block.timestamp + dateAmount;
        //insert auction data to mapping
        idToAuction[auctionId] = Auction(
            nftContract,
            auctionId,
            tokenId,
            payable(msg.sender),
            nftPool,
            startPrice,
            true,
            false,
            endAt,
            false
        );

        //the first bidder is auction creator
        auctionHighestBid[auctionId].highestBidder = msg.sender;
        //the first bid is start price
        auctionHighestBid[auctionId].bidAmount = startPrice;

        emit StartAuction(
            nftContract,
            auctionId,
            tokenId,
            msg.sender,
            nftPool,
            startPrice,
            true,
            false,
            endAt,
            false
        );
    }

    // bidder call this to bid
    function bid(uint256 auctionId) external payable {
        uint256 highestBid = auctionHighestBid[auctionId].bidAmount;

        require(idToAuction[auctionId].started, "not started");
        require(block.timestamp < idToAuction[auctionId].endAt, "ended");
        require(msg.value > highestBid, "bid amount < highest");

        if (msg.sender != address(0)) {
            //calculate left amount
            uint256 unusedAmount = 0;
            if (bidsToAuction[auctionId][msg.sender] > 0) {
                unusedAmount = bidsToAuction[auctionId][msg.sender];
            }

            // user's lastest bid will always be the highest
            bidsToAuction[auctionId][msg.sender] = msg.value;
            // Put the hihest bid to mapping
            auctionHighestBid[auctionId].bidAmount = msg.value;
            auctionHighestBid[auctionId].highestBidder = msg.sender;

            //transfer unneeded amont to bidder
            (bool sent, ) = msg.sender.call{value: unusedAmount}("");
            require(sent, "Failed to send Ether");

        } else {
            revert();
        }

        emit Bid(auctionId, msg.sender, msg.value);
    }

    //seller or winner call this to claim their item/eth
    function end(uint256 auctionId) external nonReentrant {
        require(idToAuction[auctionId].started, "not started");
        require(
            block.timestamp >= idToAuction[auctionId].endAt,
            "Auction's not past end date"
        );
        require(!idToAuction[auctionId].ended, "Auction's already ended");

        //the last bidder is always the highest one.
        uint256 highestBid = auctionHighestBid[auctionId].bidAmount;
        address highestBidder = auctionHighestBid[auctionId].highestBidder;
        address payable seller = idToAuction[auctionId].seller;
        uint256 fee = (highestBid * auctionFees) / 10000;
        uint256 transferAmount = highestBid - fee;

        if (highestBidder != address(0)) {
            //transfer nft to winner
            NFT_POOL(nftPool).transferNFT(
                idToAuction[auctionId].nftContract,
                highestBidder,
                idToAuction[auctionId].tokenId
            );
            if (!isWhitelist[msg.sender]) {
                // tranfer winner's bid to seller
                (bool sent, ) = seller.call{value: transferAmount}("");
                require(sent, "Failed Eth");
            } else {
                (bool sent, ) = seller.call{value: highestBid}("");
                require(sent, "Failed Eth");
            }
        } else {
            //transfer nft to seller if no winner
            NFT_POOL(nftPool).transferNFT(
                idToAuction[auctionId].nftContract,
                seller,
                idToAuction[auctionId].tokenId
            );
        }

        idToAuction[auctionId].ended = true;

        emit End(auctionId, highestBidder, highestBid, true);
    }

    function bidderWithdraw(uint256 auctionId) external nonReentrant {
        require(
            block.timestamp >= idToAuction[auctionId].endAt,
            "Auction's not past end date"
        );
        require(idToAuction[auctionId].ended, "Auction not ended");
        uint256 transferAmount = bidsToAuction[auctionId][msg.sender];
        address highestBidder = auctionHighestBid[auctionId].highestBidder;
        require(msg.sender != highestBidder, "Highest Bidder can't withdraw");

        (bool sent, ) = payable(msg.sender).call{value: transferAmount}("");
        require(sent, "Failed Eth");

        emit Withdraw(msg.sender, auctionId, transferAmount);
    }

    /******************* MUST_HAVE Functions *********************/

    /* tranfer to owner address*/
    function transferEth(address payable _to, uint256 _amount)
        public
        onlyOwner
    {
        (bool sent, ) = _to.call{value: _amount}("");
        require(sent, "Failed Eth");
    }
}
