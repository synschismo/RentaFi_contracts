// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721PausableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol';

import './extentions/HasSecondarySaleFees.sol';
import './libraries/IPFS.sol';
import './libraries/LiteralStrings.sol';

import 'hardhat/console.sol';

contract ChocomoldRentable is
  Initializable,
  OwnableUpgradeable,
  ERC721Upgradeable,
  ERC721BurnableUpgradeable,
  ERC721PausableUpgradeable,
  HasSecondarySaleFees
{
  using StringsUpgradeable for uint256;
  using IPFS for bytes32;
  using IPFS for bytes;
  using LiteralStrings for bytes;

  mapping(uint256 => bytes32) public ipfsHashMemory;

  string public constant defaultBaseURI = 'https://factory.chocomint.app/metadata/';
  string public customBaseURI;

  function initialize(
    address _owner,
    string memory _name,
    string memory _symbol
  ) public initializer {
    __Ownable_init_unchained();
    transferOwnership(_owner);
    __ERC721_init_unchained(_name, _symbol);
  }

  function supportsInterface(bytes4 _interfaceId)
    public
    view
    override(ERC721Upgradeable, HasSecondarySaleFees)
    returns (bool)
  {
    return super.supportsInterface(_interfaceId);
  }

  function setDefaultRoyality(address payable[] memory _royaltyAddress, uint256[] memory _royalty)
    public
    onlyOwner
  {
    _setDefaultRoyality(_royaltyAddress, _royalty);
  }

  function setCustomRoyality(
    uint256 _tokenId,
    address payable[] memory _royaltyAddress,
    uint256[] memory _royalty
  ) public onlyOwner {
    _setRoyality(_tokenId, _royaltyAddress, _royalty);
  }

  function setCustomRoyality(
    uint256[] memory _tokenIdList,
    address payable[][] memory _royaltyAddressList,
    uint256[][] memory _royaltyList
  ) public onlyOwner {
    require(
      _tokenIdList.length == _royaltyAddressList.length &&
        _tokenIdList.length == _royaltyList.length,
      'input length must be same'
    );
    for (uint256 i = 0; i < _tokenIdList.length; i++) {
      _setRoyality(_tokenIdList[i], _royaltyAddressList[i], _royaltyList[i]);
    }
  }

  function _baseURI() internal view override returns (string memory) {
    return customBaseURI;
  }

  function setCustomBaseURI(string memory _customBaseURI) public onlyOwner {
    customBaseURI = _customBaseURI;
  }

  function _setIpfsHash(uint256 _tokenId, bytes32 _ipfsHash) internal {
    ipfsHashMemory[_tokenId] = _ipfsHash;
  }

  function setIpfsHash(uint256 _tokenId, bytes32 _ipfsHash) public onlyOwner {
    _setIpfsHash(_tokenId, _ipfsHash);
  }

  function setIpfsHash(uint256[] memory _tokenIdList, bytes32[] memory _ipfsHashList)
    public
    onlyOwner
  {
    require(_tokenIdList.length == _ipfsHashList.length, 'input length must be same');
    for (uint256 i = 0; i < _tokenIdList.length; i++) {
      _setIpfsHash(_tokenIdList[i], _ipfsHashList[i]);
    }
  }

  function mint(address _to, uint256 _tokenId) public onlyOwner {
    _mint(_to, _tokenId);
  }

  function mint(address[] memory _toList, uint256[] memory _tokenIdList) public onlyOwner {
    require(_toList.length == _tokenIdList.length, 'input length must be same');
    for (uint256 i = 0; i < _tokenIdList.length; i++) {
      _mint(_toList[i], _tokenIdList[i]);
    }
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal virtual override(ERC721Upgradeable, ERC721PausableUpgradeable) {
    if (from != to && _owners[tokenId].owner != address(0)) {
      delete _owners[tokenId];
      emit UpdateOwner(tokenId, address(0), address(0), 0);
    }
  }

  //ここからアップグレード
  // Mapping from token ID to OwnerInfo
  mapping(uint256 => OwnerInfo) public _owners; // Borrower's info

  // Array with all token ids, used for enumeration
  uint256[] public _allTokens;

  struct OwnerInfo {
    address owner; // address of user role
    address lender;
    uint256 expires; // unix timestamp, user expires
  }

  // RentaFi Native
  mapping(uint256 => address) private _superOwners; // as a ERC721.owners

  // Mapping owner address to token count
  mapping(address => uint256) private _balances; // Borrower's balance

  // RentaFi Native
  mapping(address => uint256) private _superOwnerBalances; // as a ERC721.balances

  // Mapping from token ID to approved address
  mapping(uint256 => address) private _tokenApprovals;

  // Mapping from owner to operator approvals
  mapping(address => mapping(address => bool)) private _operatorApprovals;

  /**
   * @dev See {IERC721-balanceOf}.
   */
  function balanceOf(address owner) public view virtual override returns (uint256) {
    //require(owner != address(0), 'ERC721: address zero is not a valid owner');
    //return _balances[owner];
    //発行されているすべてのtokenIdを検索する必要がある
    uint256 _rental;
    uint256 _lend;
    for (uint256 i = 0; i < _allTokens.length; i++) {
      // レンタル中であれば（この時点では誰が借りているかは不明
      if (_owners[_allTokens[i]].expires >= block.timestamp) {
        // 実行者がどれくらい該当するかを総和してく
        if (_owners[_allTokens[i]].owner == owner) {
          _rental++;
        }
        if (_owners[_allTokens[i]].lender == owner) {
          _lend++;
        }
      }
    }
    return _rental + superOwnerBalanceOf(owner) - _lend; // 自分で保有している分とレンタルしている分を合わせた数量を返す
  }

  // RentaFi Native
  function superOwnerBalanceOf(address superOwner) public view virtual returns (uint256) {
    require(superOwner != address(0), 'ERC721: address zero is not a valid owner');
    return _superOwnerBalances[superOwner];
  }

  /* MODIFIED
   * @dev See {IERC721-ownerOf}.
   */
  function ownerOf(uint256 tokenId) public view virtual override returns (address) {
    if (uint256(_owners[tokenId].expires) >= block.timestamp) {
      return _owners[tokenId].owner;
    } else {
      return superOwnerOf(tokenId);
    }
  }

  function setOwner(
    uint256 tokenId,
    address owner,
    uint64 expires
  ) public virtual {
    require(
      _isApprovedOrSuperOwner(msg.sender, tokenId),
      'ERC721: caller is not token superOwner nor approved'
    );
    OwnerInfo storage info = _owners[tokenId];
    info.owner = owner;
    info.expires = expires;
    info.lender = msg.sender;
    emit UpdateOwner(tokenId, owner, msg.sender, expires);
  }

  event UpdateOwner(
    uint256 indexed tokenId,
    address indexed owner,
    address indexed lender,
    uint64 expires
  );

  //RentaFi Native
  function ownerExpires(uint256 tokenId) public view returns (uint256) {
    return _owners[tokenId].expires;
  }

  // RentaFi Native
  function superOwnerOf(uint256 tokenId) public view virtual returns (address) {
    address superOwner = _superOwners[tokenId];
    require(superOwner != address(0), 'ERC721: invalid token ID');
    return superOwner;
  }

  /**
   * @dev See {IERC721Metadata-tokenURI}.
   */
  function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
    _requireMinted(tokenId);

    string memory baseURI = _baseURI();
    return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : '';
  }

  /**
   * @dev See {IERC721-approve}.
   */
  function approve(address to, uint256 tokenId) public virtual override {
    address superOwner = superOwnerOf(tokenId);
    require(to != superOwner, 'ERC721: approval to current superOwner');

    require(
      _msgSender() == superOwner || isApprovedForAll(superOwner, _msgSender()),
      'ERC721: approve caller is not token superOwner nor approved for all'
    );

    _approve(to, tokenId);
  }

  /**
   * @dev See {IERC721-getApproved}.
   */
  function getApproved(uint256 tokenId) public view virtual override returns (address) {
    _requireMinted(tokenId);

    return _tokenApprovals[tokenId];
  }

  /**
   * @dev See {IERC721-setApprovalForAll}.
   */
  function setApprovalForAll(address operator, bool approved) public virtual override {
    _setApprovalForAll(_msgSender(), operator, approved);
  }

  /**
   * @dev See {IERC721-isApprovedForAll}.
   */
  function isApprovedForAll(address superOwner, address operator)
    public
    view
    virtual
    override
    returns (bool)
  {
    return _operatorApprovals[superOwner][operator];
  }

  /**
   * @dev See {IERC721-transferFrom}.
   */
  function transferFrom(
    address from,
    address to,
    uint256 tokenId
  ) public virtual override {
    //solhint-disable-next-line max-line-length
    require(
      _isApprovedOrSuperOwner(_msgSender(), tokenId),
      'ERC721: caller is not token superOwner nor approved'
    );

    _transfer(from, to, tokenId);
  }

  /**
   * @dev See {IERC721-safeTransferFrom}.
   */
  function safeTransferFrom(
    address from,
    address to,
    uint256 tokenId
  ) public virtual override {
    safeTransferFrom(from, to, tokenId, '');
  }

  /**
   * @dev See {IERC721-safeTransferFrom}.
   */
  function safeTransferFrom(
    address from,
    address to,
    uint256 tokenId,
    bytes memory data
  ) public virtual override {
    require(
      _isApprovedOrSuperOwner(_msgSender(), tokenId),
      'ERC721: caller is not token superOwner nor approved'
    );
    _safeTransfer(from, to, tokenId, data);
  }

  /**
   * @dev Returns whether `spender` is allowed to manage `tokenId`.
   *
   * Requirements:
   *
   * - `tokenId` must exist.
   */
  function _isApprovedOrSuperOwner(address spender, uint256 tokenId)
    internal
    view
    virtual
    returns (bool)
  {
    address superOwner = superOwnerOf(tokenId);
    return (spender == superOwner ||
      isApprovedForAll(superOwner, spender) ||
      getApproved(tokenId) == spender);
  }

  /**
   * @dev Safely mints `tokenId` and transfers it to `to`.
   *
   * Requirements:
   *
   * - `tokenId` must not exist.
   * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
   *
   * Emits a {Transfer} event.
   */
  function _safeMint(address to, uint256 tokenId) internal virtual override {
    _safeMint(to, tokenId, '');
  }

  /**
   * @dev Mints `tokenId` and transfers it to `to`.
   *
   * WARNING: Usage of this method is discouraged, use {_safeMint} whenever possible
   *
   * Requirements:
   *
   * - `tokenId` must not exist.
   * - `to` cannot be the zero address.
   *
   * Emits a {Transfer} event.
   */
  function _mint(address to, uint256 tokenId) internal virtual override {
    require(to != address(0), 'ERC721: mint to the zero address');
    require(!_exists(tokenId), 'ERC721: token already minted');

    _beforeTokenTransfer(address(0), to, tokenId);

    _superOwnerBalances[to] += 1;
    _superOwners[tokenId] = to;
    _allTokens.push(tokenId);

    emit Transfer(address(0), to, tokenId);

    _afterTokenTransfer(address(0), to, tokenId);
  }

  /**
   * @dev Destroys `tokenId`.
   * The approval is cleared when the token is burned.
   *
   * Requirements:
   *
   * - `tokenId` must exist.
   *
   * Emits a {Transfer} event.
   */
  function _burn(uint256 tokenId)
    internal
    virtual
    override(ERC721Upgradeable, HasSecondarySaleFees)
  {
    address superOwner = superOwnerOf(tokenId);

    _beforeTokenTransfer(superOwner, address(0), tokenId);

    // Clear approvals
    _approve(address(0), tokenId);

    _superOwnerBalances[superOwner] -= 1;
    delete _superOwners[tokenId];

    for (uint256 i = 0; i < _allTokens.length; i++) {
      if (_allTokens[i] == tokenId) {
        if (i != _allTokens.length - 1) {
          _allTokens[i] = _allTokens[_allTokens.length - 1];
        }
        _allTokens.pop();
        break;
      }
    }

    emit Transfer(superOwner, address(0), tokenId);

    _afterTokenTransfer(superOwner, address(0), tokenId);
  }

  /**
   * @dev Transfers `tokenId` from `from` to `to`.
   *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
   *
   * Requirements:
   *
   * - `to` cannot be the zero address.
   * - `tokenId` token must be owned by `from`.
   *
   * Emits a {Transfer} event.
   */
  function _transfer(
    address from,
    address to,
    uint256 tokenId
  ) internal virtual override {
    require(superOwnerOf(tokenId) == from, 'ERC721: transfer from incorrect superOwner');
    require(to != address(0), 'ERC721: transfer to the zero address');

    _beforeTokenTransfer(from, to, tokenId);

    // Clear approvals from the previous owner
    _approve(address(0), tokenId);

    _superOwnerBalances[from] -= 1;
    _superOwnerBalances[to] += 1;
    _superOwners[tokenId] = to;

    emit Transfer(from, to, tokenId);

    _afterTokenTransfer(from, to, tokenId);
  }

  /**
   * @dev Approve `to` to operate on `tokenId`
   *
   * Emits an {Approval} event.
   */
  function _approve(address to, uint256 tokenId) internal virtual override {
    _tokenApprovals[tokenId] = to;
    emit Approval(superOwnerOf(tokenId), to, tokenId);
  }

  /**
   * @dev Approve `operator` to operate on all of `owner` tokens
   *
   * Emits an {ApprovalForAll} event.
   */
  function _setApprovalForAll(
    address superOwner,
    address operator,
    bool approved
  ) internal virtual override {
    require(superOwner != operator, 'ERC721: approve to caller');
    _operatorApprovals[superOwner][operator] = approved;
    emit ApprovalForAll(superOwner, operator, approved);
  }

  /**
   * @dev Reverts if the `tokenId` has not been minted yet.
   */
  function _requireMinted(uint256 tokenId) internal view virtual override {
    require(_exists(tokenId), 'ERC721: invalid token ID');
  }

  /**
   * @dev Hook that is called after any transfer of tokens. This includes
   * minting and burning.
   *
   * Calling conditions:
   *
   * - when `from` and `to` are both non-zero.
   * - `from` and `to` are never both zero.
   *
   * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
   */
  function _afterTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal virtual override {}
}
