// SPDX-License-Identifier: MIT
/*
    Nftrice / 2022
*/
pragma solidity ^0.8.0;

import "./Nftmarketplace.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "hardhat/console.sol";

contract NFTRice is
    Initializable,
    ERC721EnumerableUpgradeable,
    OwnableUpgradeable
{
    //auto-increment field for each token
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    Counters.Counter private _ownerCount;

    //address of the Nft marketplace
    address public marketplaceAddress;

    bool private isInitialized;

    // address payable walletAddress
    address RICE = 0x5d0C865e353837e89505e5189E06873B3C88C0C4;
    address USDT = 0xDe14b85cf78F2ADd2E867FEE40575437D5f10c06;
    address WBRISE = 0x0eb9036cbE0f052386f36170c6b07eF0a0E3f710;

    //Nft item structure
    struct nftItem {
        uint256 itemId;
        string uri; //metadata url,
        address mintToken; //token address using mint
        address minter; //minter address
        uint256 mintPrice;
    }

    //Nft items
    mapping(uint256 => nftItem) public nftItems; //id => Item

    uint256 public constant COOLDOWN_TIME = 86400;
    uint256 public constant DENOMINATOR = 100;

    uint256 public royaltyPercent;
    uint256 public ownerPercent;
    uint256 public dev1Percent;

    uint256 public limitAmount = 20;

    uint256 public brisePrice;
    uint256 public ayraPrice;
    uint256 public ricePrice;
    uint256 public brisePriceWithHasTag;
    uint256 public ayraPriceWithHasTag;
    uint256 public ricePriceWithHasTag;

    mapping(address => uint256) readyForClaim;
    mapping(address => uint256) rewardWBRISEAmount;
    mapping(address => uint256) rewardUSDTAmount;
    mapping(address => uint256) rewardRICEAmount;

    address public dev1Address;

    //mint event(minter_address, nft_ids)
    event mintedNFT(address indexed to, uint256[] newIds);

    function initialize(
        address _marketplaceAddress,
        uint256 _royaltyPercent,
        uint256 _ownerPercent,
        uint256 _dev1Percent,
        address _riceAddress,
        address _ayraAddress,
        address _briseAddress,
        address _dev1Address,
        uint256 _limitAmount,
        uint256 _brisePrice,
        uint256 _ayraPrice,
        uint256 _ricePrice
    ) public initializer {
        __ERC721_init("MagicsNFT", "MAGICS");
        __Ownable_init();
        royaltyPercent = _royaltyPercent;
        ownerPercent = _ownerPercent;
        dev1Percent = _dev1Percent;
        marketplaceAddress = _marketplaceAddress;
        RICE = _riceAddress;
        USDT = _ayraAddress;
        WBRISE = _briseAddress;
        dev1Address = _dev1Address;
        limitAmount = _limitAmount;
        brisePrice = _brisePrice;
        brisePriceWithHasTag = _brisePrice * 2;
        ayraPrice = _ayraPrice;
        ayraPriceWithHasTag = _ayraPrice * 2;
        ricePrice = _ricePrice;
        ricePriceWithHasTag = _ricePrice * 2;
        isInitialized = true;
    }

    function isInitialize() external view returns (bool) {
        return isInitialized;
    }

    function setDev1Address(address _dev1Address) external onlyOwner {
        dev1Address = _dev1Address;
    }

    function setRoyaltyPercent(uint256 _royaltyPercent) external onlyOwner {
        royaltyPercent = _royaltyPercent;
    }

    function setDev1Percent(uint256 _dev1Percent) external onlyOwner {
        dev1Percent = _dev1Percent;
    }

    function setOwnerPercent(uint256 _ownerPercent) external onlyOwner {
        ownerPercent = _ownerPercent;
    }

    /// @notice create a new nft
    /// @param _tokenURI : URI
    function mint(
        uint256 _collectionId,
        string memory _image,
        string memory _tokenURI,
        uint256 _amount,
        address _mintToken,
        bool _hasTag
    ) external payable {
        require(_amount < limitAmount, "Overflow amount!");
        require(_amount > 0, "Invailid amount!");
        uint256 _mintPrice = 0;

        if (_mintToken == WBRISE) {
            if (_hasTag) _mintPrice = brisePriceWithHasTag;
            else _mintPrice = brisePrice;
        }
        if (_mintToken == RICE) {
            if (_hasTag) _mintPrice = ricePriceWithHasTag;
            else _mintPrice = ricePrice;
        }
        if (_mintToken == USDT) {
            if (_hasTag) _mintPrice = ayraPriceWithHasTag;
            else _mintPrice = ayraPrice;
        }

        uint256 royaltyAmount = (_mintPrice * royaltyPercent) / DENOMINATOR;
        uint256 ownerAmount = (_mintPrice * ownerPercent) / DENOMINATOR;
        uint256 dev1Amount = (_mintPrice * dev1Percent) / DENOMINATOR;

        if (_mintToken == WBRISE) {
          require(msg.value >= _mintPrice * _amount, "Invalid Amount");
        } else {
          require(ERC20Upgradeable(_mintToken).balanceOf(msg.sender) >= _mintPrice * _amount, "You don't have enough funds" );
        }

        uint256 collectionId = _collectionId;
        if (_collectionId == 0) {
          collectionId = NFTMarketplace(marketplaceAddress).createCollection( msg.sender, "unnamed", "unnamed", _image, _image, _image );
        }

        for (uint256 i = 0; i <  _tokenIds.current(); i++) {
            address ownerAddress = nftItems[i + 1].minter;
            if(_mintToken == WBRISE) {
                rewardWBRISEAmount[ownerAddress] += royaltyAmount / _ownerCount.current();
            }
            if(_mintToken == USDT) {
                rewardUSDTAmount[ownerAddress] += royaltyAmount / _ownerCount.current();
            }
            if(_mintToken == RICE) {
                rewardRICEAmount[ownerAddress] += royaltyAmount / _ownerCount.current();
            }
        }

        if(balanceOf(msg.sender) == 0) _ownerCount.increment();

        uint256[] memory newIds = new uint256[](_amount);

        for (uint256 k = 0; k < _amount; k++) {
          _tokenIds.increment();
          uint256 newItemId = _tokenIds.current();
          _safeMint(msg.sender, newItemId);
          nftItems[newItemId] = nftItem({
            itemId: newItemId,
            uri: _tokenURI,
            mintToken: _mintToken,
            minter: msg.sender,
            mintPrice: _mintPrice
          });
          newIds[k] = newItemId;

          NFTMarketplace(marketplaceAddress).createMarketItem( newItemId, collectionId, msg.sender );
        }

        if (_mintToken == WBRISE) {
          payable(owner()).transfer(ownerAmount * _amount);
          payable(dev1Address).transfer(dev1Amount * _amount);
          payable(msg.sender).transfer(msg.value - _mintPrice * _amount);
        } else {
          ERC20Upgradeable(_mintToken).transferFrom(msg.sender, address(this), (_mintPrice - ownerAmount - dev1Amount) * _amount);
          ERC20Upgradeable(_mintToken).transferFrom(msg.sender, owner(), ownerAmount * _amount);
          ERC20Upgradeable(_mintToken).transferFrom(msg.sender, dev1Address, dev1Amount * _amount);
        }

        emit mintedNFT(msg.sender, newIds);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        return nftItems[tokenId].uri;
    }

    function setMarketplace(address _marketplaceAddress) external onlyOwner {
        marketplaceAddress = _marketplaceAddress;
    }

    function getMarketplace() public view returns (address) {
        return marketplaceAddress;
    }

    function tokensOfOwner(address _owner) public view returns(uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);
        uint256[] memory tokensId = new uint256[](tokenCount);
        for(uint256 i = 0; i < tokenCount; i++) {
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokensId;
    }

    function claim() external {
        require(msg.sender != address(0), "Zero address!");
        require(isRewardClaimable(msg.sender), "You have no reward to claim");
        if(rewardWBRISEAmount[msg.sender] > 0) {
            payable(msg.sender).transfer(rewardWBRISEAmount[msg.sender]);
            rewardWBRISEAmount[msg.sender] = 0;
        }
        if(rewardUSDTAmount[msg.sender] > 0) {
            ERC20Upgradeable(USDT).transfer(msg.sender, rewardUSDTAmount[msg.sender]);
            rewardUSDTAmount[msg.sender] = 0;
        }
        if(rewardRICEAmount[msg.sender] > 0) {
            ERC20Upgradeable(RICE).transfer(msg.sender, rewardRICEAmount[msg.sender]);
            rewardRICEAmount[msg.sender] = 0;
        }
    }

    function getRewardWBRISEAmount(address _addr) external view returns(uint256) {
        return rewardWBRISEAmount[_addr];
    }

    function getRewardUSDTAmount(address _addr) external view returns(uint256) {
        return rewardUSDTAmount[_addr];
    }

    function getRewardRICEAmount(address _addr) external view returns(uint256) {
        return rewardRICEAmount[_addr];
    }

    function isRewardClaimable(address _potentialWinner) public view returns(bool){
        if(rewardWBRISEAmount[_potentialWinner] == 0 && rewardUSDTAmount[_potentialWinner] == 0 && rewardRICEAmount[_potentialWinner] == 0 ) {
            return false;
        }
        else {
            return true;
        }
    }
    function balanceWBRISE() public view returns (uint256) {
        return address(this).balance;
    }
    function balanceUSDT() public view returns (uint256) {
        return ERC20Upgradeable(USDT).balanceOf(address(this));
    }
    function balanceRICE() public view returns (uint256) {
        return ERC20Upgradeable(RICE).balanceOf(address(this));
    }
    function withdrawWBRISE(uint256 _withdrawAmount) external onlyOwner {
        require(_withdrawAmount < address(this).balance, "Insufficient amount");
        payable(owner()).transfer(_withdrawAmount);
    }
    function withdrawUSDT(uint256 _withdrawAmount) external onlyOwner {
        uint256 _balanceUSDT = ERC20Upgradeable(USDT).balanceOf(address(this));
        require(_withdrawAmount < _balanceUSDT, "Insufficient amount");
        ERC20Upgradeable(USDT).transfer(owner(), _balanceUSDT);
    }
    function withdrawRICE(uint256 _withdrawAmount) external onlyOwner {
        uint256 _balanceRICE = ERC20Upgradeable(RICE).balanceOf(address(this));
        require(_withdrawAmount < _balanceRICE, "Insufficient amount");
        ERC20Upgradeable(RICE).transfer(owner(), _balanceRICE);
    }
}
