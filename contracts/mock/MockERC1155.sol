// SPDX-License-Identifier: None
pragma solidity =0.8.13;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract MockERC1155 is ERC1155 {
    using Counters for Counters.Counter;
    Counters.Counter private totalCreated;
    string public name;
    string public symbol;

    constructor() ERC1155('') {
        name = 'Mock1155';
        symbol = 'M1155';
    }

    function mint(uint256 _amount, bytes memory _data) external {
        totalCreated.increment();
        _mint(msg.sender, totalCreated.current(), _amount, _data);
    }
}
