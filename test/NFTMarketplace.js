const { expect } = require("chai");

describe("NFT Marketplace contract", () => {
    let weth;
    let marketplace;
    let erc1155;
    let erc721;
    let erc20;


    beforeEach("Deployment", async () => {
        weth = await ethers.deployContract("WETH");
        await weth.waitForDeployment();
        const WETH_address = weth.target;

        marketplace = await ethers.deployContract("NFTMarketplace",[WETH_address]);
        await marketplace.waitForDeployment();

        erc20 = await ethers.deployContract("COINS");
        await erc20.waitForDeployment();

        erc1155 = await ethers.deployContract("MyMultiToken");
        await erc1155.waitForDeployment();

        erc721 = await ethers.deployContract("MyNFT");
        await erc721.waitForDeployment();
    })

    it("create sale 1155", async () => {
        const [owner, seller] = await ethers.getSigners();

        const TOKEN_ID = 1234;
        const NUMBER_OF_ASSETS = 10;
        const PRICE_OF_ASSET = 10;
        const PAYMENT_TOKEN = erc20.target;

        await erc1155
            .connect(seller)
            .mint(TOKEN_ID, NUMBER_OF_ASSETS,"0x");
        
        expect(await erc1155.balanceOf(seller.address, TOKEN_ID)).to.equal(NUMBER_OF_ASSETS);

        await erc1155
            .connect(seller)
            .setApprovalForAll(marketplace.target,true);
        
        await marketplace
            .connect(seller)
            .createSale1155(
                erc1155.target,
                TOKEN_ID,
                NUMBER_OF_ASSETS,
                PRICE_OF_ASSET,
                PAYMENT_TOKEN
            );
        
        const sale = await marketplace.Sales(erc1155.target, TOKEN_ID);
        expect(sale.owner).to.equal(seller.address);
        expect(sale.addressOfAsset).to.equal(erc1155.target);
        expect(sale.tokenId).to.equal(TOKEN_ID);
        expect(sale.numberOfAssets).to.equal(NUMBER_OF_ASSETS);
        expect(sale.priceOfAsset).to.equal(PRICE_OF_ASSET);
        expect(sale.paymentToken).to.equal(PAYMENT_TOKEN);
        expect(sale.isERC1155).to.equal(true);
        expect(sale.isERC721).to.equal(false);
    })

    it("create sale 721", async () => {
        const [owner, seller] = await ethers.getSigners();

        const TOKEN_ID = 5678;
        const PRICE_OF_ASSET = 10;
        const PAYMENT_TOKEN = erc20.target;

        await erc721
            .connect(seller)
            .mint(seller, TOKEN_ID);
        
        expect(await erc721.ownerOf(TOKEN_ID)).to.equal(seller);

        await erc721
            .connect(seller)
            .setApprovalForAll(marketplace.target, true);
        
        await marketplace
            .connect(seller)
            .createSale721(
                erc721.target,
                TOKEN_ID,
                PRICE_OF_ASSET,
                PAYMENT_TOKEN
            )
        
        const sale = await marketplace.Sales(erc721.target,TOKEN_ID);

        expect(sale.owner).to.equal(seller.address);
        expect(sale.addressOfAsset).to.equal(erc721.target);
        expect(sale.tokenId).to.equal(TOKEN_ID);
        expect(sale.numberOfAssets).to.equal(1);
        expect(sale.priceOfAsset).to.equal(PRICE_OF_ASSET);
        expect(sale.paymentToken).to.equal(PAYMENT_TOKEN);
        expect(sale.isERC1155).to.equal(false);
        expect(sale.isERC721).to.equal(true);

    })

    it('buy sale 1155',async () => {
        const [owner,seller, buyer] = await ethers.getSigners();

        const TOKEN_ID = 1234;
        const NUMBER_OF_ASSETS = 10;
        const PRICE_OF_ASSET = 10;
        const PAYMENT_TOKEN = erc20.target;

        await erc1155
            .connect(seller)
            .mint(TOKEN_ID, NUMBER_OF_ASSETS,"0x");
        
        expect(await erc1155.balanceOf(seller.address, TOKEN_ID)).to.equal(NUMBER_OF_ASSETS);

        await erc1155
            .connect(seller)
            .setApprovalForAll(marketplace.target,true);
        
        await marketplace
            .connect(seller)
            .createSale1155(
                erc1155.target,
                TOKEN_ID,
                NUMBER_OF_ASSETS,
                PRICE_OF_ASSET,
                PAYMENT_TOKEN
            );
        
        const sale = await marketplace.Sales(erc1155.target, TOKEN_ID);
        expect(sale.owner).to.equal(seller.address);
        

        await erc20
            .connect(buyer)
            .mint(buyer.address,sale.priceOfAsset * sale.numberOfAssets);
        
        expect(await erc20.balanceOf(buyer.address)).to.equal(sale.priceOfAsset * sale.numberOfAssets);

        await erc20
            .connect(buyer)
            .approve(marketplace.target,sale.priceOfAsset * sale.numberOfAssets)

        await marketplace
            .connect(buyer)
            .buySale1155(
                erc1155.target,
                TOKEN_ID,
                NUMBER_OF_ASSETS
            )
        expect(await erc1155.balanceOf(buyer.address, TOKEN_ID)).to.equal(NUMBER_OF_ASSETS);
        expect(await erc1155.balanceOf(seller.address, TOKEN_ID)).to.equal(0);


    })
})