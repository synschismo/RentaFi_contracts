// SPDX-License-Identifier: None
pragma solidity =0.8.13;

import '../CryptoKitties/ICryptoKitties.sol';
import '../interfaces/IVault.sol';
import 'hardhat/console.sol';

contract MockFlashloanNFT {
  address _vault;
  uint256 _matronId;

  constructor() {}

  function executeOperation(address cryptoKittie, uint256 tokenId) public payable {
    ICK(cryptoKittie).breedWithAuto{value: msg.value}(_matronId, tokenId);

    //transfer funds to the receiver
    ICK(cryptoKittie).transfer(_vault, tokenId);
  }

  function flashBreed(
    address vault,
    address cryptoKittie,
    uint256 matronId,
    uint256 tokenId
  ) public payable {
    console.log('flashbreed');
    _vault = vault;
    _matronId = matronId;

    IVault(_vault).flashloan{value: msg.value}(cryptoKittie, tokenId, address(this));
  }
}
