// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract NFT is ERC721Enumerable, Ownable {
    using Strings for uint256;

    //declares the maximum amount of tokens that can be minted, total and in presale
    uint256 private maxTotalTokens;
    //declares the amount of tokens able to be sold in presale
    uint256 private maxTokensPresale;
    //declares the amount of tokens able to be sold in platinum sale
    uint256 private maxTokensPlatinumSale;
    

    //stores the amiunt of tokens that have been minted in presale
    uint256 private numberOfTokensPresale;
    //stores the amiunt of tokens that have been minted in platinum
    uint256 private numberOfTokensPlatinumSale;
    
    //initial part of the URI for the metadata
    string private _currentBaseURI;
        
    //cost of mints depending on state of sale    
    uint private mintCostPresale = 0.22 ether;
    uint private mintCostPublicSale = 0.58 ether;
    
    //the amount of reserved mints that have currently been executed by creator and by marketing wallet
    uint private _reservedMints;
    //the maximum amount of reserved mints allowed for creator and marketing wallet
    uint private maxReservedMints;
    
    //number of mints an address can have maxmimum
    uint private maxMints;
    
    address public constant communityWallet = 0x9216879A3fBB0fdFbEF5931A59319B9430d8BDaF; 
    
    //dummy address that we use to sign the mint transaction to make sure it is valid
    address private dummy = 0x80E4929c869102140E69550BBECC20bEd61B080c; //for platinum sale

    //amount of mints that each address has executed
    mapping(address => uint256) public mintsPerAddress;
    
    //current state os sale
    enum State {NoSale, Presale, PublicSale}
    
    //the timestamp of when presale opens
    uint256 private presaleLaunchTime;
    //the timestamp of when public sale opens
    uint256 private publicSaleLaunchTime;
    //the timestamp of when platinum sale opens
    uint256 private platinumSaleLaunchTime;

    //to see if all NFTs have been revealed yet or not
    bool public reveal;

    //see if 700 eth has been trasnfered to community wallet
    bool public transfered;
        
    //declaring initial values for variables
    constructor() ERC721('Ape Gorilla Club', 'AGC') {
        //max number of NFTs that will be minted
        maxTotalTokens = 11337;
        //limit for presale
        maxTokensPresale = 1337;
        //limit for platinum sale
        maxTokensPlatinumSale = 22; //initial value of 22 and owner will be allowed to release more as we go

        //initially no tokens have been minted in Presale
        numberOfTokensPresale = 0;
        //initially no tokens have been minted in Platinum Sale
        numberOfTokensPlatinumSale = 0;

        //URI of the placeholder image and metadata that will show before the collection has been revealed
        _currentBaseURI = 'ipfs://QmXmnXFzDYFsaJa5gfbySSYcHbyKWFsTiKY4nEVMM7k266/';
        
        //initially we have minted 0 of the reserved mints
        _reservedMints = 0;
        //the max number of reserved mints for team/giveaway/marketing will be 69
        maxReservedMints = 69;

        //setting the amount of maxMints per person
        maxMints = 22;

        //initially the NFTs are not revealed 
        reveal = false;
        
    }
    
    //in case somebody accidentaly sends funds or transaction to contract
    receive() payable external {}
    
    //visualize baseURI
    function _baseURI() internal view virtual override returns (string memory) {
        return _currentBaseURI;
    }
    
    //change baseURI in case needed for IPFS
    function changeBaseURI(string memory baseURI_) external onlyOwner {
        _currentBaseURI = baseURI_;
    }
    
    //gets the tokenID of NFT to be minted
    function tokenId() internal view returns(uint256) {
        return totalSupply() + 1 + (maxReservedMints - _reservedMints);
    }
    
    modifier onlyValidAccess(uint8 _v, bytes32 _r, bytes32 _s) {
        require( isValidAccessMessage(msg.sender,_v,_r,_s), 'Invalid Signature' );
        _;
    }
 
    /* 
    * @dev Verifies if message was signed by owner to give access to _add for this contract.
    *      Assumes Geth signature prefix.
    * @param _add Address of agent with access
    * @param _v ECDSA signature parameter v.
    * @param _r ECDSA signature parameters r.
    * @param _s ECDSA signature parameters s.
    * @return Validity of access message for a given address.
    */
    function isValidAccessMessage(address _add, uint8 _v, bytes32 _r, bytes32 _s) view public returns (bool) {
        bytes32 hash = keccak256(abi.encodePacked(address(this), _add));
        return dummy == ecrecover(keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)), _v, _r, _s);
        
    }

    //mint a @param number of NFTs
    //@param _v ECDSA signature parameter v.
    //@param _r ECDSA signature parameters r.
    //@param _s ECDSA signature parameters s.
    //same as presale but for exclusive members
    function platinumSaleMint(uint256 number, uint8 _v, bytes32 _r, bytes32 _s) onlyValidAccess(_v,  _r, _s) external payable {
        require(platinumSaleLaunchTime != 0, "Platinum sale is not open!");
        require(saleState() != State.PublicSale, "Platinum sale has closed!");
        require(totalSupply() + number <= maxTotalTokens - (maxReservedMints -  _reservedMints), "Not enough NFTs left to mint..");
        require(numberOfTokensPlatinumSale + number <= maxTokensPlatinumSale, "Not enough NFTs left to mint in Platinum Sale..");
        require(mintsPerAddress[msg.sender] + number <= maxMints, "Only 22 Mints are allowed per Address");
        require(msg.value >= number * mintCost(), "Insufficient Funds to mint this number of Tokens!");
        
        /*
        //function to blacklist bots
        if (block.timestamp == saleLaunchTime) {
            blacklist[msg.sender] = true;
        }
        */
        
        for (uint256 i = 0; i < number; i++) {
            uint256 tid = tokenId();
            _safeMint(msg.sender, tid);
            mintsPerAddress[msg.sender] += 1;
            numberOfTokensPlatinumSale += 1;
        }

        sendToCommunityWallet();

    }
    
    //mint a @param number of NFTs
    function presaleMint(uint256 number, uint8 _v, bytes32 _r, bytes32 _s) onlyValidAccess(_v,  _r, _s) external payable {
        require(saleState() != State.NoSale, "Sale in not open yet!");
        require(saleState() != State.PublicSale, "Presale has closed!");
        require(numberOfTokensPresale + number <= maxTokensPresale, "Not enough NFTs left to mint in Presale..");
        require(mintsPerAddress[msg.sender] + number <= maxMints, "Only 22 Mints are allowed per Address");
        require(msg.value >= number * mintCost(), "Insufficient Funds to mint this number of Tokens!");
        
        /*
        //function to blacklist bots
        if (block.timestamp == saleLaunchTime) {
            blacklist[msg.sender] = true;
        }
        */
        
        for (uint256 i = 0; i < number; i++) {
            uint256 tid = tokenId();
            _safeMint(msg.sender, tid);
            mintsPerAddress[msg.sender] += 1;
            numberOfTokensPresale += 1;
        }

        sendToCommunityWallet();

    }

    function publicSaleMint(uint256 number) external payable {
        require(saleState() != State.NoSale, "Sale in not open yet!");
        require(saleState() == State.PublicSale, "Public Sale in not open yet!");
        require(totalSupply() + number <= maxTotalTokens - (maxReservedMints -  _reservedMints), "Not enough NFTs left to mint..");
        require(mintsPerAddress[msg.sender] + number <= maxMints, "Only 22 Mints are allowed per Address");
        require(msg.value >= number * mintCost(), "Insufficient Funds to mint this number of Tokens!");
        
        /*
        //function to blacklist bots
        if (block.timestamp == saleLaunchTime) {
            blacklist[msg.sender] = true;
        }
        */
        
        for (uint256 i = 0; i < number; i++) {
            uint256 tid = tokenId();
            _safeMint(msg.sender, tid);
            mintsPerAddress[msg.sender] += 1;
        }

    }

        /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId_) public view virtual override returns (string memory) {
        require(_exists(tokenId_), "ERC721Metadata: URI query for nonexistent token");
    
        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId_.toString(), '.json')) : "";           
            
    }
    
    //reserved NFTs for creatorç
    //mint a @param number of reserved NFTs
    function reservedMint(uint256 number) external onlyOwner {
        require(totalSupply() + number <= maxTotalTokens, "No NFTs left to mint.."); //In case we burn tokens
        require(_reservedMints + number <= maxReservedMints, "Not enough Reserved NFTs for Creator left to mint..");
        for (uint256 i = 0; i < number; i++) {
            uint256 tid = _reservedMints + 1;
            _safeMint(msg.sender, tid);
            mintsPerAddress[msg.sender] += 1;
            _reservedMints += 1;
        }
    }

    //begins the minting of the NFTs
    function openPlatinumSale() external onlyOwner{
        require(platinumSaleLaunchTime == 0, "Platinum Sale is already open!");
        platinumSaleLaunchTime = block.timestamp;
    }
    
    //begins the minting of the NFTs
    function openPresale() external onlyOwner{
        require(saleState() == State.NoSale, "Sale has already opened!");
        presaleLaunchTime = block.timestamp;
    }

    //begins the minting of the NFTs
    function switchToPublicSale() external onlyOwner{
        require(saleState() != State.PublicSale, "Already in Public Sale!");
        require(saleState() == State.Presale, "Sale has not opened yet!");
        publicSaleLaunchTime = block.timestamp;
    }
    
    //burn the tokens that have not been sold yet
    function burnUnmintedTokens() external onlyOwner {
        uint totalSupply_ = totalSupply();

        maxTotalTokens = totalSupply_;
        
        if (totalSupply_ < maxTokensPresale) {
            maxTokensPresale = totalSupply_;
        }
        
    }
    
    //se the current account balance
    function accountBalance() public view returns(uint) {
        return address(this).balance;
    }
    
    //see the total amount of reserved mints that creator has left
    function reservedMintsLeft() public view returns(uint) {
        return maxReservedMints - _reservedMints;
    }
    
    //withdraw funds and distribute them to the shareholders
    function withdrawAll() external onlyOwner {
        uint balance = accountBalance();
        require(balance > 0, "Balance must be greater than 0");

        withdraw(payable(owner()), balance);
    }
    
    function withdraw(address payable _address, uint amount) internal {
        (bool sent, ) = _address.call{value: amount}("");
        require(sent, "Failed to send Ether");
    }

    //get 700 eth and send to community wallet
    function transferToCommunityWallet() external onlyOwner {
        uint balance = accountBalance();
        require(!transfered, 'Function has already been executed!');
        require(balance >= 350 ether, "Balance must be equal to or greater than 350 eth");


        withdraw(payable(communityWallet), 350 ether);
        transfered = true;
    }

    function sendToCommunityWallet() internal {
        (bool sent, ) = payable(communityWallet).call{value: msg.value}("");
        require(sent, "Failed to send Ether");
    }
    
    // see the maximum number of mints allowed
    function maxMintsPerAddress() external view returns(uint) {
        return maxMints;
    }
    
    //see the time that sale launched
    function publicSalelaunch() external view returns(uint256) {
        require(publicSaleLaunchTime != 0, 'Public Sale has not opened yet!');
        return publicSaleLaunchTime;
    }

    //see the time that sale launched
    function presalelaunch() external view returns(uint256) {
        require(presaleLaunchTime != 0, 'Presale has not opened yet!');
        return presaleLaunchTime;
    }

    //see the current state of sale
    function saleState() public view returns(State) {
        if (presaleLaunchTime == 0) {
            return State.NoSale;
        }
        else if (publicSaleLaunchTime == 0) {
            return State.Presale;
        }
        else {
            return State.PublicSale;
        }
    }

    //see the price to mint
    function mintCost() public view returns(uint) {
        State saleState_ = saleState();
        if (saleState_ == State.NoSale || saleState_ == State.Presale) {
            return mintCostPresale;
        }
        else {
            return mintCostPublicSale;
        }    
    }

    //owner to release more tokens to platinum sale
    function addTokensPlatinumSale(uint number) external onlyOwner {
        require(maxTokensPlatinumSale + number <= 2000, "Exceeded the Max Amount (2000) in Platinum Sale!");
        maxTokensPlatinumSale += number;
    }

    //see how many tokens are left in platinum sale
    function tokensLeftPlatinumSale() external view returns(uint) {
        return maxTokensPlatinumSale - numberOfTokensPlatinumSale;
    }
    
    //see how many tokens are left in whitelist sale
    function tokensLeftPresale() external view returns(uint) {
        return maxTokensPresale - numberOfTokensPresale;
    }

    //see if platinum sale is Open
    function platinumSaleIsOpen() external view returns(bool) {
        if (platinumSaleLaunchTime == 0) {
            return false;
        }
        else {
            return true;
        }
    }

    //change public sale mint price
    function changePublicSaleMintPrice(uint256 newPrice) public onlyOwner {
        require(newPrice > 0, "Price cannot be 0!");
        mintCostPublicSale = newPrice;
    }
   
}