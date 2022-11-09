// SPDX-License-Identifier: None
pragma solidity =0.8.13;

import '../interfaces/IMarket.sol';
import '../vaults/Vault721.sol';
import '../libraries/RentaFiSVG.sol';
import '../CryptoKitties/ICryptoKitties.sol';

interface IFlashloanReceiver {
  function executeOperation(address tokenAddress, uint256 _tokenId) external payable;
}

contract VaultCK is Vault721 {
  constructor(
    string memory _name,
    string memory _symbol,
    address _collection,
    address _collectionOwner,
    address _marketContract,
    uint256 _minDuration,
    uint256 _maxDuration,
    uint256 _collectionOwnerFeeRatio,
    uint256[] memory _minPrices,
    address[] memory _paymentTokens, // 'Stack too deep' error because of too many args!
    uint256[] memory _allowedTokenIds
  )
    Vault721(
      _name,
      _symbol,
      _collection,
      _collectionOwner,
      _marketContract,
      _minDuration,
      _maxDuration,
      _collectionOwnerFeeRatio,
      _minPrices,
      _paymentTokens,
      _allowedTokenIds
    )
  {}

  function _deployWrap() internal override {}

  function activate(
    uint256 _rentId,
    uint256 _lockId,
    address _renter,
    uint256 _amount
  ) external view override onlyMarket {
    require(false, 'onlyFlashloan');
    _rentId;
    _lockId;
    _renter;
    _amount;
  }

  function flashloan(
    address _collection,
    uint256 _tokenId,
    address _receiver
  ) public payable {
    //initialize
    //IMarket.Lend memory _lend = IMarket(marketContract).getLendRent(_lockId).lend;
    //uint256 autoBirthFee = ICK(collection).autoBirthFee();
    //uint256 flashloanFee = _lend.dailyRentalPrice * 17 / 10000;
    //require(msg.value >= autoBirthFee + flashloanFee);
    //payment
    //uint256 protocolFee = flashloanFee / 2;
    //uint256 lenderFee = flashloanFee - protocolFee;
    //payable(IMarket(marketContract).owner()).transfer(protocolFee);
    //payable(_lend.lender).transfer(lenderFee);

    //set user's contract
    IFlashloanReceiver receiver = IFlashloanReceiver(_receiver);
    //store before owner and transfer
    address ownerAddressBefore = ICK(_collection).ownerOf(_tokenId);
    ICK(_collection).transfer(_receiver, _tokenId);
    //execute user's contract
    receiver.executeOperation{value: msg.value}(_collection, _tokenId);
    //check after owner
    address ownerAddressAfter = ICK(_collection).ownerOf(_tokenId);
    require(ownerAddressBefore == ownerAddressAfter, 'Invalid flashloan');
  }

  function redeem(uint256 _lockId) external virtual override onlyMarket {
    IMarket.Lend memory _lend = IMarket(marketContract).getLendRent(_lockId).lend;
    require(msg.sender == _lend.lender || msg.sender == marketContract, 'not lender or market');
    // Send tokens back from Vault contract to the user's wallet
    ICK(originalCollection).transfer(_lend.lender, _lend.tokenId);
  }
}
