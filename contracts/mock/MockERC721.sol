// SPDX-License-Identifier: None
pragma solidity =0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract MockERC721 is ERC721 {
    using Counters for Counters.Counter;
    Counters.Counter private totalCreated;

    constructor() ERC721("Mock721", "M721") {}

    function tokenURI(uint256 tokenId) public pure override returns (string memory) {
        return Strings.toString(tokenId);
    }

    function mint() external {
        totalCreated.increment();
        _mint(msg.sender, totalCreated.current());
    }
}
