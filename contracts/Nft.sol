// contracts/GameItem.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract GameItem is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    bool isSBT = true;
    uint256 MintMaxTotal = 1000;
    string baseURI;
    string contractMetadata;
    address owner;
    mapping(address => bool) public whiteLists;

    constructor(string memory _baseURI, string memory _contractMetadata) ERC721("GameItem", "ITM") {
        baseURI = _baseURI;
        contractMetadata = _contractMetadata;
        owner = msg.sender;
    }

    function mint(address player,string memory tokenURI)
        public
        returns (uint256)
    {
        // require(whiteLists[player], "This address is not white");
        
        uint256 newItemId = _tokenIds.current();
        // string memory tokenURI = getTokenURI(newItemId);
        require(MintMaxTotal >= newItemId, "Max overflow !");
        _mint(player, newItemId);
        _setTokenURI(newItemId, tokenURI);

        _tokenIds.increment();
        return newItemId;
    }

    function setWhiteLists (address _userAddress , bool _whiteState) public byOwner(){
        whiteLists[_userAddress] = _whiteState;
    }

    function contractURI() public pure returns (string memory) {
        return "https://raw.githubusercontent.com/nextniko/web3-Intelligent-contract/main/njl-nft.json";
    }

    // function getTokenURI (uint256 index) private pure returns(string memory) {
    //     string memory indexString = Strings.toString(index);
    //     string memory headerString = "https://raw.githubusercontent.com/nextniko/web3-Intelligent-contract/main/";
    //     string memory footerString = ".json";
    //     string memory tokenURI = string.concat(
    //         headerString,
    //         indexString,
    //         footerString
    //     );
    //     return tokenURI;
    // }

    modifier byOwner(){
        require(msg.sender == owner, "Not owner!");
        _;
    }
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override{
        require(!isSBT, "SBT can not be trasnfer!");
    }
}
