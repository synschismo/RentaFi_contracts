// SPDX-License-Identifier: agpl-3.0
pragma solidity =0.8.13;

interface ICK {
    function canBreedWith(uint256 _matronId, uint256 _sireId) external view returns(bool);
    function breedWithAuto(uint256 _matronId, uint256 _sireId) external payable;
    function transfer(address _to, uint256 _tokenId) external;
    function ownerOf(uint256 _tokenId) external view returns (address owner);
    function approve(address _to, uint256 _tokenId) external;
    function autoBirthFee() external returns (uint256);
}