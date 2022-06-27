// contracts/Nftmarketplace.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Nftrice.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
//prevents re-entrancy attacks
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "hardhat/console.sol";

contract NFTMarketplace is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    //nft mint contract instance
    address public nftContractAddress;

    bool private isInitialized;

    using SafeMath for uint256;
    //auto-increment field for each item
    using Counters for Counters.Counter;

    Counters.Counter private _collectionIds; //total number of items ever created
    Counters.Counter private _itemIds; //total number of items ever created
    Counters.Counter private _itemsSold; //total number of items sold
    Counters.Counter private _rewardCount;

    uint256 public constant DENOMINATOR = 1000; //1000
    uint256 public rewardPercent1;       //70
    uint256 public transactionPercent1;  //10
    uint256 public rewardPercent2;       //65
    uint256 public transactionPercent2;  //5

    //marketplace item structure
    struct marketItem {
        uint256 itemId;
        uint256 tokenId;
        uint256 collectionId;
        string uri;
        address seller; //person selling the nft
        address owner;
        address saleToken;
        uint256 price;
        address giftAddress;
        uint256 royalty;
        bool active;
    }

    //a way to access values of the MarketItem struct above by passing an integer ID
    mapping(uint256 => marketItem) public marketItemList;

    struct collection {
        uint256 itemId;
        string name;
        string description;
        string logo;
        string banner;
        string featured;
        address owner;
        uint256 count;
        uint256 createDate;
    }

    mapping(uint256 => collection) public collectionList;

    struct reward {
        address owner;
        uint256 rice;
        uint256 usdt;
        uint256 brise;
        uint256 endDate;
    }
    mapping(address => reward) public rewards;
    mapping(uint256 => address) public rewardAddress;

    // address payable walletAddress
    address RICE = 0x5d0C865e353837e89505e5189E06873B3C88C0C4;
    address USDT = 0xDe14b85cf78F2ADd2E867FEE40575437D5f10c06;
    address BRISE = 0x0eb9036cbE0f052386f36170c6b07eF0a0E3f710;

    function initialize(
        address _nftCtxAddress,
        uint256 _rewardPercent1,
        uint256 _transactionPercent1,
        uint256 _rewardPercent2,
        uint256 _transactionPercent2,
        address _riceAddress,
        address _usdtAddress,
        address _briseAddress
    ) public initializer {
        __Ownable_init();
        nftContractAddress = _nftCtxAddress;
        rewardPercent1 = _rewardPercent1;
        transactionPercent1 = _transactionPercent1;
        rewardPercent2 = _rewardPercent2;
        transactionPercent2 = _transactionPercent2;
        RICE = _riceAddress;
        USDT = _usdtAddress;
        BRISE = _briseAddress;
        isInitialized = true;
    }

    function isInitialize() external view returns(bool) {
        return isInitialized;
    }

    event createdCollection(uint256 id);
    event itemAddedForSale(uint256 id, uint256 tokenId, uint256 price);
    event updatedMarketItem(
        uint256 id,
        uint256 price,
        address owner,
        address saleToken,
        address giftAddress,
        uint256 royalty,
        uint256 date
    );
    event updatedCollectionItem(
        uint256 id,
        string name,
        string description,
        string logo,
        string banner,
        string featured
    );
    event purchase(
        uint256 id,
        address seller,
        address buyer,
        uint256 price,
        address token,
        string tokenURI,
        uint256 date
    );
    event activeMarketItem(
        uint256 id,
        address seller,
        uint256 price,
        address token,
        uint256 date
    );
    event marketItemCreated(
        uint256 indexed id,
        uint256 indexed tokenId,
        uint256 indexed collectionId,
        address minter,
        uint256 date
    );

    modifier hasTransferApproval(uint256 tokenId) {
        require(
            NFTRice(nftContractAddress).getApproved(tokenId) == address(this),
            "Market is not approved"
        );
        _;
    }
    modifier itemExists(uint256 itemId) {
        require(
            itemId < _itemIds.current() + 1 &&
                marketItemList[itemId].itemId == itemId,
            "Could not find item"
        );
        _;
    }
    modifier isUnSold(uint256 itemId) {
        require(!marketItemList[itemId].active, "Item is already sold");
        _;
    }
    modifier isSold(uint256 itemId) {
        require(marketItemList[itemId].active, "Item is yet not sale");
        _;
    }
    modifier isOwner(uint256 itemId) {
        require(
            marketItemList[itemId].seller == msg.sender,
            "Sender does not own the item"
        );
        _;
    }
    modifier isExistCollection(uint256 collectionId) {
        require(
            collectionList[collectionId].itemId == collectionId,
            "Could not find collection"
        );
        _;
    }
    modifier isCollectionOwner(uint256 collectionId) {
        require(
            collectionList[collectionId].owner == msg.sender,
            "Sender does not own the item"
        );
        _;
    }

    function createCollection(
        address owner,
        string memory name,
        string memory description,
        string memory logo,
        string memory banner,
        string memory featured
    ) public returns (uint256) {
        _collectionIds.increment();
        uint256 itemId = _collectionIds.current();

        collectionList[itemId] = collection(
            itemId,
            name,
            description,
            logo,
            banner,
            featured,
            owner,
            0,
            block.timestamp
        );
        emit createdCollection(itemId);
        return itemId;
    }

    function createMarketItem(
        uint256 tokenId,
        uint256 collectionId,
        address owner
    ) external {
        require(msg.sender == nftContractAddress, "sender is not owner");
        require(tokenId > _itemIds.current(), "tokenId is exist");

        _itemIds.increment(); //add 1 to the total number of items ever created
        uint256 itemId = _itemIds.current();

        string memory uri = NFTRice(nftContractAddress).tokenURI(tokenId);
        marketItemList[itemId] = marketItem(
            itemId,
            tokenId,
            collectionId,
            uri,
            owner, //address of the seller putting the nft up for sale
            owner,
            address(0),
            0,
            address(0),
            0,
            false
        );

        collectionList[collectionId].count += 1;
        //initailize zero amount of the seller reward
        if (rewards[owner].owner != owner) {
            _rewardCount.increment();
            uint256 rewardId = _rewardCount.current();
            rewardAddress[rewardId] = owner;

            rewards[owner] = reward(
                owner,
                0,
                0,
                0,
                block.timestamp + 60 * 86400
            );
        }
        //log this transaction
        emit marketItemCreated(itemId, tokenId, collectionId, owner, block.timestamp);
    }

    function createMarketSale(uint256 itemId)
        external
        isOwner(itemId)
        isUnSold(itemId)
        itemExists(itemId)
    {
        address seller = marketItemList[itemId].seller;
        uint256 tokenId = marketItemList[itemId].tokenId;

        marketItemList[itemId].active = true;

        ERC721EnumerableUpgradeable(nftContractAddress).transferFrom(seller, address(this), tokenId);

        emit activeMarketItem(itemId, seller, marketItemList[itemId].price, marketItemList[itemId].saleToken, block.timestamp);
    }

    function buyMarketItem(uint256 itemId)
        public
        payable
        isSold(itemId)
        nonReentrant
    {
        address payable contractAddress = payable(address(this));
        address saleToken = marketItemList[itemId].saleToken;
        uint256 price = marketItemList[itemId].price;
        uint256 tokenId = marketItemList[itemId].tokenId;
        address payable seller = payable(marketItemList[itemId].seller);
        address payable buyer = payable(msg.sender);
        address payable minter = payable(marketItemList[itemId].owner);
        uint256 royalty = marketItemList[itemId].royalty;

        if (saleToken == BRISE) {
            require(
                msg.value == price,
                "Please submit the asking price in order to complete purchase"
            );
            // If buyer sent more than price, we send them back their rest of funds
            if (msg.value > price) {
                buyer.transfer(msg.value - price);
            }

            uint256 royaltyValue = price.div(DENOMINATOR).mul(royalty);

            // 8% commission cut in BRISE
            uint256 rewardValue = price.div(DENOMINATOR).mul(rewardPercent1); // 7% transaction fee
            uint256 transactionValue = price.div(DENOMINATOR).mul(
                transactionPercent1
            ); // 1% transaction fee

            //pay the seller the amount 92%
            uint256 sellerValue = price.sub(royaltyValue).sub(rewardValue).sub(
                transactionValue
            );

            if (royaltyValue > 0) {
                minter.transfer(royaltyValue);
            }
            seller.transfer(sellerValue);
            payable(owner()).transfer(transactionValue);

            uint256 rewardCount = _rewardCount.current();

            for (uint256 i = 0; i < rewardCount; i++) {
                address _address = rewardAddress[i + 1];
                if (rewards[_address].endDate > block.timestamp) {
                    rewards[_address].brise = rewards[_address].brise.add(
                        rewardValue.div(rewardCount)
                    );
                }
            }
        } else {
            require(
                ERC20Upgradeable(saleToken).balanceOf(msg.sender) > price,
                "Please submit the asking price in order to complete purchase"
            );

            uint256 royaltyValue = price.div(DENOMINATOR).mul(royalty);
            uint256 rewardValue = price.div(DENOMINATOR).mul(rewardPercent2);
            uint256 transactionValue = price.div(DENOMINATOR).mul(
                transactionPercent2
            );

            uint256 sellerValue = price.sub(royaltyValue).sub(rewardValue).sub(
                transactionValue
            );

            if (royaltyValue > 0) {
                ERC20Upgradeable(saleToken).transferFrom(buyer, minter, royaltyValue);
            }

            ERC20Upgradeable(saleToken).transferFrom(buyer, seller, sellerValue);
            ERC20Upgradeable(saleToken).transferFrom(buyer, owner(), transactionValue);
            ERC20Upgradeable(saleToken).transferFrom(buyer, contractAddress, rewardValue);

            uint256 rewardCount = _rewardCount.current();

            for (uint256 i = 0; i < rewardCount; i++) {
                address _address = rewardAddress[i + 1];
                if (rewards[_address].endDate > block.timestamp) {
                    if (saleToken == USDT)
                        rewards[_address].usdt = rewards[_address].usdt.add(
                            rewardValue.div(rewardCount)
                        );
                    if (saleToken == RICE)
                        rewards[_address].rice = rewards[_address].rice.add(
                            rewardValue.div(rewardCount)
                        );
                }
            }
        }
        //transfer ownership of the nft from the contract itself to the buyer
        ERC721EnumerableUpgradeable(nftContractAddress).transferFrom(address(this), buyer, tokenId);

        marketItemList[itemId].seller = payable(buyer); //mark buyer as new owner
        marketItemList[itemId].giftAddress = address(0); //mark buyer as new owner
        marketItemList[itemId].active = false; //mark that it has been sold
        _itemsSold.increment(); //increment the total number of Items sold by 1

        emit purchase(
            marketItemList[itemId].itemId,
            seller,
            buyer,
            price,
            saleToken,
            NFTRice(nftContractAddress).tokenURI(tokenId),
            block.timestamp
        );
    }

    function fetchMarketItems() public view returns (marketItem[] memory) {
        uint256 itemCount = _itemIds.current(); //total number of items ever created
        marketItem[] memory items = new marketItem[](itemCount);

        for (uint256 i = 0; i < itemCount; i++) {
            uint256 currentId = marketItemList[i + 1].itemId;
            marketItem storage currentItem = marketItemList[currentId];
            items[i] = currentItem;
        }
        return items; //return array of all unsold items
    }

    function fetchCollectionItems() public view returns (collection[] memory) {
        uint256 itemCount = _collectionIds.current(); //total number of items ever created
        collection[] memory items = new collection[](itemCount);

        for (uint256 i = 0; i < itemCount; i++) {
            uint256 currentId = collectionList[i + 1].itemId;
            collection storage currentItem = collectionList[currentId];
            items[i] = currentItem;
        }
        return items;
    }

    function updateMarketItem(
        uint256 itemId,
        uint256 updatePrice,
        address saleToken,
        address giftAddress,
        uint256 royalty
    ) external itemExists(itemId) isOwner(itemId) isUnSold(itemId) {
        marketItemList[itemId].giftAddress = giftAddress;
        marketItemList[itemId].price = updatePrice;
        marketItemList[itemId].saleToken = saleToken;
        if (msg.sender == marketItemList[itemId].owner) {
            marketItemList[itemId].royalty = royalty;
        }
        emit updatedMarketItem(
            itemId,
            updatePrice,
            msg.sender,
            saleToken,
            giftAddress,
            royalty,
            block.timestamp
        );
    }

    function updateCollectionItem(
        uint256 collectionId,
        string memory name,
        string memory description,
        string memory logo,
        string memory banner,
        string memory featured
    ) external isExistCollection(collectionId) isCollectionOwner(collectionId) {
        require(msg.sender==collectionList[collectionId].owner, 'sender is not owner of collection');
        collectionList[collectionId].name = name;
        collectionList[collectionId].description = description;
        collectionList[collectionId].logo = logo;
        collectionList[collectionId].banner = banner;
        collectionList[collectionId].featured = featured;

        emit updatedCollectionItem(
            collectionId,
            name,
            description,
            logo,
            banner,
            featured
        );
    }

    function claimRewards() external {
        if (rewards[msg.sender].endDate > block.timestamp) {
            uint256 riceAmount = rewards[msg.sender].rice;
            uint256 usdtAmount = rewards[msg.sender].usdt;
            uint256 briseAmount = rewards[msg.sender].brise;

            require(
                (riceAmount > 0 || usdtAmount > 0 || briseAmount > 0),
                "Zero balance"
            );

            if (riceAmount > 0) ERC20Upgradeable(RICE).transfer(msg.sender, riceAmount);
            if (usdtAmount > 0) ERC20Upgradeable(USDT).transfer(msg.sender, usdtAmount);
            if (briseAmount > 0) payable(msg.sender).transfer(briseAmount);

            rewards[msg.sender].rice = 0;
            rewards[msg.sender].usdt = 0;
            rewards[msg.sender].brise = 0;
        }
    }

    function totalItems() external view returns (uint256) {
        return _itemIds.current();
    }

    function totalCollection() external view returns (uint256) {
        return _collectionIds.current();
    }
}
