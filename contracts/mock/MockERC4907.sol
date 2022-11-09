// SPDX-License-Identifier: None
pragma solidity =0.8.13;

import '../ERC4907/ERC4907.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/utils/Strings.sol';

contract MockERC4907 is ERC4907 {
  using Counters for Counters.Counter;
  Counters.Counter private totalCreated;

  constructor() ERC4907('Mock4907', 'M4907') {}

  function tokenURI(uint256 tokenId) public pure override returns (string memory) {
    return Strings.toString(tokenId);
  }

  function mint() external {
    totalCreated.increment();
    _mint(msg.sender, totalCreated.current());
  }

  function burn(uint256 _tokenId) external {
    _burn(_tokenId);
  }
}
