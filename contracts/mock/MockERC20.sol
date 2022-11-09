// SPDX-License-Identifier: None
pragma solidity =0.8.13;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract MockERC20 is ERC20 {
  constructor() ERC20('Mock', 'M20') {}

  function mint(address account, uint256 amount) public {
    _mint(account, amount);
  }
}
