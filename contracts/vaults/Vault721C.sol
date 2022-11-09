// SPDX-License-Identifier: None
pragma solidity =0.8.13;

import './Vault721.sol';

contract Vault721C is Vault721 {
  enum CoolTimeMode {
    Disabled,
    Ratio,
    Days
  }

  struct CoolTimeSetting {
    CoolTimeMode mode;
    uint256 duration;
  }
  // lender => coolTime
  mapping(address => CoolTimeSetting) public lenderCoolTime;
  CoolTimeSetting public vaultCoolTime;

  struct CoolTime {
    CoolTimeMode mode;
    uint256 starts;
    uint256 expires;
  }
  // tokenId => CoolTime[]
  mapping(uint256 => CoolTime[]) private coolTimes;
  event CoolTimeStart(CoolTimeMode mode, uint256 duration);

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

  function setVaultCoolTime(CoolTimeMode _mode, uint256 _coolTimeByDayOrRatio)
    external
    onlyCollectionOwner
  {
    uint256 _duration = _coolTimeByDayOrRatio;
    if (_mode == CoolTimeMode.Days) {
      _duration = _coolTimeByDayOrRatio * 1 days;
    }
    vaultCoolTime = CoolTimeSetting({mode: _mode, duration: _duration});
  }

  function setLenderCoolTime(
    address _lender,
    CoolTimeMode _mode,
    uint256 _coolTimeByDayOrRatio
  ) external onlyCollectionOwner {
    uint256 _duration = _coolTimeByDayOrRatio;
    if (_mode == CoolTimeMode.Days) {
      _duration = _coolTimeByDayOrRatio * 1 days;
    }
    lenderCoolTime[_lender] = CoolTimeSetting({mode: _mode, duration: _duration});
  }

  function mintWNft(
    address _renter,
    uint256 _starts,
    uint256 _expires,
    uint256 _lockId,
    uint256 _tokenId,
    uint256 _amount
  ) public override onlyMarket {
    uint256 _now = block.timestamp;
    // If it starts later, only book and return.
    if (_starts > _now) return;

    CoolTime[] storage _coolTimes = coolTimes[_tokenId];

    // Check availability
    unchecked {
      for (uint256 i = 0; i < _coolTimes.length; i++) {
        require(_coolTimes[i].starts > _expires || _starts > _coolTimes[i].expires, 'CoolTime');
      }
    }

    // Delete expired coolTimes
    unchecked {
      for (uint256 i = 1; i <= _coolTimes.length; i++) {
        if (_coolTimes[i - 1].expires < _now) {
          if (_coolTimes[_coolTimes.length - 1].expires >= _now) {
            _coolTimes[i - 1] = _coolTimes[_coolTimes.length - 1];
          } else {
            i--;
          }
          _coolTimes.pop();
        }
      }
    }

    address _lender = IMarket(marketContract).getLendRent(_lockId).lend.lender;

    // CoolTime settings
    if (
      vaultCoolTime.mode != CoolTimeMode.Disabled ||
      lenderCoolTime[_lender].mode != CoolTimeMode.Disabled
    ) {
      uint256 _duration = 0;
      CoolTimeMode _mode = CoolTimeMode.Disabled;
      if (vaultCoolTime.mode != CoolTimeMode.Disabled) {
        if (vaultCoolTime.mode == CoolTimeMode.Ratio) {
          uint256 _originalDuration = _expires - _starts;
          _duration = vaultCoolTime.duration * _originalDuration;
          _mode = CoolTimeMode.Ratio;
        } else {
          _duration = vaultCoolTime.duration;
          _mode = CoolTimeMode.Days;
        }
      }
      if (lenderCoolTime[_lender].mode != CoolTimeMode.Disabled) {
        if (lenderCoolTime[_lender].mode == CoolTimeMode.Ratio) {
          uint256 _originalDuration = _expires - _starts;
          _duration = lenderCoolTime[_lender].duration * _originalDuration;
          _mode = CoolTimeMode.Ratio;
        } else {
          _duration = lenderCoolTime[_lender].duration;
          _mode = CoolTimeMode.Days;
        }
      }
      coolTimes[_tokenId].push(
        CoolTime({mode: _mode, starts: _expires, expires: _expires + _duration})
      );
      emit CoolTimeStart(_mode, _duration);
    }

    _mintWNft(_renter, _lockId, _tokenId, _amount);
  }

  function _mintWNft(
    address _renter,
    uint256 _lockId,
    uint256 _tokenId,
    uint256 _amount
  ) internal override {
    _amount;
    IWrap721(wrapContract).emitTransfer(address(this), _renter, _tokenId, _lockId);
  }
}
