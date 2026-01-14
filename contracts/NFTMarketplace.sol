// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";




contract NFTMarketplace {

    struct Sale {
        address owner; // owner
        address addressOfAsset; // Address of Asset
        uint256 tokenId; // Unique ID of the asset
        uint256 numberOfAssets; // Number of assets being sold
        uint256 priceOfAsset; // price of the asset
        address paymentToken; // Acceptable ERC20 token address as payment
        bool isERC1155; // to identify that sale is Of ERC1155 Asset
        bool isERC721; // to identify that sale is of ERC721 Asset
    }

    uint256 public constant FEE_PERCENTAGE = 55;
    uint256 public constant FEE_DENOMINATOR = 1000;
    address public immutable WETH;

    address public marketPlaceOwner;

    // Address of Asset => Unique ID of the asset => Sale Struct
    // addressOfAsset => tokenId => Sale
    mapping(address => mapping(uint256 => Sale)) public Sales;

    // fees
    // paymentToken => accumulated fees amount
    mapping(address => uint256) public Fees;

    event SaleCreated(address indexed owner, address indexed addressOfAsset, uint256 indexed tokenId, uint256 numberOfAssets, uint256 priceOfAsset, address paymentToken, bool isERC1155, bool isERC721);
    event SaleUpdated(address indexed owner, address indexed addressOfAsset, uint256 indexed tokenId, uint256 numberOfAssets, uint256 priceOfAsset, address paymentToken);
    event Purchase(address indexed buyer, address indexed seller, address indexed addressOfAsset, uint256 tokenId, uint256 numberOfAssets, uint256 priceOfAsset, address paymentToken, uint256 fees);

    constructor(address _weth){
        marketPlaceOwner = msg.sender;
        WETH = _weth;
    }

    function _checkPayment(address paymentToken) internal view returns(address){
        if (paymentToken == address(0) || paymentToken == WETH) return WETH;
        return paymentToken;
    }

    function _payment(address paymentToken, address seller, address buyer, uint256 price, uint256 sellerAmount, uint256 fee) internal{
        if(paymentToken == WETH){
            if (msg.value > 0){
                require(msg.value == price, "incorrect eth ammount");
                (bool successful,) = seller.call{value: sellerAmount}("");
                require(successful, "ETH transfer to seller failed");

                (bool feeTransfer,) = address(this).call{value: fee}("");
                require(feeTransfer, "ETH fee transfer unsucessful");
            } else {
                Fees[paymentToken] += fee;
                IERC20(WETH).transferFrom(buyer,seller,sellerAmount);
                IERC20(WETH).transferFrom(buyer, address(this),fee);
            }
            } else {
                require(msg.value == 0, "ETH not accepted for ERC20 token transfer");
                Fees[paymentToken] += fee;
                IERC20(paymentToken).transferFrom(buyer,seller,sellerAmount);
                IERC20(WETH).transferFrom(buyer, address(this),fee);
            }
    }

    function createSale1155 (
        address addressOfAsset,
        uint256 tokenId,
        uint256 numberOfAssets,
        uint256 priceOfAsset,
        address paymentToken
        ) external {
            IERC1155 nft = IERC1155(addressOfAsset);

            // checks
            require(nft.balanceOf(msg.sender, tokenId) >= numberOfAssets, "insufficient amount of token");
            require(nft.isApprovedForAll(msg.sender, address(this)) == true, "marketplace is not approvedd");
            require(priceOfAsset > 0 ,"price should be greater than 0");

            // effects
            Sale storage sale = Sales[addressOfAsset][tokenId];

            bool isUpdate = sale.owner != address(0);
            
            sale.owner = msg.sender;
            sale.addressOfAsset = addressOfAsset;
            sale.tokenId = tokenId;
            sale.numberOfAssets = numberOfAssets;
            sale.priceOfAsset = priceOfAsset;
            sale.paymentToken = paymentToken;
            sale.isERC1155 = true;
            sale.isERC721 = false;

            // interaction
            if (isUpdate){
                emit SaleUpdated(msg.sender,addressOfAsset,tokenId,numberOfAssets,priceOfAsset, paymentToken);
            } else {
                emit SaleCreated(msg.sender,addressOfAsset,tokenId,numberOfAssets,priceOfAsset, paymentToken, true, false);
            }
            
        }

        function buySale1155(
            address addressOfAsset,
            uint256 tokenId,
            uint256 numberOfAssets
        ) external payable{
            Sale storage sale = Sales[addressOfAsset][tokenId];

            // checks
            require(sale.owner != address(0),"sale does not exist");
            require(sale.isERC1155 != false, "not an ERC1155 token");
            require(numberOfAssets > 0 && numberOfAssets <= sale.numberOfAssets,"invalid asset amount");

            // effects
            uint256 price = sale.priceOfAsset * numberOfAssets;
            uint256 fee = (price * FEE_PERCENTAGE)/FEE_DENOMINATOR;
            uint256 sellerAmount = price - fee;

            sale.numberOfAssets -= numberOfAssets;
            if(sale.numberOfAssets == 0){
                delete Sales[addressOfAsset][tokenId];
            } 

            // interaction
            address paymentToken = _checkPayment(sale.paymentToken);
            _payment(paymentToken, sale.owner, msg.sender, price, sellerAmount, fee);
            IERC1155(addressOfAsset).safeTransferFrom(sale.owner, msg.sender, tokenId, numberOfAssets,"");
            emit Purchase(msg.sender, sale.owner,addressOfAsset,tokenId,numberOfAssets,price,paymentToken,fee);
        }

        function createSale721(
        address addressOfAsset,
        uint256 tokenId,
        uint256 priceOfAsset,
        address paymentToken
        ) external {
            IERC721 nft = IERC721(addressOfAsset);

            // checks
            require(nft.ownerOf(tokenId) == msg.sender, "not token owner");
            require(nft.isApprovedForAll(msg.sender, address(this)) == true, "marketplace is not approvedd");
            require(priceOfAsset > 0 ,"price should be greater than 0");

            // effects
            Sale storage sale = Sales[addressOfAsset][tokenId];

            bool isUpdate = sale.owner != address(0);
            
            sale.owner = msg.sender;
            sale.addressOfAsset = addressOfAsset;
            sale.tokenId = tokenId;
            sale.numberOfAssets = 1;
            sale.priceOfAsset = priceOfAsset;
            sale.paymentToken = paymentToken;
            sale.isERC1155 = false;
            sale.isERC721 = true;

            // interaction
            if (isUpdate){
                emit SaleUpdated(msg.sender,addressOfAsset,tokenId,1,priceOfAsset, paymentToken);
            } else {
                emit SaleCreated(msg.sender,addressOfAsset,tokenId,1,priceOfAsset, paymentToken, false, true);
            }
            
        }

        function buySale721(
            address addressOfAsset,
            uint256 tokenId
        ) external payable{
            Sale storage sale = Sales[addressOfAsset][tokenId];

            // checks
            require(sale.owner != address(0),"sale does not exist");
            require(sale.isERC721 != false, "not an ERC721 token");

            // effects
            uint256 price = sale.priceOfAsset * 1;
            uint256 fee = (price * FEE_PERCENTAGE)/FEE_DENOMINATOR;
            uint256 sellerAmount = price - fee;

            delete Sales[addressOfAsset][tokenId];

            // interaction
            address paymentToken = _checkPayment(sale.paymentToken);
            _payment(paymentToken, sale.owner, msg.sender, price, sellerAmount, fee);
            IERC721(addressOfAsset).safeTransferFrom(sale.owner, msg.sender, tokenId,"");
            emit Purchase(msg.sender, sale.owner,addressOfAsset,tokenId,1,price,paymentToken,fee);
        }
}

